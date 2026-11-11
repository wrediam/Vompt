import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vompt/core/utils/text_diff.dart';

String _render(TextDiff d) => d.spans
    .map((s) => switch (s.op) {
          DiffOp.same => s.text,
          DiffOp.added => '[+${s.text}]',
          DiffOp.removed => '[-${s.text}]',
        })
    .join();

String _after(TextDiff d) => d.spans.where((s) => s.op != DiffOp.removed).map((s) => s.text).join();

void main() {
  test('identical text has no changes', () {
    final d = TextDiff.compare('Hello there, friend.', 'Hello there, friend.');
    expect(d.hasChanges, isFalse);
    expect(_render(d), 'Hello there, friend.');
  });

  test('marks a replaced word', () {
    final d = TextDiff.compare('We cut load time in half.', 'We cut load time by half.');
    expect(_render(d), 'We cut load time[- in] [+by] half.');
    expect(d.wordsAdded, 1);
    expect(d.wordsRemoved, 1);
  });

  test('groups runs and keeps spaces unmarked', () {
    final d = TextDiff.compare(
      'In accordance with the objectives we shipped features.',
      'We shipped three big features.',
    );
    expect(_render(d), '[-In accordance with the objectives we][+We] shipped [+three big] features.');
  });

  test('keeps the new text line breaks', () {
    final d = TextDiff.compare('One.\n\nTwo three.', 'One.\n\nTwo four.\n\nFive.');
    expect(_after(d), 'One.\n\nTwo four.\n\nFive.');
  });

  test('handles empty sides', () {
    expect(_render(TextDiff.compare('', 'New script')), '[+New script]');
    expect(_render(TextDiff.compare('Old script', '')), '[-Old script]');
    expect(TextDiff.compare('', '').hasChanges, isFalse);
  });

  test('reconstructs the new text exactly from a long random edit', () {
    final rng = Random(7);
    final vocab = List.generate(60, (i) => 'w$i');
    final before = List.generate(1500, (_) => vocab[rng.nextInt(60)]).join(' ');
    final words = before.split(' ');
    for (var k = 0; k < 200; k++) {
      words[rng.nextInt(words.length)] = vocab[rng.nextInt(60)];
    }
    final after = words.join(' ');
    final d = TextDiff.compare(before, after);
    expect(_after(d), after);
    final removedOrSame = d.spans.where((s) => s.op != DiffOp.added).map((s) => s.text).join();
    expect(removedOrSame.split(RegExp(r'\s+')).where((w) => w.isNotEmpty), before.split(' '));
  });
}
