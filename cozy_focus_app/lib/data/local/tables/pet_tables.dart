import 'package:drift/drift.dart';

class Pets extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get characterId => text()();
  TextColumn get species => text()();
  TextColumn get name => text()();
  DateTimeColumn get adoptedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {userId}
      ];
}

class PetProgressTable extends Table {
  @override
  String get tableName => 'pet_progress';

  TextColumn get id => text()();
  TextColumn get petId => text()();
  IntColumn get level => integer().withDefault(const Constant(1))();
  IntColumn get experiencePoints => integer().withDefault(const Constant(0))();
  IntColumn get totalFocusMinutes => integer().withDefault(const Constant(0))();
  IntColumn get happinessScore => integer().withDefault(const Constant(50))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {petId}
      ];
}

class PetMemories extends Table {
  TextColumn get id => text()();
  TextColumn get petId => text()();
  TextColumn get memoryType => text()();
  TextColumn get content => text()();
  DateTimeColumn get happenedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
