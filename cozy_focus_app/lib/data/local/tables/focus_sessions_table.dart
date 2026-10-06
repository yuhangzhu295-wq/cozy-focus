import 'package:drift/drift.dart';

/// Drift table definition for focus_sessions.
/// Matches implementation/01_schema_draft.sql (task_name, mood added in schema v2).
class FocusSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get taskName => text().nullable()();

  /// The task this session is for, when it was started from one.
  ///
  /// Carried on the session as well as the record because the session is what a
  /// running focus knows about, and the review screen has to be able to say what
  /// the session was for before it has been saved.
  TextColumn get taskId => text().nullable()();
  IntColumn get plannedSeconds => integer()();
  TextColumn get mode => text()(); // "focus" | "shortBreak" | "longBreak"

  /// "countdown" | "countUp" | "deepFocus" — how the timer counted.
  ///
  /// Defaulted rather than nullable: every session written before this column
  /// existed was a countdown or a flow session, and
  /// [FocusTimingMode.fromLegacyPlannedSeconds] recovers which from
  /// `planned_seconds`. The migration backfills it; the default covers rows a
  /// hand-written insert might miss.
  TextColumn get timingMode =>
      text().withDefault(const Constant('countdown'))();
  DateTimeColumn get startAt => dateTime()();
  TextColumn get pauseIntervalsJson =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get endAt => dateTime().nullable()();
  TextColumn get status => text()();
  IntColumn get timezoneOffsetMinutes => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
