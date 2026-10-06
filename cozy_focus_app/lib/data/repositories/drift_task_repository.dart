import 'package:uuid/uuid.dart';

import '../../domain/models/task.dart' as domain;
import '../../domain/models/task_schedule.dart' as plan;
import '../../domain/repositories/i_task_repository.dart';
import '../../domain/services/focus_clock.dart';
import '../local/daos/task_dao.dart';

/// The task repository, backed by Drift.
///
/// Thin on purpose: the queries live in the DAO, and the assembly of a task with
/// its progress lives here because that is a read-model decision rather than a
/// storage one.
class DriftTaskRepository implements ITaskRepository {
  final TaskDao _dao;

  /// Where "today" comes from.
  ///
  /// Injected rather than read from `DateTime.now()` inline so the today filter
  /// can be tested on a day that is not the day the test runs.
  final FocusClock _clock;

  DriftTaskRepository(this._dao, {FocusClock clock = const SystemFocusClock()})
      : _clock = clock;

  @override
  Future<List<domain.Task>> findByFilter(
    String userId,
    TaskFilter filter,
  ) {
    switch (filter) {
      case TaskFilter.today:
        return _findToday(userId);
      case TaskFilter.active:
        return _dao.findByFilter(userId, domain.TaskStatus.open);
      case TaskFilter.done:
        return _dao.findByFilter(userId, domain.TaskStatus.done);
    }
  }

  /// Today's tasks: the ones planned for today, then the ones written down today
  /// with no plan at all.
  ///
  /// Two rules rather than one, and each earns its place:
  ///
  /// * Planned for today is the primary meaning — it is what the today view
  ///   shows, in the same order, so the tab and the plan agree.
  /// * Written down today with no plan is the safety net. The create screen's
  ///   加入今日计划 switch can be turned off, and a task that then appeared in no
  ///   tab at all would look like it had been lost. It is still today's work.
  ///
  /// A task planned for another day is deliberately in neither rule: it belongs
  /// to that day, and it is still reachable under 进行中.
  Future<List<domain.Task>> _findToday(String userId) async {
    final now = _clock.now();
    final today = plan.dayKeyFor(now);
    final scheduled = await _dao.tasksScheduledOn(userId, today);

    final midnight = DateTime(now.year, now.month, now.day);
    final createdToday = await _dao.tasksCreatedBetween(
      userId,
      midnight,
      midnight.add(const Duration(days: 1)),
    );
    if (createdToday.isEmpty) return scheduled;

    final plannedSomewhere = await _dao.taskIdsScheduledFrom(userId, today);
    final seen = {for (final task in scheduled) task.id};
    final unscheduled = [
      for (final task in createdToday)
        if (!seen.contains(task.id) && !plannedSomewhere.contains(task.id))
          task,
    ];
    return [...scheduled, ...unscheduled];
  }

  @override
  Future<domain.Task?> findById(String id) => _dao.findById(id);

  @override
  Future<Map<String, domain.Task>> findByIds(List<String> ids) async {
    final found = await _dao.findByIds(ids);
    return {for (final task in found) task.id: task};
  }

  @override
  Future<domain.TaskWithProgress?> findWithProgress(String id) async {
    final task = await _dao.findById(id);
    if (task == null) return null;
    final subtasks = await _dao.subtasksFor(id);
    final totals = await _dao.focusTotalsFor(id);
    final recent = await _dao.recentFocusFor(id);
    return domain.TaskWithProgress(
      task: task,
      subtasks: subtasks,
      focusedSeconds: totals.seconds,
      sessionCount: totals.sessions,
      recentFocus: [
        for (final entry in recent)
          domain.TaskFocusEntry(
            startAt: entry.startAt,
            endAt: entry.endAt,
            durationSeconds: entry.durationSeconds,
          ),
      ],
    );
  }

  @override
  Future<void> insert(domain.Task task) => _dao.insert(task);

  @override
  Future<void> update(domain.Task task) => _dao.updateTask(task);

  @override
  Future<void> setStatus(
    String taskId,
    domain.TaskStatus status, {
    DateTime? at,
  }) =>
      _dao.setStatus(taskId, status, at ?? DateTime.now());

  @override
  Future<void> deleteById(String id) => _dao.deleteById(id);

  @override
  Future<List<domain.TaskSubtask>> subtasksFor(String taskId) =>
      _dao.subtasksFor(taskId);

  @override
  Future<void> insertSubtask(domain.TaskSubtask subtask) =>
      _dao.insertSubtask(subtask);

  @override
  Future<void> updateSubtask(domain.TaskSubtask subtask) =>
      _dao.updateSubtask(subtask);

  @override
  Future<void> deleteSubtask(String id) => _dao.deleteSubtask(id);

  @override
  Future<int> countOpen(String userId) => _dao.countOpen(userId);

  @override
  Future<List<plan.PlannedTask>> schedulesForDay(
    String userId,
    String date,
  ) =>
      _dao.schedulesForDay(userId, date);

  @override
  Future<List<plan.TaskSchedule>> upcomingSchedulesFor(
    String taskId, {
    required String from,
    int limit = 1,
  }) =>
      _dao.upcomingSchedulesFor(taskId, from: from, limit: limit);

  @override
  Future<bool> isScheduledOn(String taskId, String date) =>
      _dao.isScheduledOn(taskId, date);

  @override
  Future<plan.TaskSchedule?> findScheduleOn(String taskId, String date) async {
    final rows = await _dao.upcomingSchedulesFor(taskId, from: date, limit: 1);
    if (rows.isEmpty) return null;
    // `upcomingSchedulesFor` is `>= from` and skips finished placements, so the
    // first row can be a later day. The day has to match exactly.
    return rows.first.date == date ? rows.first : null;
  }

  @override
  Future<String> schedule({
    required String taskId,
    required String userId,
    required DateTime startAt,
    required int plannedSeconds,
  }) async {
    final day = plan.dayKeyFor(startAt);
    // Idempotent: a task already on this day keeps the placement it has. The
    // create screen's switch and the schedule sheet both call this, and neither
    // should be able to put the same task on the same day twice.
    if (await _dao.isScheduledOn(taskId, day)) {
      final existing = await _dao.upcomingSchedulesFor(taskId, from: day);
      if (existing.isNotEmpty) return existing.first.id;
    }
    final id = const Uuid().v4();
    await _dao.insertSchedule(plan.TaskSchedule(
      id: id,
      taskId: taskId,
      userId: userId,
      date: day,
      startAt: startAt,
      plannedSeconds: plannedSeconds,
      createdAt: DateTime.now(),
    ));
    return id;
  }

  @override
  Future<void> updateSchedule(plan.TaskSchedule placement) =>
      _dao.updateSchedule(placement);

  @override
  Future<void> deleteSchedule(String id) => _dao.deleteSchedule(id);

  /// Focus totals for every task a user has, for the list screen.
  ///
  /// On the repository rather than the interface because only the list screen
  /// needs the batch shape; the per-task number is what the detail screen asks
  /// for and it is already on [findWithProgress].
  Future<Map<String, ({int seconds, int sessions})>> focusTotalsByTask(
    String userId,
  ) =>
      _dao.focusTotalsByTask(userId);
}
