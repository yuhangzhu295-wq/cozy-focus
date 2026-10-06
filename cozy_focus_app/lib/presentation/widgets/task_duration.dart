/// How long something is, written the way the designs write it.
///
/// One function for the task list, the today plan, the detail card and the create
/// screen. It started on the list page when only two screens needed it; the third
/// and fourth copies are what the move avoids, because three roundings of the
/// same number is how two screens end up disagreeing about what an hour is.
library;

/// `25 分钟`, `1 小时`, `1 小时 15 分钟`, or 未设置 when nothing was set.
String formatTaskDuration(int seconds) {
  if (seconds <= 0) return '未设置';
  final totalMinutes = (seconds / 60).round();
  if (totalMinutes < 60) return '$totalMinutes 分钟';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) return '$hours 小时';
  return '$hours 小时 $minutes 分钟';
}
