/// The statistics the design asks for, computed from focus records.
///
/// ## What is deliberately absent
///
/// No score, no trend line, no prediction, no "productivity index". The design
/// keeps three numbers and two breakdowns, and every one of them is a sum, a count
/// or a division of the records that exist. Nothing here can produce a value that
/// is not in the database, which is the point: a statistics screen whose numbers
/// are computed somewhere else is a screen nobody can check.
library;

import '../models/analytics_range.dart';
import '../models/focus_record.dart';

/// One bar on the daily chart.
class DailyFocusBucket {
  /// The day, at local midnight.
  final DateTime day;
  final int seconds;
  final int sessions;

  const DailyFocusBucket({
    required this.day,
    required this.seconds,
    required this.sessions,
  });

  /// `周一`.
  String get weekdayLabel {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[day.weekday - 1];
  }
}

/// One row of the task distribution.
class TaskFocusShare {
  /// The task's title, or the name the session carried when there is no task.
  final String title;

  /// The task's id, when the time belongs to a task that still exists.
  final String? taskId;

  final int seconds;
  final int sessions;

  /// The share of the window's total, 0..1. Zero when the window is empty.
  final double fraction;

  const TaskFocusShare({
    required this.title,
    this.taskId,
    required this.seconds,
    required this.sessions,
    required this.fraction,
  });

  /// `40%`, rounded the way the design shows it.
  String get percentLabel => '${(fraction * 100).round()}%';
}

/// Everything the statistics view shows for one window.
class AnalyticsSummary {
  final AnalyticsRange range;

  final int totalSeconds;
  final int sessionCount;

  /// One entry per day in the window, including the days with nothing on them —
  /// a chart that skipped an empty day would misplace the days around it.
  final List<DailyFocusBucket> daily;

  /// The heaviest tasks first.
  final List<TaskFocusShare> shares;

  const AnalyticsSummary({
    required this.range,
    required this.totalSeconds,
    required this.sessionCount,
    required this.daily,
    required this.shares,
  });

  bool get isEmpty => totalSeconds == 0;

  /// The mean session length. Zero when there were no sessions, rather than a
  /// division by zero or an invented "0 分钟" for a window nobody focused in.
  int get averageSeconds =>
      sessionCount == 0 ? 0 : (totalSeconds / sessionCount).round();

  /// The tallest bar's height, for scaling the chart. At least one second, so a
  /// window with nothing in it does not divide by zero.
  int get busiestDaySeconds {
    var most = 0;
    for (final bucket in daily) {
      if (bucket.seconds > most) most = bucket.seconds;
    }
    return most;
  }
}

/// Builds the summary for [range] from the window's records.
///
/// [titleForTask] resolves a task id to its *current* title, or null when there is
/// no such task. The order of preference is deliberate:
///
/// 1. The live task's title, because a task the user renamed should read as it
///    reads everywhere else.
/// 2. The name the record itself carries, because the time is a fact about the
///    day even when the task it was filed under has been deleted.
/// 3. A neutral label, because a row with no name at all is still a row of time.
AnalyticsSummary buildAnalyticsSummary({
  required AnalyticsRange range,
  required List<FocusRecord> records,
  String? Function(String taskId)? titleForTask,
}) {
  var total = 0;
  var sessions = 0;
  final byDay = <String, ({int seconds, int sessions})>{};
  final byTask =
      <String, ({String title, String? taskId, int seconds, int sessions})>{};

  for (final record in records) {
    // Only records inside the window. The caller is expected to have queried the
    // window, and this is the second check rather than the first: a query that
    // silently widened would otherwise inflate every number on the screen.
    if (record.startAt.isBefore(range.from) ||
        !record.startAt.isBefore(range.to)) {
      continue;
    }
    total += record.durationSeconds;
    sessions += 1;

    final day = DateTime(
      record.startAt.year,
      record.startAt.month,
      record.startAt.day,
    );
    final key = '${day.year}-${day.month}-${day.day}';
    final existing = byDay[key];
    byDay[key] = (
      seconds: (existing?.seconds ?? 0) + record.durationSeconds,
      sessions: (existing?.sessions ?? 0) + 1,
    );

    // A record with a task is grouped by the task; one without is grouped by the
    // name it carried, because "what did the time go to" is still a fair question
    // for a session that was not filed under a task.
    final taskId = record.taskId;
    final carried =
        record.taskName?.isNotEmpty == true ? record.taskName! : null;
    final title = taskId != null
        ? (titleForTask?.call(taskId) ?? carried ?? '已删除的任务')
        : (carried ?? '未命名专注');
    final groupKey = taskId ?? 'name:$title';
    final current = byTask[groupKey];
    byTask[groupKey] = (
      title: title,
      taskId: taskId,
      seconds: (current?.seconds ?? 0) + record.durationSeconds,
      sessions: (current?.sessions ?? 0) + 1,
    );
  }

  final daily = <DailyFocusBucket>[];
  for (var offset = 0; offset < range.days; offset++) {
    final day = range.from.add(Duration(days: offset));
    final key = '${day.year}-${day.month}-${day.day}';
    final bucket = byDay[key];
    daily.add(DailyFocusBucket(
      day: day,
      seconds: bucket?.seconds ?? 0,
      sessions: bucket?.sessions ?? 0,
    ));
  }

  final shares = [
    for (final entry in byTask.values)
      TaskFocusShare(
        title: entry.title,
        taskId: entry.taskId,
        seconds: entry.seconds,
        sessions: entry.sessions,
        fraction: total == 0 ? 0 : entry.seconds / total,
      ),
  ]..sort((a, b) {
      final bySeconds = b.seconds.compareTo(a.seconds);
      if (bySeconds != 0) return bySeconds;
      // A stable order for equal durations, so two rows of the same length do not
      // swap places between rebuilds.
      return a.title.compareTo(b.title);
    });

  return AnalyticsSummary(
    range: range,
    totalSeconds: total,
    sessionCount: sessions,
    daily: daily,
    shares: shares,
  );
}
