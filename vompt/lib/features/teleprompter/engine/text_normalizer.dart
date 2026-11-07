/// Normalization shared by script text and recognized speech, so both sides
/// compare on equal terms: case, punctuation, contractions, numbers written
/// as digits or words, and hyphenated or split compounds.
class TextNormalizer {
  static final _apostrophes = RegExp(r"['’‘`´]");
  static final _separators = RegExp(r'[\s\-‐‑–—/_]+');
  static final _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static final _thousands = RegExp(r'(\d),(?=\d{3}\b)');

  static const _numberWords = <String, String>{
    'zero': '0',
    'one': '1',
    'two': '2',
    'three': '3',
    'four': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'nine': '9',
    'ten': '10',
    'eleven': '11',
    'twelve': '12',
    'thirteen': '13',
    'fourteen': '14',
    'fifteen': '15',
    'sixteen': '16',
    'seventeen': '17',
    'eighteen': '18',
    'nineteen': '19',
    'twenty': '20',
    'thirty': '30',
    'forty': '40',
    'fifty': '50',
    'sixty': '60',
    'seventy': '70',
    'eighty': '80',
    'ninety': '90',
  };

  static const _ordinals = <String, String>{
    'first': '1st',
    'second': '2nd',
    'third': '3rd',
    'fourth': '4th',
    'fifth': '5th',
    'sixth': '6th',
    'seventh': '7th',
    'eighth': '8th',
    'ninth': '9th',
    'tenth': '10th',
  };

  static const _spelledOut = <String, String>{
    'ok': 'okay',
    'mr': 'mister',
    'mrs': 'missus',
    'dr': 'doctor',
    'vs': 'versus',
    'pct': 'percent',
  };

  /// Splits one whitespace-delimited word into normalized units.
  /// "five-minute" -> ["5", "minute"], "don't" -> ["dont"], "18%" -> ["18", "percent"].
  static List<String> normalizeWord(String raw) {
    var text = raw
        .toLowerCase()
        .replaceAll(_apostrophes, '')
        .replaceAll(_thousands, r'$1')
        .replaceAll('&', ' and ')
        .replaceAll('%', ' percent ')
        .replaceAll('+', ' plus ');
    final units = <String>[];
    for (final part in text.split(_separators)) {
      final cleaned = part.replaceAll(_nonWord, '');
      if (cleaned.isEmpty) continue;
      units.add(
        _numberWords[cleaned] ??
            _ordinals[cleaned] ??
            _spelledOut[cleaned] ??
            cleaned,
      );
    }
    return units;
  }

  /// Normalizes free text (e.g. a recognizer transcript) into units.
  static List<String> normalizeText(String text) {
    final units = <String>[];
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      units.addAll(normalizeWord(word));
    }
    return mergeCompoundNumbers(units);
  }

  /// "20", "5" -> "25", so "twenty-five" matches a recognizer's "25".
  static List<String> mergeCompoundNumbers(List<String> units) {
    final out = <String>[];
    for (final unit in units) {
      if (out.isNotEmpty && _isTens(out.last) && _isDigit(unit)) {
        out[out.length - 1] = '${out.last[0]}$unit';
      } else {
        out.add(unit);
      }
    }
    return out;
  }

  static bool _isTens(String s) =>
      s.length == 2 &&
      s[1] == '0' &&
      s.codeUnitAt(0) >= 0x32 &&
      s.codeUnitAt(0) <= 0x39;
  static bool _isDigit(String s) =>
      s.length == 1 && s.codeUnitAt(0) >= 0x31 && s.codeUnitAt(0) <= 0x39;

  /// Levenshtein similarity in [0, 1]; 0 when lengths differ too much to matter.
  static double similarity(String a, String b) {
    if (a == b) return 1.0;
    final la = a.length, lb = b.length;
    if (la == 0 || lb == 0 || (la - lb).abs() > 3) return 0.0;
    var prev = List<int>.generate(lb + 1, (j) => j);
    var curr = List<int>.filled(lb + 1, 0);
    for (var i = 1; i <= la; i++) {
      curr[0] = i;
      for (var j = 1; j <= lb; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var best = prev[j] + 1;
        if (curr[j - 1] + 1 < best) best = curr[j - 1] + 1;
        if (prev[j - 1] + cost < best) best = prev[j - 1] + cost;
        curr[j] = best;
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return 1.0 - prev[lb] / (la > lb ? la : lb);
  }

  /// True when two units are close enough to be the same spoken word
  /// (recognizer slips like "rebuild"/"rebuilt" or a truncated "ship"/"shipped").
  static bool isNearMatch(String spoken, String script) {
    if (spoken == script) return true;
    final shorter = spoken.length < script.length ? spoken : script;
    final longer = spoken.length < script.length ? script : spoken;
    if (shorter.length >= 3 &&
        longer.startsWith(shorter) &&
        shorter.length / longer.length >= 0.5) {
      return true;
    }
    return shorter.length >= 4 && similarity(spoken, script) >= 0.75;
  }
}

/// Filler words and disfluencies. Vocal fillers never carry script meaning;
/// lexical fillers only count when they are not part of the script.
class Fillers {
  static const vocal = <String>{
    'um',
    'umm',
    'ummm',
    'uh',
    'uhh',
    'uhhh',
    'uhm',
    'ah',
    'ahh',
    'er',
    'erm',
    'err',
    'hmm',
    'hm',
    'mm',
    'mmm',
    'eh',
  };

  static const lexical = <String>{
    'like',
    'so',
    'basically',
    'actually',
    'literally',
    'right',
    'okay',
    'well',
    'anyway',
    'honestly',
    'seriously',
    'totally',
  };

  /// Multi-word fillers, as normalized unit sequences.
  static const phrases = <List<String>>[
    ['you', 'know'],
    ['i', 'mean'],
    ['kind', 'of'],
    ['sort', 'of'],
    ['you', 'see'],
  ];

  static bool isVocal(String unit) => vocal.contains(unit);
  static bool isFillerWord(String unit) =>
      vocal.contains(unit) || lexical.contains(unit);

  /// Display label used in stats ("um" and "umm" are the same filler).
  static String label(String unit) {
    if (unit.startsWith('um') || unit == 'uhm') return 'um';
    if (unit.startsWith('uh')) return 'uh';
    if (unit.startsWith('ah')) return 'ah';
    if (unit.startsWith('er')) return 'er';
    if (unit.startsWith('hm') || unit.startsWith('mm')) return 'hmm';
    return unit;
  }
}
