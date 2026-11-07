import 'dart:math' as math;
import 'dart:typed_data';

import 'script_document.dart';
import 'text_normalizer.dart';

/// One recognized word with its position in the session's audio, in seconds.
class SpokenWord {
  final String text;
  final double start;
  final double end;
  const SpokenWord(this.text, this.start, this.end);
}

/// A script word the reader said differently.
class Misread {
  final int wordIndex;
  final String expected;
  final String said;
  const Misread(this.wordIndex, this.expected, this.said);
}

/// A run of consecutive script words that was never read.
class SkippedRange {
  final int firstWord;
  final int lastWord;
  const SkippedRange(this.firstWord, this.lastWord);
  int get length => lastWord - firstWord + 1;
}

/// Results of one practice take.
class PerformanceStats {
  final Map<String, int> fillers;
  final int spokenWords;
  final int scriptWordsCovered;
  final int matchedWords;
  final List<Misread> misreads;
  final List<SkippedRange> skipped;
  final int repeats;
  final List<String> extraWords;
  final int longPauses;
  final double longestPause;
  final double speakingSeconds;

  const PerformanceStats({
    required this.fillers,
    required this.spokenWords,
    required this.scriptWordsCovered,
    required this.matchedWords,
    required this.misreads,
    required this.skipped,
    required this.repeats,
    required this.extraWords,
    required this.longPauses,
    required this.longestPause,
    required this.speakingSeconds,
  });

  static const empty = PerformanceStats(
    fillers: {},
    spokenWords: 0,
    scriptWordsCovered: 0,
    matchedWords: 0,
    misreads: [],
    skipped: [],
    repeats: 0,
    extraWords: [],
    longPauses: 0,
    longestPause: 0,
    speakingSeconds: 0,
  );

  int get fillerCount => fillers.values.fold(0, (a, b) => a + b);
  int get skippedWords => skipped.fold(0, (a, r) => a + r.length);

  /// Words per minute of actual speaking time (fillers excluded).
  double get wordsPerMinute =>
      speakingSeconds < 5 ? 0 : spokenWords / speakingSeconds * 60;

  /// Share of the attempted script read correctly.
  double get accuracy {
    final attempted = matchedWords + misreads.length + skippedWords;
    return attempted == 0 ? 1.0 : matchedWords / attempted;
  }

  double get fillersPerMinute =>
      speakingSeconds < 5 ? 0 : fillerCount / speakingSeconds * 60;
}

/// Accumulates what was said, one finalized utterance at a time, and scores
/// it against the script: fillers, misreads, skipped lines, repeats, pauses.
///
/// Each utterance is aligned to a window of the script around where the
/// tracker says the reader is, with an affine-gap alignment so that skipping a
/// whole sentence is one cheap gap rather than many expensive deletions.
class PerformanceAnalyzer {
  PerformanceAnalyzer(this.script, {int startUnit = 0})
    : _startUnit = startUnit.clamp(0, script.length) {
    _readCount = Uint16List(script.length);
  }

  final ScriptDocument script;
  final int _startUnit;
  late final Uint16List _readCount;
  final Map<String, int> _fillers = {};
  final Map<int, Misread> _misreads = {};
  final List<String> _extra = [];
  int _spoken = 0;
  int _repeats = 0;
  int _maxUnitRead = -1;
  int _minUnitRead = 1 << 30;

  // Timing, per recognition session (audio times restart with each session).
  double? _sessionFirstStart;
  double? _lastEnd;
  double _closedSessionsSeconds = 0;
  double _openSessionSeconds = 0;
  int _longPauses = 0;
  double _longestPause = 0;

  static const longPauseSeconds = 2.0;

  static const _matchExactContent = 1.0;
  static const _nearFactor = 0.5;
  static const _substitution = -1.0;
  static const _insertion = -0.7;
  static const _fillerInsertion = -0.1;
  static const _gapOpen = -1.6;
  static const _gapExtend = -0.1;

  /// Call when a new recognition session starts (its audio clock restarts).
  void beginSession() {
    _closedSessionsSeconds += _openSessionSeconds;
    _openSessionSeconds = 0;
    _sessionFirstStart = null;
    _lastEnd = null;
  }

