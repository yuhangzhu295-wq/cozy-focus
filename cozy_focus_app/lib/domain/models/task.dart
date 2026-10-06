/// What a task category is, as data.
///
/// ## Why this is a value set and not a table
///
/// The design shows four chips — 生活 / 学习 / 工作 / 其他 — and the app already
/// has a `focus_categories` table that nothing writes to: every page today
/// hardcodes its category strings. Adding a second, *real* category table would
/// mean two category systems, one of them dead.
///
/// So categories are a fixed vocabulary in the domain, and `Task.categoryId`
/// references it. That is honest about what they are: four labels the product
/// chose, not user-created records. If a later phase lets a user add their own,
/// this becomes a table and the ids already look like ids.
library;

/// One category a task can be filed under.
class TaskCategory {
  /// The stored id. Stable, because it is written to the database.
  final String id;

  /// What the chip says.
  final String label;

  /// The design's icon per category, as a name rather than a widget so this
  /// stays a domain object with no Flutter in it.
  final String iconName;

  const TaskCategory({
    required this.id,
    required this.label,
    required this.iconName,
  });

  @override
  String toString() => 'TaskCategory($id "$label")';
}

/// The categories the product ships, in the order the design shows them.
///
/// 其他 is last on purpose: it is the one a user picks when none of the others
/// fit, and putting it first would invite it as a default.
const List<TaskCategory> taskCategories = [
  TaskCategory(id: 'life', label: '生活', iconName: 'home'),
  TaskCategory(id: 'study', label: '学习', iconName: 'book'),
  TaskCategory(id: 'work', label: '工作', iconName: 'briefcase'),
  TaskCategory(id: 'other', label: '其他', iconName: 'more'),
];

/// The category with [id], or null when there is no such category.
///
/// Null rather than a fallback: a task whose category cannot be resolved is a
/// data problem, and silently showing it as 其他 would hide it.
TaskCategory? taskCategoryFor(String? id) {
  if (id == null) return null;
  for (final category in taskCategories) {
    if (category.id == id) return category;
  }
  return null;
}

/// What a task's label is, or null when it has no resolvable category.
String? taskCategoryLabel(String? id) => taskCategoryFor(id)?.label;

/// Where a task is in its life.
///
/// Two states rather than a status enum with a dozen values: the product has
/// 进行中 and 已完成 and nothing else, and a task that is neither is open.
enum TaskStatus {
  open('open'),
  done('done');

  final String id;
  const TaskStatus(this.id);

  static TaskStatus fromId(String? id) =>
      id == 'done' ? TaskStatus.done : TaskStatus.open;
}

/// The durations the create screen offers, in seconds.
///
/// The design's chips are 25 / 40 / 50 minutes and 1 hour, with a custom option.
/// Kept here rather than in the page so a test can assert them and so the
/// estimate a task is created with is never a literal in a widget.
const List<int> taskEstimatePresets = [
  25 * 60,
  40 * 60,
  50 * 60,
  60 * 60,
];

/// A thing the user means to focus on.
class Task {
  final String id;
  final String userId;
  final String title;

  /// One of [taskCategories]' ids, or null when the user did not choose.
  final String? categoryId;

  /// How long the user expects this to take. Never zero — a task with no
  /// estimate has nothing to plan against, and the create screen defaults it.
  final int estimatedSeconds;

  /// Free text, optional.
  final String? note;

  final TaskStatus status;

  final DateTime createdAt;

  /// When it was marked done, or null while it is open.
  final DateTime? completedAt;

  /// Manual ordering within a list. Ties fall back to creation time.
  final int sortOrder;

  const Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    this.categoryId,
    this.estimatedSeconds = 25 * 60,
    this.note,
    this.status = TaskStatus.open,
    this.completedAt,
    this.sortOrder = 0,
  });

  bool get isDone => status == TaskStatus.done;

  /// The longest a title may be, matching the create screen's counter.
  static const int maxTitleLength = 30;

  /// The longest a note may be on the create screen.
  static const int maxNoteLength = 100;

  Task copyWith({
    String? title,
    String? Function()? categoryId,
    int? estimatedSeconds,
    String? Function()? note,
    TaskStatus? status,
    DateTime? Function()? completedAt,
    int? sortOrder,
  }) =>
      Task(
        id: id,
        userId: userId,
        title: title ?? this.title,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        estimatedSeconds: estimatedSeconds ?? this.estimatedSeconds,
        note: note != null ? note() : this.note,
        status: status ?? this.status,
        createdAt: createdAt,
        completedAt: completedAt != null ? completedAt() : this.completedAt,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  @override
  String toString() => 'Task($id "$title" ${status.id} ${estimatedSeconds}s)';
}

/// A step inside a task.
///
/// The detail screen shows progress as `2 / 3`, which is subtasks done over
/// subtasks total. A task with no subtasks shows no progress rather than `0 / 0`.
class TaskSubtask {
  final String id;
  final String taskId;
  final String title;
  final bool isDone;
  final int sortOrder;

  const TaskSubtask({
    required this.id,
    required this.taskId,
    required this.title,
    this.isDone = false,
    this.sortOrder = 0,
  });

  TaskSubtask copyWith({String? title, bool? isDone, int? sortOrder}) =>
      TaskSubtask(
        id: id,
        taskId: taskId,
        title: title ?? this.title,
        isDone: isDone ?? this.isDone,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  @override
  String toString() => 'TaskSubtask($id "$title" done=$isDone)';
}

/// A task with everything a screen needs to draw it.
///
/// A read model rather than a stored shape: the cumulative focus time comes from
/// `FocusRecord` rows joined by `taskId`, and the subtask counts come from the
/// subtask table. Assembling it here keeps the pages from doing three queries
/// each, and keeps "how much have I actually spent on this" in one place.
/// One past focus on a task, as the detail screen lists it.
class TaskFocusEntry {
  final DateTime startAt;
  final DateTime endAt;
  final int durationSeconds;

  const TaskFocusEntry({
    required this.startAt,
    required this.endAt,
    required this.durationSeconds,
  });
}

class TaskWithProgress {
  final Task task;
  final List<TaskSubtask> subtasks;

  /// The most recent focus sessions for this task, newest first.
  final List<TaskFocusEntry> recentFocus;

  /// Total focused seconds recorded against this task.
  final int focusedSeconds;

  /// How many focus sessions have been recorded against it.
  final int sessionCount;

  const TaskWithProgress({
    required this.task,
    this.subtasks = const [],
    this.focusedSeconds = 0,
    this.sessionCount = 0,
    this.recentFocus = const [],
  });

  int get subtasksDone => subtasks.where((s) => s.isDone).length;
  int get subtasksTotal => subtasks.length;

  /// Whether the detail screen should show a progress bar at all.
  bool get hasSubtasks => subtasks.isNotEmpty;

  /// `2 / 3`, or null when there is nothing to count.
  String? get progressLabel =>
      hasSubtasks ? '$subtasksDone / $subtasksTotal' : null;

  /// How far through the subtasks, 0..1, or null when there are none.
  double? get progressFraction =>
      hasSubtasks ? subtasksDone / subtasksTotal : null;

  /// Whether the task has taken longer than the user expected.
  bool get isOverEstimate =>
      task.estimatedSeconds > 0 && focusedSeconds > task.estimatedSeconds;

  @override
  String toString() => 'TaskWithProgress(${task.id} '
      '${focusedSeconds}s over $sessionCount session(s))';
}
