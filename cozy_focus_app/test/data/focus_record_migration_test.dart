import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide FocusSession, Pet, CraftJob, CraftRecipe, InventoryItem, RoomItem;
import '../support/schema_head.dart';

void main() {
  test('v3 upgrade deduplicates sessions and preserves entered details',
      () async {
    final dir = Directory.systemTemp.createTempSync('cozy_migration_');
    final file = File('${dir.path}${Platform.pathSeparator}cozy_focus.sqlite');
    try {
      final raw = sqlite3.open(file.path);
      try {
        // focus_sessions too, because a real v3 database had it and the chain
        // now runs on to v5, which adds a column to it. A fixture without it
        // would be a database that never existed.
        raw.execute('CREATE TABLE focus_sessions ('
            'id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, '
            'category_id TEXT, task_name TEXT, planned_seconds INTEGER NOT NULL, '
            'mode TEXT NOT NULL, start_at INTEGER NOT NULL, '
            "pause_intervals_json TEXT NOT NULL DEFAULT '[]', end_at INTEGER, "
            'status TEXT NOT NULL, timezone_offset_minutes INTEGER NOT NULL)');
        raw.execute('CREATE TABLE focus_records ('
            'id TEXT NOT NULL PRIMARY KEY, session_id TEXT NOT NULL, '
            'user_id TEXT NOT NULL, category_id TEXT, task_name TEXT, mood TEXT, '
            'duration_seconds INTEGER NOT NULL, start_at INTEGER NOT NULL, '
            'end_at INTEGER NOT NULL, recorded_at INTEGER NOT NULL, '
            'is_counted_for_reward INTEGER NOT NULL DEFAULT 1, note TEXT)');
        raw.execute('INSERT INTO focus_records '
            '(id, session_id, user_id, duration_seconds, start_at, end_at, '
            'recorded_at, task_name, mood, note) VALUES '
            "('r1','duplicate','user',1500,1,2,3,'Original',NULL,NULL),"
            "('r2','duplicate','user',1500,1,2,3,NULL,'Happy','Saved note'),"
            "('r3','other','user',600,1,2,3,NULL,NULL,NULL)");
        raw.execute('PRAGMA user_version = 3');
      } finally {
        raw.dispose();
      }

      final db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final rows = await db
            .customSelect(
              'SELECT id, session_id, duration_seconds, task_name, mood, note '
              'FROM focus_records ORDER BY id',
            )
            .get();
        expect(rows, hasLength(2));
        expect(rows.first.read<String>('id'), 'r1');
        expect(rows.first.read<String>('task_name'), 'Original');
        expect(rows.first.read<String>('mood'), 'Happy');
        expect(rows.first.read<String>('note'), 'Saved note');
        expect(rows.last.read<String>('id'), 'r3');
        expect(
            rows.fold<int>(
                0, (sum, row) => sum + row.read<int>('duration_seconds')),
            2100);

        final version =
            await db.customSelect('PRAGMA user_version').getSingle();
        // The head of the chain, which moves when a migration is added.
        expect(version.read<int>('user_version'), kSchemaHead);
        final indexes = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND name = 'idx_focus_records_session_id'",
            )
            .get();
        expect(indexes, hasLength(1));
      } finally {
        await db.close();
      }
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
