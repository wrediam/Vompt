import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cue_switch.dart';
import '../../../shared/widgets/motion.dart';
import '../providers/intelligent_teleprompter_provider.dart';

String formatClock(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Top and bottom control bars over the prompter.
class IntelligentTeleprompterControls extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onInteract;

  const IntelligentTeleprompterControls({
    super.key,
    required this.onClose,
    required this.onInteract,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<IntelligentTeleprompterProvider>();
    return SafeArea(
      child: Column(
        children: [
          _Bar(
            top: true,
            children: [
              _RoundButton(
                icon: Icons.close_rounded,
                label: 'Close',
                onPressed: onClose,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p.document?.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
              _RoundButton(
                icon: Icons.text_fields_rounded,
                label: 'Display settings',
                onPressed: () {
                  onInteract();
                  showDisplaySheet(context);
                },
              ),
            ],
          ),
          const Spacer(),
          _Bar(
            top: false,
            children: [
              _RoundButton(
                icon: Icons.restart_alt_rounded,
                label: 'Back to the top',
                onPressed: () {
                  onInteract();
                  p.reset();
                },
              ),
              const Spacer(),
              _MicButton(provider: p, onInteract: onInteract),
              const SizedBox(width: 14),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: p.hasTake ? 1 : 0.35,
                child: _PillButton(
                  icon: Icons.flag_rounded,
                  label: 'Finish take',
                  onPressed: p.hasTake
                      ? () {
                          onInteract();
                          p.finishTake();
                        }
                      : null,
                ),
              ),
              const Spacer(),
              _RoundButton(
                icon: Icons.remove_rounded,
                label: 'Smaller text',
                onPressed: () {
                  onInteract();
                  p.decreaseFontSize();
                },
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${p.fontSize.toInt()}',
                  textAlign: TextAlign.center,
                  style: AppTheme.figureSmall,
                ),
              ),
              _RoundButton(
                icon: Icons.add_rounded,
                label: 'Larger text',
                onPressed: () {
                  onInteract();
                  p.increaseFontSize();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final bool top;
  final List<Widget> children;
  const _Bar({required this.top, required this.children});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.92),
            Colors.black.withValues(alpha: 0),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, top ? 8 : 24, 16, top ? 24 : 10),
        child: Row(children: children),
      ),
    );
  }
}

/// Start, pause, resume. Amber when ready, tally red while live.
class _MicButton extends StatelessWidget {
  final IntelligentTeleprompterProvider provider;
  final VoidCallback onInteract;
  const _MicButton({required this.provider, required this.onInteract});

  @override
  Widget build(BuildContext context) {
    final live = provider.isSpeechActive;
    final preparing = provider.isPreparing;
    final label = live
        ? 'Pause'
        : preparing
        ? 'Starting'
        : provider.hasTake
        ? 'Resume'
        : 'Start';
    return Semantics(
      button: true,
      label: '$label listening',
      child: GestureDetector(
        onTap: preparing
            ? null
            : () {
                onInteract();
                provider.toggleListening();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: live ? AppColors.tally : AppColors.cue,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (preparing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.onCue,
                  ),
                )
              else
                Icon(
                  live ? Icons.pause_rounded : Icons.mic_rounded,
                  color: live ? Colors.white : AppColors.onCue,
                  size: 26,
                ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: live ? Colors.white : AppColors.onCue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _RoundButton({required this.icon, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.white.withValues(alpha: 0.10),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22)),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _PillButton({required this.icon, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The on-air light: red with a live level meter while listening.
class TallyLight extends StatelessWidget {
  const TallyLight({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<IntelligentTeleprompterProvider>();
    final live = p.isSpeechActive;
    final String text;
    if (p.modelProgress != null) {
      text = 'Downloading voice model ${(p.modelProgress! * 100).round()}%';
    } else if (p.isPreparing) {
      text = 'Starting mic';
    } else if (p.isInterrupted) {
      text = 'Mic interrupted';
    } else if (live) {
      text = 'Listening';
    } else if (p.hasTake) {
      text = 'Paused';
    } else {
      text = 'Mic off';
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: live
            ? AppColors.tally.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TallyDot(live: live),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: live ? AppColors.paper : AppColors.muted,
            ),
          ),
          if (live) ...[
            const SizedBox(width: 10),
            ValueListenableBuilder<double>(
              valueListenable: p.level,
              builder: (context, db, _) => _Meter(db: db),
            ),
          ],
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  final double db;
  const _Meter({required this.db});

  @override
  Widget build(BuildContext context) {
    // -55 dBFS (room tone) to -15 dBFS (close, confident speech).
    final lit = ((db + 55) / 40 * 5).clamp(0, 5).round();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 5; i++)
          Container(
            width: 3,
            height: 6.0 + i * 2.5,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: i < lit
                  ? (i >= 4 ? AppColors.cue : AppColors.paper)
                  : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
      ],
    );
  }
}

/// Elapsed time, pace and filler count, quiet enough to ignore while reading.
class StatsReadout extends StatelessWidget {
  const StatsReadout({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<IntelligentTeleprompterProvider>();
    final wpm = p.wordsPerMinute;
    final fillers = p.stats.fillerCount;
    Widget item(String value, String unit) => Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: value, style: AppTheme.figureSmall),
            TextSpan(
              text: ' $unit',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
    return StreamBuilder<int>(
      // Tick once a second so the clock moves between speech updates.
      stream: p.isSpeechActive
          ? Stream.periodic(const Duration(seconds: 1), (i) => i)
          : null,
      builder: (context, _) => Container(
        padding: const EdgeInsets.fromLTRB(0, 6, 14, 6),
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: Colors.black.withValues(alpha: 0.72),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            item(formatClock(p.elapsed), ''),
            item(wpm > 0 ? wpm.round().toString() : '–', 'wpm'),
            item('$fillers', fillers == 1 ? 'filler' : 'fillers'),
          ],
        ),
      ),
    );
  }
}

/// Display settings in a panel that slides in from the right. The prompter
/// stays visible (dimmed, not blurred) so size and alignment changes show live.
Future<void> showDisplaySheet(BuildContext context) {
  final provider = context.read<IntelligentTeleprompterProvider>();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close display settings',
    barrierColor: Colors.black.withValues(alpha: 0.25),
    transitionDuration: Duration(milliseconds: reduceMotion(context) ? 1 : 340),
    pageBuilder: (_, _, _) => ChangeNotifierProvider.value(
      value: provider,
      child: const _DisplayPanel(),
    ),
    transitionBuilder: (context, animation, _, child) {
      final t = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(t),
        child: child,
      );
    },
  );
}

class _DisplayPanel extends StatelessWidget {
  const _DisplayPanel();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<IntelligentTeleprompterProvider>();
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 360,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.raised,
          borderRadius: BorderRadius.horizontal(left: Radius.circular(28)),
          border: Border(left: BorderSide(color: AppColors.line)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            left: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Display', style: text.titleLarge)),
                    _RoundButton(
                      icon: Icons.close_rounded,
                      label: 'Close',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Text size', style: text.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _RoundButton(
                      icon: Icons.remove_rounded,
                      label: 'Smaller text',
                      onPressed: p.decreaseFontSize,
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${p.fontSize.toInt()}',
                          style: AppTheme.figure,
                        ),
                      ),
                    ),
                    _RoundButton(
                      icon: Icons.add_rounded,
                      label: 'Larger text',
                      onPressed: p.increaseFontSize,
                    ),
                  ],
                ),
                Slider(
                  min: 16,
                  max: 72,
                  divisions: 28,
                  value: p.fontSize,
                  onChanged: p.setFontSize,
                ),
                const Divider(height: 28),
                SwitchRow(
                  title: 'Center lines',
                  subtitle: 'Off lines up text on the left',
                  value: p.centerText,
                  onChanged: (_) => p.toggleCenterText(),
                ),
                SwitchRow(
                  title: 'Mirror for glass',
                  subtitle: 'Flip text for a beam-splitter teleprompter',
                  value: p.isMirrored,
                  onChanged: (_) => p.toggleMirror(),
                ),
                SwitchRow(
                  title: 'Time, pace and fillers',
                  subtitle: 'The readout in the top corner',
                  value: p.showStats,
                  onChanged: (_) => p.toggleStats(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The tally dot. While live it sends out a slow ring, like an on-air light.
class _TallyDot extends StatefulWidget {
  final bool live;
  const _TallyDot({required this.live});

  @override
  State<_TallyDot> createState() => _TallyDotState();
}

class _TallyDotState extends State<_TallyDot>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_TallyDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.live && !reduceMotion(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.live ? AppColors.tally : AppColors.muted;
    return SizedBox(
      width: 10,
      height: 10,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _TallyPainter(color: color, ring: widget.live ? _c.value : null),
        ),
      ),
    );
  }
}

class _TallyPainter extends CustomPainter {
  final Color color;
  final double? ring;
  _TallyPainter({required this.color, this.ring});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final t = ring;
    if (t != null) {
      final eased = Curves.easeOut.transform(t);
      canvas.drawCircle(
        c,
        r + r * 1.6 * eased,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: 0.7 * (1 - eased)),
      );
      canvas.drawCircle(
        c,
        r * 1.3,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawCircle(c, r, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TallyPainter old) => old.ring != ring || old.color != color;
}
