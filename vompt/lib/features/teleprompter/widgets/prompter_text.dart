import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/colors.dart';
import '../../../core/theme/app_theme.dart';

/// The script as one paragraph, scrolled so the current word's line sits on
/// the reading line. Long-press a word to continue from it.
class PrompterText extends StatefulWidget {
  final List<String> words;
  final List<int> newlinesBefore;
  final int currentWord;
  final double fontSize;
  final bool centered;

  /// Fraction of the viewport height where the reading line sits.
  final double readingLine;
  final ValueChanged<int> onJump;
  final VoidCallback onTap;

  const PrompterText({
    super.key,
    required this.words,
    required this.newlinesBefore,
    required this.currentWord,
    required this.fontSize,
    required this.centered,
    required this.onJump,
    required this.onTap,
    this.readingLine = 0.32,
  });

  @override
  State<PrompterText> createState() => _PrompterTextState();
}

class _PrompterTextState extends State<PrompterText> {
  final _scroll = ScrollController();
  final _paragraphKey = GlobalKey();
  String _text = '';
  List<int> _starts = const [];
  List<String>? _composedFrom;
  double? _laidOutWidth;

  @override
  void didUpdateWidget(PrompterText old) {
    super.didUpdateWidget(old);
    if (old.currentWord != widget.currentWord ||
        old.fontSize != widget.fontSize ||
        old.centered != widget.centered ||
        !identical(old.words, widget.words)) {
      final jump =
          !identical(old.words, widget.words) ||
          (widget.currentWord - old.currentWord).abs() > 40;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _follow(animate: !jump),
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _compose() {
    if (identical(_composedFrom, widget.words)) return;
    final buffer = StringBuffer();
    final starts = List<int>.filled(widget.words.length, 0);
    for (var i = 0; i < widget.words.length; i++) {
      if (i > 0) {
        final breaks = i < widget.newlinesBefore.length
            ? widget.newlinesBefore[i]
            : 0;
        buffer.write(
          breaks >= 2
              ? '\n\n'
              : breaks == 1
              ? '\n'
              : ' ',
        );
      }
      starts[i] = buffer.length;
      buffer.write(widget.words[i]);
    }
    _text = buffer.toString();
    _starts = starts;
    _composedFrom = widget.words;
  }

  RenderParagraph? get _paragraph {
    final render = _paragraphKey.currentContext?.findRenderObject();
    return render is RenderParagraph ? render : null;
  }

  void _follow({bool animate = true}) {
    final paragraph = _paragraph;
    if (!mounted ||
        paragraph == null ||
        !_scroll.hasClients ||
        _starts.isEmpty) {
      return;
    }
    final index = widget.currentWord.clamp(0, _starts.length - 1);
    final start = _starts[index];
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(
        baseOffset: start,
        extentOffset: start + widget.words[index].length,
      ),
    );
    if (boxes.isEmpty) return;
    // The scroll view's top padding equals the reading line, so a line's top
    // is exactly the offset that puts it there.
    final target = widget.currentWord < 0
        ? 0.0
        : boxes.first.top.clamp(0.0, _scroll.position.maxScrollExtent);
    if ((target - _scroll.offset).abs() < 1) return;
    if (animate) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  void _jumpAt(Offset globalPosition) {
    final paragraph = _paragraph;
    if (paragraph == null || _starts.isEmpty) return;
    final offset = paragraph
        .getPositionForOffset(paragraph.globalToLocal(globalPosition))
        .offset;
    var lo = 0, hi = _starts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_starts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    HapticFeedback.mediumImpact();
    widget.onJump(lo);
  }

  @override
  Widget build(BuildContext context) {
    _compose();
    final base = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w600,
      height: 1.38,
      color: AppColors.paper,
    );

    final current = widget.currentWord;
    final spans = <TextSpan>[];
    if (current < 0 || current >= _starts.length) {
      spans.add(TextSpan(text: _text));
    } else {
      final start = _starts[current];
      final end = start + widget.words[current].length;
      spans
        ..add(
          TextSpan(
            text: _text.substring(0, start),
            style: TextStyle(color: AppColors.paper.withValues(alpha: 0.38)),
          ),
        )
        ..add(
          TextSpan(
            text: _text.substring(start, end),
            style: TextStyle(
              color: AppColors.cue,
              fontWeight: FontWeight.w800,
              backgroundColor: AppColors.cue.withValues(alpha: 0.16),
            ),
          ),
        )
        ..add(TextSpan(text: _text.substring(end)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final line = constraints.maxHeight * widget.readingLine;
        // Rotation or a new safe area re-wraps the text; re-anchor the current
        // line instead of leaving the old offset pointing at a different one.
        if (_laidOutWidth != null && _laidOutWidth != constraints.maxWidth) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _follow(animate: false),
          );
        }
        _laidOutWidth = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPressStart: (d) => _jumpAt(d.globalPosition),
          child: SingleChildScrollView(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(56, line, 56, constraints.maxHeight),
            child: RichText(
              key: _paragraphKey,
              textAlign: widget.centered ? TextAlign.center : TextAlign.start,
              text: TextSpan(style: base, children: spans),
            ),
          ),
        );
      },
    );
  }
}
