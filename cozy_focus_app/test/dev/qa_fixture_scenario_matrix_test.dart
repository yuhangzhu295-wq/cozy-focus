/// Every ordered pair of QA scenarios, round-tripped.
///
/// For each pair (A, B): `seed(A) -> seed(B) -> reset -> seed(A)` must leave the
/// same database as a single `seed(A)`. That is the property eight review rounds
/// kept finding holes in, one interaction at a time - the snapshot timing, the
/// memory ids, the craft job, the inventory rows. Testing pairs one at a time
/// finds one hole per round; testing all 64 finds them at once.
///
/// The fingerprint compares the columns that are properties of the seeded state,
/// including ownership (`user_id`), the pet and its progress id. It deliberately
/// excludes `task_schedules.id` and `task_schedules.created_at`: the app
/// generates a fresh id and reads the real clock in `schedule()`, so two
/// identical seeds legitimately differ there. The id is still checked for
/// validity — see `a seeded placement is addressable by its own id` — because
/// excluding it from equality is not the same as not testing it.
library;

import 'package:cozy_focus_app/data/local/app_database.dart' hide TaskSchedule;
import 'package:cozy_focus_app/dev/qa_fixture.dart';
import 'package:cozy_focus_app/domain/models/task_schedule.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _C implements FocusClock {
  @override
  DateTime now() => DateTime(2026, 10, 18, 11, 40);
}

Future<String> fingerprint(AppDatabase db) async {
  // Only columns whose value is a property of the seeded state. `task_schedules`
  // carries an id the app generates per call and a created_at taken from the
  // real clock, so two identical seeds legitimately differ there; comparing them
  // would report the app's own id generation as a fixture bug.
  const tables = <String, String>{
    'pets': 'id,user_id,character_id,species,name',
    'tasks': 'id,user_id,title,category_id,estimated_seconds,note,status,'
        'created_at,completed_at,sort_order',
    'task_schedules': 'task_id,user_id,date,start_at,planned_seconds,status',
    'distraction_notes': 'id,user_id,text,category_id,status,created_at,'
        'handled_at,converted_task_id,session_id',
    'focus_sessions':
        'id,user_id,category_id,task_name,task_id,planned_seconds,'
            'mode,timing_mode,start_at,end_at,status,timezone_offset_minutes',
    'focus_records': 'id,session_id,user_id,category_id,task_name,task_id,mood,'
        'gains,duration_seconds,start_at,end_at,is_counted_for_reward',
    'reward_ledger': 'session_id,user_id,focus_coins_earned,experience_earned,'
        'settled_at',
    'pet_memories': 'id,pet_id,memory_type,content,happened_at',
    'inventory_items': 'id,user_id,item_id,quantity',
    'room_items': 'id,user_id,item_id,position_x,position_y,scale,z_index,'
        'is_visible',
    'craft_jobs': 'id,user_id,recipe_id,status,progress_seconds,reward_claimed',
    'pet_progress': 'id,pet_id,level,experience_points,total_focus_minutes,'
        'happiness_score',
    'app_settings': 'key,value',
  };
  final b = StringBuffer();
  for (final entry in tables.entries) {
    final rows = await db
        .customSelect(
          'select ${entry.value} from ${entry.key} order by 1, 2',
        )
        .get();
    b.writeln('${entry.key}:${rows.length}');
    for (final r in rows) {
      final keys = r.data.keys.toList()..sort();
      b.writeln(keys.map((k) => '$k=${r.data[k]}').join('|'));
    }
  }
  return b.toString();
}

QaFixtureHarness harnessFor(AppDatabase db, ProviderContainer c) =>
    QaFixtureHarness(
      pets: c.read(petRepositoryProvider),
      craft: c.read(craftRepositoryProvider),
      tasks: c.read(taskRepositoryProvider),
      sessions: c.read(focusSessionRepositoryProvider),
      records: c.read(focusRecordRepositoryProvider),
      notes: c.read(distractionRepositoryProvider),
      ledger: c.read(rewardLedgerRepositoryProvider),
      db: db,
      clock: c.read(focusClockProvider),
    );

/// Every table `reset()` must empty, and the two rows it deliberately keeps.
///
/// The base pet is the production adoption row (`mochi_pet_id`), which the app
/// creates on first launch. Reset leaves it because removing it would let a QA
/// cleanup delete a real user's companion — and because the app reaches that
/// state on its own. Everything else the fixture touches must be gone.
const _resetMustEmpty = <String>[
  'tasks',
  'task_schedules',
  'distraction_notes',
  'focus_sessions',
  'focus_records',
  'reward_ledger',
  'pet_memories',
  'inventory_items',
  'room_items',
  'craft_jobs',
];

/// Fixture bookkeeping that outlives a reset on purpose.
///
/// Empty: reset clears every key it wrote, including the inventory grant
/// ledger. The list stays because the test's shape should not change the day a
/// legitimate marker is added — it should be a deliberate edit.
const _allowedBookkeeping = <String>[];