  /// Adds one finalized utterance. [anchorUnit] is the tracker's position
  /// when it arrived; the utterance is matched against the script around it.
  void addUtterance(List<SpokenWord> words, {required int anchorUnit}) {
    if (words.isEmpty) return;
    _recordTiming(words);

    final tokens = <String>[];
    for (final word in words) {
      tokens.addAll(script.normalizeSpeech(word.text));
    }
    if (tokens.isEmpty) return;

    final anchor = anchorUnit.clamp(0, script.length);
    final lo = math.max(0, anchor - tokens.length * 2 - 40);
    final hi = math.min(script.length, anchor + 30 + tokens.length ~/ 2);
    _classify(tokens, _align(tokens, lo, hi), lo);
  }

  PerformanceStats get stats {
    final skipped = <SkippedRange>[];
    if (_maxUnitRead >= 0) {
      final from = math.min(_startUnit, _minUnitRead);
      int? runStart;
      for (var u = from; u <= _maxUnitRead + 1; u++) {
        final unread = u <= _maxUnitRead && _readCount[u] == 0;
        if (unread) {
          runStart ??= u;
        } else if (runStart != null) {
          skipped.add(
            SkippedRange(script.unitWord[runStart], script.unitWord[u - 1]),
          );
          runStart = null;
        }
      }
    }
    var covered = 0;
    var matched = 0;
    for (var u = 0; u < script.length; u++) {
      if (_readCount[u] > 0) {
        covered++;
        if (!_misreads.containsKey(u)) matched++;
      }
    }
    return PerformanceStats(
      fillers: Map.unmodifiable(_fillers),
      spokenWords: _spoken,
      scriptWordsCovered: covered,
      matchedWords: matched,
      misreads: List.unmodifiable(_misreads.values),
      skipped: skipped,
      repeats: _repeats,
      extraWords: List.unmodifiable(_extra),
      longPauses: _longPauses,
      longestPause: _longestPause,
      speakingSeconds: _closedSessionsSeconds + _openSessionSeconds,
    );
  }

  void _recordTiming(List<SpokenWord> words) {
    for (final word in words) {
      final hasTime = word.end > 0 || word.start > 0;
      if (!hasTime) continue;
      _sessionFirstStart ??= word.start;
      final last = _lastEnd;
      if (last != null) {
        final gap = word.start - last;
        if (gap >= longPauseSeconds) {
          _longPauses++;
          _longestPause = math.max(_longestPause, gap);
        }
      }
      _lastEnd = math.max(last ?? 0, word.end);
      _openSessionSeconds = _lastEnd! - _sessionFirstStart!;
    }
  }

  double _substitutionScore(String token, int unit) {
    final target = script.units[unit];
    final weight = script.unitWeight[unit] * _matchExactContent;
    if (token == target) return weight;
    if (Fillers.isVocal(token)) return double.negativeInfinity;
    if (TextNormalizer.isNearMatch(token, target)) return weight * _nearFactor;
    return _substitution;
  }

  /// Affine-gap semi-global alignment of [tokens] to units [lo, hi): the
  /// window's leading and trailing units are free, gaps inside cost
  /// open + extend. Returns ops: >= 0 is "token read unit", -1 "extra token".
  List<int> _align(List<String> tokens, int lo, int hi) {
    final t = tokens.length;
    final m = hi - lo;
    const negInf = double.negativeInfinity;
    // Three layers: 0 = diagonal, 1 = extra token, 2 = skipped unit.
    final score = List.generate(3, (_) => Float64List((t + 1) * (m + 1)));
    final from = List.generate(3, (_) => Uint8List((t + 1) * (m + 1)));
    int at(int i, int j) => i * (m + 1) + j;

    for (var j = 0; j <= m; j++) {
      score[0][at(0, j)] = 0; // free leading units
      score[1][at(0, j)] = negInf;
      score[2][at(0, j)] = negInf;
    }
    for (var i = 1; i <= t; i++) {
      final ins = Fillers.isFillerWord(tokens[i - 1])
          ? _fillerInsertion
          : _insertion;
      for (var j = 0; j <= m; j++) {
        final c = at(i, j);
        // Diagonal: token i reads unit j.
        if (j > 0) {
          final p = at(i - 1, j - 1);
          final b = _bestLayer(score, p);
          score[0][c] =
              score[b][p] + _substitutionScore(tokens[i - 1], lo + j - 1);
          from[0][c] = b;
        } else {
          score[0][c] = negInf;
        }
        // Extra token: stays on unit j.
        final p = at(i - 1, j);
        final b = _bestLayer(score, p);
        score[1][c] = score[b][p] + ins;
        from[1][c] = b;
        // Skipped unit j.
        if (j > 0) {
          final q = at(i, j - 1);
          final open = math.max(score[0][q], score[1][q]) + _gapOpen;
          final extend = score[2][q] + _gapExtend;
          if (extend >= open) {
            score[2][c] = extend;
            from[2][c] = 2;
          } else {
            score[2][c] = open;
            from[2][c] = score[0][q] >= score[1][q] ? 0 : 1;
          }
        } else {
          score[2][c] = negInf;
        }
      }
    }

    // Free trailing units: end wherever the last token scores best.
    var endJ = 0;
    var endLayer = 0;
    var endScore = negInf;
    for (var j = 0; j <= m; j++) {
      for (var layer = 0; layer < 2; layer++) {
        final v = score[layer][at(t, j)];
        if (v > endScore) {
          endScore = v;
          endJ = j;
          endLayer = layer;
        }
      }
    }

    final ops = List<int>.filled(t, -1);
    var i = t, j = endJ, layer = endLayer;
    while (i > 0) {
      final prev = from[layer][at(i, j)];
      switch (layer) {
        case 0:
          ops[i - 1] = j - 1;
          i--;
          j--;
        case 1:
          ops[i - 1] = -1;
          i--;
        default:
          j--;
      }
      layer = prev;
    }
    return ops;
  }

