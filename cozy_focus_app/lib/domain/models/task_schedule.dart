/// One task placed on one day.
library;

import 'task.dart';

/// Where a placement is in its life.
///
/// `planned` and `done` are what the product has; `skipped` exists because a
/// day ends and a plan that was not done should stop being "next" rather than
/// sitting at the top of tomorrow's list forever.
enum TaskScheduleStatus {
  planned('planned'),
  done('done'),
  skipped('skipped');

  final String id;
  const TaskScheduleStatus(this.id);

  static TaskScheduleStatus fromId(String? id) {
    for (final status in TaskScheduleStatus.values) {
      if (status.id == id) return status;
    }
    return TaskScheduleStatus.planned;
  }
}

/// A task, on a day, at a time.
class TaskSchedule {
  final String id;
  final String taskId;
  final String userId;

  /// The local calendar day, `YYYY-MM-DD`.
  final String date;

  final DateTime startAt;
  final int plannedSeconds;
  final TaskScheduleStatus status;
  final DateTime createdAt;

  const TaskSchedule({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.date,
    required this.startAt,
    required this.plannedSeconds,
    required this.createdAt,
    this.status = TaskScheduleStatus.planned,
  });

  bool get isPlanned => status == TaskScheduleStatus.planned;

  TaskSchedule copyWith({
    DateTime? startAt,
    int? plannedSeconds,
    TaskScheduleStatus? status,
  }) =>
      TaskSchedule(
        id: id,
        taskId: taskId,
        userId: userId,
        // Re-derived whenever the time moves: the two are never allowed to
        // disagree, so there is no path that sets one without the other.
        date: startAt != null ? dayKeyFor(startAt) : date,
        startAt: startAt ?? this.startAt,
        plannedSeconds: plannedSeconds ?? this.plannedSeconds,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  @override
  String toString() =>
      'TaskSchedule($id task=$taskId $date ${plannedSeconds}s ${status.id})';
}

/// The `YYYY-MM-DD` key for a local time.
///
/// One function, used by the column, by the queries and by the tests, because
/// two implementations of "what day is this" is how a plan lands on the wrong
/// day at a timezone boundary.
String dayKeyFor(DateTime at) {
  final month = at.month.toString().padLeft(2, '0');
  final day = at.day.toString().padLeft(2, '0');
  return '${at.year}-$month-$day';
}

/// A schedule with the task it places.
///
/// A read model for the today view, which needs both and would otherwise do a
/// lookup per row.
class PlannedTask {
  final TaskSchedule schedule;
  final String title;
  final String? categoryId;

  /// Whether the task itself is finished, as opposed to this placement.
  ///
  /// Two different facts, and the screen needs both: a task marked done from the
  /// task list used to keep being offered as 下一个任务 with a 开始 button, because
  /// the plan only ever read the placement's own status.
  final TaskStatus taskStatus;

  const PlannedTask({
    required this.schedule,
    required this.title,
    this.categoryId,
    this.taskStatus = TaskStatus.open,
  });

  /// Whether there is anything left to do here, from either record.
  bool get isOutstanding => schedule.isPlanned && taskStatus != TaskStatus.done;

  @override
  String toString() => 'PlannedTask(${schedule.date} "$title")';
}
