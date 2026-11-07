import 'text_normalizer.dart';

/// A script prepared for speech tracking.
///
/// [words] are the whitespace-separated words shown on screen (the web remote
/// splits the same way, so word indexes agree). Each word yields zero or more
/// normalized [units]; tracking happens over units and maps back to words.
class ScriptDocument {
  final List<String> words;
  final List<String> units;

  /// For each unit, the index of the on-screen word it came from.
  final List<int> unitWord;

  /// For each unit, how much a match is worth: function words are weak evidence.
  final List<double> unitWeight;

  /// Unit text -> unit indexes, for exact lookups across the whole script.
  final Map<String, List<int>> index;

  /// Concatenations of adjacent units ("off"+"line" -> "offline") -> the pair.
  final Map<String, List<String>> _pairs;

  ScriptDocument._(
    this.words,
    this.units,
    this.unitWord,
    this.unitWeight,
    this.index,
    this._pairs,
  );

  factory ScriptDocument(String content) {
    final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    final words = normalized.isEmpty ? <String>[] : normalized.split(' ');

    final units = <String>[];
    final unitWord = <int>[];
    for (var w = 0; w < words.length; w++) {
      for (final unit in TextNormalizer.normalizeWord(words[w])) {
        // "twenty five" -> "25", attributed to the later word.
        if (units.isNotEmpty &&
            TextNormalizer.mergeCompoundNumbers([units.last, unit]).length ==
                1) {
          units[units.length - 1] = TextNormalizer.mergeCompoundNumbers([
            units.last,
            unit,
          ]).single;
          unitWord[unitWord.length - 1] = w;
          continue;
        }
        units.add(unit);
        unitWord.add(w);
      }
    }

    final index = <String, List<int>>{};
    for (var u = 0; u < units.length; u++) {
      (index[units[u]] ??= <int>[]).add(u);
    }
    final pairs = <String, List<String>>{};
    for (var u = 0; u + 1 < units.length; u++) {
      pairs.putIfAbsent(
        units[u] + units[u + 1],
        () => [units[u], units[u + 1]],
      );
    }
    final weights = [
      for (final unit in units) _functionWords.contains(unit) ? 0.6 : 1.0,
    ];
    return ScriptDocument._(words, units, unitWord, weights, index, pairs);
  }

  int get length => units.length;
  bool get isEmpty => units.isEmpty;

  /// First unit belonging to on-screen word [wordIndex] or later.
  int unitForWord(int wordIndex) {
    for (var u = 0; u < units.length; u++) {
      if (unitWord[u] >= wordIndex) return u;
    }
    return units.length;
  }

  /// Normalizes recognized speech and reconciles compound splits against the
  /// script's vocabulary: "on boarding" -> "onboarding" when the script says
  /// "onboarding", and "offline" -> "off line" when it says "off-line".
  List<String> normalizeSpeech(String text) {
    final raw = TextNormalizer.normalizeText(text);
    final out = <String>[];
    for (var i = 0; i < raw.length; i++) {
      final token = raw[i];
      if (i + 1 < raw.length) {
        final joined = token + raw[i + 1];
        if (index.containsKey(joined) &&
            (!index.containsKey(token) || !index.containsKey(raw[i + 1]))) {
          out.add(joined);
          i++;
          continue;
        }
      }
      if (!index.containsKey(token)) {
        final pair = _pairs[token];
        if (pair != null) {
          out.addAll(pair);
          continue;
        }
      }
      out.add(token);
    }
    return out;
  }

  static const _functionWords = <String>{
    'a',
    'an',
    'the',
    'and',
    'or',
    'but',
    'of',
    'to',
    'in',
    'on',
    'at',
    'by',
    'for',
    'with',
    'from',
    'as',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'it',
    'its',
    'this',
    'that',
    'these',
    'those',
    'i',
    'you',
    'we',
    'they',
    'he',
    'she',
    'my',
    'your',
    'our',
    'their',
    'his',
    'her',
    'me',
    'us',
    'them',
    'so',
    'if',
    'then',
    'than',
    'do',
    'not',
    'no',
    'have',
    'has',
    'had',
    'will',
    'can',
    'just',
    'up',
    'out',
    'all',
    'what',
    'when',
    'how',
  };
}
