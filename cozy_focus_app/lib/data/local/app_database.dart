import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/focus_sessions_table.dart';
import 'tables/focus_records_table.dart';
import 'tables/focus_categories_table.dart';
import 'tables/craft_tables.dart';
import 'tables/pet_tables.dart';
import 'tables/achievement_table.dart';
import 'tables/sync_tables.dart';
import 'daos/focus_session_dao.dart';
import 'daos/focus_record_dao.dart';
import 'daos/reward_ledger_dao.dart';
import 'daos/sync_outbox_dao.dart';
import 'daos/pet_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    FocusSessions,
    FocusRecords,
    FocusCategories,
    CraftRecipes,
    CraftJobs,
    InventoryItems,
    RoomItems,
    Pets,
    PetProgressTable,
    PetMemories,
    Achievements,
    SyncOutboxTable,
    RewardLedgerTable,
  ],
  daos: [
    FocusSessionDao,
    FocusRecordDao,
    RewardLedgerDao,
    SyncOutboxDao,
    PetDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing — pass an in-memory connection.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        // Future migrations go here, keyed by version.
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement('PRAGMA journal_mode = WAL');
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'cozy_focus.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
