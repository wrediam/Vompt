import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class WordCounter extends StatelessWidget {
  final int wordCount;
  final int characterCount;
  final double estimatedReadingTime;

  const WordCounter({
    super.key,
    required this.wordCount,
    required this.characterCount,
    required this.estimatedReadingTime,
  });

  String _formatReadingTime(double minutes) {
    if (minutes < 1) {
      final seconds = (minutes * 60).round();
      return '$seconds sec';
    } else if (minutes < 60) {
      return '${minutes.toStringAsFixed(1)} min';
    } else {
      final hours = (minutes / 60).floor();
      final mins = (minutes % 60).round();
      return '${hours}h ${mins}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.screenPadding,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat(
            context,
            icon: Icons.text_fields,
            label: 'Words',
            value: wordCount.toString(),
          ),
          _buildStat(
            context,
            icon: Icons.abc,
            label: 'Characters',
            value: characterCount.toString(),
          ),
          _buildStat(
            context,
            icon: Icons.schedule,
            label: 'Reading Time',
            value: _formatReadingTime(estimatedReadingTime),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.textTheme.bodyMedium?.color),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
