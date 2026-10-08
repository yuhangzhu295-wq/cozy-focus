/// How long something is, written the way the designs write it.
///
/// In the domain rather than in a widget because the timeline projection builds
/// its own detail lines — `50 分钟 · 剩余 25 分钟` — and a second formatter there
/// would be a second answer to what an hour is. The presentation layer's
/// `formatTaskDuration` delegates here.
library;

/// How many minutes a duration is worth.
///
/// The app's **one** rule for turning seconds into minutes, so a figure and its
/// breakdown cannot disagree. The report pages used to split seconds themselves
/// with integer division, which floors: a week of 9,359 seconds read
/// `2 小时 36 分钟` on the records screen, where [formatDurationText] rounds, and
/// `2h 35m` on the weekly report, which floored — the same week, two answers.
/// The wrapped page rounded to whole hours on top of that, so the same week was
/// `3 小时` there.
///
/// Rounds rather than floors because this reports time already spent: ninety
/// seconds is nearer two minutes than one. What gets **paid** is a separate
/// question with its own rule — `RewardService.settle` floors, because paying for
/// a minute nobody spent is a different mistake from rounding a display, and the
/// two are not the same decision.
int durationMinutes(int seconds) => seconds <= 0 ? 0 : (seconds / 60).round();

/// `25 分钟`, `1 小时`, `1 小时 15 分钟`, or 未设置 when nothing was set.
String formatDurationText(int seconds) {
  if (seconds <= 0) return '未设置';
  final totalMinutes = durationMinutes(seconds);
  if (totalMinutes < 60) return '$totalMinutes 分钟';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) return '$hours 小时';
  return '$hours 小时 $minutes 分钟';
}

/// The same duration split into the parts a report prints separately.
///
/// `2h 35m` is the form design 06 uses inside its ring, so the report pages keep
/// that shape — but the numbers now come from [durationMinutes], which is what
/// stops them disagreeing with every other screen.
({int hours, int minutes}) durationParts(int seconds) {
  final total = durationMinutes(seconds);
  return (hours: total ~/ 60, minutes: total % 60);
}
