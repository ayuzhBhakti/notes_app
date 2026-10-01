/// Human-readable timestamp for a note row.
///
/// Deliberately hand-rolled rather than pulling in `intl` for one line of
/// output. [when] is null while a server timestamp is still unresolved.
String formatNoteTime(DateTime? when) {
  if (when == null) return 'Saving…';

  final DateTime now = DateTime.now();
  final Duration diff = now.difference(when);

  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final String day = when.day.toString();
  final String month = months[when.month - 1];
  return when.year == now.year
      ? '$day $month'
      : '$day $month ${when.year}';
}
