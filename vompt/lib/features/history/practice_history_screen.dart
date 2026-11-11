import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import '../../shared/widgets/readable_width.dart';

import '../../core/constants/colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/document.dart';
import '../../data/models/practice_session.dart';
import '../../data/repositories/practice_repository.dart';

/// Every practice take of one script, with the filler trend across takes.
class PracticeHistoryScreen extends StatefulWidget {
  final Document document;
  const PracticeHistoryScreen({super.key, required this.document});

  @override
  State<PracticeHistoryScreen> createState() => _PracticeHistoryScreenState();
}

class _PracticeHistoryScreenState extends State<PracticeHistoryScreen> {
  final _repo = PracticeRepository();
  List<PracticeSession>? _takes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final takes = await _repo.forDocument(widget.document.id);
    if (mounted) setState(() => _takes = takes);
  }

  Future<void> _delete(PracticeSession take) async {
    await _repo.delete(take.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final takes = _takes;
    return Scaffold(
      appBar: AppBar(title: Text(widget.document.title)),
      body: takes == null
          ? const Center(child: CircularProgressIndicator())
          : takes.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No takes yet', style: text.headlineSmall),
                  const SizedBox(height: 10),
                  Text(
                    'Tap Rehearse and read the script out loud. When you finish, '
                    'your pace, fillers and skipped lines are saved here.',
                    style: text.bodyLarge?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            )
          : ReadableWidth(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  _Trend(takes: takes),
                  const Divider(),
                  for (var i = 0; i < takes.length; i++) ...[
                    Dismissible(
                      key: ValueKey(takes[i].id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _delete(takes[i]),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: AppColors.tally,
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      child: _TakeRow(take: takes[i], number: takes.length - i),
                    ),
                    const Divider(indent: 20, endIndent: 20),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Trend extends StatelessWidget {
  final List<PracticeSession> takes;
  const _Trend({required this.takes});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final chronological = takes.reversed.toList();
    final latest = takes.first;
    final best = takes
        .map((t) => t.fillersPerMinute)
        .reduce((a, b) => a < b ? a : b);
    final String headline;
    if (takes.length == 1) {
      headline =
          '${latest.fillersPerMinute.toStringAsFixed(1)} fillers a minute on your first take.';
    } else {
      final first = chronological.first.fillersPerMinute;
      final now = latest.fillersPerMinute;
      headline = now < first
          ? 'Fillers down from ${first.toStringAsFixed(1)} to ${now.toStringAsFixed(1)} a minute over ${takes.length} takes.'
          : '${now.toStringAsFixed(1)} fillers a minute on your latest take. Your best is ${best.toStringAsFixed(1)}.';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: text.titleLarge),
          if (takes.length > 1) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 64,
              width: double.infinity,
              child: CustomPaint(
                painter: _Sparkline(
                  chronological.map((t) => t.fillersPerMinute).toList(),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Fillers a minute, oldest take on the left',
              style: text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Sparkline extends CustomPainter {
  final List<double> values;
  _Sparkline(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final top = maxV <= 0 ? 1.0 : maxV;
    Offset at(int i) => Offset(
      size.width * i / (values.length - 1),
      size.height - 6 - (size.height - 12) * (values[i] / top),
    );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.cue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      at(values.length - 1),
      4.5,
      Paint()..color = AppColors.cue,
    );
  }

  @override
  bool shouldRepaint(_Sparkline old) => old.values != values;
}

class _TakeRow extends StatelessWidget {
  final PracticeSession take;
  final int number;
  const _TakeRow({required this.take, required this.number});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final d = Duration(milliseconds: (take.durationSeconds * 1000).round());
    final clock =
        '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    final fillers = take.fillers.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    Widget figure(String value, String label) => Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTheme.figureSmall.copyWith(fontSize: 18)),
          Text(label, style: text.bodySmall),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Take $number', style: text.titleSmall),
              const SizedBox(width: 10),
              Text(
                DateFormat('MMM d, h:mm a').format(take.createdAt),
                style: text.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              figure(clock, 'time'),
              figure('${take.wordsPerMinute.round()}', 'wpm'),
              figure(
                '${take.fillerCount}',
                take.fillerCount == 1 ? 'filler' : 'fillers',
              ),
              figure('${(take.accuracy * 100).round()}%', 'as written'),
            ],
          ),
          if (fillers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              fillers.map((f) => '"${f.key}" ${f.value}').join(', '),
              style: text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
