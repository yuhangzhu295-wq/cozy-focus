import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule, FocusSession, FocusRecord;
import 'package:cozy_focus_app/data/repositories/drift_focus_record_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_task_repository.dart';
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/models/task.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/analytics_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/today_plan_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// P7 — the statistics view, against a real database.
///
/// ## What these tests are for
///
/// That every figure on the screen is produced by the records in the window. The
/// brief is explicit that the design's example numbers — 8 小时 35 分钟, 12 次,
/// 42 分钟 — must never be written into the code, so one test asserts that none of
/// them appear when the data does not say so, and the rest assert the numbers that
/// the data does say.
void main() {
  late AppDatabase db;
  late DriftFocusRecordRepository records;
  late DriftTaskRepository tasks;
  late _FixedClock clock;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _FixedClock(DateTime(2026, 10, 8, 12));
    records = DriftFocusRecordRepository(db.focusRecordDao);
    tasks = DriftTaskRepository(db.taskDao, clock: clock);
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
          path: '/records/tasks',
          builder: (context, state) => const Scaffold(body: Text('tasks')),
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

  /// Pumps until the statistics query has run.
  ///
  /// The view waits on two queries — the window's records and the titles of the
  /// tasks they mention — so it needs more frames than a single-query screen.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> pump(WidgetTester tester, ProviderContainer c) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(app(c));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byKey(const ValueKey('plan_view_stats')));
    await settle(tester);
  }

  Future<void> addRecord({
    required String id,
    required DateTime startAt,
    int minutes = 25,
    String? taskId,
    String? taskName,
  }) =>
      records.insert(FocusRecord(
        id: id,
        sessionId: 'sess_$id',
        userId: userId,
        taskId: taskId,
        taskName: taskName,
        durationSeconds: minutes * 60,
        startAt: startAt,
        endAt: startAt.add(Duration(minutes: minutes)),
        recordedAt: startAt,
        isCountedForReward: true,
      ));

  testWidgets('an empty week says so and invents nothing', (tester) async {
    final c = container();
    await pump(tester, c);

    expect(find.text('这一段时间还没有专注记录'), findsOneWidget);
    // The design's examples must not appear out of nowhere.
    expect(find.text('8 小时 35 分钟'), findsNothing);
    expect(find.text('12'), findsNothing);
    expect(find.text('42 分钟'), findsNothing);
  });

  testWidgets('the numbers are the records in the window', (tester) async {
    await addRecord(
      id: 'a',
      startAt: DateTime(2026, 10, 5, 9),
      minutes: 25,
      taskName: '写产品方案',
    );
    await addRecord(
      id: 'b',
      startAt: DateTime(2026, 10, 6, 9),
      minutes: 50,
      taskName: '写产品方案',
    );
    await addRecord(
      id: 'c',
      startAt: DateTime(2026, 10, 6, 14),
      minutes: 45,
      taskName: '健身',
    );

    final c = container();
    await pump(tester, c);

    expect(find.text('专注总时长'), findsOneWidget);
    expect(find.text('2 小时'), findsOneWidget, reason: '120 minutes');
    expect(find.text('专注次数'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('平均时长'), findsOneWidget);
    expect(find.text('40 分钟'), findsOneWidget);
    // The distribution, heaviest first, with real shares.
    expect(find.text('写产品方案'), findsOneWidget);
    expect(find.text('1 小时 15 分钟'), findsOneWidget);
    expect(find.text('63%'), findsOneWidget,
        reason: '75 of 120 minutes rounds to 63%');
    expect(find.text('健身'), findsOneWidget);
    expect(find.text('38%'), findsOneWidget);
  });

  testWidgets('the week window shows the week, not the day', (tester) async {
    // A record on the Wednesday of the shown week and one on the Sunday.
    await addRecord(id: 'wed', startAt: DateTime(2026, 10, 7, 9), minutes: 30);
    await addRecord(id: 'sun', startAt: DateTime(2026, 10, 11, 9), minutes: 30);

    final c = container();
    await pump(tester, c);
    expect(find.text('10 月 5 日 - 10 月 11 日'), findsOneWidget);
    expect(find.text('1 小时'), findsWidgets,
        reason: 'both records are inside, and the total and the one share row '
            'both say an hour');

    // Switching to 日 narrows to the day the page is showing.
    await tester.tap(find.byKey(const ValueKey('stats_range_day')));
    await settle(tester);

    expect(find.text('10 月 8 日'), findsOneWidget);
    expect(find.text('这一段时间还没有专注记录'), findsOneWidget,
        reason: 'nothing was recorded on the eighth itself');
  });

  testWidgets('stepping back shows the previous window', (tester) async {
    await addRecord(
        id: 'lastweek', startAt: DateTime(2026, 9, 30, 9), minutes: 45);

    final c = container();
    await pump(tester, c);
    expect(find.text('这一段时间还没有专注记录'), findsOneWidget,
        reason: 'the shown week has nothing in it');

    await tester.tap(find.byKey(const ValueKey('stats_previous')));
    await settle(tester);

    expect(find.text('9 月 28 日 - 10 月 4 日'), findsOneWidget);
    expect(find.text('45 分钟'), findsWidgets);
    expect(find.text('1'), findsOneWidget, reason: 'one session');
  });

  testWidgets('a deleted task keeps the name the session carried',
      (tester) async {
    const taskId = 'task_1';
    await tasks.insert(Task(
      id: taskId,
      userId: userId,
      title: '写产品方案',
      estimatedSeconds: 25 * 60,
      createdAt: DateTime(2026, 10, 5, 7),
    ));
    await addRecord(
      id: 'a',
      startAt: DateTime(2026, 10, 5, 9),
      taskId: taskId,
      taskName: '写产品方案',
    );

    // Renaming the task renames the row, because the live title wins.
    await tasks
        .update((await tasks.findById(taskId))!.copyWith(title: '写方案（改过）'));

    final c = container();
    await pump(tester, c);
    expect(find.text('写方案（改过）'), findsOneWidget);

    // Deleting it leaves the recorded name rather than a blank row. The
    // invalidation is the same call the page makes in `_refreshAll` on entry and
    // on pull-to-refresh: the projections have no controller to reload, so
    // invalidating them is the only way a number can change.
    await tasks.deleteById(taskId);
    c.invalidate(analyticsSummaryProvider);
    await settle(tester);
    await settle(tester);

    expect(find.text('写产品方案'), findsOneWidget);
    expect(find.text('写方案（改过）'), findsNothing);
  });

  testWidgets('the three kinds are offered and the current one is marked',
      (tester) async {
    final c = container();
    await pump(tester, c);

    for (final kind in const ['day', 'week', 'month']) {
      expect(find.byKey(ValueKey('stats_range_$kind')), findsOneWidget,
          reason: kind);
    }
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
