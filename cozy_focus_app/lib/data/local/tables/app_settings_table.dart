import 'package:drift/drift.dart';

/// A small key/value store for the app's own preferences.
///
/// ## Why a table and not a second storage mechanism
///
/// The app already has SQLite, migrated and tested. A preferences package would be
/// a second place user data lives, with its own lifetime, its own backup story and
/// its own way to be silently empty after a restore. One key/value table inside
/// the database that already holds the focus history means a setting and the data
/// it configures are backed up, restored and cleared together.
///
/// Deliberately untyped: the columns are `key` and `value` as text, and the
/// repository gives them meaning. A table with a column per setting would need a
/// migration for every new preference, which is the cost this exists to avoid.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
