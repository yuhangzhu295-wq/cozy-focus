import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cozy_focus_app/data/local/app_database.dart' hide FocusSession;
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/focus_active_page.dart';
import 'package:cozy_focus_app/presentation/pages/focus_setup_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// P3 — the mode control on both screens.
///
/// ## What a widget test adds here
///
/// The engine tests prove the rules. These prove the screens are wired to them:
/// that the choice reaches the database rather than only the segment's colour,
/// that the display follows the mode, and that the pause control in 深度专注 says
/// why it is unavailable instead of being live and then refused.
void main() {
  late AppDatabase db;
  late _TestClock clock;
  late ProviderContainer container;

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

  /// Pumps a few frames instead of `pumpAndSettle`.
  ///
  /// Both focus screens carry the companion, whose idle animation repeats
  /// forever, so `pumpAndSettle` never returns. Fixed frames are enough: every
  /// state change here is a rebuild, not a transition to wait out.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  void setScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget app(Widget child) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.lightTheme, home: child),
      );

  Widget routedApp() {
    final router = GoRouter(
      initialLocation: '/focus/setup',
      routes: [
        GoRoute(
          path: '/focus/setup',
          builder: (context, state) => const FocusSetupPage(),
        ),
        GoRoute(
          path: '/focus/active',
          builder: (context, state) => const Scaffold(body: Text('active')),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }

  Future<void> pumpSetup(WidgetTester tester) async {
    setScreenSize(tester);
    await tester.pumpWidget(routedApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  Future<void> chooseMode(WidgetTester tester, FocusTimingMode mode) async {
    final finder = find.byKey(ValueKey('setup_mode_${mode.id}'));
    await tester.ensureVisible(finder);
    await settle(tester);
    await tester.tap(finder);
    await settle(tester);
  }

  group('the setup screen', () {
    testWidgets('offers the three modes with 番茄钟 chosen', (tester) async {
      await pumpSetup(tester);

      for (final mode in FocusTimingMode.values) {
        expect(find.byKey(ValueKey('setup_mode_${mode.id}')), findsOneWidget,
            reason: mode.id);
        expect(find.text(mode.label), findsWidgets, reason: mode.id);
      }
      final today = tester
          .getSemantics(find.byKey(const ValueKey('setup_mode_countdown')));
      expect(today.hasFlag(SemanticsFlag.isSelected), isTrue);
    });

    testWidgets('the duration chips belong to the countdown only',
        (tester) async {
      await pumpSetup(tester);
      expect(find.text('选择专注时长'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);

      await chooseMode(tester, FocusTimingMode.countUp);
      expect(find.text('选择专注时长'), findsNothing,
          reason: 'a mode with no target must not offer one');
      expect(find.text('50'), findsNothing);
      expect(find.text('不设时长，想专注多久就多久，结束时由你自己收尾。'), findsOneWidget);

      await chooseMode(tester, FocusTimingMode.deepFocus);
      expect(find.text('不设时长，也不能暂停 —— 这一段就是专心不被打断。'), findsOneWidget);

      await chooseMode(tester, FocusTimingMode.countdown);
      expect(find.text('选择专注时长'), findsOneWidget);
    });

    testWidgets('starting a countdown stores the chosen length',
        (tester) async {
      await pumpSetup(tester);

      await tester.ensureVisible(find.text('50'));
      await settle(tester);
      await tester.tap(find.text('50'));
      await settle(tester);

      final start = find.text('开始专注');
      await tester.ensureVisible(start);
      await settle(tester);
      await tester.tap(start);
      await settle(tester);

      final session = container.read(focusSessionControllerProvider).session;
      expect(session, isNotNull);
      expect(session!.timingMode, FocusTimingMode.countdown);
      expect(session.plannedSeconds, 50 * 60);
      final persisted = await db.focusSessionDao.findById(session.id);
      expect(persisted!.timingMode, FocusTimingMode.countdown);
      expect(persisted.plannedSeconds, 50 * 60);

      // A running session holds a one-second display ticker, and a test that
      // ends with it pending fails the harness rather than the assertion.
      await container
          .read(focusSessionControllerProvider.notifier)
          .cancelSession();
    });

    testWidgets('starting 正计时 stores no length at all', (tester) async {
      await pumpSetup(tester);
      await chooseMode(tester, FocusTimingMode.countUp);

      final start = find.text('开始专注');
      await tester.ensureVisible(start);
      await settle(tester);
      await tester.tap(start);
      await settle(tester);

      final session = container.read(focusSessionControllerProvider).session;
      expect(session!.timingMode, FocusTimingMode.countUp);
      expect(session.plannedSeconds, 0,
          reason: 'the choice has to reach the database, not only the segment');
      final persisted = await db.focusSessionDao.findById(session.id);
      expect(persisted!.timingMode, FocusTimingMode.countUp);
      expect(persisted.plannedSeconds, 0);

      await container
          .read(focusSessionControllerProvider.notifier)
          .cancelSession();
    });
  });

  group('the running screen', () {
    Future<void> startAndPump(
      WidgetTester tester,
      FocusTimingMode mode, {
      int plannedSeconds = 25 * 60,
    }) async {
      setScreenSize(tester);
      await container
          .read(focusSessionControllerProvider.notifier)
          .startSession(
            userId: 'default_user',
            plannedSeconds: plannedSeconds,
            mode: FocusMode.focus,
            timingMode: mode,
            taskName: '写产品方案',
          );
      await tester.pumpWidget(app(const FocusActivePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
    }

    testWidgets('shows the mode the session is running in', (tester) async {
      await startAndPump(tester, FocusTimingMode.countdown);

      for (final mode in FocusTimingMode.values) {
        expect(find.byKey(ValueKey('focus_mode_${mode.id}')), findsOneWidget,
            reason: mode.id);
      }
      final active = tester
          .getSemantics(find.byKey(const ValueKey('focus_mode_countdown')));
      expect(active.hasFlag(SemanticsFlag.isSelected), isTrue);

      await container
          .read(focusSessionControllerProvider.notifier)
          .cancelSession();
    });

    testWidgets('switching to 正计时 changes the number and writes the session',
        (tester) async {
      await startAndPump(tester, FocusTimingMode.countdown);
      clock.advance(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));

      // A countdown shows what is left.
      expect(find.text('20:00'), findsOneWidget);

      final target = find.byKey(const ValueKey('focus_mode_countUp'));
      await tester.ensureVisible(target);
      await settle(tester);
      await tester.tap(target);
      await settle(tester);

      // And a flow session shows what has passed.
      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('20:00'), findsNothing);

      final session = container.read(focusSessionControllerProvider).session!;
      expect(session.timingMode, FocusTimingMode.countUp);
      final persisted = await db.focusSessionDao.findById(session.id);
      expect(persisted!.timingMode, FocusTimingMode.countUp);
      expect(persisted.plannedSeconds, 0);

      await container
          .read(focusSessionControllerProvider.notifier)
          .cancelSession();
    });

    testWidgets('深度专注 disables pause and says why', (tester) async {
      await startAndPump(tester, FocusTimingMode.deepFocus);

      expect(find.text('深度专注中'), findsOneWidget);
      expect(find.text('暂停'), findsNothing);

      // The control is a round one now, so the refusal shows up on its gesture
      // rather than on an ElevatedButton's onPressed. The point is unchanged:
      // unavailable, not live and then refused.
      final control = tester.widget<GestureDetector>(
        find
            .ancestor(
              of: find.text('深度专注中'),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(control.onTap, isNull,
          reason: 'the control is unavailable, not live and then refused');

      // And it says so to a screen reader, which is the half a tap test misses.
      final node = tester.getSemantics(find.text('深度专注中'));
      expect(node.label, '深度专注中');
      expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse);

      // And the engine agrees, which is the half a widget test cannot fake.
      await expectLater(
        container.read(focusSessionControllerProvider.notifier).pauseSession(),
        throwsA(isA<StateError>()),
      );

      await container
          .read(focusSessionControllerProvider.notifier)
          .cancelSession();
    });

    testWidgets('a countdown and 正计时 keep a working pause', (tester) async {
      await startAndPump(tester, FocusTimingMode.countUp);
      expect(find.text('暂停'), findsOneWidget);

      await tester.tap(find.text('暂停'));
      await settle(tester);
      expect(container.read(focusSessionControllerProvider).session!.status,
          FocusSessionStatus.paused);
      expect(find.text('继续专注'), findsOneWidget);

      await container
          .read(focusSessionControllerProvider.notifier)
          .cancelSession();
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
