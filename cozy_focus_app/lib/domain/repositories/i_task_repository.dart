import '../models/task.dart';
import '../models/task_schedule.dart';

/// The three lists the task screen filters between.
///
/// `today` is not a filter over `Task` — it is "tasks scheduled for today",
/// which needs the schedule domain from P2. It is declared here because the
/// screen has three tabs and the repository is what answers them; until P2 lands
/// it answers `today` with the same set as `open`, and the wiring is in place.
enum TaskFilter {
  today('today'),
  active('active'),
  done('done');

  final String id;
  const TaskFilter(this.id);
}

/// Reading and writing tasks.
///
/// Deliberately narrow, and deliberately not a query builder: the screens need
/// a handful of shapes and each one is a method, so "what does the list screen
/// ask for" is answerable by reading this file.
abstract interface class ITaskRepository {
  /// Tasks matching [filter], newest first within their group.
  Future<List<Task>> findByFilter(String userId, TaskFilter filter);

  /// One task, or null.
  Future<Task?> findById(String id);

  /// The tasks with these ids, keyed by id. Missing ids are simply absent.
  ///
  /// One query for a whole screen's worth of rows: the statistics view resolves
  /// the title of every task it shows, and a lookup per row is N queries for one
  /// page.
  Future<Map<String, Task>> findByIds(List<String> ids);

  /// A task with its subtasks and its focus totals.
  ///
  /// The detail screen's shape. Returns null for an unknown id rather than
  /// throwing, because a deep link to a deleted task is an ordinary event.
  Future<TaskWithProgress?> findWithProgress(String id);

  Future<void> insert(Task task);
  Future<void> update(Task task);

  /// Marks [taskId] done, or open again, and stamps `completedAt` accordingly.
  Future<void> setStatus(String taskId, TaskStatus status, {DateTime? at});

  /// Deletes the task and its subtasks.
  Future<void> deleteById(String id);

  /// Subtasks of [taskId], in order.
  Future<List<TaskSubtask>> subtasksFor(String taskId);

  Future<void> insertSubtask(TaskSubtask subtask);
  Future<void> updateSubtask(TaskSubtask subtask);
  Future<void> deleteSubtask(String id);

  /// How many tasks are still open — for the records tab's badge and the empty
  /// state's copy.
  Future<int> countOpen(String userId);

  // ── planning ──────────────────────────────────────────────────────────────

  /// A day's placements, in time order, each with the task it places.
  Future<List<PlannedTask>> schedulesForDay(String userId, String date);

  /// The next placements for [taskId] from [from] onward.
  Future<List<TaskSchedule>> upcomingSchedulesFor(String taskId,
      {required String from, int limit});

  /// Whether [taskId] is already placed on [date].
  Future<bool> isScheduledOn(String taskId, String date);

  /// The placement for [taskId] on [date], or null.
  ///
  /// The schedule screen needs the row itself rather than a yes/no: a task that is
  /// already on the day has a time and a length, and a form that offered fresh
  /// ones would be offering to change something it did not know about.
  Future<TaskSchedule?> findScheduleOn(String taskId, String date);

  /// Places [taskId] on a day at a time, for [plannedSeconds].
  ///
  /// Returns the new placement's id. Adding the same task to the same day twice
  /// is a no-op that returns the existing placement's id rather than stacking a
  /// second row: the switch on the create screen can be flipped twice, and a
  /// plan with the same task on it twice is not a plan.
  Future<String> schedule({
    required String taskId,
    required String userId,
    required DateTime startAt,
    required int plannedSeconds,
  });

  Future<void> updateSchedule(TaskSchedule placement);
  Future<void> deleteSchedule(String id);
}
