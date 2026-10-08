import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart' hide FocusSession;
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/focus_active_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// The running screen's ring, which the design draws and the app did not have.
///
/// ## Found by comparing the 16 designs against the screens
///
/// Reference 04 puts the timer inside a large thin ring with a sprout on top, and
/// the annotation calls it the screen's main visual. The app drew the number
/// alone — the largest single difference on that page. The ring drains with what
/// is left, so a full ring at the start reads as "all of it still to go".
///
/// An open-ended mode has no fraction to draw, and passing one would invent a
/// target the user never set, so it gets the track alone. That is the case worth
/// a test: `remaining == null` is a decision, not an absence.
void main() {
  late AppDatabase db;
  late _TestClock clock;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _TestClock(DateTime(2026, 10, 8, 9));
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(clock),
      currentUserIdProvider.overrideWithValue('default_user'),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> startAndPump(
    WidgetTester tester, {
    required int plannedSeconds,
    FocusTimingMode mode = FocusTimingMode.countdown,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await container.read(focusSessionControllerProvider.notifier).startSession(
          userId: 'default_user',
          plannedSeconds: plannedSeconds,
          mode: FocusMode.focus,
          timingMode: mode,
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const FocusActivePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  double? ringRemaining(WidgetTester tester) =>
      tester.widget<FocusTimerRing>(find.byType(FocusTimerRing)).remaining;

  testWidgets('a countdown starts with the whole ring', (tester) async {
    await startAndPump(tester, plannedSeconds: 25 * 60);

    expect(find.byType(FocusTimerRing), findsOneWidget);
    expect(ringRemaining(tester), 1.0,
        reason: 'nothing has been spent yet, so all of it is still to go');

    await container
        .read(focusSessionControllerProvider.notifier)
        .cancelSession();
  });

  testWidgets('and drains as the target is used up', (tester) async {
    await startAndPump(tester, plannedSeconds: 25 * 60);

    // Halfway: ten of twenty minutes.
    clock.advance(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));

    expect(ringRemaining(tester), closeTo(0.6, 0.01),
        reason: '15 of 25 minutes left');
    expect(find.text('15:00'), findsOneWidget);

    await container
        .read(focusSessionControllerProvider.notifier)
        .cancelSession();
  });

  testWidgets('an open-ended mode draws no fraction', (tester) async {
    // 正计时 has no target, so a ring with a fraction would imply one.
    await startAndPump(
      tester,
      plannedSeconds: 0,
      mode: FocusTimingMode.countUp,
    );

    expect(find.byType(FocusTimerRing), findsOneWidget);
    expect(ringRemaining(tester), isNull);

    await container
        .read(focusSessionControllerProvider.notifier)
        .cancelSession();
  });

  testWidgets('a paused session says so, on the ring', (tester) async {
    await startAndPump(tester, plannedSeconds: 25 * 60);
    await container
        .read(focusSessionControllerProvider.notifier)
        .pauseSession();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('已暂停'), findsOneWidget);

    await container
        .read(focusSessionControllerProvider.notifier)
        .cancelSession();
  });
}

class _TestClock implements FocusClock {
  _TestClock(this._now);
  DateTime _now;

  void advance(Duration by) => _now = _now.add(by);

  @override
  DateTime now() => _now;
}
