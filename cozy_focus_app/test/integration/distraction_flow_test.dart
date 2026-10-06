import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule, FocusSession, DistractionNote;
import 'package:cozy_focus_app/domain/models/distraction_note.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/repositories/i_distraction_repository.dart';
import 'package:cozy_focus_app/domain/repositories/i_task_repository.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/distraction_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';

/// P4 Gate — the flow the phase has to earn.
///
/// `focus -> 记一下 -> the note is stored against the session -> the focus is
/// untouched -> complete and save -> the record exists -> the inbox -> 转成任务 ->
/// the note is handled and a real task exists`.
///
/// ## Why it runs on the real controller and the real engine
///
/// The claim this phase makes is that capturing a thought costs the user no focus
/// time. That is only true if the session keeps running and nothing is subtracted
/// — so the assertion is on the session's elapsed seconds across the capture, not
/// on the note having been written. A test that stopped at "a row exists" would
/// not notice a capture that quietly paused the timer.
void main() {
  late AppDatabase db;
  late _TestClock clock;
  late ProviderContainer container;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _TestClock(DateTime(2026, 10, 8, 9));
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(clock),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  FocusSessionController focus() =>
      container.read(focusSessionControllerProvider.notifier);
  DistractionInboxController inbox() =>
      container.read(distractionInboxControllerProvider.notifier);
  IDistractionRepository notes() =>
      container.read(distractionRepositoryProvider);
  ITaskRepository tasks() => container.read(taskRepositoryProvider);

  testWidgets('the whole flow leaves the right rows behind', (tester) async {
    // ── start focusing ───────────────────────────────────────────────────────
    final session = await focus().startSession(
      userId: userId,
      plannedSeconds: 25 * 60,
      mode: FocusMode.focus,
      taskName: '写产品方案',
    );
    clock.advance(const Duration(minutes: 8));
    await tester.pump(const Duration(seconds: 1));

    final elapsedBeforeCapture =
        container.read(focusSessionControllerProvider).elapsedSeconds;
    expect(elapsedBeforeCapture, 8 * 60);

    // ── 记一下 ──────────────────────────────────────────────────────────────
    await inbox().capture(
      text: '买充电线',
      categoryId: 'life',
      sessionId: session.id,
    );

    // ── and the focus is untouched ──────────────────────────────────────────
    final afterCapture = container.read(focusSessionControllerProvider);
    expect(afterCapture.session!.status, FocusSessionStatus.running,
        reason: 'capturing a thought must not pause the session');
    expect(afterCapture.session!.pauseIntervals, isEmpty,
        reason: 'and must not record a pause, which would subtract time later');
    expect(afterCapture.elapsedSeconds, elapsedBeforeCapture,
        reason: 'no time is lost to writing something down');

    clock.advance(const Duration(minutes: 12));
    await tester.pump(const Duration(seconds: 1));
    expect(
        container.read(focusSessionControllerProvider).elapsedSeconds, 20 * 60,
        reason: 'and the timer keeps counting from the real clock');

    // ── finish the session ──────────────────────────────────────────────────
    await focus().completeSession();
    await focus().saveSession(note: '初稿写完');

    final record = await db.focusRecordDao.findBySessionId(session.id);
    expect(record, isNotNull);
    expect(record!.durationSeconds, 20 * 60,
        reason: 'the session recorded the twenty minutes, not eighteen');

    // ── the note is still there and still points at the session ─────────────
    final stored = await notes().notesForSession(session.id);
    expect(stored, hasLength(1));
    expect(stored.single.text, '买充电线');
    expect(stored.single.categoryId, 'life');
    expect(stored.single.isOpen, isTrue,
        reason: 'saving the session is not a decision about the thought');
    expect(stored.single.createdAt, DateTime(2026, 10, 8, 9, 8),
        reason:
            'the note is dated by the app clock, at the moment it was made');

    // ── and the inbox shows it ──────────────────────────────────────────────
    await inbox().load();
    expect(
        container.read(distractionInboxControllerProvider).notes, hasLength(1));
    expect(container.read(distractionInboxControllerProvider).openTotal, 1);

    // ── 转成任务 ────────────────────────────────────────────────────────────
    final taskId = await inbox().convertToTask(stored.single);

    final created = await tasks().findById(taskId);
    expect(created, isNotNull);
    expect(created!.title, '买充电线');
    expect(created.categoryId, 'life');
    expect(created.note, '买充电线');
    expect(created.isDone, isFalse);

    final handled = await notes().findById(stored.single.id);
    expect(handled!.isOpen, isFalse);
    expect(handled.convertedTaskId, taskId);
    expect(handled.handledAt, isNotNull);

    // The inbox is empty again, and the thought is a task.
    expect(await notes().countOpen(userId), 0);
    expect(
        (await tasks().findByFilter(userId, TaskFilter.active))
            .map((t) => t.title),
        ['买充电线']);
  });

  testWidgets('安排到今天 files it and schedules it', (tester) async {
    final session = await focus().startSession(
      userId: userId,
      plannedSeconds: 25 * 60,
      mode: FocusMode.focus,
      taskName: '写产品方案',
    );
    await inbox().capture(
      text: '准备下周的汇报资料',
      categoryId: 'work',
      sessionId: session.id,
    );
    await focus().cancelSession();

    final note = (await notes().notesForSession(session.id)).single;
    final taskId = await inbox().convertToTask(note, alsoPlaceToday: true);

    final day = await tasks().schedulesForDay(userId, '2026-10-08');
    expect(day, hasLength(1));
    expect(day.single.schedule.taskId, taskId);
    expect(day.single.schedule.startAt, DateTime(2026, 10, 8, 9, 30));
    expect(day.single.schedule.plannedSeconds,
        DistractionNote.defaultPlacementSeconds);

    // And the scheduled task is a real one, so starting it from the plan will
    // attribute the time to it.
    final started = await focus().startSession(
      userId: userId,
      plannedSeconds: day.single.schedule.plannedSeconds,
      mode: FocusMode.focus,
      taskName: day.single.title,
      taskId: day.single.schedule.taskId,
    );
    expect(started.taskId, taskId);
    clock.advance(const Duration(minutes: 25));
    await focus().completeSession();
    await focus().saveSession();

    expect((await tasks().findWithProgress(taskId))!.focusedSeconds, 25 * 60);
  });

  testWidgets('several notes from one session all keep its id', (tester) async {
    final session = await focus().startSession(
      userId: userId,
      plannedSeconds: 25 * 60,
      mode: FocusMode.focus,
      taskName: '写产品方案',
    );
    clock.advance(const Duration(minutes: 3));
    await tester.pump(const Duration(seconds: 1));
    await inbox().capture(text: '第一件', sessionId: session.id);
    clock.advance(const Duration(minutes: 4));
    await tester.pump(const Duration(seconds: 1));
    await inbox().capture(text: '第二件', sessionId: session.id);
    clock.advance(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));

    await focus().completeSession();
    await focus().saveSession();

    final forSession = await notes().notesForSession(session.id);
    expect(forSession.map((n) => n.text), ['第一件', '第二件'],
        reason: 'the order they arrived is what a review reads them in');
    expect(await notes().countOpen(userId), 2);
    expect(
        (await db.focusRecordDao.findBySessionId(session.id))!.durationSeconds,
        12 * 60,
        reason: 'two captures cost nothing: the twelve minutes are all focus');
  });

  testWidgets('a note captured without a session is still kept',
      (tester) async {
    // The sheet is reachable from a running session today, but the repository
    // must not require one: a thought is the user's whether or not a timer was
    // running when they had it.
    await inbox().capture(text: '洗碗机该修了');

    final open = await notes().findByFilter(userId, DistractionFilter.open);
    expect(open.single.sessionId, isNull);
    expect(open.single.text, '洗碗机该修了');
  });
}

class _TestClock implements FocusClock {
  _TestClock(this._now);
  DateTime _now;

  void advance(Duration by) => _now = _now.add(by);

  @override
  DateTime now() => _now;
}
