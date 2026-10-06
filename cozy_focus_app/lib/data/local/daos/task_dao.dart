import 'package:drift/drift.dart';

import '../../../domain/models/task.dart' as domain;
import '../tables/focus_records_table.dart';
import '../tables/task_tables.dart';
import '../app_database.dart';

part 'task_dao.g.dart';

/// Reads and writes tasks and their subtasks.
///
/// It also aggregates `focus_records`, because "how long have I spent on this"
/// is a question about records joined by task id — and a repository that made
/// the caller do that join would put the same SQL in every screen that wants the
/// number.
@DriftAccessor(tables: [Tasks, TaskSubtasks, FocusRecords])
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

  domain.TaskSubtask _mapSubtask(TaskSubtask row) => domain.TaskSubtask(
        id: row.id,
        taskId: row.taskId,
        title: row.title,
        isDone: row.isDone,
        sortOrder: row.sortOrder,
      );
}
