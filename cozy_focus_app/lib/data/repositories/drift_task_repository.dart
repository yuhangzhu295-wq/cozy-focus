import '../../domain/models/task.dart' as domain;
import '../../domain/repositories/i_task_repository.dart';
import '../local/daos/task_dao.dart';

/// The task repository, backed by Drift.
///
/// Thin on purpose: the queries live in the DAO, and the assembly of a task with
/// its progress lives here because that is a read-model decision rather than a
/// storage one.
class DriftTaskRepository implements ITaskRepository {
  final TaskDao _dao;
  DriftTaskRepository(this._dao);

  @override
  Future<List<domain.Task>> findByFilter(
    String userId,
    TaskFilter filter,
  ) {
    switch (filter) {
      case TaskFilter.today:
        // Until P2 lands the schedule domain there is no "today" to filter by.
        // Answering with the open tasks is the honest stand-in: it is the same
        // set the screen showed before the tab existed, and P2 replaces this
        // branch with a real schedule lookup rather than leaving it.
        return _dao.findByFilter(userId, domain.TaskStatus.open);
      case TaskFilter.active:
        return _dao.findByFilter(userId, domain.TaskStatus.open);
      case TaskFilter.done:
        return _dao.findByFilter(userId, domain.TaskStatus.done);
    }
  }

  @override
  Future<domain.Task?> findById(String id) => _dao.findById(id);

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
