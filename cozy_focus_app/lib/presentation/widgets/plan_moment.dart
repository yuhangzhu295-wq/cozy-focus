/// How a planned moment is written on screen.
///
/// Separate from [formatTaskDuration] because this is a point in time rather
/// than a length, and separate from the today view's own label because the two
/// answer different questions: the plan screen names the day it is showing, while
/// a tile has to say *which* day the plan is for.
library;

import '../../domain/models/task_schedule.dart';

/// `今天 14:00`, `明天 09:00`, or `10 月 8 日 09:00`.
///
/// [now] is passed in rather than read here so the label follows the app's clock
/// and can be tested on a day that is not today.
String formatPlanMoment(TaskSchedule schedule, DateTime now) {
  final at = schedule.startAt;
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final time =
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

  final difference = day.difference(today).inDays;
  if (difference == 0) return '今天 $time';
  if (difference == 1) return '明天 $time';
  if (difference == -1) return '昨天 $time';
  return '${at.month} 月 ${at.day} 日 $time';
}
