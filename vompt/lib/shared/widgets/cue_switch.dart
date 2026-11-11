import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/colors.dart';

/// An on/off switch that lights cue amber when on.
class CueSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const CueSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 52,
          height: 30,
          padding: const EdgeInsets.all(3),
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: value ? AppColors.cue : AppColors.line,
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? AppColors.onCue : AppColors.paper,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled setting with a [CueSwitch]; the whole row is tappable.
class SwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: text.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            CueSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
