import 'package:drift/drift.dart';

class CraftRecipes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get requiredMinutes => integer()();
  TextColumn get ingredientCostsJson =>
      text().withDefault(const Constant('{}'))();
  TextColumn get outputItemId => text()();
  IntColumn get outputQuantity => integer().withDefault(const Constant(1))();
  TextColumn get artworkPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CraftJobs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get recipeId => text()();
  TextColumn get status => text()();

  /// Accumulated focus seconds contributed to this craft job.
  IntColumn get progressSeconds => integer().withDefault(const Constant(0))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  BoolColumn get rewardClaimed =>
      boolean().withDefault(const Constant(false))();
  TextColumn get sessionId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class InventoryItems extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get itemId => text()();
  IntColumn get quantity => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {userId, itemId}
      ];
}

class RoomItems extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get itemId => text()();
  RealColumn get positionX => real()();
  RealColumn get positionY => real()();
  RealColumn get scale => real().withDefault(const Constant(1.0))();
  IntColumn get zIndex => integer().withDefault(const Constant(0))();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  DateTimeColumn get placedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
