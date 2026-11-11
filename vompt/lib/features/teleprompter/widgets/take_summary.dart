import 'package:material_ui/material_ui.dart';

import '../../../core/constants/colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/script_assistant.dart';
import '../../../shared/widgets/motion.dart';
import '../engine/performance_analyzer.dart';
import 'intelligent_teleprompter_controls.dart' show formatClock;

/// Plain-language read on pace, for video and live delivery.
({String label, Color color}) paceVerdict(double wpm) {
  if (wpm <= 0) {
    return (label: 'Not enough speech to judge pace', color: AppColors.muted);
  }
  if (wpm < 120) {
    return (label: 'Slow. Most viewers like 130 to 165', color: AppColors.cue);
  }
  if (wpm <= 170) return (label: 'Comfortable pace', color: AppColors.good);
  return (label: 'Fast. Try to land closer to 150', color: AppColors.cue);
}

/// What happened in the take that just ended, with the next step.
class TakeSummary extends StatelessWidget {
  final PerformanceStats stats;
  final Duration duration;
  final double wordsPerMinute;
  final List<String> scriptWords;
  final bool countsVocalFillers;
  final VoidCallback onAgain;
  final VoidCallback onDone;

  const TakeSummary({
    super.key,
    required this.stats,
    required this.duration,
    required this.wordsPerMinute,
    required this.scriptWords,
    required this.countsVocalFillers,
    required this.onAgain,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final pace = paceVerdict(wordsPerMinute);
    final fillers = stats.fillers.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final theme = Theme.of(context);

    final headline =
        '${formatClock(duration)} at ${wordsPerMinute.round()} words a minute.';
    final parts = <String>[
      stats.fillerCount == 0
          ? 'No fillers'
          : '${stats.fillerCount} ${stats.fillerCount == 1 ? 'filler' : 'fillers'}',
      if (stats.skipped.isNotEmpty)
        '${stats.skippedWords} ${stats.skippedWords == 1 ? 'word' : 'words'} skipped',
      '${(stats.accuracy * 100).round()}% of words read as written',
    ];

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(headline, style: theme.textTheme.displaySmall),
        const SizedBox(height: 10),
        Text(
          '${parts.join(', ')}.',
          style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: pace.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                pace.label,
                style: TextStyle(
                  color: pace.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: onAgain,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Run it again'),
            ),
            OutlinedButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ],
    );

    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CoachNotes(
          stats: stats,
          duration: duration,
          wordsPerMinute: wordsPerMinute,
          scriptWords: scriptWords,
        ),
        _Section(
          title: 'Fillers',
          empty: 'None heard. Clean take.',
          note: countsVocalFillers
              ? null
              : 'This iPhone can\'t hear "um" and "uh", so only filler words like "like" are counted.',
          children: [
            for (final f in fillers)
              _CountRow(
                label: '"${f.key}"',
                count: f.value,
                max: fillers.first.value,
              ),
          ],
        ),
        _Section(
          title: 'Skipped',
          empty: 'Nothing skipped.',
          children: [
            for (final r in stats.skipped.take(4))
              _Quote(
                scriptWords.sublist(r.firstWord, r.lastWord + 1).join(' '),
              ),
            if (stats.skipped.length > 4)
              _Muted('and ${stats.skipped.length - 4} more'),
          ],
        ),
        _Section(
          title: 'Words that didn\'t match',
          empty: 'Every word matched the script.',
          note: stats.misreads.isEmpty
              ? null
              : 'Some of these may be the recognizer mishearing you.',
          children: [
            for (final m in stats.misreads.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Said ',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      TextSpan(
                        text: '"${m.said}"',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(
                        text: ' for ',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      TextSpan(
                        text: '"${m.expected}"',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            if (stats.misreads.length > 6)
              _Muted('and ${stats.misreads.length - 6} more'),
          ],
        ),
        _Section(
          title: 'Flow',
          children: [
            Text(
              stats.repeats == 0
                  ? 'No restarts.'
                  : '${stats.repeats} ${stats.repeats == 1 ? 'restart' : 'restarts'}, where you went back over words.',
            ),
            const SizedBox(height: 6),
            Text(
              stats.longPauses == 0
                  ? 'No pauses over ${PerformanceAnalyzer.longPauseSeconds.round()} seconds.'
                  : '${stats.longPauses} long ${stats.longPauses == 1 ? 'pause' : 'pauses'}, longest ${stats.longestPause.toStringAsFixed(1)} s.',
            ),
          ],
        ),
      ],
    );

    return Material(
      color: AppColors.ink,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth > 700;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: RiseIn(child: left)),
                        const SizedBox(width: 48),
                        Expanded(
                          flex: 6,
                          child: RiseIn(
                            delay: const Duration(milliseconds: 160),
                            child: right,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        RiseIn(child: left),
                        const SizedBox(height: 32),
                        RiseIn(
                          delay: const Duration(milliseconds: 160),
                          child: right,
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

/// Three tips from Apple's on-device model. Hidden when it isn't available.
class _CoachNotes extends StatefulWidget {
  final PerformanceStats stats;
  final Duration duration;
  final double wordsPerMinute;
  final List<String> scriptWords;
  const _CoachNotes({
    required this.stats,
    required this.duration,
    required this.wordsPerMinute,
    required this.scriptWords,
  });

  @override
  State<_CoachNotes> createState() => _CoachNotesState();
}

class _CoachNotesState extends State<_CoachNotes> {
  late final Future<String?> _tips = _load();

  Future<String?> _load() async {
    if (widget.duration.inSeconds < 10) return null;
    final assistant = ScriptAssistant.instance;
    if (!(await assistant.availability()).available) return null;
    try {
      return await assistant.coach(
        widget.stats,
        duration: widget.duration,
        wordsPerMinute: widget.wordsPerMinute,
        scriptWords: widget.scriptWords,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _tips,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _Section(
            title: 'Coach notes',
            children: [_Muted('Thinking it over…')],
          );
        }
        final tips = snap.data;
        if (tips == null || tips.isEmpty) return const SizedBox.shrink();
        return _Section(
          title: 'Coach notes',
          children: [
            for (final tip in tips.split('\n'))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(tip),
              ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? empty;
  final String? note;
  final List<Widget> children;
  const _Section({
    required this.title,
    required this.children,
    this.empty,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (children.isEmpty && empty != null)
            _Muted(empty!)
          else
            ...children,
          if (note != null) ...[const SizedBox(height: 4), _Muted(note!)],
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  final String label;
  final int count;
  final int max;
  const _CountRow({
    required this.label,
    required this.count,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Align(
                alignment: Alignment.centerLeft,
                // Bars grow to their value as the summary appears.
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: count / max),
                  duration: Duration(
                    milliseconds: reduceMotion(context) ? 1 : 900,
                  ),
                  curve: Curves.easeOutCubic,
                  builder: (context, f, _) => Container(
                    height: 8,
                    width: c.maxWidth * f,
                    decoration: BoxDecoration(
                      color: AppColors.cue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: AppTheme.figureSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  final String text;
  const _Quote(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.cue, width: 2)),
      ),
      child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
    );
  }
}

class _Muted extends StatelessWidget {
  final String text;
  const _Muted(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodySmall);
}
