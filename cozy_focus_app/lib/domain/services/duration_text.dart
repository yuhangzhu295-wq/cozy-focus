/// How long something is, written the way the designs write it.
///
/// In the domain rather than in a widget because the timeline projection builds
/// its own detail lines — `50 分钟 · 剩余 25 分钟` — and a second formatter there
/// would be a second answer to what an hour is. The presentation layer's
/// `formatTaskDuration` delegates here.
library;

/// `25 分钟`, `1 小时`, `1 小时 15 分钟`, or 未设置 when nothing was set.
String formatDurationText(int seconds) {
  if (seconds <= 0) return '未设置';
  final totalMinutes = (seconds / 60).round();
  if (totalMinutes < 60) return '$totalMinutes 分钟';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) return '$hours 小时';
  return '$hours 小时 $minutes 分钟';
}
