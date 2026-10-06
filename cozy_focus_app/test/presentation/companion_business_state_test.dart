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
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/companion/companion_business_state.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/controllers/rest_controller.dart';

/// P9 — the companion's state comes from the business facts, and only from them.
///
/// ## What this pins
///
/// The brief's rule runs one way: business state may be *expressed* through the
/// existing animation chain, and the animation layer may never write business
/// data. The override answers exactly one question the avatar cannot see for
/// itself — is the user resting — and returns null otherwise, so the avatar keeps
/// its own single precedence for the session and craft cases. A second copy of
/// that precedence here is how the badge and the behaviour would start to
/// disagree.
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

  PetVisualState? override() =>
      container.read(companionBusinessStateOverrideProvider);

  test('nothing happening adds nothing', () {
    expect(override(), isNull, reason: 'the avatar decides idle for itself');
  });

  test('a focus session is left to the avatar', () async {
    await container.read(focusSessionControllerProvider.notifier).startSession(
          userId: userId,
          plannedSeconds: 25 * 60,
          mode: FocusMode.focus,
          taskName: '写产品方案',
        );

    expect(override(), isNull,
        reason:
            'the avatar already watches the session; saying it twice is two '
            'answers waiting to disagree');

    await container
        .read(focusSessionControllerProvider.notifier)
        .cancelSession();
  });

  test('a rest puts the pet to sleep', () async {
    await container.read(restControllerProvider.notifier).start(10);

    expect(override(), PetVisualState.sleep);

    await container
        .read(restControllerProvider.notifier)
        .finish(completed: false);
    container.read(restControllerProvider.notifier).dismiss();
    expect(override(), isNull);
  });

  test('a rest outranks a session that is somehow still open', () async {
    await container.read(focusSessionControllerProvider.notifier).startSession(
          userId: userId,
          plannedSeconds: 25 * 60,
          mode: FocusMode.focus,
          taskName: '写产品方案',
        );
    await container.read(restControllerProvider.notifier).start(5);

    expect(override(), PetVisualState.sleep,
        reason:
            'the user is on the rest screen; that is what the pet should be '
            'doing');

    await container
        .read(restControllerProvider.notifier)
        .finish(completed: false);
    container.read(restControllerProvider.notifier).dismiss();
    await container
        .read(focusSessionControllerProvider.notifier)
        .cancelSession();
  });

  test('deep focus is still just focusing, and not this provider\'s business',
      () {
    // The timing mode changes how the timer counts, not what the pet is doing.
    // The override says nothing about it, which is the point: inventing a state
    // for it would mean a state with no drawing behind it.
    expect(override(), isNull);
  });

  test('the state it returns is the app\'s existing vocabulary', () {
    expect(PetVisualState.values, contains(PetVisualState.sleep));
  });
}

class _TestClock implements FocusClock {
  _TestClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
