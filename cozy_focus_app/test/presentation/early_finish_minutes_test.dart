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

/// The running screen said two different numbers for the same elapsed time.
///
/// ## The P32 §31A question, reproduced
///
/// A session ended at a displayed 已经专注了 30 分钟 credited 29:55 — five seconds
/// under the rug's 1800-second recipe, so the craft sat at 29/30 and needed a
/// second session. The note asked for the exact cause before deciding whether it
/// was a defect or a product question about grace.
///
/// The cause is not in the settlement. The settlement is exact: 1795 seconds in,
/// 1795 seconds out, and `29 分钟` worth of coins. The cause is that **this one
/// screen rounds the same quantity twice, in opposite directions**:
///
/// - the running page's own label: `(elapsedSeconds / 60).floor()` → 29 分钟
/// - the early-finish dialog: `(elapsedSeconds / 60).ceil()` → 30 分钟
///
/// So the dialog promises a whole minute the user has not focused. The authority
/// is `RewardService.settle`, which pays `(elapsedSeconds / 60).floor()` minutes
/// — 29 here — and the completion screen beside it prints 29:55. The dialog was
/// the only thing saying 30.
///
/// Whether a 1800-second recipe should accept 1795 seconds of focus is still the
/// owner's call. That the app should not tell the user they have done 30 minutes
/// when it is about to credit 29 is not.
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

  /// Starts a 30-minute countdown and leaves it 5 seconds short.
  Future<void> pumpAtFiveSecondsShort(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await container.read(focusSessionControllerProvider.notifier).startSession(
          userId: userId,
          plannedSeconds: 30 * 60,
          mode: FocusMode.focus,
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

    // 1795 seconds: the elapsed the P30 walk settled at.
    clock.advance(const Duration(seconds: 1795));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    final state = container.read(focusSessionControllerProvider);
    expect(state.elapsedSeconds, 1795);
    expect(state.remainingSeconds, 5,
        reason: 'the countdown has not reached its target yet');
  }

  testWidgets('the dialog does not promise a minute the reward will not pay',
      (tester) async {
    await pumpAtFiveSecondsShort(tester);

    final early = find.text('提前结束');
    await tester.ensureVisible(early);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(early);
    await tester.pump(const Duration(milliseconds: 400));

    // And the dialog that asks whether to stop. Both are on this screen, about
    // this session, at this instant.
    expect(find.text('提前结束专注吗？'), findsOneWidget);
    // `RewardService` pays (1795 / 60).floor() == 29 minutes. The dialog must
    // agree with the reward it is about to settle, not round past it.
    expect(
      find.textContaining('已经专注了 29 分钟'),
      findsOneWidget,
    );
    expect(
      find.textContaining('已经专注了 30 分钟'),
      findsNothing,
      reason: '30 minutes is what the settlement is about to refuse: 1795 '
          'seconds is five short of the 1800-second recipe',
    );

    await container
        .read(focusSessionControllerProvider.notifier)
        .cancelSession();
  });

  testWidgets('and it does not round a session up to a whole minute',
      (tester) async {
    // 59 seconds is 0 whole minutes by the settlement's own arithmetic, so that
    // is what the dialog says.
    await container.read(focusSessionControllerProvider.notifier).startSession(
          userId: userId,
          plannedSeconds: 30 * 60,
          mode: FocusMode.focus,
        );
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
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
    clock.advance(const Duration(seconds: 59));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    final early = find.text('提前结束');
    await tester.ensureVisible(early);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(early);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('已经专注了 0 分钟'), findsOneWidget);
    expect(find.textContaining('已经专注了 1 分钟'), findsNothing);

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
