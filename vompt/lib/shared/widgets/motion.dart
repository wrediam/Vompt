import 'package:material_ui/material_ui.dart';

/// True when the person has asked iOS to reduce motion.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Dips slightly under the finger and springs back, so taps feel physical.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 320),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down() {
    if (!reduceMotion(context)) _c.forward();
  }

  void _up() => _c.reverse();

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _down() : null,
      onTapUp: enabled ? (_) => _up() : null,
      onTapCancel: enabled ? _up : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              _up();
              widget.onLongPress!();
            },
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          // Quick dip in; overshooting spring on release.
          final t = _c.status == AnimationStatus.reverse
              ? Curves.easeOutBack.transform(_c.value)
              : Curves.easeOut.transform(_c.value);
          return Transform.scale(
            scale: 1 - (1 - widget.pressedScale) * t,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Rises into place once, like a line of script scrolling up the prompter.
/// Give list rows increasing [delay]s for a staggered entrance.
class RiseIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double offset;

  const RiseIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 22,
  });

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _c.value = 1;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
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
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
