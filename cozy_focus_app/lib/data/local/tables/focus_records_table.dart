import 'package:drift/drift.dart';

class FocusRecords extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get userId => text()();
  TextColumn get categoryId => text().nullable()();
  IntColumn get durationSeconds => integer()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime()();
  DateTimeColumn get recordedAt => dateTime()();
  BoolColumn get isCountedForReward => boolean().withDefault(const Constant(true))();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
