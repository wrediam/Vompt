import 'package:intl/intl.dart';

/// "Today, 3:42 PM", "Yesterday, 9:10 AM", "Nov 7, 3:42 PM", "Nov 7, 2025".
String friendlyWhen(DateTime when, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateTime(when.year, when.month, when.day);
  final days = DateTime(today.year, today.month, today.day).difference(day).inDays;
  final time = DateFormat('h:mm a').format(when);
  if (days == 0) return 'Today, $time';
  if (days == 1) return 'Yesterday, $time';
  if (when.year != today.year) return DateFormat('MMM d, y').format(when);
  return '${DateFormat('MMM d').format(when)}, $time';
}
