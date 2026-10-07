import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule;
import 'package:cozy_focus_app/data/repositories/drift_focus_record_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_focus_session_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_pet_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_reward_ledger_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_task_repository.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/task_schedule.dart';
import 'package:cozy_focus_app/domain/repositories/i_task_repository.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/domain/services/focus_session_engine.dart';
import 'package:cozy_focus_app/domain/services/reward_service.dart';
import 'package:cozy_focus_app/domain/services/today_planner.dart';
import 'package:cozy_focus_app/presentation/controllers/task_controller.dart';

/// P2 Gate — the flow the phase has to earn.
///
/// `write a task down with 加入今日计划 on -> it is on today's plan -> start focus
/// from the plan row -> complete and save -> the record carries the task -> the
/// task's cumulative time goes up -> the plan can be finished -> the next card
/// moves on`.
///
/// ## Why it runs on the real engine and the real repositories
///
/// The phase adds one seam — a plan row leading into a focus session — and the
/// seam is where the task id either travels or does not. A test that stopped at
/// "the placement row exists" would not notice the session losing the id, and the
/// time would land on a task nobody could see.
void main() {
  late AppDatabase db;
  late FocusSessionEngine engine;
  late _TestClock clock;
  late DriftTaskRepository tasks;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _TestClock(DateTime(2026, 10, 7, 8));
    tasks = DriftTaskRepository(db.taskDao, clock: clock);
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

  /// Focuses for [duration] on a task, the way the plan's 开始 button does.
  Future<String> focusFromPlan(PlannedTask placement) async {
    final session = await engine.start(
      userId: userId,
      plannedSeconds: placement.schedule.plannedSeconds,
      mode: FocusMode.focus,
      taskName: placement.title,
      taskId: placement.schedule.taskId,
    );
    clock.advance(Duration(seconds: placement.schedule.plannedSeconds));
    await engine.complete();
    await engine.save();
    return session.id;
  }

  test('the whole flow leaves the right rows behind', () async {
    // ── write it down, with the create screen's switch on ───────────────────
    final taskId = await createTask(
      repository: tasks,
      userId: userId,
      title: '写产品方案',
      categoryId: 'work',
      estimatedSeconds: 25 * 60,
      note: '梳理核心功能',
      createdAt: clock.now(),
    );
    final scheduleId = await tasks.schedule(
      taskId: taskId,
      userId: userId,
      startAt: DateTime(2026, 10, 7, 8, 30),
      plannedSeconds: 25 * 60,
    );

    // ── the plan shows it, which is what the today screen reads ─────────────
    final day = await tasks.schedulesForDay(userId, '2026-10-07');
    expect(day, hasLength(1));
    expect(day.single.title, '写产品方案');
    expect(day.single.categoryId, 'work');
    expect(day.single.schedule.plannedSeconds, 25 * 60);
    expect(nextPlacement(day)!.schedule.id, scheduleId);

    // ── 开始 from the card carries the task into the session ────────────────
    final session = await engine.start(
      userId: userId,
      plannedSeconds: day.single.schedule.plannedSeconds,
      mode: FocusMode.focus,
      taskName: day.single.title,
      taskId: day.single.schedule.taskId,
    );
    expect(session.taskId, taskId,
        reason:
            'a session started from the plan must still know what it is for');

    clock.advance(const Duration(minutes: 25));
    await engine.complete();
    await engine.save(note: '写完初稿');

    // ── the record carries it, which is what makes the time count ───────────
    final record = await db.focusRecordDao.findBySessionId(session.id);
    expect(record, isNotNull);
    expect(record!.taskId, taskId);
    expect(record.durationSeconds, 25 * 60);

    // ── the task's total went up, read from the records ─────────────────────
    final progress = (await tasks.findWithProgress(taskId))!;
    expect(progress.focusedSeconds, 25 * 60);
    expect(progress.sessionCount, 1);

    // ── finishing the placement is a status write, not a delete ─────────────
    final placement =
        (await tasks.schedulesForDay(userId, '2026-10-07')).single;
    await tasks.updateSchedule(
      placement.schedule.copyWith(status: TaskScheduleStatus.done),
    );
    final after = await tasks.schedulesForDay(userId, '2026-10-07');
    expect(after, hasLength(1), reason: 'the day keeps what happened on it');
    expect(nextPlacement(after), isNull,
        reason: 'and the card stops offering it');
    expect((await tasks.findWithProgress(taskId))!.focusedSeconds, 25 * 60,
        reason: 'marking the plan done is not a reason to forget the time');
  });

  test('the card moves on to the next placement as each one is finished',
      () async {
    final first = await createTask(
      repository: tasks,
      userId: userId,
      title: '写产品方案',
      estimatedSeconds: 25 * 60,
      createdAt: clock.now(),
    );
    final second = await createTask(
      repository: tasks,
      userId: userId,
      title: '熟悉阅读',
      estimatedSeconds: 50 * 60,
      createdAt: clock.now(),
    );
    await tasks.schedule(
      taskId: first,
      userId: userId,
      startAt: DateTime(2026, 10, 7, 9),
      plannedSeconds: 25 * 60,
    );
    await tasks.schedule(
      taskId: second,
      userId: userId,
      startAt: DateTime(2026, 10, 7, 10, 30),
      plannedSeconds: 50 * 60,
    );

    var day = await tasks.schedulesForDay(userId, '2026-10-07');
    expect(nextPlacement(day)!.title, '写产品方案');

    await focusFromPlan(day.first);
    final firstPlacement =
        (await tasks.schedulesForDay(userId, '2026-10-07')).first;
    await tasks.updateSchedule(
      firstPlacement.schedule.copyWith(status: TaskScheduleStatus.done),
    );

    day = await tasks.schedulesForDay(userId, '2026-10-07');
    expect(nextPlacement(day)!.title, '熟悉阅读',
        reason: 'the card has to be the next thing, not the first thing');
    expect(day.map((p) => p.schedule.status),
        [TaskScheduleStatus.done, TaskScheduleStatus.planned]);
  });

  test('time focused from the plan is attributed to the planned task only',
      () async {
    final planned = await createTask(
      repository: tasks,
      userId: userId,
      title: '写产品方案',
      estimatedSeconds: 25 * 60,
      createdAt: clock.now(),
    );
    final other = await createTask(
      repository: tasks,
      userId: userId,
      title: '健身',
      estimatedSeconds: 40 * 60,
      createdAt: clock.now(),
    );
    await tasks.schedule(
      taskId: planned,
      userId: userId,
      startAt: DateTime(2026, 10, 7, 9),
      plannedSeconds: 25 * 60,
    );

    final day = await tasks.schedulesForDay(userId, '2026-10-07');
    await focusFromPlan(day.single);

    expect((await tasks.findWithProgress(planned))!.focusedSeconds, 25 * 60);
    expect((await tasks.findWithProgress(other))!.focusedSeconds, 0,
        reason: 'a session belongs to the task it was started for, not to the '
            'last task the user looked at');
  });

  test('the plan for tomorrow is not in today, and today is not lost',
      () async {
    final today = await createTask(
      repository: tasks,
      userId: userId,
      title: '今天的事',
      estimatedSeconds: 25 * 60,
      createdAt: clock.now(),
    );
    final tomorrow = await createTask(
      repository: tasks,
      userId: userId,
      title: '明天的事',
      estimatedSeconds: 25 * 60,
      createdAt: clock.now(),
    );
    await tasks.schedule(
      taskId: today,
      userId: userId,
      startAt: DateTime(2026, 10, 7, 9),
      plannedSeconds: 25 * 60,
    );
    await tasks.schedule(
      taskId: tomorrow,
      userId: userId,
      startAt: DateTime(2026, 10, 8, 9),
      plannedSeconds: 25 * 60,
    );

    expect(
      (await tasks.schedulesForDay(userId, '2026-10-07')).map((p) => p.title),
      ['今天的事'],
    );
    expect(
      (await tasks.schedulesForDay(userId, '2026-10-08')).map((p) => p.title),
      ['明天的事'],
    );
    // And the day boundary is the clock's, not the machine's.
    clock.set(DateTime(2026, 10, 8, 8));
    expect(
      (await tasks.findByFilter(userId, TaskFilter.today)).map((t) => t.title),
      ['明天的事'],
    );
  });

  test('deleting a task removes its plan and keeps the other days intact',
      () async {
    final doomed = await createTask(
      repository: tasks,
      userId: userId,
      title: '不做了',
      estimatedSeconds: 25 * 60,
      createdAt: clock.now(),
    );
    final kept = await createTask(
      repository: tasks,
      userId: userId,
      title: '写产品方案',
      estimatedSeconds: 25 * 60,
      createdAt: clock.now(),
    );
    for (final taskId in [doomed, kept]) {
      await tasks.schedule(
        taskId: taskId,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );
    }

    await tasks.deleteById(doomed);

    final day = await tasks.schedulesForDay(userId, '2026-10-07');
    expect(day.map((p) => p.title), ['写产品方案'],
        reason: 'the cascade has to take only the deleted task\'s placements');
  });
}

/// A clock the test moves by hand.
class _TestClock implements FocusClock {
  _TestClock(this._now);
  DateTime _now;

  void advance(Duration by) => _now = _now.add(by);
  void set(DateTime value) => _now = value;

  @override
  DateTime now() => _now;
}