  static int _bestLayer(List<Float64List> score, int index) {
    var best = 0;
    if (score[1][index] > score[best][index]) best = 1;
    if (score[2][index] > score[best][index]) best = 2;
    return best;
  }

  void _classify(List<String> tokens, List<int> ops, int lo) {
    var inRepeat = false;
    var i = 0;
    while (i < tokens.length) {
      final token = tokens[i];
      final op = ops[i];
      if (op >= 0) {
        final unit = lo + op;
        final wasRead = _readCount[unit] > 0;
        if (_readCount[unit] < 65535) _readCount[unit]++;
        _maxUnitRead = math.max(_maxUnitRead, unit);
        _minUnitRead = math.min(_minUnitRead, unit);
        _spoken++;
        final target = script.units[unit];
        if (!TextNormalizer.isNearMatch(token, target)) {
          _misreads.putIfAbsent(
            unit,
            () => Misread(
              script.unitWord[unit],
              script.words[script.unitWord[unit]],
              token,
            ),
          );
        } else {
          _misreads.remove(unit);
        }
        if (wasRead && !inRepeat) {
          // Reading the same script words again = going back over them.
          _repeats++;
          inRepeat = true;
        } else if (!wasRead) {
          inRepeat = false;
        }
        i++;
        continue;
      }

      // A run of extra tokens: fillers, a false start, or an ad-lib.
      var end = i;
      while (end < tokens.length && ops[end] < 0) {
        end++;
      }
      final words = <String>[];
      for (var k = i; k < end; k++) {
        final phrase = _phraseAt(tokens, ops, k);
        if (phrase != null) {
          _count(phrase.join(' '));
          k += phrase.length - 1;
        } else if (Fillers.isFillerWord(tokens[k])) {
          _count(Fillers.label(tokens[k]));
        } else {
          words.add(tokens[k]);
        }
      }
      if (words.isNotEmpty) {
        _spoken += words.length;
        // Words that echo the script right before or after the run are a
        // restart ("drink a glass of, drink a glass of water"), not an ad-lib.
        final nearby = _unitsAround(ops, lo, i, end);
        if (words.where(nearby.contains).length * 2 >= words.length) {
          if (!inRepeat) _repeats++;
          inRepeat = true;
        } else {
          _extra.addAll(words);
          inRepeat = false;
        }
      }
      i = end;
    }
  }

  Set<String> _unitsAround(List<int> ops, int lo, int start, int end) {
    const span = 8;
    final out = <String>{};
    var seen = 0;
    for (var k = start - 1; k >= 0 && seen < span; k--) {
      if (ops[k] >= 0) {
        out.add(script.units[lo + ops[k]]);
        seen++;
      }
    }
    seen = 0;
    for (var k = end; k < ops.length && seen < span; k++) {
      if (ops[k] >= 0) {
        out.add(script.units[lo + ops[k]]);
        seen++;
      }
    }
    return out;
  }

  List<String>? _phraseAt(List<String> tokens, List<int> ops, int i) {
    for (final phrase in Fillers.phrases) {
      if (i + phrase.length > tokens.length) continue;
      var ok = true;
      for (var k = 0; k < phrase.length; k++) {
        if (tokens[i + k] != phrase[k] || ops[i + k] >= 0) {
          ok = false;
          break;
        }
      }
      if (ok) return phrase;
    }
    return null;
  }

  void _count(String label) => _fillers[label] = (_fillers[label] ?? 0) + 1;
}
