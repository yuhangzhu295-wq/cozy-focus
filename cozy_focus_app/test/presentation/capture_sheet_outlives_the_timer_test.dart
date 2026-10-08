import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide FocusSession, DistractionNote;
import 'package:cozy_focus_app/domain/models/distraction_note.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/focus_active_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// A thought typed into the capture sheet must survive the timer running out.
///
/// ## Found by walking the flow on a device
///
/// The sheet is deliberately a sheet so that capturing a thought costs no focus
/// time. But the completion navigation is a `go`, which replaces the route stack
/// and takes the sheet down with it — so a countdown that expired while the user
/// was still writing closed the sheet and discarded the text. On the device the
/// note simply never appeared in the inbox, and nothing in the suite noticed
/// because every existing test drove the sheet on its own, with no session
/// ticking underneath it.
void main() {
  late AppDatabase db;
  late _TestClock clock;
  late ProviderContainer container;

  const userId = 'default_user';
  const target = 90;

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

  /// A router with the two routes the flow actually visits, so "did it navigate
  /// away" is a question about the route rather than about a widget's absence.
  Widget app() {
    final router = GoRouter(
      initialLocation: '/focus/active',
      routes: [
        GoRoute(
          path: '/focus/active',
          builder: (context, state) => const FocusActivePage(),
        ),
        GoRoute(
          path: '/focus/complete',
          builder: (context, state) =>
              const Scaffold(body: Text('completion screen')),
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

  /// Pumps a few frames. The companion's idle animation repeats forever, so
  /// `pumpAndSettle` would never return.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> startAndOpenSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await container.read(focusSessionControllerProvider.notifier).startSession(
          userId: userId,
          plannedSeconds: target,
          mode: FocusMode.focus,
        );
    await tester.pumpWidget(app());
    await settle(tester);

    final capture = find.text('记一下');
    await tester.ensureVisible(capture);
    await settle(tester);
    await tester.tap(capture);
    await settle(tester);

    expect(find.text('分心收集箱'), findsOneWidget);
  }

  /// Lets the countdown reach its target and the display ticker notice.
  Future<void> letTheTimerExpire(WidgetTester tester) async {
    clock.advance(const Duration(seconds: target + 1));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
  }

  Future<List<DistractionNote>> notes() =>
      db.distractionDao.findByFilter(userId, DistractionFilter.all);

  testWidgets('the sheet stays open when the countdown expires under it',
      (tester) async {
    await startAndOpenSheet(tester);
    await tester.enterText(find.byType(TextField), '买充电线');
    await tester.pump();

    await letTheTimerExpire(tester);

    expect(find.text('分心收集箱'), findsOneWidget,
        reason: 'the user was still writing; the thought is not cancelled '
            'just because the timer finished');
    expect(find.text('completion screen'), findsNothing);

    // Let the tree go before the test ends: the page owns a one-second
    // heartbeat and a test that ends with it pending fails the harness.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the thought is saved, then the flow moves on', (tester) async {
    await startAndOpenSheet(tester);
    await tester.enterText(find.byType(TextField), '买充电线');
    await tester.pump();
    await letTheTimerExpire(tester);

    await tester.tap(find.text('记下，继续专注'));
    await settle(tester);

    final saved = await notes();
    expect(saved, hasLength(1),
        reason: 'the ordering must not decide whether the note exists');
    expect(saved.single.text, '买充电线');
    expect(saved.single.sessionId, isNotNull,
        reason: 'it interrupted a real session and still says which');
    expect(find.text('completion screen'), findsOneWidget,
        reason: 'the session is over, so the sheet hands over to the summary');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('closing without saving still moves on', (tester) async {
    await startAndOpenSheet(tester);
    await letTheTimerExpire(tester);

    await tester.tap(find.byKey(const ValueKey('distraction_close')));
    await settle(tester);

    expect(await notes(), isEmpty);
    expect(find.text('completion screen'), findsOneWidget,
        reason: 'the deferred navigation must not be lost when nothing is '
            'saved');

    await tester.pumpWidget(const SizedBox());
  });
}

class _TestClock implements FocusClock {
  _TestClock(this._now);
  DateTime _now;

  void advance(Duration by) => _now = _now.add(by);

  @override
  DateTime now() => _now;
}
