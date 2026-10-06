import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide
        Task,
        TaskSubtask,
        TaskSchedule,
        FocusSession,
        FocusRecord,
        RestSession;
import 'package:cozy_focus_app/domain/models/rest_session.dart';
import 'package:cozy_focus_app/domain/repositories/i_rest_repository.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/controllers/rest_controller.dart';

/// P8 — a rest, from the button to the row.
///
/// ## What is being pinned
///
/// That a rest is a real fact with a real length, that it is not a focus session
/// wearing a different hat, and that the pet's resting state follows the rest
/// rather than being set by the screen on its own.
void main() {
  late AppDatabase db;
  late _TestClock clock;
  late ProviderContainer container;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _TestClock(DateTime(2026, 10, 8, 14));
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

  RestController rest() => container.read(restControllerProvider.notifier);
  RestUIState state() => container.read(restControllerProvider);
  IRestRepository repo() => container.read(restRepositoryProvider);

  testWidgets('starting writes a running rest', (tester) async {
    final session = await rest().start(10);

    expect(session.plannedSeconds, 600);
    expect(session.status, RestStatus.running);
    expect(session.endAt, isNull);
    expect(session.startAt, clock.now());

    final stored = await repo().findById(session.id);
    expect(stored, isNotNull);
    expect(stored!.plannedSeconds, 600);
    expect(stored.isRunning, isTrue);

    // A running rest holds a one-second display ticker; a test that ends with it
    // pending fails the harness rather than the assertion.
    rest().dismiss();
  });

  testWidgets('the pet rests while the rest runs and not before',
      (tester) async {
    expect(state().petShouldRest, isFalse);

    await rest().start(10);
    expect(state().petShouldRest, isTrue,
        reason: 'the screen asks for the pet state; the animation layer only '
            'expresses what it is given');

    rest().dismiss();
  });

  testWidgets('the countdown is the timestamps, not the ticker',
      (tester) async {
    await rest().start(10);

    clock.advance(const Duration(minutes: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(state().elapsedSeconds, 3 * 60);
    expect(state().remainingSeconds, 7 * 60);

    // No ticker fires at all here, and the answer is still right.
    clock.advance(const Duration(minutes: 2));
    expect(state().session!.elapsedSecondsAt(clock.now()), 5 * 60);
    expect(state().session!.remainingSecondsAt(clock.now()), 5 * 60);

    rest().dismiss();
  });

  testWidgets('a rest that reaches its length ends itself', (tester) async {
    final session = await rest().start(5);
    clock.advance(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));

    final stored = await repo().findById(session.id);
    expect(stored!.status, RestStatus.completed);
    expect(stored.endAt, clock.now());
    expect(state().isResting, isFalse);
    expect(state().petShouldRest, isFalse);
  });

  testWidgets('ending early keeps the time it actually lasted', (tester) async {
    final session = await rest().start(30);
    clock.advance(const Duration(minutes: 4));
    await tester.pump(const Duration(seconds: 1));

    final ended = await rest().finish(completed: false);

    expect(ended!.status, RestStatus.cancelled);
    expect(ended.endAt, clock.now());
    expect(ended.elapsedSecondsAt(clock.now()), 4 * 60,
        reason: 'a rest ended early is still a rest that happened');
    expect((await repo().findById(session.id))!.status, RestStatus.cancelled);
  });

  testWidgets('only one rest runs at a time', (tester) async {
    final first = await rest().start(10);
    clock.advance(const Duration(minutes: 2));
    final second = await rest().start(30);

    expect(second.id, first.id,
        reason: 'a second rest would leave the first with no end time');
    expect(second.plannedSeconds, 600);

    rest().dismiss();
  });

  testWidgets('a rest survives the app being closed', (tester) async {
    final session = await rest().start(15);
    clock.advance(const Duration(minutes: 6));

    // A fresh container over the same database is what a relaunch looks like.
    final reopened = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(clock),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
    addTearDown(reopened.dispose);

    await reopened.read(restControllerProvider.notifier).restore();
    final restored = reopened.read(restControllerProvider);

    expect(restored.session!.id, session.id);
    expect(restored.isResting, isTrue);
    expect(restored.elapsedSeconds, 6 * 60);
    expect(restored.remainingSeconds, 9 * 60);

    // Both containers have a ticker for this rest; both are released.
    await reopened.read(restControllerProvider.notifier).finish();
    rest().dismiss();
  });

  testWidgets('a rest does not touch focus totals', (tester) async {
    await rest().start(10);
    clock.advance(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));

    // The point of its own table: resting is not focusing, and a rest must not
    // appear in any focus total.
    final day = DateTime(2026, 10, 8);
    expect(
      await db.focusRecordDao.findByDateRange(userId,
          from: day, to: day.add(const Duration(days: 1))),
      isEmpty,
    );
    expect(
        await repo().totalSecondsBetween(
          userId,
          day,
          day.add(const Duration(days: 1)),
        ),
        10 * 60);
  });

  testWidgets('the total counts rests that ended and not the one running',
      (tester) async {
    final day = DateTime(2026, 10, 8);
    final next = day.add(const Duration(days: 1));

    await rest().start(10);
    clock.advance(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(await repo().totalSecondsBetween(userId, day, next), 600);

    await rest().start(30);
    clock.advance(const Duration(minutes: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(await repo().totalSecondsBetween(userId, day, next), 600,
        reason: 'a rest still running has not finished being a fact');

    await rest().finish(completed: false);
    expect(await repo().totalSecondsBetween(userId, day, next), 600 + 180);
  });

  testWidgets('dismissing clears the screen without deleting the rest',
      (tester) async {
    final session = await rest().start(10);
    clock.advance(const Duration(minutes: 2));
    await tester.pump(const Duration(seconds: 1));
    await rest().finish(completed: false);

    rest().dismiss();

    expect(state().session, isNull);
    expect(state().isResting, isFalse);
    expect(await repo().findById(session.id), isNotNull,
        reason: 'the row stays; only the screen was reset');
  });

  group('the model', () {
    test('offers the four lengths the design shows', () {
      expect(RestSession.presets, [5, 10, 15, 30]);
      expect(RestSession.defaultMinutes, 10);
    });

    test('a backwards clock is zero, not a crash', () {
      final session = RestSession(
        id: 'r1',
        userId: userId,
        plannedSeconds: 600,
        startAt: DateTime(2026, 10, 8, 14),
        createdAt: DateTime(2026, 10, 8, 14),
      );
      expect(session.elapsedSecondsAt(DateTime(2026, 10, 8, 13)), 0);
      expect(session.remainingSecondsAt(DateTime(2026, 10, 8, 13)), 600);
    });

    test('a finished rest has no remaining time', () {
      final session = RestSession(
        id: 'r1',
        userId: userId,
        plannedSeconds: 600,
        startAt: DateTime(2026, 10, 8, 14),
        endAt: DateTime(2026, 10, 8, 14, 3),
        status: RestStatus.cancelled,
        createdAt: DateTime(2026, 10, 8, 14),
      );
      expect(session.remainingSecondsAt(DateTime(2026, 10, 8, 15)), isNull);
      expect(session.elapsedSecondsAt(DateTime(2026, 10, 8, 15)), 3 * 60,
          reason: 'a closed rest reads its own end time');
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
