import 'package:drift/drift.dart';

/// A thought captured during focus, so it does not have to be chased now.
///
/// ## Why its own table rather than a task with a flag
///
/// A distraction is not a task yet. Most of them will be deleted, and the ones
/// that survive become tasks — but a note that has not been decided about must
/// not appear in the task list, the today plan, or any count of open work. A
/// `isDraft` column on `tasks` would put them in every query that already exists
/// and every query written later, and one forgotten `WHERE` is enough to show the
/// user a task list full of things they never agreed to do.
///
/// ## Why `session_id` is not a foreign key
///
/// It records which focus session the thought interrupted, which is real
/// provenance. A note outlives its session — the session may be cancelled, and
/// the note is still the user's — so a cascade would delete the wrong one of the
/// two.
class DistractionNotes extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();

  /// What the user typed, trimmed. Never empty — see the repository.
  TextColumn get text_ => text().named('text')();

  /// One of the shipped category ids, or null. The design calls it an optional
  /// tag, and an optional tag that defaults to 其他 is not optional.
  TextColumn get categoryId => text().nullable()();

  /// `open` or `handled`.
  ///
  /// `open` is the inbox: what the user still has to decide about. A note leaves
  /// it by being converted into a task, placed on a day, or deleted — and the
  /// ones that were converted or placed are kept as `handled` rather than
  /// deleted, because "this thought became that task" is worth being able to see.
  TextColumn get status => text().withDefault(const Constant('open'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get handledAt => dateTime().nullable()();

  /// The task this note became, when it was converted.
  ///
  /// Not a foreign key for the same reason as `session_id`: deleting the task
  /// later must not resurrect the note into the inbox.
  TextColumn get convertedTaskId => text().nullable()();

  /// The focus session the thought arrived during, when there was one.
  TextColumn get sessionId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
