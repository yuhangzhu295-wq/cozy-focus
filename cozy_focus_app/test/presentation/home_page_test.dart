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
        DistractionNote;
import 'package:cozy_focus_app/domain/models/task.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/home_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/current_task_card.dart';
import 'package:cozy_focus_app/presentation/widgets/hourly_focus_chart.dart';

/// The home page, against a real database.
///
/// ## Why this file did not exist until now
///
/// The home page is the app's front door and had **no widget test at all**. That
/// is how it could be missing an entire element the design draws — the
/// current-task card — without a single test noticing, and how its duration
/// selector could be drawn in a treatment the design does not use.
///
/// These are the first assertions on it. They cover what the design 01 audit
/// found, so the next person to touch this screen has something to break.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider
          .overrideWithValue(_FixedClock(DateTime(2026, 10, 9, 14, 0))),
      currentUserIdProvider.overrideWithValue('default_user'),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Widget harness() {
    // A fresh router per test: a shared global router leaked its location
    // between tests once already in this project.
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/focus/setup',
          builder: (_, __) => const Scaffold(body: Text('setup')),
        ),
        GoRoute(
          path: '/records',
          builder: (_, __) => const Scaffold(body: Text('records')),
        ),
        GoRoute(
          path: '/records/today',
          builder: (_, __) => const Scaffold(body: Text('today plan')),
        ),
        GoRoute(
          path: '/rest',
          builder: (_, __) => const Scaffold(body: Text('rest')),
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

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1080 / 411;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(harness());
    // Fixed frames rather than settling: the companion's idle animation repeats
    // forever, so `pumpAndSettle` never returns on this screen.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  group('the duration selector', () {
    testWidgets('is named the way the design names it', (tester) async {
      await pumpHome(tester);

      expect(find.text('选择专注时长'), findsOneWidget);
      expect(find.text('专注时长'), findsNothing);
    });

    testWidgets('gives every card a leaf', (tester) async {
      await pumpHome(tester);

      // Four lengths, four leaves. The design puts one above each number; the
      // screen used to draw none.
      expect(
        find.byIcon(Icons.eco_rounded),
        findsNWidgets(4),
      );
    });

    testWidgets('draws the chosen one solid, with its number in white',
        (tester) async {
      await pumpHome(tester);

      final chosen = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('25'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(chosen.color, AppColors.durationSelected);

      final number = tester.widget<Text>(find.text('25'));
      expect(number.style?.color, Colors.white);
    });

    testWidgets('leaves the unchosen ones on the page surface', (tester) async {
      await pumpHome(tester);

      final other = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('50'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(other.color, AppColors.surface);

      final number = tester.widget<Text>(find.text('50'));
      expect(number.style?.color, AppColors.textPrimary);
    });
  });

  group('the 放松一下 row', () {
    testWidgets('is its own row, not a second button in the focus card',
        (tester) async {
      await pumpHome(tester);

      // The old treatment was an outlined button with the same label and
      // nothing else, sitting inside the focus card at 开始专注's width — which
      // made resting look like a second way to start focusing. The design's row
      // carries a subtitle and a chevron, and those are what tell the two apart.
      expect(find.text('放松一下'), findsOneWidget);
      expect(find.text('累了就休息一会儿吧'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
    });

    testWidgets('sits below the card that holds 开始专注', (tester) async {
      await pumpHome(tester);

      final startButton = tester.getRect(find.text('开始专注'));
      final restRow = tester.getRect(find.text('放松一下'));

      expect(
        restRow.top,
        greaterThan(startButton.bottom),
        reason: 'the design puts it in its own card below 今天的专注',
      );
    });

    testWidgets('leads to the rest screen', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('放松一下'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('rest'), findsOneWidget);
    });
  });

  group('the cards design 01 draws', () {
    testWidgets('carries the hourly distribution', (tester) async {
      await pumpHome(tester);

      expect(find.byType(HourlyFocusChart), findsOneWidget);
      // The axis is the design's.
      for (final hour in const [6, 9, 12, 15, 18, 21]) {
        expect(find.text('$hour'), findsWidgets, reason: '$hour');
      }
    });

    testWidgets('shows no current-task card when nothing is planned',
        (tester) async {
      await pumpHome(tester);

      expect(find.byType(CurrentTaskCard), findsNothing);
    });

    testWidgets('says zero rather than nothing when the day is empty',
        (tester) async {
      await pumpHome(tester);

      expect(find.text('0 分钟'), findsOneWidget);
      expect(find.text('完成 0 次专注'), findsOneWidget);
    });

    testWidgets('the session belongs to the task the card names',
        (tester) async {
      // The card above the timer names a task, so a session started from that
      // same screen belongs to it. It used to start with no task at all, under
      // the generic name '专注任务' — found by walking the first-use flow on a
      // device and reading the row it wrote: the card said '当前任务 first-task'
      // and the record's `task_id` was null, so the task's own totals never moved.
      final tasks = container.read(taskRepositoryProvider);
      await tasks.insert(Task(
        id: 'task-1',
        userId: 'default_user',
        title: 'first-task',
        estimatedSeconds: 25 * 60,
        createdAt: DateTime(2026, 10, 9, 9),
      ));
      await tasks.schedule(
        taskId: 'task-1',
        userId: 'default_user',
        startAt: DateTime(2026, 10, 9, 20),
        plannedSeconds: 25 * 60,
      );

      await pumpHome(tester);
      expect(find.text('first-task'), findsOneWidget,
          reason: 'the card names the task before the timer starts');

      await tester.tap(find.text('开始专注'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      final session = container.read(focusSessionControllerProvider).session;
      expect(session, isNotNull);
      expect(session!.taskId, 'task-1');
      expect(session.taskName, 'first-task');

      // The session is still running, and its ticker outlives the widget tree.
      await container
          .read(focusSessionControllerProvider.notifier)
          .cancelSession();
    });
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
