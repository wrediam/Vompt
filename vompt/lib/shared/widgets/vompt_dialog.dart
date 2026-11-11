import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/colors.dart';
import 'motion.dart';

/// Vompt's dialogs: the screen behind blurs and dims, and a card springs up
/// with the cue mark beside its title (tally red when the action destroys).
Future<T?> showVomptDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final still = reduceMotion(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: Duration(milliseconds: still ? 1 : 380),
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (context, animation, _, child) {
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
                    sigmaX: 14 * fade.value,
                    sigmaY: 14 * fade.value,
                  ),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.5 * fade.value),
                  ),
                ),
              ),
            ),
          ),
          FadeTransition(
            opacity: fade,
            child: AnimatedBuilder(
              animation: lift,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, 28 * (1 - lift.value)),
                child: Transform.scale(
                  scale: 0.94 + 0.06 * lift.value,
                  child: child,
                ),
              ),
              child: child,
            ),
          ),
        ],
      );
    },
  );
}

/// Asks before doing something. Resolves true when confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  if (destructive) HapticFeedback.mediumImpact();
  final ok = await showVomptDialog<bool>(
    context,
    builder: (context) => VomptDialogCard(
      title: title,
      message: message,
      accent: destructive ? AppColors.tally : AppColors.cue,
      actions: [
        DialogPill(
          label: confirmLabel,
          color: destructive ? AppColors.tally : AppColors.cue,
          onPressed: () => Navigator.pop(context, true),
        ),
        DialogTextButton(
          label: cancelLabel,
          onPressed: () => Navigator.pop(context, false),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Asks for a line of text, e.g. a new title. Resolves null when cancelled.
Future<String?> textDialog(
  BuildContext context, {
  required String title,
  String? message,
  String initial = '',
  String hint = '',
  required String confirmLabel,
}) {
  final controller = TextEditingController(text: initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  return showVomptDialog<String>(
    context,
    builder: (context) => VomptDialogCard(
      title: title,
      message: message,
      accent: AppColors.cue,
      body: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        style: Theme.of(context).textTheme.titleMedium,
        decoration: InputDecoration(
          hintText: hint,
          fillColor: AppColors.raisedHigh,
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        DialogPill(
          label: confirmLabel,
          color: AppColors.cue,
          onPressed: () => Navigator.pop(context, controller.text),
        ),
        DialogTextButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}

class VomptDialogCard extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? body;
  final List<Widget> actions;
  final Color accent;

  const VomptDialogCard({
    super.key,
    required this.title,
    this.message,
    this.body,
    required this.actions,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.raised,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 40,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 10),
                          child: CustomPaint(
                            size: const Size(10, 14),
                            painter: CueMarkPainter(accent),
                          ),
                        ),
                        Expanded(child: Text(title, style: text.titleLarge)),
                      ],
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: Text(
                          message!,
                          style: text.bodyLarge?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                    if (body != null) ...[const SizedBox(height: 18), body!],
                    const SizedBox(height: 22),
                    ...actions,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The prompter's reading-line cue: a right-pointing triangle.
class CueMarkPainter extends CustomPainter {
  final Color color;
  const CueMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(CueMarkPainter old) => old.color != color;
}

class DialogPill extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const DialogPill({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final onColor = color == AppColors.tally ? Colors.white : AppColors.onCue;
    return Pressable(
      onTap: onPressed,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: color,
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onColor,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class DialogTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const DialogTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.muted,
        minimumSize: const Size.fromHeight(48),
      ),
      child: Text(label),
    );
  }
}
