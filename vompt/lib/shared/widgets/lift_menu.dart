import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/colors.dart';
import 'motion.dart';

class LiftMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool destructive;
  final bool primary;

  const LiftMenuItem({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.destructive = false,
    this.primary = false,
  });
}

/// Lifts the row under [anchor] out of the list, blurs everything else, and
/// fans its actions in beneath it (or above, when there is no room below).
Future<void> showLiftMenu(
  BuildContext context, {
  required BuildContext anchor,
  required Widget preview,
  required List<LiftMenuItem> items,
}) async {
  final box = anchor.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  HapticFeedback.mediumImpact();
  final still = reduceMotion(context);

  LiftMenuItem? chosen;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: Duration(milliseconds: still ? 1 : 420),
    pageBuilder: (context, animation, _) => _LiftMenu(
      rect: rect,
      preview: preview,
      items: items,
      animation: animation,
      onChoose: (item) {
        chosen = item;
        Navigator.pop(context);
      },
    ),
  );
  // Act after the menu is gone, so dialogs open over the list.
  chosen?.onSelected();
}

class _LiftMenu extends StatelessWidget {
  final Rect rect;
  final Widget preview;
  final List<LiftMenuItem> items;
  final Animation<double> animation;
  final ValueChanged<LiftMenuItem> onChoose;

  const _LiftMenu({
    required this.rect,
    required this.preview,
    required this.items,
    required this.animation,
    required this.onChoose,
  });

  static const _itemHeight = 54.0;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final menuH = items.length * _itemHeight + 12;
    final menuW = math.min(280.0, rect.width - 24);

    // Below the card if it fits, above if that fits, otherwise slide the
    // card up just enough to fit the menu below it.
    var cardTop = rect.top;
    var menuBelow = true;
    final floor = size.height - pad.bottom - 16;
    if (rect.bottom + _gap + menuH > floor) {
      if (rect.top - _gap - menuH > pad.top + 16) {
        menuBelow = false;
      } else {
        cardTop = floor - menuH - _gap - rect.height;
      }
    }

    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final lift = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: fade,
              builder: (context, _) => BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 16 * fade.value,
                  sigmaY: 16 * fade.value,
                ),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.45 * fade.value),
                ),
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: lift,
          builder: (context, child) {
            final top = rect.top + (cardTop - rect.top) * lift.value;
            // Full-bleed rows float in from the edges as they lift.
            final inset = 12 * lift.value;
            return Positioned(
              left: rect.left + inset,
              top: top,
              width: rect.width - inset * 2,
              child: Transform.scale(
                scale: 1 + 0.035 * lift.value,
                child: child,
              ),
            );
          },
          child: IgnorePointer(
            child: Material(
              color: AppColors.raised,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.cue.withValues(alpha: 0.45),
                  ),
                ),
                child: preview,
              ),
            ),
          ),
        ),
        Positioned(
          left: rect.left + 16,
          width: menuW,
          top: menuBelow ? cardTop + rect.height + _gap : null,
          bottom: menuBelow ? null : size.height - rect.top + _gap,
          child: Material(
            color: AppColors.raisedHigh,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _Fan(
                      animation: animation,
                      index: i,
                      fromAbove: !menuBelow,
                      child: _ItemRow(
                        item: items[i],
                        height: _itemHeight,
                        onTap: () => onChoose(items[i]),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Each item slides and fades in a beat after the one before.
class _Fan extends StatelessWidget {
  final Animation<double> animation;
  final int index;
  final bool fromAbove;
  final Widget child;

  const _Fan({
    required this.animation,
    required this.index,
    required this.fromAbove,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = math.min(0.15 + index * 0.08, 0.6);
    final t = CurvedAnimation(
      parent: animation,
      curve: Interval(start, math.min(start + 0.45, 1), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: t,
      builder: (context, child) => Opacity(
        opacity: t.value,
        child: Transform.translate(
          offset: Offset(0, (fromAbove ? 10 : -10) * (1 - t.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _ItemRow extends StatelessWidget {
  final LiftMenuItem item;
  final double height;
  final VoidCallback onTap;

  const _ItemRow({required this.item, required this.height, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = item.destructive
        ? AppColors.tally
        : item.primary
        ? AppColors.cue
        : AppColors.paper;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Icon(item.icon, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: item.primary ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
