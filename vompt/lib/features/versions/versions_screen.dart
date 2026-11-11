import 'package:material_ui/material_ui.dart';

import '../../core/constants/colors.dart';
import '../../core/utils/dates.dart';
import '../../data/models/document.dart';
import '../../data/models/script_version.dart';
import '../../data/repositories/version_repository.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/readable_width.dart';
import 'version_detail_screen.dart';

/// Restores [version] over the current script; returns once saved.
typedef RestoreVersion = Future<void> Function(ScriptVersion version);

/// The script's history as a timeline, newest at the top.
class VersionsScreen extends StatefulWidget {
  final Document document;
  final RestoreVersion onRestore;

  const VersionsScreen({
    super.key,
    required this.document,
    required this.onRestore,
  });

  @override
  State<VersionsScreen> createState() => _VersionsScreenState();
}

class _VersionsScreenState extends State<VersionsScreen> {
  List<ScriptVersion>? _versions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = VersionRepository();
    // Make sure what is on screen now is in the history.
    await repo.checkpoint(widget.document, VersionKind.edit);
    final versions = await repo.forDocument(widget.document.id);
    if (mounted) setState(() => _versions = versions);
  }

  Future<void> _open(ScriptVersion version, ScriptVersion? older) async {
    final restored = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VersionDetailScreen(
          document: widget.document,
          version: version,
          onRestore: widget.onRestore,
        ),
      ),
    );
    if (restored == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final versions = _versions;
    return Scaffold(
      appBar: AppBar(title: const Text('Versions')),
      body: versions == null
          ? const Center(child: CircularProgressIndicator())
          : ReadableWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
                children: [
                  Text(widget.document.title, style: text.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    versions.isEmpty
                        ? 'Versions appear here as you edit and use Assist.'
                        : '${versions.length} ${versions.length == 1 ? 'version' : 'versions'} since '
                              '${friendlyWhen(versions.last.createdAt).split(',').first}. '
                              'Tap one to compare it with your script now.',
                    style: text.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 22),
                  for (var i = 0; i < versions.length; i++)
                    RiseIn(
                      delay: Duration(milliseconds: 40 * (i < 12 ? i : 12)),
                      child: _TimelineEntry(
                        version: versions[i],
                        older: i + 1 < versions.length ? versions[i + 1] : null,
                        isCurrent: versions[i].content == widget.document.content,
                        isFirst: i == 0,
                        isLast: i == versions.length - 1,
                        onTap: () => _open(
                          versions[i],
                          i + 1 < versions.length ? versions[i + 1] : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final ScriptVersion version;
  final ScriptVersion? older;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _TimelineEntry({
    required this.version,
    required this.older,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final delta = older == null ? null : version.wordCount - older!.wordCount;
    final excerpt = version.content.trim().replaceAll(RegExp(r'\s+'), ' ');
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: CustomPaint(
              painter: _RailPainter(isFirst: isFirst, isLast: isLast),
              child: Align(
                alignment: const Alignment(0, -0.62),
                child: _Node(kind: version.kind, current: isCurrent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Pressable(
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: isCurrent ? AppColors.raisedHigh : AppColors.raised,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrent
                        ? AppColors.cue.withValues(alpha: 0.5)
                        : AppColors.line,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(version.headline, style: text.titleSmall),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: ShapeDecoration(
                              color: AppColors.cue.withValues(alpha: 0.16),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text(
                              'Current',
                              style: TextStyle(
                                color: AppColors.cue,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        style: text.bodySmall,
                        children: [
                          TextSpan(text: friendlyWhen(version.createdAt)),
                          TextSpan(text: '   ${version.wordCount} words'),
                          if (delta != null && delta != 0)
                            TextSpan(
                              text: delta > 0 ? '   +$delta' : '   −${-delta}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: delta > 0
                                    ? AppColors.cue
                                    : AppColors.tally.withValues(alpha: 0.9),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  final bool isFirst;
  final bool isLast;
  const _RailPainter({required this.isFirst, required this.isLast});

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final node = size.height * 0.19;
    final paint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 2;
    if (!isFirst) canvas.drawLine(Offset(x, 0), Offset(x, node), paint);
    if (!isLast) canvas.drawLine(Offset(x, node), Offset(x, size.height), paint);
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.isFirst != isFirst || old.isLast != isLast;
}

/// Timeline node: amber and glowing for the current text; a sparkle for
/// Assist, a return arrow for restores, a ring for edits.
class _Node extends StatelessWidget {
  final VersionKind kind;
  final bool current;
  const _Node({required this.kind, required this.current});

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      VersionKind.assist => Icons.auto_awesome_rounded,
      VersionKind.restore => Icons.undo_rounded,
      VersionKind.studio => Icons.laptop_rounded,
      _ => null,
    };
    final size = icon == null ? 14.0 : 26.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: current ? AppColors.cue : AppColors.ink,
        border: Border.all(
          color: current ? AppColors.cue : AppColors.paper.withValues(alpha: 0.7),
          width: 2,
        ),
        boxShadow: current
            ? [BoxShadow(color: AppColors.cue.withValues(alpha: 0.55), blurRadius: 12)]
            : null,
      ),
      child: icon == null
          ? null
          : Icon(
              icon,
              size: 14,
              color: current ? AppColors.onCue : AppColors.paper,
            ),
    );
  }
}
