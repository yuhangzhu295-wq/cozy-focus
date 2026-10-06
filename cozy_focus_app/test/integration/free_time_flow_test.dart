import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide
        Task,
        TaskSubtask,
        TaskSchedule,
        FocusSession,
        FocusRecord,
        RestSession;
import 'package:cozy_focus_app/domain/models/rest_session.dart';
import 'package:cozy_focus_app/domain/models/timeline_entry.dart';
import 'package:cozy_focus_app/domain/repositories/i_rest_repository.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/controllers/rest_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/timeline_controller.dart';
import 'package:cozy_focus_app/presentation/pages/rest_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// P8 Gate — Golden Flow C, on the real screen and the real database.
///
/// `首页 放松一下 -> choose 10 minutes -> the pet rests -> the rest runs out ->
/// the timeline has a rest row`.
///
/// ## Why the page is pumped rather than driven by the controller
///
/// The controller's own tests prove the lifecycle. What this adds is that the
/// button on the screen starts the rest, that the screen asks the pet to rest, and
/// that the row the timeline reads is the row the screen wrote — the three seams
/// the phase introduces.
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

  IRestRepository repo() => container.read(restRepositoryProvider);

  Widget app() {
    final router = GoRouter(
      initialLocation: '/rest',
      routes: [
        GoRoute(path: '/rest', builder: (context, state) => const RestPage()),
        GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('home'))),
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

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
  }

  /// Pumps fixed frames: the companion's idle animation repeats forever, so
  /// `pumpAndSettle` never returns on this screen.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the whole flow leaves a real rest behind', (tester) async {
    await pump(tester);

    // ── the screen offers the design's four lengths ─────────────────────────
    expect(find.text('休息一下'), findsOneWidget);
    expect(find.text('这次休息多久？'), findsOneWidget);
    for (final minutes in RestSession.presets) {
      expect(find.byKey(ValueKey('rest_preset_$minutes')), findsOneWidget,
          reason: '$minutes');
    }

    // ── choose 10 and start ─────────────────────────────────────────────────
    await tester.tap(find.byKey(const ValueKey('rest_preset_10')));
    await settle(tester);
    await tester.tap(find.text('开始休息'));
    await settle(tester);

    expect(find.text('休息中'), findsOneWidget);
    expect(find.text('10 分钟'), findsOneWidget,
        reason: 'ten minutes is what is left at the start');

    final running = await repo().findRunning(userId);
    expect(running, isNotNull);
    expect(running!.plannedSeconds, 600);
    expect(running.status, RestStatus.running);

    // ── the rest runs out ───────────────────────────────────────────────────
    clock.advance(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    expect(find.text('休息结束'), findsOneWidget);
    final finished = await repo().findById(running.id);
    expect(finished!.status, RestStatus.completed);
    expect(finished.endAt, clock.now());

    // ── and the timeline has the row ────────────────────────────────────────
    final day = DateTime(2026, 10, 8);
    final entries = await container.read(dayTimelineProvider(day).future);

    expect(entries, hasLength(1));
    expect(entries.single.kind, TimelineKind.rest);
    expect(entries.single.title, '休息一下');
    expect(entries.single.clock, '14:00');
    expect(entries.single.durationSeconds, 10 * 60);
    expect(entries.single.isRunning, isFalse);
  });

  testWidgets('ending a rest early is a rest that still happened',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('rest_preset_30')));
    await settle(tester);
    await tester.tap(find.text('开始休息'));
    await settle(tester);

    clock.advance(const Duration(minutes: 4));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.text('26 分钟'), findsOneWidget);

    await tester.tap(find.text('结束休息'));
    await settle(tester);

    // The screen goes back to the chooser, and the rest is a row.
    expect(find.text('这次休息多久？'), findsOneWidget);
    final sessions = await repo().findBetween(
      userId,
      DateTime(2026, 10, 8),
      DateTime(2026, 10, 9),
    );
    expect(sessions, hasLength(1));
    expect(sessions.single.status, RestStatus.cancelled);
    expect(sessions.single.elapsedSecondsAt(clock.now()), 4 * 60);

    final entries =
        await container.read(dayTimelineProvider(DateTime(2026, 10, 8)).future);
    expect(entries.single.detail, '4 分钟 · 提前结束',
        reason:
            'the timeline says the rest was cut short rather than hiding it');
  });

  testWidgets('a running rest is the highlighted row on the timeline',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('开始休息'));
    await settle(tester);

    clock.advance(const Duration(minutes: 3));
    await tester.pump(const Duration(seconds: 1));

    final entries =
        await container.read(dayTimelineProvider(DateTime(2026, 10, 8)).future);
    expect(entries.single.isRunning, isTrue);
    expect(entries.single.title, '休息中');
    expect(entries.single.detail, '已休息 3 分钟');

    await container
        .read(restControllerProvider.notifier)
        .finish(completed: false);
    container.read(restControllerProvider.notifier).dismiss();
  });

  testWidgets('the chooser is back after a rest, ready for another',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('开始休息'));
    await settle(tester);
    await tester.tap(find.text('结束休息'));
    await settle(tester);

    // A second rest is a new row, not a continuation of the first.
    await tester.tap(find.text('开始休息'));
    await settle(tester);
    expect(find.text('休息中'), findsOneWidget);

    final sessions = await repo().findBetween(
      userId,
      DateTime(2026, 10, 8),
      DateTime(2026, 10, 9),
    );
    expect(sessions, hasLength(2));

    await container
        .read(restControllerProvider.notifier)
        .finish(completed: false);
    container.read(restControllerProvider.notifier).dismiss();
  });
}

class _TestClock implements FocusClock {
  _TestClock(this._now);
  DateTime _now;

  void advance(Duration by) => _now = _now.add(by);

  @override
  DateTime now() => _now;
}
