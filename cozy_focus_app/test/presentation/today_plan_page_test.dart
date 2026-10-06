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
import 'package:cozy_focus_app/presentation/pages/today_plan_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// P2 — the today view, against a real database and a real router.
///
/// ## Why the router is real
///
/// The screen's whole job is to send the user somewhere with the right task: the
/// 开始 button has to reach `/focus/setup` carrying the task id, or a session
/// started from the plan would not count towards the task it was for. A stubbed
/// navigation callback would assert the stub, so this builds a router whose
/// `/focus/setup` route renders the query parameter it received.
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

  Widget app(ProviderContainer c) {
    final router = GoRouter(
      initialLocation: '/records/today',
      routes: [
        GoRoute(
          path: '/records/today',
          builder: (context, state) => const TodayPlanPage(),
        ),
        GoRoute(
          path: '/focus/setup',
          builder: (context, state) => Scaffold(
            body: Text('setup:${state.uri.queryParameters['taskId']}'),
          ),
        ),
        GoRoute(
          path: '/records/tasks',
          builder: (context, state) => const Scaffold(body: Text('task list')),
        ),
        GoRoute(
          path: '/records/tasks/:id',
          builder: (context, state) =>
              Scaffold(body: Text('detail:${state.pathParameters['id']}')),
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

  Future<void> pump(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(app(c));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  var seqCounter = 0;

  Future<String> task(String title,
      {int minutes = 25, String? category}) async {
    final id = 'task_${seqCounter++}';
    await repo.insert(Task(
      id: id,
      userId: userId,
      title: title,
      categoryId: category,
      estimatedSeconds: minutes * 60,
      createdAt: DateTime(2026, 10, 7, 7),
    ));
    return id;
  }

  Future<void> place(
    String taskId, {
    required int hour,
    int minutes = 25,
    int day = 7,
  }) =>
      repo.schedule(
        taskId: taskId,
        userId: userId,
        startAt: DateTime(2026, 10, day, hour),
        plannedSeconds: minutes * 60,
      );

  testWidgets('an empty day says so and offers the way to fill it',
      (tester) async {
    final c = container();
    await pump(tester, c);

    expect(find.text('今天还没有安排'), findsOneWidget);
    expect(find.text('去安排任务'), findsOneWidget);

    await tester.tap(find.text('去安排任务'));
    await tester.pumpAndSettle();
    expect(find.text('task list'), findsOneWidget);
  });

  testWidgets('the plan is drawn in time order with the time and length',
      (tester) async {
    final later = await task('健身', minutes: 40, category: 'life');
    final earlier = await task('写产品方案', category: 'work');
    await place(later, hour: 14, minutes: 40);
    await place(earlier, hour: 9);

    final c = container();
    await pump(tester, c);

    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('14:00'), findsOneWidget);
    expect(find.text('写产品方案'), findsWidgets);
    expect(find.text('25 分钟'), findsWidgets);
    expect(find.text('40 分钟'), findsOneWidget);
    expect(find.text('工作'), findsWidgets);
    expect(find.text('生活'), findsWidgets);
  });

  testWidgets('下一个任务 is the earliest still-planned placement', (tester) async {
    final first = await task('写产品方案');
    final second = await task('熟悉阅读', minutes: 50);
    await place(second, hour: 10);
    await place(first, hour: 9);

    final c = container();
    await pump(tester, c);

    // The card's title is the earliest one, and it is on screen twice: once in
    // the card and once in the list below it.
    expect(find.text('下一个任务'), findsOneWidget);
    expect(find.text('写产品方案'), findsNWidgets(2));
  });

  testWidgets('开始 carries the task into the focus flow', (tester) async {
    final id = await task('写产品方案');
    await place(id, hour: 9);

    final c = container();
    await pump(tester, c);

    await tester.tap(find.text('开始'));
    await tester.pumpAndSettle();

    expect(find.text('setup:$id'), findsOneWidget,
        reason: 'without the id the session cannot count towards the task');
  });

  testWidgets('a finished placement leaves the card empty', (tester) async {
    final id = await task('写产品方案');
    await place(id, hour: 9);
    final placement = (await repo.schedulesForDay(userId, '2026-10-07')).single;
    await repo.updateSchedule(
      placement.schedule.copyWith(status: TaskScheduleStatus.done),
    );

    final c = container();
    await pump(tester, c);

    expect(find.text('下一个任务'), findsNothing,
        reason: 'a finished task is not the next thing to do');
    expect(find.text('写产品方案'), findsOneWidget,
        reason: 'and it is still on the day');
  });

  testWidgets('the timeline segment draws the same placements', (tester) async {
    final id = await task('写产品方案');
    await place(id, hour: 9);

    final c = container();
    await pump(tester, c);
    expect(find.byKey(const ValueKey('plan_view_timeline')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan_view_timeline')));
    await tester.pumpAndSettle();

    expect(find.text('写产品方案'), findsNWidgets(2),
        reason: 'card plus row: the segment changes the layout, not the data');
    expect(find.text('09:00'), findsOneWidget);
  });

  testWidgets('long press offers finishing it, and finishing writes through',
      (tester) async {
    final id = await task('写产品方案');
    await place(id, hour: 9);

    final c = container();
    await pump(tester, c);

    await tester.longPress(find.text('09:00'));
    await tester.pumpAndSettle();
    expect(find.text('标记为已完成'), findsOneWidget);
    expect(find.text('从今日移除'), findsOneWidget);

    await tester.tap(find.text('标记为已完成'));
    await tester.pumpAndSettle();

    final reread = await repo.schedulesForDay(userId, '2026-10-07');
    expect(reread.single.schedule.status, TaskScheduleStatus.done,
        reason: 'the sheet has to write, not only close');
  });

  testWidgets('removing takes it off the day without deleting the task',
      (tester) async {
    final id = await task('写产品方案');
    await place(id, hour: 9);

    final c = container();
    await pump(tester, c);

    await tester.longPress(find.text('09:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从今日移除'));
    await tester.pumpAndSettle();

    expect(await repo.schedulesForDay(userId, '2026-10-07'), isEmpty);
    expect(await repo.findById(id), isNotNull);
    expect(find.text('今天还没有安排'), findsOneWidget);
  });

  testWidgets('tapping a row opens the task', (tester) async {
    final id = await task('写产品方案');
    await place(id, hour: 9);

    final c = container();
    await pump(tester, c);

    await tester.tap(find.text('09:00'));
    await tester.pumpAndSettle();
    expect(find.text('detail:$id'), findsOneWidget);
  });

  testWidgets('the header names the day the clock says it is', (tester) async {
    final c = container();
    await pump(tester, c);
    expect(find.text('10 月 7 日 · 周三'), findsOneWidget);
  });
}

/// A clock the test sets by hand, so "today" is a fixed day rather than the day
/// the suite happens to run on.
class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
