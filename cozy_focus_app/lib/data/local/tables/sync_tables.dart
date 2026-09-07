import 'package:drift/drift.dart';

class SyncOutboxTable extends Table {
  @override
  String get tableName => 'sync_outbox';

  TextColumn get id => text()();
  TextColumn get tableName_ => text().named('table_name')();
  TextColumn get recordId => text()();
  TextColumn get operation => text()();
  TextColumn get payloadJson => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class RewardLedgerTable extends Table {
  @override
  String get tableName => 'reward_ledger';

  // session_id IS the primary key — enforces one-reward-per-session
  TextColumn get sessionId => text()();
  TextColumn get userId => text()();
  IntColumn get focusCoinsEarned => integer()();
  IntColumn get experienceEarned => integer()();
  TextColumn get craftRecipeUnlocked => text().nullable()();
  DateTimeColumn get settledAt => dateTime()();

  @override
  Set<Column> get primaryKey => {sessionId};
}
