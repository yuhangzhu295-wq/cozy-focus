import 'package:drift/drift.dart';

/// A deliberate break, as its own fact.
///
/// ## Why this is not a focus session
///
/// `FocusMode` already has `shortBreak` and `longBreak`, and reusing them for
/// rest would make one value answer two questions: whether the user is working or
/// resting, and how long the timer is. Those are exactly the two things P3
/// separated for the timing modes, and merging them here would undo it — a break
/// session would start counting towards focus totals, appear in the statistics as
/// focus, and the pet would be told to focus during a rest.
///
/// So a rest is its own row. It never contributes to focus totals, and the
/// statistics do not count it.
class RestSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();

  /// How long the user asked for. Always positive — a rest with no length is not
  /// a thing the screen offers.
  IntColumn get plannedSeconds => integer()();

  DateTimeColumn get startAt => dateTime()();

  /// Null while the rest is running.
  DateTimeColumn get endAt => dateTime().nullable()();

  /// `running`, `completed` or `cancelled`.
  ///
  /// `cancelled` is kept rather than deleted: a rest the user ended early is a
  /// fact about the day, and the timeline shows how long it actually lasted.
  TextColumn get status => text().withDefault(const Constant('running'))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
