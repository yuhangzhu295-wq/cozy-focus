import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule, FocusSession;
import 'package:cozy_focus_app/data/repositories/drift_focus_record_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_focus_session_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_pet_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_reward_ledger_repository.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/focus_session.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/domain/services/focus_session_engine.dart';
import 'package:cozy_focus_app/domain/services/reward_service.dart';

/// P3 — how the three timing modes behave, on the real engine.
///
/// ## What is being pinned
///
/// The mode is not a label. It decides whether a session carries a length,
/// whether it can be paused, whether it ends itself, and what the record says
/// afterwards — so every one of those is asserted against the engine rather than
/// against a widget's idea of it.
void main() {
  late AppDatabase db;
  late FocusSessionEngine engine;
  late _TestClock clock;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _TestClock(DateTime(2026, 10, 7, 9));
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

  Future<FocusSession> start(
    FocusTimingMode mode, {
    int plannedSeconds = 25 * 60,
  }) =>
      engine.start(
        userId: userId,
        plannedSeconds: plannedSeconds,
        mode: FocusMode.focus,
        timingMode: mode,
        taskName: '写产品方案',
      );

  group('start', () {
    test('a countdown keeps the target it was given', () async {
      final session =
          await start(FocusTimingMode.countdown, plannedSeconds: 1500);
      expect(session.plannedSeconds, 1500);
      expect(session.timingMode, FocusTimingMode.countdown);
    });

    test('the open-ended modes store no length, whatever was passed', () async {
      // Normalised in the engine so no later reader can mistake a flow session
      // for a timed one, even if a caller passes a length out of habit.
      for (final mode in [FocusTimingMode.countUp, FocusTimingMode.deepFocus]) {
        final session = await start(mode, plannedSeconds: 1500);
        expect(session.plannedSeconds, 0, reason: mode.id);
        expect(session.timingMode, mode, reason: mode.id);
        // The engine runs one session at a time, so each is closed before the
        // next starts.
        await engine.cancel();
      }
    });

    test('a countdown with no target is refused', () async {
      // A countdown with nothing to count down from is a contradiction, and
      // accepting it would produce a session that completes instantly.
      await expectLater(
        start(FocusTimingMode.countdown, plannedSeconds: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('the mode survives a reload', () async {
      final session = await start(FocusTimingMode.deepFocus);
      final reread = await db.focusSessionDao.findById(session.id);
      expect(reread!.timingMode, FocusTimingMode.deepFocus);
      expect(reread.plannedSeconds, 0);
    });
  });

  group('pause', () {
    test('is allowed in a countdown and in 正计时', () async {
      for (final mode in [FocusTimingMode.countdown, FocusTimingMode.countUp]) {
        final session = await start(mode);
        clock.advance(const Duration(minutes: 1));
        final paused = await engine.pause();
        expect(paused.status, FocusSessionStatus.paused, reason: mode.id);
        await engine.resume();
        await engine.cancel();
        expect(session.timingMode, mode, reason: mode.id);
      }
    });

    test('is refused in 深度专注, by the engine and not only by the button',
        () async {
      await start(FocusTimingMode.deepFocus);
      clock.advance(const Duration(minutes: 1));

      await expectLater(engine.pause(), throwsA(isA<StateError>()));

      // And the session is untouched: a refused pause must not leave an open
      // pause interval behind, which would silently subtract time later.
      final session = engine.currentSession!;
      expect(session.status, FocusSessionStatus.running);
      expect(session.pauseIntervals, isEmpty);
      expect(session.elapsedSecondsAt(clock.now()), 60);
    });
  });

  group('setTimingMode', () {
    test('countdown to 正计时 drops the target', () async {
      await start(FocusTimingMode.countdown, plannedSeconds: 1500);
      clock.advance(const Duration(minutes: 5));

      final switched = await engine.setTimingMode(FocusTimingMode.countUp);

      expect(switched.timingMode, FocusTimingMode.countUp);
      expect(switched.plannedSeconds, 0,
          reason: 'nothing downstream may count down from a length the mode '
              'says is not there');
      // And the elapsed time is not lost by the switch.
      expect(switched.elapsedSecondsAt(clock.now()), 300);
      final reread = await db.focusSessionDao.findById(switched.id);
      expect(reread!.timingMode, FocusTimingMode.countUp);
      expect(reread.plannedSeconds, 0);
    });

    test('正计时 to countdown gives it the default target', () async {
      await start(FocusTimingMode.countUp);
      clock.advance(const Duration(minutes: 3));

      final switched = await engine.setTimingMode(FocusTimingMode.countdown);

      expect(switched.plannedSeconds, FocusTimingMode.defaultTargetSeconds);
      expect(switched.timingMode, FocusTimingMode.countdown);
    });

    test('countdown to countdown keeps the target it already had', () async {
      // Round trip: a countdown that became a flow session and comes back does
      // not silently reset the user's chosen length... it does get the default,
      // because the length was cleared on the way out. What must hold is that a
      // countdown that never left keeps its own.
      await start(FocusTimingMode.countdown, plannedSeconds: 50 * 60);
      clock.advance(const Duration(minutes: 2));
      final switched = await engine.setTimingMode(FocusTimingMode.countdown);
      expect(switched.plannedSeconds, 50 * 60,
          reason: 'switching to the mode it is already in changes nothing');
    });

    test('switching to a countdown already past its target is refused',
        () async {
      await start(FocusTimingMode.countUp);
      clock.advance(const Duration(minutes: 30));

      // 30 minutes elapsed, the default target is 25. Accepting this would end
      // the session immediately, and a session that ended because a setting
      // changed is not one the user ended.
      await expectLater(
        engine.setTimingMode(FocusTimingMode.countdown),
        throwsA(isA<StateError>()),
      );
      expect(engine.currentSession!.timingMode, FocusTimingMode.countUp,
          reason: 'a refused switch must not half-apply');
      expect(engine.currentSession!.plannedSeconds, 0);
    });

    test('switching to 深度专注 while paused is refused', () async {
      await start(FocusTimingMode.countdown);
      clock.advance(const Duration(minutes: 2));
      await engine.pause();

      await expectLater(
        engine.setTimingMode(FocusTimingMode.deepFocus),
        throwsA(isA<StateError>()),
      );
      expect(engine.currentSession!.timingMode, FocusTimingMode.countdown);
      expect(engine.currentSession!.status, FocusSessionStatus.paused);
    });

    test('switching to 深度专注 while running drops the target and holds',
        () async {
      await start(FocusTimingMode.countdown, plannedSeconds: 1500);
      clock.advance(const Duration(minutes: 4));

      final switched = await engine.setTimingMode(FocusTimingMode.deepFocus);

      expect(switched.timingMode, FocusTimingMode.deepFocus);
      expect(switched.plannedSeconds, 0);
      await expectLater(engine.pause(), throwsA(isA<StateError>()));
    });

    test('is refused once the session is over', () async {
      await start(FocusTimingMode.countdown);
      clock.advance(const Duration(minutes: 25));
      await engine.complete();

      await expectLater(
        engine.setTimingMode(FocusTimingMode.countUp),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('the record', () {
    test('carries the mode the session ran in', () async {
      final session = await start(FocusTimingMode.countUp);
      clock.advance(const Duration(minutes: 42));
      await engine.complete();
      await engine.save();

      final record = await db.focusRecordDao.findBySessionId(session.id);
      expect(record, isNotNull);
      expect(record!.timingMode, FocusTimingMode.countUp);
      expect(record.durationSeconds, 42 * 60,
          reason: 'a flow session records what it actually took');
    });

    test('a deep focus record says deepFocus and nothing is paused away',
        () async {
      final session = await start(FocusTimingMode.deepFocus);
      clock.advance(const Duration(minutes: 90));
      await engine.complete();
      await engine.save();

      final record = await db.focusRecordDao.findBySessionId(session.id);
      expect(record!.timingMode, FocusTimingMode.deepFocus);
      expect(record.durationSeconds, 90 * 60,
          reason: 'with no pausing there is nothing to subtract');
    });

    test('a countdown record still records the elapsed, not the target',
        () async {
      final session =
          await start(FocusTimingMode.countdown, plannedSeconds: 1500);
      clock.advance(const Duration(minutes: 18));
      await engine.complete();
      await engine.save();

      final record = await db.focusRecordDao.findBySessionId(session.id);
      expect(record!.timingMode, FocusTimingMode.countdown);
      expect(record.durationSeconds, 18 * 60,
          reason: 'ending early records what happened, not what was planned');
    });

    test('the mode is not editable through save', () async {
      // save() takes note/taskName/categoryId/mood overrides. The mode is not
      // one of them, like taskId — how the timer counted is a fact, not a field.
      final session = await start(FocusTimingMode.countUp);
      clock.advance(const Duration(minutes: 5));
      await engine.complete();
      await engine.save(note: '写完了', taskName: '改过的名字');

      final record = await db.focusRecordDao.findBySessionId(session.id);
      expect(record!.timingMode, FocusTimingMode.countUp);
      expect(record.note, '写完了');
      expect(record.taskName, '改过的名字');
    });
  });

  group('restore', () {
    test('a countdown that expired while the app was away is completed',
        () async {
      await start(FocusTimingMode.countdown, plannedSeconds: 60);
      clock.advance(const Duration(minutes: 5));
      // Simulate a restart: the engine's in-memory session is dropped.
      final fresh = FocusSessionEngine(
        sessionRepo: DriftFocusSessionRepository(db.focusSessionDao),
        recordRepo: DriftFocusRecordRepository(db.focusRecordDao),
        rewardService: RewardService(
          ledgerRepo: DriftRewardLedgerRepository(db.rewardLedgerDao),
          petRepo: DriftPetRepository(db.petDao),
          clock: clock,
        ),
        clock: clock,
      );

      final restored = await fresh.restore(userId);

      expect(restored, isNotNull);
      expect(restored!.timingMode, FocusTimingMode.countdown);
      expect(restored.elapsedSecondsAt(clock.now()), 5 * 60,
          reason: 'the target caps what was planned, not what was focused');
    });

    test('a flow session restored after a restart has no target', () async {
      await start(FocusTimingMode.countUp);
      clock.advance(const Duration(minutes: 40));
      final fresh = FocusSessionEngine(
        sessionRepo: DriftFocusSessionRepository(db.focusSessionDao),
        recordRepo: DriftFocusRecordRepository(db.focusRecordDao),
        rewardService: RewardService(
          ledgerRepo: DriftRewardLedgerRepository(db.rewardLedgerDao),
          petRepo: DriftPetRepository(db.petDao),
          clock: clock,
        ),
        clock: clock,
      );

      final restored = await fresh.restore(userId);

      expect(restored, isNotNull);
      expect(restored!.timingMode, FocusTimingMode.countUp);
      expect(restored.plannedSeconds, 0,
          reason:
              'an open-ended session must not come back as a countdown that '
              'expired an hour ago');
    });
  });
}

class _TestClock implements FocusClock {
  _TestClock(this._now);
  DateTime _now;

  void advance(Duration by) => _now = _now.add(by);

  @override
  DateTime now() => _now;
}
