/// Short relative time such as "just now", "5m ago", "3h ago", "2d ago" or "4w ago".
String timeAgo(DateTime? time) {
  if (time == null) return '';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}

const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Date and time such as "Sat 2 Nov, 8:00 PM"; the year is added when it isn't this year.
String formatDateTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final year = time.year == DateTime.now().year ? '' : ' ${time.year}';
  return '${_weekdays[time.weekday - 1]} ${time.day} ${_months[time.month - 1]}$year, '
      '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
}

/// Date such as "2 Nov 2026".
String formatDate(DateTime time) => '${time.day} ${_months[time.month - 1]} ${time.year}';
