import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';

class MutableTestClock implements FocusClock {
  DateTime _now;
  MutableTestClock(this._now);
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
}

void main() {
  late AppDatabase db;
  late MutableTestClock testClock;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    testClock = MutableTestClock(DateTime(2026, 9, 8, 9, 0, 0));
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider.overrideWithValue(testClock),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Focus Session Controller & Lifecycle Tests', () {
    test('1. Start session creates running session and persists in Drift', () async {
      final controller = container.read(focusSessionControllerProvider.notifier);
      final session = await controller.startSession(
        userId: 'test_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
        taskName: 'Math Homework',
        categoryName: '学习',
      );

      expect(session.status, FocusSessionStatus.running);
      expect(session.plannedSeconds, 1500);

      final persisted = await db.focusSessionDao.findById(session.id);
      expect(persisted, isNotNull);
      expect(persisted!.status, FocusSessionStatus.running);

      final uiState = container.read(focusSessionControllerProvider);
      expect(uiState.session?.id, session.id);
      expect(uiState.petState, PetVisualState.focus);
    });

    test('2. Pause and Resume accumulates pause intervals correctly', () async {
      final controller = container.read(focusSessionControllerProvider.notifier);
      await controller.startSession(
        userId: 'test_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
      );

      // Advance 10 minutes (600s)
      testClock.advance(const Duration(minutes: 10));
      await controller.pauseSession();

      var uiState = container.read(focusSessionControllerProvider);
      expect(uiState.session?.status, FocusSessionStatus.paused);
      expect(uiState.petState, PetVisualState.pause);
      expect(uiState.elapsedSeconds, 600);

      // Pause for 5 minutes (300s)
      testClock.advance(const Duration(minutes: 5));

      // Resume
      await controller.resumeSession();
      uiState = container.read(focusSessionControllerProvider);
      expect(uiState.session?.status, FocusSessionStatus.running);
      expect(uiState.petState, PetVisualState.focus);
      // Immediately upon resume, elapsed is still 600s (excludes pause)
      expect(uiState.elapsedSeconds, 600);

      // Focus another 10 minutes (600s)
      testClock.advance(const Duration(minutes: 10));
      // Trigger complete
      final completed = await controller.completeSession();
      expect(completed.status, FocusSessionStatus.finishing);

      uiState = container.read(focusSessionControllerProvider);
      // Total elapsed should be exactly 20 minutes (1200s), NOT 25 minutes (1500s)
      expect(uiState.elapsedSeconds, 1200);
    });

    test('3. Early finish cancel clears session without creating FocusRecord', () async {
      final controller = container.read(focusSessionControllerProvider.notifier);
      final session = await controller.startSession(
        userId: 'test_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
      );

      testClock.advance(const Duration(minutes: 2));
      await controller.cancelSession();

      final uiState = container.read(focusSessionControllerProvider);
      expect(uiState.session, isNull);

      final record = await db.focusRecordDao.findBySessionId(session.id);
      expect(record, isNull);
    });

    test('4. Complete Session != Saved Record separation', () async {
      final controller = container.read(focusSessionControllerProvider.notifier);
      final session = await controller.startSession(
        userId: 'test_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
      );

      testClock.advance(const Duration(minutes: 25));
      await controller.completeSession();

      // Status is finishing, NOT yet saved
      var uiState = container.read(focusSessionControllerProvider);
      expect(uiState.session?.status, FocusSessionStatus.finishing);

      // No record in DB yet
      var record = await db.focusRecordDao.findBySessionId(session.id);
      expect(record, isNull);

      // Now save with mood and note
      final savedResult = await controller.saveSession(note: '心情: 😊 | 效率很高');
      expect(savedResult.status, FocusSessionStatus.saved);

      uiState = container.read(focusSessionControllerProvider);
      expect(uiState.session, isNull);

      // Now record exists in Drift
      record = await db.focusRecordDao.findBySessionId(session.id);
      expect(record, isNotNull);
      expect(record!.durationSeconds, 1500);
      expect(record.note, contains('心情: 😊'));
    });

    test('5. Reward settlement idempotency rejects duplicate settlement', () async {
      final controller = container.read(focusSessionControllerProvider.notifier);
      final session = await controller.startSession(
        userId: 'test_user',
        plannedSeconds: 1200,
        mode: FocusMode.focus,
      );

      testClock.advance(const Duration(minutes: 20));
      await controller.completeSession();
      await controller.saveSession();

      // First reward ledger entry exists
      final ledger = await db.rewardLedgerDao.findBySessionId(session.id);
      expect(ledger, isNotNull);
      expect(ledger!.experienceEarned, 20 * 5); // 100 XP

      // Settle again on same session ID via repository
      final rewardRepo = container.read(rewardLedgerRepositoryProvider);
      final doubleSettle = await rewardRepo.settleReward(ledger);
      expect(doubleSettle, isFalse, reason: 'Duplicate settlement must be rejected');
    });

    test('6. Home controller aggregates real today focus data from Drift', () async {
      final homeController = container.read(homeControllerProvider.notifier);
      await homeController.loadHomeData();

      var homeState = container.read(homeControllerProvider);
      expect(homeState.todayFocusSeconds, 0);

      // Complete and save a 30-min session
      final sessionController = container.read(focusSessionControllerProvider.notifier);
      await sessionController.startSession(
        userId: HomeController.defaultUserId,
        plannedSeconds: 1800,
        mode: FocusMode.focus,
      );
      testClock.advance(const Duration(minutes: 30));
      await sessionController.completeSession();
      await sessionController.saveSession();

      await homeController.loadHomeData();
      homeState = container.read(homeControllerProvider);
      expect(homeState.todayFocusSeconds, 1800);
      expect(homeState.todayMinutes, 30);
    });

    test('7. App restart / process restore recovers active session from Drift', () async {
      // Simulate session started in previous run
      final sessionController = container.read(focusSessionControllerProvider.notifier);
      final originalSession = await sessionController.startSession(
        userId: 'restore_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
      );

      testClock.advance(const Duration(minutes: 12));

      // Simulate app kill & new container
      final newContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          focusClockProvider.overrideWithValue(testClock),
        ],
      );

      final newController = newContainer.read(focusSessionControllerProvider.notifier);
      final restored = await newController.restoreSession('restore_user');

      expect(restored, isNotNull);
      expect(restored!.id, originalSession.id);
      expect(restored.status, FocusSessionStatus.restored);

      final newUiState = newContainer.read(focusSessionControllerProvider);
      expect(newUiState.elapsedSeconds, 720); // 12 minutes
      expect(newUiState.remainingSeconds, 780); // 25 - 12 = 13 minutes

      newContainer.dispose();
    });

    test('8. Restored session can be completed or cancelled without StateError', () async {
      final sessionController = container.read(focusSessionControllerProvider.notifier);
      await sessionController.startSession(
        userId: 'restore_test_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
      );

      testClock.advance(const Duration(minutes: 10));

      // Simulate app kill & restore
      final newContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          focusClockProvider.overrideWithValue(testClock),
        ],
      );

      final newController = newContainer.read(focusSessionControllerProvider.notifier);
      final restored = await newController.restoreSession('restore_test_user');
      expect(restored, isNotNull);
      expect(restored!.status, FocusSessionStatus.restored);

      // Now complete the restored session
      final completed = await newController.completeSession();
      expect(completed.status, FocusSessionStatus.finishing);

      // Save the record
      final saved = await newController.saveSession(note: 'Restored & saved successfully');
      expect(saved.status, FocusSessionStatus.saved);

      final record = await db.focusRecordDao.findBySessionId(restored.id);
      expect(record, isNotNull);
      expect(record!.durationSeconds, 600);

      newContainer.dispose();
    });
  });
}
