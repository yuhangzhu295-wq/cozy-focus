import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide
        Task,
        TaskSubtask,
        TaskSchedule,
        FocusSession,
        FocusRecord,
        RestSession;
import 'package:cozy_focus_app/domain/models/rest_session.dart';
import '../support/schema_head.dart';

/// P8 — a v9 database gains rest sessions.
///
/// ## What this proves
///
/// The migration is one new table, so the risk is not a lossy conversion — it is
/// that the table the code writes to is not the one the migration created, or that
/// opening an existing database fails part way. The fixture is a real v9 file with
/// focus history in it, and the assertions go through the DAO the rest screen
/// uses.
void main() {
  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test('v9 opens at the head with rest sessions and nothing lost', () async {
    final dir = Directory.systemTemp.createTempSync('cozy_p8_migration_');
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
            'task_id TEXT, mood TEXT, gains TEXT, next_intention TEXT, '
            "timing_mode TEXT NOT NULL DEFAULT 'countdown', "
            'duration_seconds INTEGER NOT NULL, start_at INTEGER NOT NULL, '
            'end_at INTEGER NOT NULL, recorded_at INTEGER NOT NULL, '
            'is_counted_for_reward INTEGER NOT NULL DEFAULT 1, note TEXT)');
        raw.execute('INSERT INTO focus_records '
            '(id, session_id, user_id, duration_seconds, start_at, end_at, '
            'recorded_at) VALUES '
            "('r1', 'sess1', 'default_user', 1500, 1759800000000, "
            '1759800900000, 1759800900000)');
        raw.execute('PRAGMA user_version = 9');
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
                "AND name = 'rest_sessions'")
            .get();
        expect(tables, hasLength(1));

        // The table is the one the code expects, not merely one with the right
        // name: it is written and read through the DAO the rest screen uses.
        await db.restDao.insert(RestSession(
          id: 'rest1',
          userId: 'default_user',
          plannedSeconds: 600,
          startAt: DateTime(2026, 10, 8, 14),
          createdAt: DateTime(2026, 10, 8, 14),
        ));
        final running = await db.restDao.findRunning('default_user');
        expect(running, isNotNull);
        expect(running!.plannedSeconds, 600);
        expect(running.isRunning, isTrue);

        await db.restDao.updateSession(running.copyWith(
          endAt: DateTime(2026, 10, 8, 14, 10),
          status: RestStatus.completed,
        ));
        expect(
          await db.restDao.totalSecondsBetween(
            'default_user',
            DateTime(2026, 10, 8),
            DateTime(2026, 10, 9),
          ),
          600,
        );

        // Nothing that was there is gone.
        final records = await db
            .customSelect('SELECT id, duration_seconds FROM focus_records')
            .get();
        expect(records, hasLength(1));
        expect(records.single.read<int>('duration_seconds'), 1500);
      } finally {
        await db.close();
      }
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
