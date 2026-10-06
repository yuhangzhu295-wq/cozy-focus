import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule;
import 'package:cozy_focus_app/domain/models/task_schedule.dart';

/// P2 — a database written by the previous version opens and gains the plan.
///
/// ## Why the v5 database is written out by hand
///
/// The migration's job is to take a database that exists in the world and add
/// what is missing without touching what is there. Building the v5 file from the
/// current code would test the current code against itself, so the DDL below is
/// the v5 shape written literally — including a task and a focus record that must
/// still be there afterwards.
void main() {
  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test('v5 opens at the head with the plan table added and nothing lost',
      () async {
    final dir = Directory.systemTemp.createTempSync('cozy_p2_migration_');
    final file = File('${dir.path}${Platform.pathSeparator}cozy_focus.sqlite');
    try {
      final raw = sqlite3.open(file.path);
      try {
        // focus_sessions as well, because a real v5 database had it and the
        // chain now runs on to v7, which adds a column to it. A fixture without
        // it would be a database that never existed — and it fails, which is how
        // this was found.
        raw.execute('CREATE TABLE focus_sessions ('
            'id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, '
            'category_id TEXT, task_name TEXT, task_id TEXT, '
            'planned_seconds INTEGER NOT NULL, mode TEXT NOT NULL, '
            'start_at INTEGER NOT NULL, '
            "pause_intervals_json TEXT NOT NULL DEFAULT '[]', "
            'end_at INTEGER, status TEXT NOT NULL, '
            'timezone_offset_minutes INTEGER NOT NULL)');
        raw.execute('CREATE TABLE tasks ('
            'id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, '
            'title TEXT NOT NULL, category_id TEXT, '
            'estimated_seconds INTEGER NOT NULL DEFAULT 1500, note TEXT, '
            'status TEXT NOT NULL DEFAULT \'open\', '
            'created_at INTEGER NOT NULL, completed_at INTEGER, '
            'sort_order INTEGER NOT NULL DEFAULT 0)');
        raw.execute('CREATE TABLE task_subtasks ('
            'id TEXT NOT NULL PRIMARY KEY, task_id TEXT NOT NULL, '
            'title TEXT NOT NULL, is_done INTEGER NOT NULL DEFAULT 0, '
            'sort_order INTEGER NOT NULL DEFAULT 0, '
            'FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE)');
        raw.execute('CREATE TABLE focus_records ('
            'id TEXT NOT NULL PRIMARY KEY, session_id TEXT NOT NULL, '
            'user_id TEXT NOT NULL, category_id TEXT, task_name TEXT, mood TEXT, '
            'duration_seconds INTEGER NOT NULL, start_at INTEGER NOT NULL, '
            'end_at INTEGER NOT NULL, recorded_at INTEGER NOT NULL, '
            'is_counted_for_reward INTEGER NOT NULL DEFAULT 1, note TEXT, '
            'task_id TEXT)');
        raw.execute('INSERT INTO tasks '
            '(id, user_id, title, category_id, estimated_seconds, created_at) '
            "VALUES ('t1', 'default_user', '写产品方案', 'work', 1500, 1759800000000)");
        raw.execute('INSERT INTO task_subtasks (id, task_id, title) '
            "VALUES ('s1', 't1', '梳理核心功能')");
        raw.execute('INSERT INTO focus_records '
            '(id, session_id, user_id, duration_seconds, start_at, end_at, '
            'recorded_at, task_id) VALUES '
            "('r1', 'sess1', 'default_user', 1500, 1759800000000, "
            '1759800900000, 1759800900000, \'t1\')');
        raw.execute('PRAGMA user_version = 5');
      } finally {
        raw.dispose();
      }

      final db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        // The plan table now exists and is usable.
        final tables = await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table' "
                "AND name = 'task_schedules'")
            .get();
        expect(tables, hasLength(1),
            reason: 'the migration must add the table, not rely on a fresh '
                'install');

        final version =
            await db.customSelect('PRAGMA user_version').getSingle();
        expect(version.read<int>('user_version'), 7);

        // The unique index that stops a task being on one day twice.
        final indexes = await db
            .customSelect(
                'SELECT name FROM sqlite_master WHERE type = \'index\' '
                "AND name = 'idx_task_schedules_task_day'")
            .get();
        expect(indexes, hasLength(1));

        // Nothing that was there is gone.
        final tasks = await db
            .customSelect('SELECT id, title, category_id FROM tasks')
            .get();
        expect(tasks, hasLength(1));
        expect(tasks.single.read<String>('title'), '写产品方案');
        expect(tasks.single.read<String>('category_id'), 'work');

        final subtasks = await db
            .customSelect('SELECT id, task_id FROM task_subtasks')
            .get();
        expect(subtasks, hasLength(1));

        final records = await db
            .customSelect(
                'SELECT id, task_id, duration_seconds FROM focus_records')
            .get();
        expect(records, hasLength(1));
        expect(records.single.read<String>('task_id'), 't1');
        expect(records.single.read<int>('duration_seconds'), 1500);

        // And the new table is writable through the real DAO, which is what
        // proves the migration produced the schema the code expects rather than
        // a table with the right name.
        await db.taskDao.insertSchedule(TaskSchedule(
          id: 'plan1',
          taskId: 't1',
          userId: 'default_user',
          date: '2026-10-07',
          startAt: DateTime(2026, 10, 7, 9),
          plannedSeconds: 1500,
          createdAt: DateTime(2026, 10, 7, 8),
        ));
        final day =
            await db.taskDao.schedulesForDay('default_user', '2026-10-07');
        expect(day, hasLength(1));
        expect(day.single.title, '写产品方案',
            reason: 'the join to tasks has to work on the migrated schema');

        // The unique constraint is real: a second row for the same task and day
        // is refused by the database, not only by the repository.
        await expectLater(
          db.customStatement(
            "INSERT INTO task_schedules (id, task_id, user_id, date, start_at, "
            "planned_seconds, status, created_at) VALUES ('s2', 't1', "
            "'default_user', '2026-10-07', 1759800000000, 1500, 'planned', "
            '1759800000000)',
          ),
          throwsA(isA<Exception>()),
        );
      } finally {
        await db.close();
      }
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