void main() {
  for (final a in QaScenario.values) {
    for (final b in QaScenario.values) {
      test('${a.id} -> ${b.id} -> reset -> ${a.id}', () async {
        var db = AppDatabase.forTesting(NativeDatabase.memory());
        var c = ProviderContainer(overrides: [
          appDatabaseProvider.overrideWithValue(db),
          focusClockProvider.overrideWithValue(_C()),
        ]);
        var h = harnessFor(db, c);
        await h.seed(a);
        final expected = await fingerprint(db);
        c.dispose();
        await db.close();

        db = AppDatabase.forTesting(NativeDatabase.memory());
        c = ProviderContainer(overrides: [
          appDatabaseProvider.overrideWithValue(db),
          focusClockProvider.overrideWithValue(_C()),
        ]);
        h = harnessFor(db, c);
        await h.seed(a);
        await h.seed(b);
        await h.reset();
        await h.seed(a);
        final actual = await fingerprint(db);
        c.dispose();
        await db.close();

        if (actual != expected) {
          final e = expected.split('\n');
          final t = actual.split('\n');
          final diffs = <String>[];
          for (var i = 0; i < e.length || i < t.length; i++) {
            final le = i < e.length ? e[i] : '<missing>';
            final la = i < t.length ? t[i] : '<missing>';
            if (le != la) {
              diffs.add('expected: $le  actual: $la');
              if (diffs.length == 5) break;
            }
          }
          // ignore: avoid_print
          print('DIFF ${a.id} -> ${b.id}: ${diffs.join(' || ')}');
        }
        expect(actual, expected,
            reason: '${a.id} -> ${b.id} -> reset -> ${a.id} does not match a '
                'single ${a.id}');
      });
    }
  }

  for (final a in QaScenario.values) {
    test('${a.id}: reset leaves only the base pet', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider.overrideWithValue(_C()),
      ]);
      final h = harnessFor(db, c);
      await h.seed(a);
      await h.reset();

      for (final table in _resetMustEmpty) {
        final n = (await db
                .customSelect('select count(*) as c from $table')
                .getSingle())
            .read<int>('c');
        expect(n, 0, reason: '${a.id} left $table rows after reset');
      }
      final settings = await db
          .customSelect('select key from app_settings order by key')
          .get();
      for (final row in settings) {
        final key = row.read<String>('key');
        expect(
            key.startsWith('qa_') || _allowedBookkeeping.contains(key), isTrue,
            reason: '${a.id} left a non-fixture app setting: $key');
      }
      final unexpected = settings
          .map((r) => r.read<String>('key'))
          .where((k) => !_allowedBookkeeping.contains(k))
          .toList();
      expect(unexpected, isEmpty,
          reason: '${a.id} left bookkeeping that a seed would not recreate');
      final pets =
          (await db.customSelect('select count(*) as c from pets').getSingle())
              .read<int>('c');
      expect(pets, 1,
          reason: 'the base pet is the production adoption row and stays');
      final progress = await db.petDao.findProgress(QaFixtureHarness.petId);
      expect(progress!.experiencePoints, 0);
      expect(progress.totalFocusMinutes, 0);

      c.dispose();
      await db.close();
    });
  }

  test('every seeded placement is addressable by its own id', () async {
    // The fingerprint excludes task_schedules.id because the app generates a
    // fresh one per call, so two seeds differ there. That is not the same as the
    // id being untested: the plan page updates and deletes placements by it.
    //
    // Read the rows from the table rather than through `findScheduleOn`: that
    // reader deliberately skips finished placements, and one of the three is
    // already done.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(_C()),
    ]);
    final h = harnessFor(db, c);
    await h.seed(QaScenario.demoDay);

    final rows = await db
        .customSelect(
          'select id, task_id, date, status from task_schedules '
          "where task_id like 'qa_demo_task_%' order by task_id",
        )
        .get();
    expect(rows, hasLength(3));
    for (final row in rows) {
      final id = row.read<String>('id');
      expect(id, isNotEmpty);
      final placement = await c.read(taskRepositoryProvider).findScheduleOn(
          row.read<String>('task_id'), row.read<String>('date'));
      // The done one is filtered out by that reader; the planned ones are found.
      if (row.read<String>('status') == 'planned') {
        expect(placement, isNotNull, reason: 'a planned row must be findable');
        expect(placement!.id, id);
      }

      await c.read(taskRepositoryProvider).updateSchedule(
            TaskSchedule(
              id: id,
              taskId: row.read<String>('task_id'),
              userId: 'default_user',
              date: row.read<String>('date'),
              startAt: DateTime(2026, 10, 18, 14),
              plannedSeconds: 1500,
              status: TaskScheduleStatus.done,
              createdAt: DateTime(2026, 10, 12),
            ),
          );
      final updated = (await db.customSelect(
        'select status from task_schedules where id = ?',
        variables: [Variable.withString(id)],
      ).getSingle())
          .read<String>('status');
      expect(updated, 'done', reason: 'the id must address a real row');
    }

    c.dispose();
    await db.close();
  });
}
