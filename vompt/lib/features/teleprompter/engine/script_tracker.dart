import 'dart:math' as math;
import 'dart:typed_data';

import 'script_document.dart';
import 'text_normalizer.dart';

/// Follows a reader through a script from a live, revisable transcript.
///
/// This is an online Viterbi alignment: every script position keeps a score
/// that is updated for each recognized word, with costs for skipping ahead,
/// going back, misreading, and saying words that are not in the script.
/// Because every position stays alive, a wrong guess (say, an ad-lib that
/// happens to match later text) corrects itself as soon as the reader carries
/// on, instead of stranding the highlight.
///
/// Recognizers keep revising the end of their transcript while you speak.
/// [update] takes the whole transcript each time, rolls back to the last word
/// that did not change, and replays from there.
class ScriptTracker {
  ScriptTracker(this.script) : _n = script.length {
    _pred = Float64List(_n);
    _match = Float64List(_n);
    _next = Float64List(_n + 1);
    reset();
  }

  final ScriptDocument script;
  final int _n;

  // Scores are log-domain: higher is better.
  static const _skipOpen = 0.3;
  static const _skipPerWord = 0.25;
  static const _skipCap = 6.0;
  static const _backOpen = 1.0;
  static const _backPerWord = 0.08;
  static const _backCap = 6.0;
  static const _mismatch = -1.0;
  static const _insertion = -0.8;
  static const _fillerInsertion = -0.15;
  static const _nearMatchFactor = 0.55;
  static const _fuzzyBehind = 20;
  static const _fuzzyAhead = 40;
  static const _maxHistory = 80;

  /// How far ahead the highlight follows the best guess without hesitation.
  static const _localAhead = 15;

  /// Margins a guess must win by before the highlight moves backward or makes
  /// a far jump, so one stray word never yanks the screen around.
  static const _backMargin = 0.6;
  static const _jumpMargin = 1.5;

  /// State s means units [0, s) have been read; s ranges over 0.._n.
  late Float64List _scores;
  late final Float64List _pred;
  late final Float64List _match;
  late final Float64List _next;
  int _display = 0;

  final List<String> _processed = [];
  final List<_Snapshot> _history = [];
  int _historyBase = 0;
  int _ignoreBefore = 0;

  /// Index of the last on-screen word read, or -1 before the first.
  int get currentWordIndex =>
      _display == 0 ? -1 : script.unitWord[_display - 1];

  /// The next unit the reader is expected to say.
  int get position => _display;

  bool get isAtEnd => _display >= _n;

  /// Starts over with the reader positioned before [startUnit].
  void reset({int startUnit = 0}) {
    final start = startUnit.clamp(0, _n);
    _scores = Float64List(_n + 1);
    for (var s = 0; s <= _n; s++) {
      _scores[s] = -_moveCost(start, s);
    }
    _display = start;
    _ignoreBefore = 0;
    _clearHistory();
  }

  /// Moves the reader to on-screen word [wordIndex] (next to be read), e.g.
  /// after a tap. Words already in the current transcript are ignored.
  void jumpToWord(int wordIndex) {
    final ignore = _ignoreBefore + _processed.length;
    reset(startUnit: script.unitForWord(wordIndex));
    _ignoreBefore = ignore;
  }

  /// Call when the recognizer starts a fresh transcript (a new listening
  /// session). The reader's position carries over.
  void beginTranscript() {
    _ignoreBefore = 0;
    _clearHistory();
  }

  /// Feeds the full normalized transcript of the current session.
  /// Returns true if the highlighted word changed.
  bool update(List<String> transcript) {
    final tokens = transcript.length > _ignoreBefore
        ? transcript.sublist(_ignoreBefore)
        : const <String>[];
    final before = _display;

    var common = 0;
    final limit = math.min(tokens.length, _processed.length);
    while (common < limit && tokens[common] == _processed[common]) {
      common++;
    }
    if (common < _processed.length) {
      // Revisions deeper than the kept history are accepted as they were.
      final restoreAt = math.max(common, _historyBase);
      _restore(_history[restoreAt - _historyBase]);
      _processed.length = restoreAt;
      _history.length = restoreAt - _historyBase + 1;
      common = restoreAt;
    }
    for (var k = common; k < tokens.length; k++) {
      _step(tokens[k]);
      _processed.add(tokens[k]);
      _history.add(_Snapshot(Float64List.fromList(_scores), _display));
      if (_history.length > _maxHistory) {
        _history.removeAt(0);
        _historyBase++;
      }
    }
    return _display != before;
  }

