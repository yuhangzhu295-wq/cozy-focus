import 'package:drift/drift.dart';

/// Drift table definition for focus_sessions.
/// Matches implementation/01_schema_draft.sql (task_name, mood added in schema v2).
class FocusSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get taskName => text().nullable()();
  IntColumn get plannedSeconds => integer()();
  TextColumn get mode => text()(); // "focus" | "shortBreak" | "longBreak"
  DateTimeColumn get startAt => dateTime()();
  TextColumn get pauseIntervalsJson =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get endAt => dateTime().nullable()();
  TextColumn get status => text()();
  IntColumn get timezoneOffsetMinutes => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
