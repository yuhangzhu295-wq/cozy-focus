import 'package:drift/drift.dart';

class Achievements extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get achievementKey => text()();
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get threshold => integer()();
  IntColumn get currentValue => integer().withDefault(const Constant(0))();
  BoolColumn get isUnlocked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get unlockedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [{userId, achievementKey}];
}
