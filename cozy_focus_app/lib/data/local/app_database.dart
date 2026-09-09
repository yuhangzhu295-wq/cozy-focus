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
import 'daos/craft_dao.dart';
import 'daos/settlement_dao.dart';

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
    CraftDao,
    SettlementDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing — pass an in-memory connection.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _seedRecipes();
      },
      onUpgrade: (m, from, to) async {
        // v1 -> v2: add taskName to focus_sessions and focus_records;
        //           add mood to focus_records.
        if (from < 2) {
          await m.addColumn(focusSessions, focusSessions.taskName);
          await m.addColumn(focusRecords, focusRecords.taskName);
          await m.addColumn(focusRecords, focusRecords.mood);
        }
        // v2 -> v3: add progressSeconds to craft_jobs; seed recipes.
        if (from < 3) {
          await m.addColumn(craftJobs, craftJobs.progressSeconds);
          await _seedRecipes();
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement('PRAGMA journal_mode = WAL');
      },
    );
  }

  /// Seeds canonical craft recipes if table is empty.
  Future<void> _seedRecipes() async {
    final existing = await craftDao.findAllRecipes();
    if (existing.isNotEmpty) return;
    const seeds = [
      (id: 'sofa', name: '温馨沙发', minutes: 30, outputId: 'sofa'),
      (id: 'table', name: '原木茶几', minutes: 20, outputId: 'table'),
      (id: 'bookshelf', name: '书架', minutes: 90, outputId: 'bookshelf'),
      (id: 'bed', name: '小床', minutes: 60, outputId: 'bed'),
      (id: 'rug', name: '地毯', minutes: 30, outputId: 'rug'),
      (id: 'lamp', name: '落地灯', minutes: 45, outputId: 'lamp'),
      (id: 'cabinet', name: '收纳柜', minutes: 120, outputId: 'cabinet'),
      (id: 'desk', name: '窗边书桌', minutes: 180, outputId: 'desk'),
    ];
    for (final s in seeds) {
      await into(craftRecipes).insertOnConflictUpdate(CraftRecipesCompanion(
        id: Value(s.id),
        name: Value(s.name),
        requiredMinutes: Value(s.minutes),
        outputItemId: Value(s.outputId),
        outputQuantity: const Value(1),
        ingredientCostsJson: const Value('{}'),
      ));
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'cozy_focus.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
