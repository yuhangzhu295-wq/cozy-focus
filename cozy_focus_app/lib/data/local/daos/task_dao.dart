import 'package:drift/drift.dart';

import '../../../domain/models/task.dart' as domain;
import '../../../domain/models/task_schedule.dart' as schedule;
import '../tables/focus_records_table.dart';
import '../tables/task_schedule_table.dart';
import '../tables/task_tables.dart';
import '../app_database.dart';

part 'task_dao.g.dart';

/// Reads and writes tasks and their subtasks.
///
/// It also aggregates `focus_records`, because "how long have I spent on this"
/// is a question about records joined by task id — and a repository that made
/// the caller do that join would put the same SQL in every screen that wants the
/// number.
@DriftAccessor(tables: [Tasks, TaskSubtasks, TaskSchedules, FocusRecords])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);

  // ── tasks ─────────────────────────────────────────────────────────────────

  Future<void> insert(domain.Task task) async {
    await into(tasks).insert(
      TasksCompanion(
        id: Value(task.id),
        userId: Value(task.userId),
        title: Value(task.title),
        categoryId: Value(task.categoryId),
        estimatedSeconds: Value(task.estimatedSeconds),
        note: Value(task.note),
        status: Value(task.status.id),
        createdAt: Value(task.createdAt),
        completedAt: Value(task.completedAt),
        sortOrder: Value(task.sortOrder),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> updateTask(domain.Task task) async {
    await (update(tasks)..where((t) => t.id.equals(task.id))).write(
      TasksCompanion(
        title: Value(task.title),
        categoryId: Value(task.categoryId),
        estimatedSeconds: Value(task.estimatedSeconds),
        note: Value(task.note),
        status: Value(task.status.id),
        completedAt: Value(task.completedAt),
        sortOrder: Value(task.sortOrder),
      ),
    );
  }

  Future<void> setStatus(
      String taskId, domain.TaskStatus status, DateTime? at) async {
    await (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        status: Value(status.id),
        completedAt: Value(status == domain.TaskStatus.done ? at : null),
      ),
    );
  }

  /// Deletes the task. Its subtasks go with it through the foreign key, which
  /// requires `PRAGMA foreign_keys = ON` — set in `beforeOpen`.
  Future<void> deleteById(String id) async {
    await (delete(tasks)..where((t) => t.id.equals(id))).go();
  }

  Future<domain.Task?> findById(String id) async {
    final row =
        await (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapTask(row);
  }

  /// Tasks for one of the list screen's tabs.
  ///
  /// Ordering: open tasks by manual order then newest first, done tasks by when
  /// they were finished. A completed list sorted by creation would bury the
  /// thing the user just ticked.
  Future<List<domain.Task>> findByFilter(
    String userId,
    domain.TaskStatus status,
  ) async {
    final query = select(tasks)
      ..where((t) => t.userId.equals(userId))
      ..where((t) => t.status.equals(status.id));
    if (status == domain.TaskStatus.done) {
      query.orderBy([
        (t) => OrderingTerm.desc(t.completedAt),
        (t) => OrderingTerm.desc(t.createdAt),
      ]);
    } else {
      query.orderBy([
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.desc(t.createdAt),
      ]);
    }
    final rows = await query.get();
    return rows.map(_mapTask).toList();
  }

  /// Every task for a user, both states. For the timeline and the tests that
  /// assert a whole set.
  Future<List<domain.Task>> findAll(String userId) async {
    final rows = await (select(tasks)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_mapTask).toList();
  }

  Future<int> countOpen(String userId) async {
    final count = tasks.id.count();
    final query = selectOnly(tasks)
      ..addColumns([count])
      ..where(tasks.userId.equals(userId) &
          tasks.status.equals(domain.TaskStatus.open.id));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// The tasks a set of ids names, for the timeline's batch lookup.
  Future<List<domain.Task>> findByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await (select(tasks)..where((t) => t.id.isIn(ids))).get();
    return rows.map(_mapTask).toList();
  }

  // ── subtasks ──────────────────────────────────────────────────────────────

  Future<List<domain.TaskSubtask>> subtasksFor(String taskId) async {
    final rows = await (select(taskSubtasks)
          ..where((t) => t.taskId.equals(taskId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    return rows.map(_mapSubtask).toList();
  }

  Future<void> insertSubtask(domain.TaskSubtask subtask) async {
    await into(taskSubtasks).insert(
      TaskSubtasksCompanion(
        id: Value(subtask.id),
        taskId: Value(subtask.taskId),
        title: Value(subtask.title),
        isDone: Value(subtask.isDone),
        sortOrder: Value(subtask.sortOrder),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> updateSubtask(domain.TaskSubtask subtask) async {
    await (update(taskSubtasks)..where((t) => t.id.equals(subtask.id))).write(
      TaskSubtasksCompanion(
        title: Value(subtask.title),
        isDone: Value(subtask.isDone),
        sortOrder: Value(subtask.sortOrder),
      ),
    );
  }

  Future<void> deleteSubtask(String id) async {
    await (delete(taskSubtasks)..where((t) => t.id.equals(id))).go();
  }

  // ── focus totals ──────────────────────────────────────────────────────────

  /// Seconds and session count recorded against [taskId].
  ///
  /// One query for both numbers rather than two, and it is the *only* place the
  /// join lives. A task with no records is `(0, 0)` and not null, because "no
  /// focus yet" is an answer and not a missing one.
  Future<({int seconds, int sessions})> focusTotalsFor(String taskId) async {
    final seconds = focusRecords.durationSeconds.sum();
    final sessions = focusRecords.id.count();
    final query = selectOnly(focusRecords)
      ..addColumns([seconds, sessions])
      ..where(focusRecords.taskId.equals(taskId));
    final row = await query.getSingle();
    return (
      seconds: row.read(seconds) ?? 0,
      sessions: row.read(sessions) ?? 0,
    );
  }

  /// Focus totals for every task that has any, keyed by task id.
  ///
  /// The list screen needs this for a whole page at once; doing it per row would
  /// be N queries for one screen.
  Future<Map<String, ({int seconds, int sessions})>> focusTotalsByTask(
    String userId,
  ) async {
    final seconds = focusRecords.durationSeconds.sum();
    final sessions = focusRecords.id.count();
    final query = selectOnly(focusRecords)
      ..addColumns([focusRecords.taskId, seconds, sessions])
      ..where(
          focusRecords.userId.equals(userId) & focusRecords.taskId.isNotNull())
      ..groupBy([focusRecords.taskId]);
    final rows = await query.get();
    final result = <String, ({int seconds, int sessions})>{};
    for (final row in rows) {
      final id = row.read(focusRecords.taskId);
      if (id == null) continue;
      result[id] = (
        seconds: row.read(seconds) ?? 0,
        sessions: row.read(sessions) ?? 0,
      );
    }
    return result;
  }

  /// This task's focus records, newest first.
  ///
  /// Returns the raw rows rather than a domain `FocusRecord`, because the detail
  /// screen only needs the times and the duration and mapping the whole record
  /// would be work nobody reads. The list is capped because the screen shows the
  /// most recent few and "more" is a separate route.
  Future<List<({DateTime startAt, DateTime endAt, int durationSeconds})>>
      recentFocusFor(String taskId, {int limit = 5}) async {
    final rows = await (select(focusRecords)
          ..where((t) => t.taskId.equals(taskId))
          ..orderBy([(t) => OrderingTerm.desc(t.startAt)])
          ..limit(limit))
        .get();
    return [
      for (final row in rows)
        (
          startAt: row.startAt,
          endAt: row.endAt,
          durationSeconds: row.durationSeconds,
        ),
    ];
  }

  // ── schedules ─────────────────────────────────────────────────────────────

  Future<void> insertSchedule(schedule.TaskSchedule placement) async {
    await into(taskSchedules).insert(
      TaskSchedulesCompanion(
        id: Value(placement.id),
        taskId: Value(placement.taskId),
        userId: Value(placement.userId),
        date: Value(placement.date),
        startAt: Value(placement.startAt),
        plannedSeconds: Value(placement.plannedSeconds),
        status: Value(placement.status.id),
        createdAt: Value(placement.createdAt),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> updateSchedule(schedule.TaskSchedule placement) async {
    await (update(taskSchedules)..where((t) => t.id.equals(placement.id)))
        .write(
      TaskSchedulesCompanion(
        date: Value(placement.date),
        startAt: Value(placement.startAt),
        plannedSeconds: Value(placement.plannedSeconds),
        status: Value(placement.status.id),
      ),
    );
  }

  Future<void> deleteSchedule(String id) async {
    await (delete(taskSchedules)..where((t) => t.id.equals(id))).go();
  }

  /// A day's placements, in time order, each with the task it places.
  ///
  /// One join rather than a lookup per row: the today view draws every row with
  /// its title and category, and a query per row is N queries for one screen.
  Future<List<schedule.PlannedTask>> schedulesForDay(
    String userId,
    String date,
  ) async {
    final query = select(taskSchedules).join([
      innerJoin(tasks, tasks.id.equalsExp(taskSchedules.taskId)),
    ])
      ..where(
          taskSchedules.userId.equals(userId) & taskSchedules.date.equals(date))
      ..orderBy([OrderingTerm.asc(taskSchedules.startAt)]);

    final rows = await query.get();
    return [
      for (final row in rows)
        schedule.PlannedTask(
          schedule: _mapSchedule(row.readTable(taskSchedules)),
          title: row.readTable(tasks).title,
          categoryId: row.readTable(tasks).categoryId,
          taskStatus: domain.TaskStatus.fromId(row.readTable(tasks).status),
        ),
    ];
  }

  /// A task's placements from [from] onward, in time order.
  ///
  /// For the detail screen's "下次计划": the next time this task is planned,
  /// which is a different question from today's list.
  Future<List<schedule.TaskSchedule>> upcomingSchedulesFor(
    String taskId, {
    required String from,
    int limit = 1,
  }) async {
    final rows = await (select(taskSchedules)
          ..where((t) =>
              t.taskId.equals(taskId) &
              t.date.isBiggerOrEqualValue(from) &
              t.status.equals(schedule.TaskScheduleStatus.planned.id))
          ..orderBy([(t) => OrderingTerm.asc(t.startAt)])
          ..limit(limit))
        .get();
    return rows.map(_mapSchedule).toList();
  }

  /// Whether [taskId] is already placed on [date].
  ///
  /// Asked before adding, so the create screen's switch is idempotent rather
  /// than stacking a second placement on the same day.
  Future<bool> isScheduledOn(String taskId, String date) async {
    final count = taskSchedules.id.count();
    final query = selectOnly(taskSchedules)
      ..addColumns([count])
      ..where(taskSchedules.taskId.equals(taskId) &
          taskSchedules.date.equals(date));
    final row = await query.getSingle();
    return (row.read(count) ?? 0) > 0;
  }

  /// Tasks placed on [date], in start-time order.
  ///
  /// The task list's 今天 tab. A task with no placement is not here — that is
  /// what makes 今天 mean "planned for today" rather than "not finished yet",
  /// which is what 进行中 already means.
  Future<List<domain.Task>> tasksScheduledOn(String userId, String date) async {
    final query = select(tasks).join([
      innerJoin(taskSchedules, taskSchedules.taskId.equalsExp(tasks.id)),
    ])
      ..where(
          taskSchedules.userId.equals(userId) & taskSchedules.date.equals(date))
      ..orderBy([OrderingTerm.asc(taskSchedules.startAt)]);
    final rows = await query.get();
    return [for (final row in rows) _mapTask(row.readTable(tasks))];
  }

  /// Tasks created within [from, to), newest first.
  ///
  /// Half of the 今天 tab's second rule: a task written down today with no plan
  /// yet is still part of today, so that switching 加入今日计划 off on the create
  /// screen does not make the task invisible.
  Future<List<domain.Task>> tasksCreatedBetween(
    String userId,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await (select(tasks)
          ..where((t) =>
              t.userId.equals(userId) &
              t.createdAt.isBiggerOrEqualValue(from) &
              t.createdAt.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_mapTask).toList();
  }

  /// Every task id this user has a placement for, from [from] onward.
  ///
  /// One query for the whole set rather than one per task, so the 今天 tab can
  /// tell "created today but never planned" from "planned for another day"
  /// without a query per row.
  Future<Set<String>> taskIdsScheduledFrom(String userId, String from) async {
    final rows = await (select(taskSchedules)
          ..where((t) =>
              t.userId.equals(userId) & t.date.isBiggerOrEqualValue(from)))
        .get();
    return {for (final row in rows) row.taskId};
  }

  // ── mapping ───────────────────────────────────────────────────────────────

  domain.Task _mapTask(Task row) => domain.Task(
        id: row.id,
        userId: row.userId,
        title: row.title,
        categoryId: row.categoryId,
        estimatedSeconds: row.estimatedSeconds,
        note: row.note,
        status: domain.TaskStatus.fromId(row.status),
        createdAt: row.createdAt,
        completedAt: row.completedAt,
        sortOrder: row.sortOrder,
      );

  schedule.TaskSchedule _mapSchedule(TaskSchedule row) => schedule.TaskSchedule(
        id: row.id,
        taskId: row.taskId,
        userId: row.userId,
        date: row.date,
        startAt: row.startAt,
        plannedSeconds: row.plannedSeconds,
        status: schedule.TaskScheduleStatus.fromId(row.status),
        createdAt: row.createdAt,
      );

  domain.TaskSubtask _mapSubtask(TaskSubtask row) => domain.TaskSubtask(
        id: row.id,
        taskId: row.taskId,
        title: row.title,
        isDone: row.isDone,
        sortOrder: row.sortOrder,
      );
}
