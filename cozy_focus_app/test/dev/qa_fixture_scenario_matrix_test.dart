/// Every ordered pair of QA scenarios, round-tripped.
///
/// For each pair (A, B): `seed(A) -> seed(B) -> reset -> seed(A)` must leave the
/// same database as a single `seed(A)`. That is the property eight review rounds
/// kept finding holes in, one interaction at a time - the snapshot timing, the
/// memory ids, the craft job, the inventory rows. Testing pairs one at a time
/// finds one hole per round; testing all 64 finds them at once.
///
/// The fingerprint compares the columns that are properties of the seeded state.
/// It deliberately excludes `task_schedules.id` and `task_schedules.created_at`:
/// the app generates a fresh id and reads the real clock in `schedule()`, so two
/// identical seeds legitimately differ there. Including them would report the
/// app's own id generation as a fixture defect.
library;

import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/dev/qa_fixture.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
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
    'tasks': 'id,title,category_id,estimated_seconds,note,status,'
        'created_at,completed_at,sort_order',
    'task_schedules': 'task_id,date,start_at,planned_seconds,status,user_id',
    'distraction_notes': 'id,text,category_id,status,created_at,handled_at,'
        'converted_task_id,session_id',
    'focus_sessions': 'id,category_id,task_name,task_id,planned_seconds,mode,'
        'timing_mode,start_at,end_at,status,timezone_offset_minutes',
    'focus_records': 'id,session_id,category_id,task_name,task_id,mood,gains,'
        'duration_seconds,start_at,end_at,is_counted_for_reward',
    'reward_ledger': 'session_id,focus_coins_earned,experience_earned,'
        'settled_at',
    'pet_memories': 'id,memory_type,content,happened_at',
    'inventory_items': 'id,item_id,quantity',
    'room_items': 'id,item_id,position_x,position_y,scale,z_index,is_visible',
    'craft_jobs': 'id,recipe_id,status,progress_seconds,reward_claimed',
    'pet_progress': 'level,experience_points,total_focus_minutes,'
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
}
