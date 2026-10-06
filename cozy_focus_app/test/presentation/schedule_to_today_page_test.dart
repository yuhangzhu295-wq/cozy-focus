import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule;
import 'package:cozy_focus_app/data/repositories/drift_task_repository.dart';
import 'package:cozy_focus_app/domain/models/task.dart';
import 'package:cozy_focus_app/domain/models/task_schedule.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/controllers/today_plan_controller.dart';
import 'package:cozy_focus_app/presentation/pages/schedule_to_today_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// P2 — 安排到今日计划, against a real database.
///
/// ## What these tests are for
///
/// The form has four inputs and one write. The risk is not that it renders; it is
/// that the write does not use the values on screen, or that the defaults are
/// invented rather than derived. So every assertion here ends at the database or
/// at the value the screen shows, never at "the button was tapped".
void main() {
  late AppDatabase db;
  late DriftTaskRepository repo;
  late _FixedClock clock;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _FixedClock(DateTime(2026, 10, 7, 8));
    repo = DriftTaskRepository(db.taskDao, clock: clock);
  });

  tearDown(() async => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(clock),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Widget app(ProviderContainer c, String taskId) {
    final router = GoRouter(
      initialLocation: '/records/tasks/$taskId/schedule',
      routes: [
        GoRoute(
          path: '/records/tasks/:id/schedule',
          builder: (context, state) =>
              ScheduleToTodayPage(taskId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/records/tasks/:id',
          builder: (context, state) =>
              Scaffold(body: Text('detail:${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/records/today',
          builder: (context, state) => const Scaffold(body: Text('today plan')),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester,
    ProviderContainer c,
    String taskId,
  ) async {
    await tester.pumpWidget(app(c, taskId));
    await tester.pump();
    // Two queries now: the slots for the day, and the placement this task may
    // already have on it. The second decides what the save button says and does,
    // so the form is not usable until it answers.
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 80));
  }

  Future<String> task({
    String title = '写产品方案',
    String? note,
    String? category,
    int minutes = 25,
  }) async {
    const id = 'task_1';
    await repo.insert(Task(
      id: id,
      userId: userId,
      title: title,
      categoryId: category,
      note: note,
      estimatedSeconds: minutes * 60,
      createdAt: DateTime(2026, 10, 7, 7),
    ));
    return id;
  }

  group('a task already planned for the day', () {
    testWidgets('opens on the placement it has, and offers to update it',
        (tester) async {
      final id = await task(minutes: 25);
      await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );

      final c = container();
      await pump(tester, c, id);

      // Prefilled from the row that exists, not from the clock: the form used to
      // open on the next half hour and offer to add a second placement.
      expect(find.text('09'), findsOneWidget);
      expect(find.text('00'), findsOneWidget);
      expect(find.text('更新计划'), findsOneWidget,
          reason: 'the button has to say what it will do');
      expect(find.text('添加到今日计划'), findsNothing);
      expect(find.text('这一天已经有安排，保存后会更新原来的时间。'), findsOneWidget);
    });

    testWidgets('saving moves the placement instead of doing nothing',
        (tester) async {
      final id = await task(minutes: 25);
      await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );

      final c = container();
      await pump(tester, c, id);

      // Scrolled to first: the note this screen adds when the task is already
      // planned pushes the chips down, and a tap on an off-screen widget lands
      // nowhere — which reads as "the update did nothing".
      await tester.ensureVisible(find.text('1 小时'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 小时'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('更新计划'));
      await tester.pumpAndSettle();

      final day = await repo.schedulesForDay(userId, '2026-10-07');
      expect(day, hasLength(1),
          reason: 'an update must not add a second placement');
      expect(day.single.schedule.plannedSeconds, 60 * 60,
          reason:
              'before this the save returned the existing row and discarded '
              'the values on screen');
      expect(day.single.schedule.startAt, DateTime(2026, 10, 7, 9),
          reason: 'the time it already had is kept unless the user changes it');
    });

    testWidgets('another day is still an add, not an update', (tester) async {
      final id = await task(minutes: 25);
      await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );

      final c = container();
      await pump(tester, c, id);
      expect(find.text('更新计划'), findsOneWidget);

      // The form is for today; a task planned for tomorrow has no placement on
      // today and the button has to say so.
      await c.read(todayPlanControllerProvider.notifier).showDay(
            DateTime(2026, 10, 8),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });
  });

  testWidgets('shows the task it is placing, with its note', (tester) async {
    final id = await task(note: '梳理核心功能', category: 'work');
    final c = container();
    await pump(tester, c, id);

    expect(find.text('安排到今日计划'), findsOneWidget);
    expect(find.text('写产品方案'), findsOneWidget);
    expect(find.text('梳理核心功能'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
  });

  testWidgets('the default start is the next half hour, not an invented time',
      (tester) async {
    final id = await task();
    final c = container();
    await pump(tester, c, id);

    // The clock is 08:00, so the form opens on 08:30.
    expect(find.text('08'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('今天 10 月 7 日 · 周三'), findsOneWidget);
  });

  testWidgets('the default length is the task estimate', (tester) async {
    final id = await task(minutes: 40);
    final c = container();
    await pump(tester, c, id);

    // 40 is one of the presets, so it shows as a selected chip.
    expect(find.text('40 分钟'), findsOneWidget);
    expect(find.text('1 小时'), findsOneWidget);
    expect(find.text('自定义'), findsOneWidget);
  });

  testWidgets('推荐时段 comes from the day and a tap moves the start time',
      (tester) async {
    final id = await task();
    final other = await task(title: '健身', minutes: 60);
    await repo.schedule(
      taskId: other,
      userId: userId,
      startAt: DateTime(2026, 10, 7, 9),
      plannedSeconds: 60 * 60,
    );

    final c = container();
    await pump(tester, c, id);

    // 09:00 is taken by 健身, so the first free slot is 08:30 and 10:00 must be
    // offered — a recommendation that ignored the day would offer 09:00.
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('09:00'), findsNothing);

    await tester.tap(find.text('10:00'));
    await tester.pumpAndSettle();
    expect(find.text('10'), findsOneWidget);
    expect(find.text('00'), findsOneWidget);
  });

  testWidgets('the chips choose the length that gets saved', (tester) async {
    final id = await task();
    final c = container();
    await pump(tester, c, id);

    await tester.tap(find.text('1 小时'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加到今日计划'));
    await tester.pumpAndSettle();

    final day = await repo.schedulesForDay(userId, '2026-10-07');
    expect(day.single.schedule.plannedSeconds, 60 * 60,
        reason: 'the chip that was on screen has to be the number that landed');
    expect(day.single.schedule.startAt, DateTime(2026, 10, 7, 8, 30));
    expect(day.single.schedule.taskId, id);
    expect(day.single.schedule.date, '2026-10-07');
    expect(day.single.schedule.status, TaskScheduleStatus.planned);
  });

  testWidgets('saving pops with the placement id', (tester) async {
    // The create screen and the detail screen both use the returned id to know
    // the write happened; a form that saved and stayed put would leave the user
    // on a form for something already scheduled.
    final id = await task();
    final c = container();
    await pump(tester, c, id);

    await tester.tap(find.text('添加到今日计划'));
    await tester.pumpAndSettle();

    expect(await repo.schedulesForDay(userId, '2026-10-07'), hasLength(1));
  });

  testWidgets('a custom length outside the range is refused, not clamped',
      (tester) async {
    final id = await task();
    final c = container();
    await pump(tester, c, id);

    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('时长需要在 1 到 600 分钟之间。'), findsOneWidget);
    expect(find.text('自定义'), findsOneWidget,
        reason: 'the length is unchanged, so the chip is still the unselected '
            'custom one');
  });

  testWidgets('a custom length in range is used', (tester) async {
    final id = await task();
    final c = container();
    await pump(tester, c, id);

    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '75');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('1 小时 15 分钟'), findsOneWidget);

    await tester.tap(find.text('添加到今日计划'));
    await tester.pumpAndSettle();
    final day = await repo.schedulesForDay(userId, '2026-10-07');
    expect(day.single.schedule.plannedSeconds, 75 * 60);
  });

  testWidgets('a task that is gone says so instead of an empty form',
      (tester) async {
    final c = container();
    await pump(tester, c, 'no_such_task');
    expect(find.text('这个任务已经不在了。'), findsOneWidget);
    expect(find.text('添加到今日计划'), findsNothing);
  });

  testWidgets('the task card leads to the task', (tester) async {
    final id = await task();
    final c = container();
    await pump(tester, c, id);

    await tester.tap(find.text('写产品方案'));
    await tester.pumpAndSettle();
    expect(find.text('detail:$id'), findsOneWidget);
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
