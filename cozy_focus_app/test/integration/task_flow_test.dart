import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask;
import 'package:cozy_focus_app/data/repositories/drift_focus_record_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_focus_session_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_pet_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_reward_ledger_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_task_repository.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/repositories/i_task_repository.dart';
import 'package:cozy_focus_app/domain/models/task.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/domain/services/focus_session_engine.dart';
import 'package:cozy_focus_app/domain/services/reward_service.dart';
import 'package:cozy_focus_app/presentation/controllers/task_controller.dart';

/// P1 Gate — the business flow the phase has to earn.
///
/// `create a task -> it appears in the list -> start focus for it -> complete and
/// save -> the record carries the task -> the task's focused time goes up`.
///
/// ## Why it runs on the real engine and the real repositories
///
/// The gate is not "a task can be inserted". It is that the *whole* path a user
/// takes leaves the right rows behind, and the part most likely to be wrong is
/// the seam: the task id travelling from the create screen, through the focus
/// session, into the record, and back out as a number on the detail screen. A
/// test with a stub repository at any point in that chain would assert the stub.
void main() {
  late AppDatabase db;
  late FocusSessionEngine engine;
  late _TestClock clock;
  late DriftTaskRepository tasks;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _TestClock(DateTime(2026, 10, 7, 9));
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

  /// Runs a whole focus session: start, wait, complete, save.
  Future<void> focusFor(
    Duration duration, {
    String? taskId,
    String? note,
  }) async {
    await engine.start(
      userId: userId,
      plannedSeconds: duration.inSeconds,
      mode: FocusMode.focus,
      taskName: '写产品方案',
      taskId: taskId,
    );
    clock.advance(duration);
    await engine.complete();
    await engine.save(note: note);
  }

  test('the whole flow leaves the right rows behind', () async {
    // ── create a task, through the function the create screen calls ──────────
    final taskId = await createTask(
      repository: tasks,
      userId: userId,
      title: '写产品方案',
      categoryId: 'work',
      estimatedSeconds: 25 * 60,
      note: '初稿',
    );

    // ── it appears in the list ──────────────────────────────────────────────
    final listed = await tasks.findByFilter(userId, TaskFilter.active);
    expect(listed.map((t) => t.id), contains(taskId));
    expect(listed.first.title, '写产品方案');
    expect(listed.first.categoryId, 'work');

    // ── starting focus for it carries the task into the session ─────────────
    final session = await engine.start(
      userId: userId,
      plannedSeconds: 25 * 60,
      mode: FocusMode.focus,
      taskName: '写产品方案',
      taskId: taskId,
    );
    expect(session.taskId, taskId,
        reason: 'the session must know what it is for, or the record cannot');

    clock.advance(const Duration(minutes: 25));
    await engine.complete();
    await engine.save(note: '写完初稿');

    // ── and the record carries it, which is what makes the time count ───────
    final record = await db.focusRecordDao.findBySessionId(session.id);
    expect(record, isNotNull);
    expect(record!.taskId, taskId,
        reason: 'a record without the task id is time that belongs to nobody');
    expect(record.durationSeconds, 25 * 60);
    expect(record.note, '写完初稿');

    // ── the task's total went up, read from the records ─────────────────────
    final progress = (await tasks.findWithProgress(taskId))!;
    expect(progress.focusedSeconds, 25 * 60);
    expect(progress.sessionCount, 1);
    expect(progress.isOverEstimate, isFalse);
  });

  test('two sessions on one task add up, and a taskless one does not',
      () async {
    final taskId = await createTask(
      repository: tasks,
      userId: userId,
      title: '写产品方案',
      estimatedSeconds: 60 * 60,
    );

    await focusFor(const Duration(minutes: 20), taskId: taskId);
    await focusFor(const Duration(minutes: 25), taskId: taskId);
    // Focus without a task stays a first-class way to focus, and its time must
    // not be attributed to the last task the user happened to look at.
    await focusFor(const Duration(minutes: 30));

    final progress = (await tasks.findWithProgress(taskId))!;
    expect(progress.focusedSeconds, 45 * 60);
    expect(progress.sessionCount, 2);
  });

  test('completing a task does not lose its recorded time', () async {
    final taskId = await createTask(
      repository: tasks,
      userId: userId,
      title: '写产品方案',
      estimatedSeconds: 25 * 60,
    );
    await focusFor(const Duration(minutes: 25), taskId: taskId);

    await tasks.setStatus(taskId, TaskStatus.done,
        at: DateTime(2026, 10, 7, 18));

    final progress = (await tasks.findWithProgress(taskId))!;
    expect(progress.task.isDone, isTrue);
    expect(progress.focusedSeconds, 25 * 60,
        reason: 'finishing a task is not a reason to forget what it cost');
    // And it moved to the done tab, not out of the app.
    expect(
      (await tasks.findByFilter(userId, TaskFilter.done)).map((t) => t.id),
      contains(taskId),
    );
  });

  test('a paused session records the focused time, not the wall clock',
      () async {
    // The same rule the whole app is built on: elapsed truth comes from the
    // timestamps, and a pause is subtracted. A task's total must agree with what
    // the completion screen showed.
    final taskId = await createTask(
      repository: tasks,
      userId: userId,
      title: '写产品方案',
      estimatedSeconds: 25 * 60,
    );

    await engine.start(
      userId: userId,
      plannedSeconds: 25 * 60,
      mode: FocusMode.focus,
      taskName: '写产品方案',
      taskId: taskId,
    );
    clock.advance(const Duration(minutes: 10));
    await engine.pause();
    clock.advance(const Duration(minutes: 5)); // paused: not focus
    await engine.resume();
    clock.advance(const Duration(minutes: 10));
    await engine.complete();
    await engine.save();

    final progress = (await tasks.findWithProgress(taskId))!;
    expect(progress.focusedSeconds, 20 * 60,
        reason: 'the five paused minutes are not focus time');
  });
}

/// A clock the test moves by hand.
///
/// The engine's elapsed truth is timestamps read from the clock, so a test that
/// wants a twenty-five minute session has to move the clock rather than wait.
class _TestClock implements FocusClock {
  _TestClock(this._now);
  DateTime _now;

  void advance(Duration by) => _now = _now.add(by);

  @override
  DateTime now() => _now;
}
