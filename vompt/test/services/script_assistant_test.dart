import 'package:flutter_test/flutter_test.dart';
import 'package:vompt/services/script_assistant.dart';

void main() {
  group('removeDashes', () {
    final cases = {
      'Over the last quarter—we shipped three features.':
          'Over the last quarter, we shipped three features.',
      'We rebuilt the flow—new users love it.':
          'We rebuilt the flow, new users love it.',
      'We rebuilt the flow — new users love it.':
          'We rebuilt the flow, new users love it.',
      'Aim for 130–165 words a minute.': 'Aim for 130 to 165 words a minute.',
      'Aim for 130 — 165 words.': 'Aim for 130 to 165 words.',
      'It works -- really well.': 'It works, really well.',
      'Fast - and simple.': 'Fast, and simple.',
      'It ended—.': 'It ended.',
      '— First point\n— Second point': 'First point\nSecond point',
      'And then—': 'And then',
      'A five-minute walk, well-known and up-to-date.':
          'A five-minute walk, well-known and up-to-date.',
    };
    cases.forEach((input, expected) {
      test(input, () => expect(ScriptAssistant.removeDashes(input), expected));
    });

    test('leaves no dash characters in a messy answer', () {
      const messy =
          'Here is the revised script:\n\n'
          '— Today we\'re launching—finally—our new app.\n'
          'It cuts load time in half – and churn fell 10–15% -- in a quarter.';
      final out = ScriptAssistant.cleanForTest(messy);
      expect(out, isNot(matches(RegExp('[‒–—―]|--| - '))));
      expect(
        out,
        "Today we're launching, finally, our new app.\n"
        'It cuts load time in half, and churn fell 10 to 15%, in a quarter.',
      );
    });
  });
}
