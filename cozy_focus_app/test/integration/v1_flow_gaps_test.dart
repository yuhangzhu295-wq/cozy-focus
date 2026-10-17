import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart' hide Task;
import 'package:cozy_focus_app/data/repositories/drift_focus_record_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_focus_session_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_pet_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_reward_ledger_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_task_repository.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/task.dart';
import 'package:cozy_focus_app/domain/repositories/i_task_repository.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/domain/services/focus_session_engine.dart';
import 'package:cozy_focus_app/domain/services/reward_service.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/controllers/rest_controller.dart';

/// Two FLOW-01/FLOW-02 cases the existing suites did not cover.
///
/// The rest of the V1 flow matrix is already exercised by the A-F golden flows,
/// `task_flow_test`, `focus_timing_mode_flow_test` and
/// `persistence_recovery_test`; this file only adds what was genuinely missing,
/// rather than restating them with new names.
void main() {
  late AppDatabase db;
  late FocusSessionEngine engine;
  late _TestClock clock;
  late DriftTaskRepository tasks;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _TestClock(DateTime(2026, 10, 9, 9));
    tasks = DriftTaskRepository(db.taskDao);
    engine = FocusSessionEngine(
      sessionRepo: DriftFocusSessionRepository(db.focusSessionDao),
      recordRepo: DriftFocusRecordRepository(db.focusRecordDao),
      rewardService: RewardService(
        ledgerRepo: DriftRewardLedgerRepository(db.rewardLedgerDao),
        petRepo: DriftPetRepository(db.petDao),
        clock: clock,
      ),
      clock: clock,
    );
  });

  tearDown(() async => db.close());

  test('FLOW-01: editing a task keeps its recorded time and its history',
      () async {
    final createdAt = clock.now();
    final task = Task(
      id: 'task-edit',
      userId: userId,
      title: '写周报',
      categoryId: 'work',
      estimatedSeconds: 25 * 60,
      createdAt: createdAt,
    );
    await tasks.insert(task);

    await engine.start(
      userId: userId,
      plannedSeconds: 25 * 60,
      mode: FocusMode.focus,
      taskName: '写周报',
      taskId: task.id,
    );
    clock.advance(const Duration(minutes: 25));
    await engine.complete();
    await engine.save(note: '初稿');

    final beforeEdit = (await tasks.findWithProgress(task.id))!;
    expect(beforeEdit.focusedSeconds, 25 * 60);

    // The edit the detail screen performs: same id, new wording.
    await tasks.update(task.copyWith(
      title: '写季度周报',
      categoryId: () => 'study',
      note: () => '改成季度口径',
    ));

    final afterEdit = (await tasks.findWithProgress(task.id))!;
    expect(afterEdit.task.title, '写季度周报');
    expect(afterEdit.task.categoryId, 'study');
    expect(afterEdit.task.note, '改成季度口径');
    expect(afterEdit.focusedSeconds, 25 * 60,
        reason: 'renaming a task must not detach the time already recorded for '
            'it');
    expect(afterEdit.sessionCount, 1);

    // The record is history: it keeps the title it was saved under. Rewriting
    // it would make yesterday's record claim it was always called something it
    // was not.
    final record = await db.focusRecordDao.findBySessionId(
      (await db.focusSessionDao.findRecent(userId, limit: 1)).single.id,
    );
    expect(record, isNotNull);
    expect(record!.taskName, '写周报');
    expect(record.taskId, task.id);

    // And the list reads the edited row, not a cached copy.
    final listed = await tasks.findByFilter(userId, TaskFilter.active);
    expect(listed.single.title, '写季度周报');
  });

  test('FLOW-02: finishing a countdown early records the time actually focused',
      () async {
    await engine.start(
      userId: userId,
      plannedSeconds: 25 * 60,
      mode: FocusMode.focus,
      timingMode: FocusTimingMode.countdown,
      taskName: '提前结束',
    );
    clock.advance(const Duration(minutes: 10, seconds: 30));

    // The user presses 完成 before the target, which is the ordinary early
    // finish rather than an error path.
    await engine.complete();
    await engine.save();

    final session =
        (await db.focusSessionDao.findRecent(userId, limit: 1)).single;
    final record = await db.focusRecordDao.findBySessionId(session.id);
    expect(record, isNotNull);
    expect(record!.durationSeconds, 10 * 60 + 30,
        reason: 'the record is the focused time, not the planned time');
    expect(record.durationSeconds, lessThan(25 * 60));

    // The ledger agrees with the record: 2 coins per whole minute.
    final ledger = await db.rewardLedgerDao.findBySessionId(session.id);
    expect(ledger, isNotNull);
    expect(ledger!.focusCoinsEarned, 20);
  });

  test('FLOW-04: a rest records its length and earns no focus reward',
      () async {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(clock),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
    addTearDown(container.dispose);

    final rest = container.read(restControllerProvider.notifier);
    // Let the constructor's async restore() finish before starting.
    await Future<void>.delayed(Duration.zero);

    await rest.start(10);
    clock.advance(const Duration(minutes: 10));
    await rest.finish();

    expect(await db.restDao.findRunning(userId), isNull,
        reason: 'the rest has an end time');
    final sessions = await db.customSelect(
      'SELECT COUNT(*) AS c FROM rest_sessions WHERE status = ?',
      variables: [const Variable<String>('completed')],
    ).getSingle();
    expect(sessions.data['c'], 1);

    // The two things a rest must never do: become focus time, or become coins.
    final records = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM focus_records',
        )
        .getSingle();
    expect(records.data['c'], 0, reason: 'rest is not a focus record');
    final ledger = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM reward_ledger',
        )
        .getSingle();
    expect(ledger.data['c'], 0, reason: 'rest earns no coins and no XP');
  });
}

class _TestClock implements FocusClock {
  DateTime _now;
  _TestClock(this._now);

  @override
  DateTime now() => _now;

  void advance(Duration duration) => _now = _now.add(duration);
}
