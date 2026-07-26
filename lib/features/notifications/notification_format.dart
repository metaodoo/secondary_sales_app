import 'package:intl/intl.dart';

/// Short relative age for a notification timestamp (e.g. "5m ago", "3d ago"),
/// falling back to an absolute date beyond a week.
String notificationRelativeTime(DateTime? time) {
  if (time == null) return '';
  final diff = DateTime.now().difference(time);
  if (diff.isNegative || diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(time);
}

/// Full absolute timestamp for the detail view.
String notificationFullTime(DateTime? time) {
  if (time == null) return '';
  return DateFormat('MMM d, yyyy • h:mm a').format(time);
}
