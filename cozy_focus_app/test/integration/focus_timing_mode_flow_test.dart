import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cozy_focus_app/data/local/app_database.dart' hide FocusSession;
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';

/// P3 Gate — the flow the phase has to earn.
///
/// `choose a mode -> the session runs the way that mode says -> it ends the way
/// that mode says -> the record says which mode it was`.
///
/// ## Why this runs on the controller's real ticker
///
/// The one place the mode could be right everywhere except the running screen is
/// the display ticker, which is also the only thing that can end a session by
/// itself. The engine tests prove the rules; these prove the ticker obeys them —
/// a 正计时 session must not be completed by a countdown that is not there, and a
/// 番茄钟 must still end itself on time.
///
/// The ticker is a *display refresh*: it fires on the test's fake timer and reads
/// elapsed time from the injected clock, which is the same arrangement production
/// uses and the reason `Timer.periodic` is never the source of truth.
void main() {
  late AppDatabase db;
  late _TestClock clock;
  late ProviderContainer container;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _TestClock(DateTime(2026, 10, 7, 9));
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(clock),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  FocusSessionController controller() =>
      container.read(focusSessionControllerProvider.notifier);

  FocusSessionUIState state() => container.read(focusSessionControllerProvider);

  Future<String> start(FocusTimingMode mode,
      {int plannedSeconds = 25 * 60}) async {
    final session = await controller().startSession(
      userId: userId,
      plannedSeconds: plannedSeconds,
      mode: FocusMode.focus,
      timingMode: mode,
      taskName: '写产品方案',
    );
    return session.id;
  }

  /// Moves the clock and lets the display ticker run, the way wall time does.
  Future<void> elapse(WidgetTester tester, Duration duration) async {
    clock.advance(duration);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  testWidgets('a 番茄钟 still ends itself at the target', (tester) async {
    final id = await start(FocusTimingMode.countdown, plannedSeconds: 60);

    await elapse(tester, const Duration(seconds: 30));
    expect(state().isCompleted, isFalse, reason: 'half way is not finished');
    expect(state().remainingSeconds, 30);

    await elapse(tester, const Duration(seconds: 30));
    expect(state().isCompleted, isTrue,
        reason: 'the countdown reaching zero is still what ends a 番茄钟');

    await controller().saveSession();
    final record = await db.focusRecordDao.findBySessionId(id);
    expect(record!.timingMode, FocusTimingMode.countdown);
    expect(record.durationSeconds, 60);
  });

  testWidgets('正计时 is never ended by the ticker', (tester) async {
    final id = await start(FocusTimingMode.countUp);

    // Far past the length a countdown would have had.
    await elapse(tester, const Duration(minutes: 50));
    expect(state().isCompleted, isFalse,
        reason: 'a mode with no target has nothing to reach');
    expect(state().session!.status, FocusSessionStatus.running);
    expect(state().remainingSeconds, 0, reason: 'and nothing left to show');
    expect(state().elapsedSeconds, 50 * 60);
    expect(state().isCountingUp, isTrue);

    // It ends when the user says so.
    await controller().completeSession();
    await controller().saveSession();
    final record = await db.focusRecordDao.findBySessionId(id);
    expect(record!.timingMode, FocusTimingMode.countUp);
    expect(record.durationSeconds, 50 * 60);
  });

  testWidgets('深度专注 runs, refuses to pause, and records its whole length',
      (tester) async {
    final id = await start(FocusTimingMode.deepFocus);

    await elapse(tester, const Duration(minutes: 10));
    await expectLater(controller().pauseSession(), throwsA(isA<StateError>()));
    expect(state().session!.status, FocusSessionStatus.running);

    await elapse(tester, const Duration(minutes: 80));
    expect(state().isCompleted, isFalse);

    await controller().completeSession();
    await controller().saveSession();
    final record = await db.focusRecordDao.findBySessionId(id);
    expect(record!.timingMode, FocusTimingMode.deepFocus);
    expect(record.durationSeconds, 90 * 60,
        reason: 'no pause happened, so nothing is subtracted');
  });

  testWidgets('switching modes mid-session keeps the time already focused',
      (tester) async {
    final id = await start(FocusTimingMode.countdown, plannedSeconds: 50 * 60);

    await elapse(tester, const Duration(minutes: 20));
    expect(state().remainingSeconds, 30 * 60);

    await controller().setTimingMode(FocusTimingMode.countUp);
    await tester.pump();

    expect(state().timingMode, FocusTimingMode.countUp);
    expect(state().isCountingUp, isTrue);
    expect(state().elapsedSeconds, 20 * 60,
        reason: 'the twenty minutes already focused are not a setting');
    expect(state().remainingSeconds, 0);

    await elapse(tester, const Duration(minutes: 15));
    expect(state().isCompleted, isFalse);

    await controller().completeSession();
    await controller().saveSession();
    final record = await db.focusRecordDao.findBySessionId(id);
    expect(record!.timingMode, FocusTimingMode.countUp,
        reason: 'the record says how the session ended up counting');
    expect(record.durationSeconds, 35 * 60,
        reason: 'switching modes must not cost the user their time');
  });

  testWidgets('a countdown that becomes 深度专注 can no longer be paused',
      (tester) async {
    await start(FocusTimingMode.countdown);
    await elapse(tester, const Duration(minutes: 5));

    await controller().setTimingMode(FocusTimingMode.deepFocus);
    await tester.pump();

    expect(state().timingMode, FocusTimingMode.deepFocus);
    expect(state().session!.plannedSeconds, 0);
    await expectLater(controller().pauseSession(), throwsA(isA<StateError>()));

    await controller().cancelSession();
  });

  testWidgets('a session restored from disk keeps its mode', (tester) async {
    final id = await start(FocusTimingMode.deepFocus);
    await elapse(tester, const Duration(minutes: 20));

    // A fresh container over the same database is what a relaunch looks like.
    final reopened = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(clock),
    ]);
    addTearDown(reopened.dispose);

    final restored = await reopened
        .read(focusSessionControllerProvider.notifier)
        .restoreSession(userId);

    expect(restored, isNotNull);
    expect(restored!.id, id);
    final restoredState = reopened.read(focusSessionControllerProvider);
    expect(restoredState.timingMode, FocusTimingMode.deepFocus);
    expect(restoredState.isCountingUp, isTrue);
    expect(restoredState.isCompleted, isFalse,
        reason: 'a 深度专注 session has no target to have expired');
    expect(restoredState.elapsedSeconds, 20 * 60);

    await reopened
        .read(focusSessionControllerProvider.notifier)
        .cancelSession();
    // The first container's controller is still holding a display ticker for the
    // session it started; the test ends with it pending otherwise.
    await controller().cancelSession();
  });
}

class _TestClock implements FocusClock {
  _TestClock(this._now);
  DateTime _now;

  void advance(Duration by) => _now = _now.add(by);

  @override
  DateTime now() => _now;
}
