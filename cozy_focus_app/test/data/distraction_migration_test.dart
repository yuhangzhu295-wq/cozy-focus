import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule, FocusSession, DistractionNote;
import 'package:cozy_focus_app/domain/models/distraction_note.dart';
import '../support/schema_head.dart';

/// P4 — a v7 database gains the inbox.
///
/// ## What this proves
///
/// The migration is a single new table, so the risk is not a lossy conversion —
/// it is that the table the code queries is not the table the migration created,
/// or that opening an existing database fails part way and leaves the user with
/// neither. So the fixture is a real v7 file with rows in it, and the assertions
/// go through the DAO the inbox actually uses.
void main() {
  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test('v7 opens as v8 with the inbox added and nothing lost', () async {
    final dir = Directory.systemTemp.createTempSync('cozy_p4_migration_');
    final file = File('${dir.path}${Platform.pathSeparator}cozy_focus.sqlite');
    try {
      final raw = sqlite3.open(file.path);
      try {
        raw.execute('CREATE TABLE focus_sessions ('
            'id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, '
            'category_id TEXT, task_name TEXT, task_id TEXT, '
            'planned_seconds INTEGER NOT NULL, mode TEXT NOT NULL, '
            "timing_mode TEXT NOT NULL DEFAULT 'countdown', "
            'start_at INTEGER NOT NULL, '
            "pause_intervals_json TEXT NOT NULL DEFAULT '[]', "
            'end_at INTEGER, status TEXT NOT NULL, '
            'timezone_offset_minutes INTEGER NOT NULL)');
        raw.execute('CREATE TABLE focus_records ('
            'id TEXT NOT NULL PRIMARY KEY, session_id TEXT NOT NULL, '
            'user_id TEXT NOT NULL, category_id TEXT, task_name TEXT, '
            'task_id TEXT, mood TEXT, '
            "timing_mode TEXT NOT NULL DEFAULT 'countdown', "
            'duration_seconds INTEGER NOT NULL, start_at INTEGER NOT NULL, '
            'end_at INTEGER NOT NULL, recorded_at INTEGER NOT NULL, '
            'is_counted_for_reward INTEGER NOT NULL DEFAULT 1, note TEXT)');
        raw.execute('CREATE TABLE tasks ('
            'id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, '
            'title TEXT NOT NULL, category_id TEXT, '
            'estimated_seconds INTEGER NOT NULL DEFAULT 1500, note TEXT, '
            "status TEXT NOT NULL DEFAULT 'open', created_at INTEGER NOT NULL, "
            'completed_at INTEGER, sort_order INTEGER NOT NULL DEFAULT 0)');
        raw.execute('INSERT INTO focus_records '
            '(id, session_id, user_id, duration_seconds, start_at, end_at, '
            'recorded_at) VALUES '
            "('r1', 'sess1', 'default_user', 1500, 1759800000000, "
            '1759800900000, 1759800900000)');
        raw.execute('INSERT INTO tasks '
            '(id, user_id, title, created_at) VALUES '
            "('t1', 'default_user', '写产品方案', 1759800000000)");
        raw.execute('PRAGMA user_version = 7');
      } finally {
        raw.dispose();
      }

      final db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final version =
            await db.customSelect('PRAGMA user_version').getSingle();
        expect(version.read<int>('user_version'), kSchemaHead);

        final tables = await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table' "
                "AND name = 'distraction_notes'")
            .get();
        expect(tables, hasLength(1));

        // The table is the one the code expects, not merely one with the right
        // name: it is written and read through the DAO the inbox uses.
        await db.distractionDao.insert(DistractionNote(
          id: 'n1',
          userId: 'default_user',
          text: '买充电线',
          categoryId: 'life',
          createdAt: _at,
        ));
        final open = await db.distractionDao
            .findByFilter('default_user', DistractionFilter.open);
        expect(open, hasLength(1));
        expect(open.single.text, '买充电线');
        expect(open.single.categoryId, 'life');
        expect(open.single.isOpen, isTrue);

        // Nothing that was there is gone.
        final records = await db
            .customSelect('SELECT id, duration_seconds FROM focus_records')
            .get();
        expect(records, hasLength(1));
        expect(records.single.read<int>('duration_seconds'), 1500);
        final tasks =
            await db.customSelect('SELECT id, title FROM tasks').get();
        expect(tasks.single.read<String>('title'), '写产品方案');
      } finally {
        await db.close();
      }
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}

/// A fixed moment. Not `const`, because `DateTime`'s constructor is not.
final _at = DateTime(2026, 10, 7, 14, 23);
