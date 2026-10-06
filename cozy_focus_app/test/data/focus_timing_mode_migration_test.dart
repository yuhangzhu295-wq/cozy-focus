import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule, FocusSession;
import '../support/schema_head.dart';

/// P3 — a v6 database gains the timing mode, and the old rows keep their meaning.
///
/// ## Why the backfill is the point
///
/// Adding a column with a default would label every historical session a
/// countdown. The app already had flow sessions — they were the ones with no
/// length — and calling them countdowns would put them in the 番茄钟 statistics
/// and make the timeline claim a target that never existed. So the migration
/// reads the old rows' own `planned_seconds` and says what they were.
void main() {
  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test('v6 opens as v7 with the mode backfilled from the old rows', () async {
    final dir = Directory.systemTemp.createTempSync('cozy_p3_migration_');
    final file = File('${dir.path}${Platform.pathSeparator}cozy_focus.sqlite');
    try {
      final raw = sqlite3.open(file.path);
      try {
        raw.execute('CREATE TABLE focus_sessions ('
            'id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, '
            'category_id TEXT, task_name TEXT, task_id TEXT, '
            'planned_seconds INTEGER NOT NULL, mode TEXT NOT NULL, '
            'start_at INTEGER NOT NULL, '
            "pause_intervals_json TEXT NOT NULL DEFAULT '[]', "
            'end_at INTEGER, status TEXT NOT NULL, '
            'timezone_offset_minutes INTEGER NOT NULL)');
        raw.execute('CREATE TABLE focus_records ('
            'id TEXT NOT NULL PRIMARY KEY, session_id TEXT NOT NULL, '
            'user_id TEXT NOT NULL, category_id TEXT, task_name TEXT, '
            'task_id TEXT, mood TEXT, duration_seconds INTEGER NOT NULL, '
            'start_at INTEGER NOT NULL, end_at INTEGER NOT NULL, '
            'recorded_at INTEGER NOT NULL, '
            'is_counted_for_reward INTEGER NOT NULL DEFAULT 1, note TEXT)');
        raw.execute('CREATE UNIQUE INDEX idx_focus_records_session_id '
            'ON focus_records(session_id)');

        // A timed session, a flow session, and a record whose session row was
        // already removed by a delete.
        raw.execute('INSERT INTO focus_sessions '
            '(id, user_id, planned_seconds, mode, start_at, status, '
            'timezone_offset_minutes) VALUES '
            "('timed', 'default_user', 1500, 'focus', 1759800000000, 'completed', 480),"
            "('flow', 'default_user', 0, 'focus', 1759803600000, 'completed', 480)");
        raw.execute('INSERT INTO focus_records '
            '(id, session_id, user_id, duration_seconds, start_at, end_at, '
            'recorded_at) VALUES '
            "('r_timed', 'timed', 'default_user', 1500, 1759800000000, 1759800900000, 1759800900000),"
            "('r_flow', 'flow', 'default_user', 2520, 1759803600000, 1759806120000, 1759806120000),"
            "('r_orphan', 'gone', 'default_user', 600, 1759800000000, 1759800600000, 1759800600000)");
        raw.execute('PRAGMA user_version = 6');
      } finally {
        raw.dispose();
      }

      final db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final version =
            await db.customSelect('PRAGMA user_version').getSingle();
        expect(version.read<int>('user_version'), kSchemaHead);

        final sessions = await db
            .customSelect('SELECT id, planned_seconds, timing_mode '
                'FROM focus_sessions ORDER BY id')
            .get();
        expect(sessions, hasLength(2));
        expect(sessions.first.read<String>('id'), 'flow');
        expect(sessions.first.read<String>('timing_mode'), 'countUp',
            reason: 'a session with no length was a flow session, not a '
                'countdown that expired at zero');
        expect(sessions.last.read<String>('id'), 'timed');
        expect(sessions.last.read<String>('timing_mode'), 'countdown');

        final records = await db
            .customSelect('SELECT id, duration_seconds, timing_mode '
                'FROM focus_records ORDER BY id')
            .get();
        final byId = {
          for (final row in records) row.read<String>('id'): row,
        };
        expect(byId['r_flow']!.read<String>('timing_mode'), 'countUp');
        expect(byId['r_timed']!.read<String>('timing_mode'), 'countdown');
        // Documented rather than hidden: a record whose session row is gone has
        // no length left to read, so it keeps the column default.
        expect(byId['r_orphan']!.read<String>('timing_mode'), 'countdown');

        // Nothing that was there is gone.
        expect(byId['r_flow']!.read<int>('duration_seconds'), 2520);

        // And the new column is readable through the real DAO, which is what
        // proves the migration produced the schema the code expects.
        final mapped = await db.focusSessionDao.findById('flow');
        expect(mapped, isNotNull);
        expect(mapped!.timingMode.name, 'countUp');
        expect(mapped.plannedSeconds, 0);
      } finally {
        await db.close();
      }
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
