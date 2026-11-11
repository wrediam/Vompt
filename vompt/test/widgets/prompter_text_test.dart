import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vompt/features/teleprompter/widgets/prompter_text.dart';

void main() {
  final words = List.generate(200, (i) => 'word$i');
  final breaks = List.generate(200, (i) => i > 0 && i % 30 == 0 ? 2 : 0);

  Future<void> pump(
    WidgetTester tester,
    int current, {
    double width = 956,
    double height = 440,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: PrompterText(
              words: words,
              newlinesBefore: breaks,
              currentWord: current,
              fontSize: 40,
              centered: true,
              onJump: (_) {},
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('keeps the current word on the reading line', (tester) async {
    tester.view.physicalSize = const Size(956, 440);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, -1);
    for (final current in [26, 64, 120]) {
      await pump(tester, current);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      final text = (paragraph.text as TextSpan).toPlainText();
      final start = text.indexOf('word$current ');
      final box = paragraph
          .getBoxesForSelection(
            TextSelection(
              baseOffset: start,
              extentOffset: start + 'word$current'.length,
            ),
          )
          .first;
      final onScreen = paragraph.localToGlobal(Offset(0, box.top)).dy;
      expect(onScreen, closeTo(440 * 0.32, 2), reason: 'word $current');
    }
  });

  testWidgets('re-anchors when the text re-wraps (rotation)', (tester) async {
    tester.view.physicalSize = const Size(956, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, -1, width: 440, height: 956);
    await pump(tester, 60, width: 440, height: 956);
    await pump(tester, 60);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    final text = (paragraph.text as TextSpan).toPlainText();
    final start = text.indexOf('word60 ');
    final box = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + 6),
        )
        .first;
    expect(
      paragraph.localToGlobal(Offset(0, box.top)).dy,
      closeTo(440 * 0.32, 2),
    );
  });
}
