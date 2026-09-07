import 'package:drift/drift.dart';

/// Drift table definition for focus_sessions.
/// This mirrors implementation/01_schema_draft.sql exactly.
class FocusSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get categoryId => text().nullable()();
  IntColumn get plannedSeconds => integer()();
  TextColumn get mode => text()();  // "focus" | "shortBreak" | "longBreak"
  DateTimeColumn get startAt => dateTime()();
  TextColumn get pauseIntervalsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get endAt => dateTime().nullable()();
  TextColumn get status => text()();
  IntColumn get timezoneOffsetMinutes => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
