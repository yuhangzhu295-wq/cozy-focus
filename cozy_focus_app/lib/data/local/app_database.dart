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
import 'tables/distraction_note_table.dart';
import 'tables/task_schedule_table.dart';
import 'tables/task_tables.dart';
import 'daos/focus_session_dao.dart';
import 'daos/focus_record_dao.dart';
import 'daos/reward_ledger_dao.dart';
import 'daos/sync_outbox_dao.dart';
import 'daos/pet_dao.dart';
import 'daos/craft_dao.dart';
import 'daos/settlement_dao.dart';
import 'daos/distraction_dao.dart';
import 'daos/task_dao.dart';

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
    Tasks,
    TaskSubtasks,
    TaskSchedules,
    DistractionNotes,
  ],
  daos: [
    FocusSessionDao,
    FocusRecordDao,
    RewardLedgerDao,
    SyncOutboxDao,
    PetDao,
    CraftDao,
    SettlementDao,
    TaskDao,
    DistractionDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing — pass an in-memory connection.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

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
        // v3 -> v4: preserve entered details from duplicate records before
        // enforcing one record per session.
        if (from < 4) {
          for (final column in ['category_id', 'task_name', 'mood', 'note']) {
            await customStatement('''
              UPDATE focus_records AS kept
              SET $column = (
                SELECT duplicate.$column
                FROM focus_records AS duplicate
                WHERE duplicate.session_id = kept.session_id
                  AND NULLIF(duplicate.$column, '') IS NOT NULL
                ORDER BY duplicate.rowid DESC
                LIMIT 1
              )
              WHERE kept.rowid IN (
                SELECT MIN(rowid) FROM focus_records GROUP BY session_id
              )
                AND NULLIF(kept.$column, '') IS NULL
                AND EXISTS (
                  SELECT 1 FROM focus_records AS duplicate
                  WHERE duplicate.session_id = kept.session_id
                    AND NULLIF(duplicate.$column, '') IS NOT NULL
                );
            ''');
          }
          await customStatement('''
            DELETE FROM focus_records
            WHERE rowid NOT IN (
              SELECT MIN(rowid)
              FROM focus_records
              GROUP BY session_id
            );
          ''');
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_focus_records_session_id ON focus_records(session_id);',
          );
        }
        // v4 -> v5: the task domain, and the link from a focus session and
        // record to the task it was for.
        if (from < 5) {
          await m.createTable(tasks);
          await m.createTable(taskSubtasks);
          await m.addColumn(focusSessions, focusSessions.taskId);
          await m.addColumn(focusRecords, focusRecords.taskId);
        }
        // v5 -> v6: where a task is planned. Its own table rather than a date on
        // the task, because the same task can be planned for more than one day
        // and each placement has its own time.
        if (from < 6) {
          await m.createTable(taskSchedules);
          // Created separately as well as in the table's own constraints, so a
          // database that already ran this step without the constraint picks it
          // up on the next open rather than keeping a table that allows a task
          // to be on the same day twice.
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_task_schedules_task_day '
            'ON task_schedules(task_id, date);',
          );
        }
        // v6 -> v7: how the timer counted, on the session and on the record it
        // writes.
        if (from < 7) {
          await m.addColumn(focusSessions, focusSessions.timingMode);
          await m.addColumn(focusRecords, focusRecords.timingMode);
          // Backfill from what the old rows already said. A session with no
          // length was a flow session, which is 正计时; everything else counted
          // down. The records follow their session, because a record carries no
          // length of its own — and a record whose session row is gone keeps the
          // column default, since by then there is nothing left to tell from.
          await customStatement(
            "UPDATE focus_sessions SET timing_mode = 'countUp' "
            'WHERE planned_seconds <= 0',
          );
          await customStatement(
            "UPDATE focus_records SET timing_mode = 'countUp' WHERE session_id "
            'IN (SELECT id FROM focus_sessions WHERE planned_seconds <= 0)',
          );
        }
        // v7 -> v8: the distraction inbox. A new table, so nothing existing is
        // touched and there is nothing to backfill — a database from before this
        // phase simply has no captured thoughts yet.
        if (from < 8) {
          await m.createTable(distractionNotes);
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
