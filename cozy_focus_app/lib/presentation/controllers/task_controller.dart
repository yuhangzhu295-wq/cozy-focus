import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/task.dart';
import '../../domain/repositories/i_task_repository.dart';
import '../../data/repositories/drift_task_repository.dart';
import 'providers.dart';

/// The task list screen's state.
class TaskListState {
  final bool isLoading;
  final TaskFilter filter;
  final List<Task> tasks;

  /// Focus totals for the tasks on screen, keyed by task id.
  ///
  /// Loaded with the list rather than per row: the screen shows a duration on
  /// every row, and a query per row is N queries for one page.
  final Map<String, ({int seconds, int sessions})> totals;

  final String? error;

  const TaskListState({
    this.isLoading = false,
    this.filter = TaskFilter.today,
    this.tasks = const [],
    this.totals = const {},
    this.error,
  });

  bool get isEmpty => !isLoading && tasks.isEmpty;

  TaskListState copyWith({
    bool? isLoading,
    TaskFilter? filter,
    List<Task>? tasks,
    Map<String, ({int seconds, int sessions})>? totals,
    String? Function()? error,
  }) =>
      TaskListState(
        isLoading: isLoading ?? this.isLoading,
        filter: filter ?? this.filter,
        tasks: tasks ?? this.tasks,
        totals: totals ?? this.totals,
        error: error != null ? error() : this.error,
      );

  /// The focused seconds recorded for [taskId], or zero.
  int secondsFor(String taskId) => totals[taskId]?.seconds ?? 0;
}

/// The task list, with its three tabs.
class TaskListController extends StateNotifier<TaskListState> {
  TaskListController(this._ref) : super(const TaskListState()) {
    load();
  }

  final Ref _ref;

  ITaskRepository get _repo => _ref.read(taskRepositoryProvider);

  String get _userId => _ref.read(currentUserIdProvider);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: () => null);
    try {
      final tasks = await _repo.findByFilter(_userId, state.filter);
      final totals = await _focusTotals();
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          tasks: tasks,
          totals: totals,
        );
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: () => '$error');
      }
    }
  }

  /// The batch focus totals, when the repository can answer them.
  ///
  /// Read through the concrete repository rather than the interface: the batch
  /// shape is a list-screen concern and the interface stays the set of things
  /// every implementation must be able to do. A repository that cannot answer
  /// gives an empty map, and the rows show no duration rather than a wrong one.
  Future<Map<String, ({int seconds, int sessions})>> _focusTotals() async {
    final repo = _repo;
    if (repo is DriftTaskRepository) {
      return repo.focusTotalsByTask(_userId);
    }
    return const {};
  }

  Future<void> setFilter(TaskFilter filter) async {
    if (state.filter == filter) return;
    state = state.copyWith(filter: filter, tasks: const []);
    await load();
  }

  /// Ticks a task done, or open again.
  ///
  /// Reloads rather than patching the list in place: a task that just became
  /// done belongs in a different tab, and leaving it in the current one would
  /// show a row the filter says is not there.
  Future<void> toggleDone(Task task) async {
    final next = task.isDone ? TaskStatus.open : TaskStatus.done;
    await _repo.setStatus(task.id, next, at: DateTime.now());
    await load();
  }

  Future<void> delete(String taskId) async {
    await _repo.deleteById(taskId);
    await load();
  }
}

/// The task detail screen's state.
class TaskDetailState {
  final bool isLoading;
  final TaskWithProgress? progress;
  final String? error;

  const TaskDetailState({
    this.isLoading = false,
    this.progress,
    this.error,
  });

  bool get isMissing => !isLoading && progress == null;

  TaskDetailState copyWith({
    bool? isLoading,
    TaskWithProgress? Function()? progress,
    String? Function()? error,
  }) =>
      TaskDetailState(
        isLoading: isLoading ?? this.isLoading,
        progress: progress != null ? progress() : this.progress,
        error: error != null ? error() : this.error,
      );
}

/// One task, by id.
class TaskDetailController extends StateNotifier<TaskDetailState> {
  TaskDetailController(this._ref, this.taskId)
      : super(const TaskDetailState()) {
    load();
  }

  final Ref _ref;
  final String taskId;

  ITaskRepository get _repo => _ref.read(taskRepositoryProvider);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: () => null);
    try {
      final progress = await _repo.findWithProgress(taskId);
      if (mounted) {
        state = state.copyWith(isLoading: false, progress: () => progress);
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: () => '$error');
      }
    }
  }

  Future<void> setStatus(TaskStatus status) async {
    await _repo.setStatus(taskId, status, at: DateTime.now());
    await load();
  }

  Future<void> updateNote(String? note) async {
    final current = state.progress?.task;
    if (current == null) return;
    await _repo.update(current.copyWith(note: () => note));
    await load();
  }

  Future<void> toggleSubtask(TaskSubtask subtask) async {
    await _repo.updateSubtask(subtask.copyWith(isDone: !subtask.isDone));
    await load();
  }

  Future<void> addSubtask(String title) async {
    await _repo.insertSubtask(TaskSubtask(
      id: const Uuid().v4(),
      taskId: taskId,
      title: title,
      sortOrder: state.progress?.subtasks.length ?? 0,
    ));
    await load();
  }

  Future<void> deleteSubtask(String id) async {
    await _repo.deleteSubtask(id);
    await load();
  }

  Future<void> deleteTask() => _repo.deleteById(taskId);
}

/// Creates a task and returns its id.
///
/// A plain function rather than a controller: creating is a one-shot action with
/// a result, and the create screen navigates to the new task. A notifier would
/// be state nobody reads.
///
/// Takes the repository and the user id rather than a `Ref`, so it is callable
/// from a widget, from a test and from the P4 inbox's "turn this note into a
/// task" without any of them constructing a container.
Future<String> createTask({
  required ITaskRepository repository,
  required String userId,
  required String title,
  String? categoryId,
  int? estimatedSeconds,
  String? note,
  String? id,
}) async {
  final taskId = id ?? const Uuid().v4();
  final trimmedNote = note?.trim();
  await repository.insert(Task(
    id: taskId,
    userId: userId,
    title: title.trim(),
    categoryId: categoryId,
    estimatedSeconds: estimatedSeconds ?? taskEstimatePresets.first,
    note: trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote,
    createdAt: DateTime.now(),
  ));
  return taskId;
}
