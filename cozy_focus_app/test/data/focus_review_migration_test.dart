import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule, FocusSession, FocusRecord;
import 'package:cozy_focus_app/domain/models/focus_review.dart';
import '../support/schema_head.dart';

/// P5 — a v8 database gains the review's fields, and its moods are translated.
///
/// ## Why the translation matters
///
/// The save screen used to offer six emoji and store the character. The four
/// named moods replace them. Leaving the old values in place would make the
/// statistics count two vocabularies for one question — the same session feeling
/// filed under a face and under a word — so the migration translates the six it
/// knows. Anything it does not know is left exactly as it was, because guessing
/// at a mood the user never picked is worse than an unreadable one.
void main() {
  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test('v8 opens at the head with the review fields and translated moods',
      () async {
    final dir = Directory.systemTemp.createTempSync('cozy_p5_migration_');
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

        // One row per shape that has to survive: a recognised emoji, an
        // unrecognised value, and no mood at all.
        void insert(String id, String? mood, int duration) {
          final value = mood == null ? 'NULL' : "'$mood'";
          raw.execute('INSERT INTO focus_records '
              '(id, session_id, user_id, mood, duration_seconds, start_at, '
              'end_at, recorded_at) VALUES '
              "('$id', 'sess_$id', 'default_user', $value, $duration, "
              '1759800000000, 1759800900000, 1759800900000)');
        }

        insert('happy', String.fromCharCode(0x1F60A), 1500);
        insert('pleading', String.fromCharCode(0x1F97A), 600);
        insert('unheard', 'some-old-value', 300);
        insert('none', null, 900);
        raw.execute('PRAGMA user_version = 8');
      } finally {
        raw.dispose();
      }

      final db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final version =
            await db.customSelect('PRAGMA user_version').getSingle();
        expect(version.read<int>('user_version'), kSchemaHead);

        final rows = await db
            .customSelect('SELECT id, mood, gains, next_intention, '
                'duration_seconds FROM focus_records ORDER BY id')
            .get();
        final byId = {
          for (final row in rows) row.read<String>('id'): row,
        };
        expect(byId, hasLength(4));

        expect(byId['happy']!.read<String>('mood'), 'good',
            reason: 'the smiling face meant 不错');
        expect(byId['pleading']!.read<String>('mood'), 'distracted',
            reason: 'the pleading face meant 分心较多');
        expect(byId['unheard']!.read<String>('mood'), 'some-old-value',
            reason: 'an unrecognised value is left exactly as it was');
        expect(byId['none']!.read<String?>('mood'), isNull);

        // The two new columns exist and start empty, which is the truth: nobody
        // recorded a gain before the screen that asks for one existed.
        for (final id in ['happy', 'pleading', 'unheard', 'none']) {
          expect(byId[id]!.read<String?>('gains'), isNull, reason: id);
          expect(byId[id]!.read<String?>('next_intention'), isNull, reason: id);
        }

        // And nothing that was there is gone.
        expect(byId['happy']!.read<int>('duration_seconds'), 1500);
        expect(byId['pleading']!.read<int>('duration_seconds'), 600);
        expect(byId['unheard']!.read<int>('duration_seconds'), 300);
        expect(byId['none']!.read<int>('duration_seconds'), 900);

        // Read through the DAO the review screen uses, so this proves the schema
        // the code expects rather than only a table with the right columns.
        final record = await db.focusRecordDao.findBySessionId('sess_happy');
        expect(record, isNotNull);
        expect(record!.moodValue, FocusMood.good);
        expect(record.gainValues, isEmpty);
        final unknown = await db.focusRecordDao.findBySessionId('sess_unheard');
        expect(unknown!.moodValue, isNull,
            reason: 'the screen shows nothing selected rather than a wrong '
                'answer');
      } finally {
        await db.close();
      }
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