  void _clearHistory() {
    _processed.clear();
    _history
      ..clear()
      ..add(_Snapshot(Float64List.fromList(_scores), _display));
    _historyBase = 0;
  }

  void _restore(_Snapshot snapshot) {
    _scores.setAll(0, snapshot.scores);
    _display = snapshot.display;
  }

  double _moveCost(int from, int to) {
    if (to == from) return 0;
    if (to > from) {
      return math.min(_skipOpen + _skipPerWord * (to - from), _skipCap);
    }
    return math.min(_backOpen + _backPerWord * (from - to), _backCap);
  }

  void _step(String word) {
    final n = _n;
    if (n == 0) return;
    final s = _scores;

    // How well the word matches each unit.
    _match.fillRange(0, n, _mismatch);
    final exact = script.index[word];
    if (exact != null) {
      for (final u in exact) {
        _match[u] = script.unitWeight[u];
      }
    }
    if (!Fillers.isVocal(word)) {
      final lo = math.max(0, _display - _fuzzyBehind);
      final hi = math.min(n, _display + _fuzzyAhead);
      for (var u = lo; u < hi; u++) {
        if (_match[u] < 0 &&
            TextNormalizer.isNearMatch(word, script.units[u])) {
          _match[u] = _nearMatchFactor * script.unitWeight[u];
        }
      }
    }

    // Best way to arrive at unit u from any state p, forward (u >= p) ...
    var run = double.negativeInfinity;
    var prefix = double.negativeInfinity;
    for (var u = 0; u < n; u++) {
      if (u > 0) {
        final prev = s[u - 1];
        run = math.max(run, prev) - _skipPerWord;
        prefix = math.max(prefix, prev);
      }
      var best = s[u];
      if (run - _skipOpen > best) best = run - _skipOpen;
      if (prefix - _skipCap > best) best = prefix - _skipCap;
      _pred[u] = best;
    }
    // ... or backward (u < p), i.e. re-reading.
    run = double.negativeInfinity;
    var suffix = double.negativeInfinity;
    for (var u = n - 1; u >= 0; u--) {
      final later = s[u + 1];
      run = math.max(run, later) - _backPerWord;
      suffix = math.max(suffix, later);
      var best = _pred[u];
      if (run - _backOpen > best) best = run - _backOpen;
      if (suffix - _backCap > best) best = suffix - _backCap;
      _pred[u] = best;
    }

    // Either the word reads unit u (landing in state u + 1) or it is an
    // extra word and the reader stays put.
    final insertion = Fillers.isFillerWord(word)
        ? _fillerInsertion
        : _insertion;
    _next[0] = s[0] + insertion;
    for (var u = 0; u < n; u++) {
      final read = _pred[u] + _match[u];
      final stay = s[u + 1] + insertion;
      _next[u + 1] = read > stay ? read : stay;
    }

    var best = 0;
    for (var st = 1; st <= n; st++) {
      if (_next[st] > _next[best]) best = st;
    }
    final top = _next[best];
    for (var st = 0; st <= n; st++) {
      s[st] = _next[st] - top;
    }
    _moveDisplay(best);
  }

  void _moveDisplay(int best) {
    final d = _display;
    if (best >= d && best <= d + _localAhead) {
      _display = best;
      return;
    }
    final hi = math.min(_n, d + _localAhead);
    var local = d;
    for (var st = d + 1; st <= hi; st++) {
      if (_scores[st] > _scores[local]) local = st;
    }
    final margin = best < d ? _backMargin : _jumpMargin;
    _display = _scores[best] - _scores[local] >= margin ? best : local;
  }
}

class _Snapshot {
  final Float64List scores;
  final int display;
  _Snapshot(this.scores, this.display);
}
