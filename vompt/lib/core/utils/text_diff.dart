import 'dart:typed_data';

enum DiffOp { same, added, removed }

/// A run of text that is unchanged, added, or removed.
class DiffSpan {
  final DiffOp op;
  final String text;
  const DiffSpan(this.op, this.text);

  @override
  String toString() => '${op.name}(${text.replaceAll('\n', r'\n')})';
}

/// Word-level differences between two versions of a script.
///
/// Words are compared exactly (so "Today," and "today" differ). Whitespace is
/// never reported as a change on its own: kept and added words use the new
/// text's spacing and line breaks, removed words the old text's.
class TextDiff {
  final List<DiffSpan> spans;
  final int wordsAdded;
  final int wordsRemoved;

  const TextDiff._(this.spans, this.wordsAdded, this.wordsRemoved);

  bool get hasChanges => wordsAdded > 0 || wordsRemoved > 0;

  /// Diffs [before] against [after]. Runs in O(n·m) time but linear memory
  /// (Hirschberg's algorithm), after trimming the unchanged start and end.
  static TextDiff compare(String before, String after) {
    final a = _Tokens(before);
    final b = _Tokens(after);
    final ids = <String, int>{};
    final ia = Int32List.fromList([for (final w in a.words) ids.putIfAbsent(w, () => ids.length)]);
    final ib = Int32List.fromList([for (final w in b.words) ids.putIfAbsent(w, () => ids.length)]);

    final keepA = List<bool>.filled(ia.length, false);
    final keepB = List<bool>.filled(ib.length, false);
    var lo = 0;
    while (lo < ia.length && lo < ib.length && ia[lo] == ib[lo]) {
      keepA[lo] = keepB[lo] = true;
      lo++;
    }
    var hiA = ia.length, hiB = ib.length;
    while (hiA > lo && hiB > lo && ia[hiA - 1] == ib[hiB - 1]) {
      hiA--;
      hiB--;
      keepA[hiA] = keepB[hiB] = true;
    }
    _hirschberg(ia, lo, hiA, ib, lo, hiB, keepA, keepB);

    final out = _Builder();
    var i = 0, j = 0, added = 0, removed = 0;
    while (i < ia.length || j < ib.length) {
      if (i < ia.length && !keepA[i]) {
        out.add(DiffOp.removed, a.gaps[i], a.words[i]);
        removed++;
        i++;
      } else if (j < ib.length && !keepB[j]) {
        out.add(DiffOp.added, b.gaps[j], b.words[j]);
        added++;
        j++;
      } else {
        out.add(DiffOp.same, b.gaps[j], b.words[j]);
        i++;
        j++;
      }
    }
    out.trailing(b.tail);
    return TextDiff._(out.spans, added, removed);
  }

  /// Marks the longest common subsequence of a[aLo:aHi] and b[bLo:bHi].
  static void _hirschberg(
    Int32List a, int aLo, int aHi,
    Int32List b, int bLo, int bHi,
    List<bool> keepA, List<bool> keepB,
  ) {
    final n = aHi - aLo, m = bHi - bLo;
    if (n == 0 || m == 0) return;
    if (n == 1) {
      for (var j = bLo; j < bHi; j++) {
        if (a[aLo] == b[j]) {
          keepA[aLo] = keepB[j] = true;
          return;
        }
      }
      return;
    }
    final mid = aLo + n ~/ 2;
    final forward = _lcsForward(a, aLo, mid, b, bLo, bHi);
    final backward = _lcsBackward(a, mid, aHi, b, bLo, bHi);
    var split = 0, best = -1;
    for (var k = 0; k <= m; k++) {
      final total = forward[k] + backward[m - k];
      if (total > best) {
        best = total;
        split = k;
      }
    }
    _hirschberg(a, aLo, mid, b, bLo, bLo + split, keepA, keepB);
    _hirschberg(a, mid, aHi, b, bLo + split, bHi, keepA, keepB);
  }

  /// row[k] = LCS length of a[aLo:aHi] and b[bLo:bLo+k].
  static Int32List _lcsForward(Int32List a, int aLo, int aHi, Int32List b, int bLo, int bHi) {
    final m = bHi - bLo;
    var prev = Int32List(m + 1), curr = Int32List(m + 1);
    for (var i = aLo; i < aHi; i++) {
      for (var k = 1; k <= m; k++) {
        curr[k] = a[i] == b[bLo + k - 1]
            ? prev[k - 1] + 1
            : (prev[k] > curr[k - 1] ? prev[k] : curr[k - 1]);
      }
      final t = prev;
      prev = curr;
      curr = t;
    }
    return prev;
  }

  /// row[k] = LCS length of a[aLo:aHi] and the last k tokens of b[bLo:bHi].
  static Int32List _lcsBackward(Int32List a, int aLo, int aHi, Int32List b, int bLo, int bHi) {
    final m = bHi - bLo;
    var prev = Int32List(m + 1), curr = Int32List(m + 1);
    for (var i = aHi - 1; i >= aLo; i--) {
      for (var k = 1; k <= m; k++) {
        curr[k] = a[i] == b[bHi - k]
            ? prev[k - 1] + 1
            : (prev[k] > curr[k - 1] ? prev[k] : curr[k - 1]);
      }
      final t = prev;
      prev = curr;
      curr = t;
    }
    return prev;
  }
}

/// Words with the whitespace before each, plus any trailing whitespace.
class _Tokens {
  final List<String> words = [];
  final List<String> gaps = [];
  String tail = '';

  _Tokens(String text) {
    var gap = '';
    for (final m in RegExp(r'\s+|\S+').allMatches(text)) {
      final t = m[0]!;
      if (t.trim().isEmpty) {
        gap += t;
      } else {
        words.add(t);
        gaps.add(gap);
        gap = '';
      }
    }
    tail = gap;
  }
}

/// Merges runs. Same and added spans together are exactly the new text;
/// same and removed spans hold the old words. A removed run carries the space
/// before it (it belongs to the old text); an added run's leading space stays
/// unmarked so highlights cover words, not gaps.
class _Builder {
  final List<DiffSpan> spans = [];

  void add(DiffOp op, String gap, String word) {
    if (op == DiffOp.removed || (spans.isNotEmpty && spans.last.op == op)) {
      _push(op, gap + word);
      return;
    }
    if (gap.isNotEmpty) _push(DiffOp.same, gap);
    _push(op, word);
  }

  void trailing(String tail) {
    if (tail.isNotEmpty) _push(DiffOp.same, tail);
  }

  void _push(DiffOp op, String text) {
    if (spans.isNotEmpty && spans.last.op == op) {
      spans[spans.length - 1] = DiffSpan(op, spans.last.text + text);
    } else {
      spans.add(DiffSpan(op, text));
    }
  }
}
