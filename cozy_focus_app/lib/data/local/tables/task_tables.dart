import 'package:drift/drift.dart';

/// A thing the user means to focus on.
///
/// `estimatedSeconds` is a duration rather than minutes because everything else
/// in this schema stores seconds, and a second unit is how a rounding bug gets
/// in. The screens convert for display.
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();

  /// The longest the create screen allows is enforced there; the column is a
  /// plain string so a longer title from a later feature is not silently cut.
  TextColumn get title => text()();

  /// One of the shipped category ids, or null. Not a foreign key: categories are
  /// a domain value set, not a table, and a dangling reference would be worse
  /// than the honest absence.
  TextColumn get categoryId => text().nullable()();

  IntColumn get estimatedSeconds =>
      integer().withDefault(const Constant(1500))();

  TextColumn get note => text().nullable()();

  /// `open` or `done`.
  TextColumn get status => text().withDefault(const Constant('open'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A step inside a task.
class TaskSubtasks extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get title => text()();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};

  /// Deleting a task takes its subtasks with it, in the database rather than in
  /// the repository: a subtask whose task is gone is unreachable and would only
  /// accumulate.
  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE',
      ];
}
