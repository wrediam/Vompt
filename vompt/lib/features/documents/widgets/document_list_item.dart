import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../data/models/document.dart';
import '../../../data/models/practice_session.dart';

/// One script in the library: title, its opening line, and how it last went.
class DocumentListItem extends StatelessWidget {
  final Document document;
  final PracticeSession? latestTake;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Future<bool> Function() onDelete;

  const DocumentListItem({
    super.key,
    required this.document,
    required this.latestTake,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  static String relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return DateFormat('EEEE').format(date);
    return DateFormat('MMM d').format(date);
  }

  static String readTime(int words) {
    final seconds = (words / 150 * 60).round();
    if (words == 0) return 'Empty';
    if (seconds < 60) return '$seconds s read';
    final m = seconds ~/ 60, s = seconds % 60;
    return s < 15
        ? '$m min read'
        : '$m min ${s.toString().padLeft(2, '0')} s read';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final preview = document.content.trim().replaceAll(RegExp(r'\s+'), ' ');
    final take = latestTake;

    return Dismissible(
      key: ValueKey(document.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.tally,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document.title,
                style: text.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    readTime(document.wordCount),
                    style: text.labelMedium?.copyWith(color: AppColors.paper),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Edited ${relativeDate(document.modifiedAt)}',
                    style: text.bodySmall,
                  ),
                  const Spacer(),
                  if (take != null) _TakeBadge(take: take),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TakeBadge extends StatelessWidget {
  final PracticeSession take;
  const _TakeBadge({required this.take});

  @override
  Widget build(BuildContext context) {
    final clean = take.fillerCount == 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: clean ? AppColors.good : AppColors.cue,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          clean
              ? 'Last take clean'
              : 'Last take ${take.fillerCount} ${take.fillerCount == 1 ? 'filler' : 'fillers'}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.paper),
        ),
      ],
    );
  }
}
