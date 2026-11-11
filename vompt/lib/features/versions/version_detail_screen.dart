import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/text_diff.dart';
import '../../data/models/document.dart';
import '../../data/models/script_version.dart';
import '../../shared/widgets/diff_text.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/readable_width.dart';
import '../../shared/widgets/vompt_dialog.dart';
import 'versions_screen.dart';

TextDiff _compare(List<String> pair) => TextDiff.compare(pair[0], pair[1]);

/// One version, compared with the script as it is now, with Restore.
/// Pops true after a restore.
class VersionDetailScreen extends StatefulWidget {
  final Document document;
  final ScriptVersion version;
  final RestoreVersion onRestore;

  const VersionDetailScreen({
    super.key,
    required this.document,
    required this.version,
    required this.onRestore,
  });

  @override
  State<VersionDetailScreen> createState() => _VersionDetailScreenState();
}

class _VersionDetailScreenState extends State<VersionDetailScreen> {
  TextDiff? _diff;
  int _mode = 0;
  bool _restoring = false;

  bool get _isCurrent => widget.version.content == widget.document.content;

  @override
  void initState() {
    super.initState();
    final pair = [widget.version.content, widget.document.content];
    // Long scripts are compared off the UI thread.
    final run = pair[0].length + pair[1].length > 12000
        ? compute(_compare, pair)
        : Future.value(_compare(pair));
    run.then((d) {
      if (mounted) setState(() => _diff = d);
    });
  }

  Future<void> _restore() async {
    final ok = await confirmDialog(
      context,
      title: 'Restore this version?',
      message:
          'Your script now is saved as a version first, so you can switch back any time.',
      confirmLabel: 'Restore',
    );
    if (!ok || !mounted) return;
    setState(() => _restoring = true);
    await widget.onRestore(widget.version);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reading = text.bodyLarge!.copyWith(fontSize: 18, height: 1.6);
    final diff = _diff;
    return Scaffold(
      appBar: AppBar(title: Text(widget.version.headline)),
      body: ReadableWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friendlyWhen(widget.version.createdAt),
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  if (_isCurrent)
                    Text('This is your script now.', style: text.bodySmall)
                  else if (diff != null)
                    Row(
                      children: [
                        Flexible(child: DiffCounts(diff: diff)),
                        Text(' since this version', style: text.bodySmall),
                      ],
                    ),
                  if (!_isCurrent) ...[
                    const SizedBox(height: 14),
                    SegmentToggle(
                      labels: const ['What changed since', 'This version'],
                      selected: _mode,
                      onChanged: (i) => setState(() => _mode = i),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: diff == null && !_isCurrent
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _mode == 0 && !_isCurrent
                            ? Column(
                                key: const ValueKey('changes'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _Legend(),
                                  const SizedBox(height: 14),
                                  DiffText(diff: diff!, style: reading),
                                ],
                              )
                            : SelectableText(
                                widget.version.content,
                                key: const ValueKey('plain'),
                                style: reading,
                              ),
                      ),
                    ),
            ),
            if (!_isCurrent)
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: widget.version.content),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Version copied')),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted,
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy'),
                      ),
                      const Spacer(),
                      Pressable(
                        onTap: _restoring ? null : _restore,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          alignment: Alignment.center,
                          decoration: const ShapeDecoration(
                            color: AppColors.cue,
                            shape: StadiumBorder(),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.undo_rounded,
                                color: AppColors.onCue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _restoring ? 'Restoring' : 'Restore this version',
                                style: const TextStyle(
                                  color: AppColors.onCue,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    Widget chip(String sample, TextStyle style, String meaning) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(sample, style: style),
        const SizedBox(width: 6),
        Text(meaning, style: small),
      ],
    );
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [
        chip(
          'Added',
          TextStyle(
            fontWeight: FontWeight.w700,
            backgroundColor: AppColors.cue.withValues(alpha: 0.26),
            decoration: TextDecoration.underline,
            decorationColor: AppColors.cue,
          ),
          'since this version',
        ),
        chip(
          'Removed',
          TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.tally.withValues(alpha: 0.75),
            decoration: TextDecoration.lineThrough,
            decorationColor: AppColors.tally,
          ),
          'only in this version',
        ),
      ],
    );
  }
}
