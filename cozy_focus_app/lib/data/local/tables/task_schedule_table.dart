import 'package:drift/drift.dart';

/// A task placed on a particular day, at a particular time.
///
/// ## Why this is its own table rather than fields on `tasks`
///
/// A task can be planned for several days — the same "写产品方案" on Monday and
/// again on Wednesday — and each placement has its own start time and its own
/// planned length. Putting a date on the task would make the second placement
/// overwrite the first, which is the bug this table exists to avoid.
///
/// ## Why `date` and `startAt` are separate
///
/// `date` is the day the plan is *for*, as a local calendar day, and it is what
/// the today view queries on. `startAt` is the time of day, stored as a full
/// timestamp because that is what the rest of the schema uses and a second time
/// representation is how an off-by-one-timezone bug gets in. The date is derived
/// from `startAt` when a plan is created, never typed separately, so the two
/// cannot disagree.
class TaskSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get userId => text()();

  /// The local calendar day this placement is for, as `YYYY-MM-DD`.
  ///
  /// A string rather than a date because it is compared and grouped, not
  /// arithmetic, and a `DateTime` at midnight is one timezone change away from
  /// being the previous day.
  TextColumn get date => text()();

  /// When the placement starts.
  DateTimeColumn get startAt => dateTime()();

  /// How long the user intends to spend, which may differ from the task's own
  /// estimate: planning twenty minutes of a two-hour task is normal.
  IntColumn get plannedSeconds => integer()();

  /// `planned`, `done` or `skipped`.
  TextColumn get status => text().withDefault(const Constant('planned'))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  /// Deleting a task removes its placements: a plan for a task that is gone is
  /// unreachable.
  ///
  /// One placement per task per day is enforced here rather than only in the
  /// repository, because "the same task twice on today's list" is not a plan and
  /// every writer — the create screen's switch, the schedule page, and P4's
  /// distraction conversion — would otherwise have to remember to check.
  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE',
        'UNIQUE (task_id, date)',
      ];
}
