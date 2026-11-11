import 'package:material_ui/material_ui.dart';

import '../../core/constants/colors.dart';
import '../../core/utils/text_diff.dart';
import 'motion.dart';

/// Renders a [TextDiff]: added words get an amber wash that fades in when the
/// comparison appears; removed words are struck through in muted red.
class DiffText extends StatefulWidget {
  final TextDiff diff;
  final TextStyle style;
  final bool showRemoved;

  const DiffText({
    super.key,
    required this.diff,
    required this.style,
    this.showRemoved = true,
  });

  @override
  State<DiffText> createState() => _DiffTextState();
}

class _DiffTextState extends State<DiffText>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.value = 1;
    } else if (_c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_c.value);
        final spans = <InlineSpan>[];
        for (final s in widget.diff.spans) {
          switch (s.op) {
            case DiffOp.same:
              spans.add(TextSpan(text: s.text));
            case DiffOp.added:
              spans.add(
                TextSpan(
                  text: s.text,
                  style: TextStyle(
                    color: AppColors.paper,
                    backgroundColor: AppColors.cue.withValues(alpha: 0.26 * t),
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.cue.withValues(alpha: t),
                    decorationThickness: 2,
                  ),
                ),
              );
            case DiffOp.removed:
              if (!widget.showRemoved) continue;
              // The space before a removed run stays plain.
              final lead = RegExp(r'^\s*').firstMatch(s.text)![0]!;
              if (lead.isNotEmpty) spans.add(TextSpan(text: lead));
              spans.add(
                TextSpan(
                  text: s.text.substring(lead.length),
                  style: TextStyle(
                    color: AppColors.tally.withValues(alpha: 0.75),
                    decoration: TextDecoration.lineThrough,
                    decorationColor: AppColors.tally,
                    decorationThickness: 2,
                  ),
                ),
              );
          }
        }
        return Text.rich(TextSpan(style: widget.style, children: spans));
      },
    );
  }
}

/// "+12 words, −4 words" style counts, colored by direction.
class DiffCounts extends StatelessWidget {
  final TextDiff diff;
  const DiffCounts({super.key, required this.diff});

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    if (!diff.hasChanges) {
      return Text('No changes', style: small);
    }
    return Text.rich(
      TextSpan(
        style: small?.copyWith(fontWeight: FontWeight.w700),
        children: [
          if (diff.wordsAdded > 0)
            TextSpan(
              text: '+${diff.wordsAdded} ${diff.wordsAdded == 1 ? 'word' : 'words'}',
              style: const TextStyle(color: AppColors.cue),
            ),
          if (diff.wordsAdded > 0 && diff.wordsRemoved > 0)
            const TextSpan(text: '   '),
          if (diff.wordsRemoved > 0)
            TextSpan(
              text: '−${diff.wordsRemoved} ${diff.wordsRemoved == 1 ? 'word' : 'words'}',
              style: TextStyle(color: AppColors.tally.withValues(alpha: 0.9)),
            ),
        ],
      ),
    );
  }
}

/// A two-option pill switch with a sliding thumb.
class SegmentToggle extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  const SegmentToggle({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const h = 38.0;
        final w = (c.maxWidth.isFinite ? c.maxWidth : 260.0) / labels.length;
        return Container(
          height: h,
          decoration: ShapeDecoration(
            color: AppColors.raisedHigh,
            shape: const StadiumBorder(),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                left: selected * w + 3,
                top: 3,
                width: w - 6,
                height: h - 6,
                child: const DecoratedBox(
                  decoration: ShapeDecoration(
                    color: AppColors.paper,
                    shape: StadiumBorder(),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(i),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: 'Atkinson',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: i == selected
                                  ? AppColors.ink
                                  : AppColors.muted,
                            ),
                            child: Text(labels[i]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
