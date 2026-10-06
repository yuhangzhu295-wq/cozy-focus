import 'package:drift/drift.dart';

class FocusRecords extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get userId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get taskName => text().nullable()();

  /// The task this record was focused on, when it came from one.
  ///
  /// Nullable, and deliberately not a foreign key with a cascade: a record is a
  /// fact about time the user spent, and deleting the task it was filed under
  /// must not delete the history. A record whose task is gone keeps its
  /// `taskName` and simply stops counting towards a task's total.
  TextColumn get taskId => text().nullable()();
  TextColumn get mood => text().nullable()();
  IntColumn get durationSeconds => integer()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime()();
  DateTimeColumn get recordedAt => dateTime()();
  BoolColumn get isCountedForReward =>
      boolean().withDefault(const Constant(true))();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {sessionId},
      ];
}
