import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule;
import 'package:cozy_focus_app/data/repositories/drift_task_repository.dart';
import 'package:cozy_focus_app/domain/repositories/i_task_repository.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/create_task_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// P2 — 加入今日计划 on the create screen.
///
/// ## Why the switch needs its own test
///
/// It was deliberately left out of P1 because a switch with no table behind it
/// would be the fake control the brief forbids. Now that the table exists, the
/// thing to prove is the pair: on means a placement row exists afterwards, off
/// means none does and the task is still findable. A test that only checked the
/// switch's own colour would pass on the version that saved nothing.
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
      initialLocation: '/records/tasks/new',
      routes: [
        GoRoute(
          path: '/records/tasks/new',
          builder: (context, state) => const CreateTaskPage(),
        ),
        GoRoute(
          path: '/records/tasks',
          builder: (context, state) => const Scaffold(body: Text('task list')),
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

  Future<void> fillTitle(WidgetTester tester, String title) async {
    await tester.enterText(find.byType(TextField).first, title);
    await tester.pump();
  }

  testWidgets('the switch is on by default and says when it would land',
      (tester) async {
    await pump(tester, container());

    expect(find.text('加入今日计划'), findsOneWidget);
    // The clock is 08:00, so the honest subtitle names 08:30 — the value the
    // save will actually use, not a generic promise.
    expect(find.text('保存后会自动添加到今天 08:30 的计划里。'), findsOneWidget);
  });

  testWidgets('saving with the switch on writes the task and the placement',
      (tester) async {
    await pump(tester, container());
    await fillTitle(tester, '写产品方案');

    await tester.tap(find.text('保存任务'));
    await tester.pumpAndSettle();

    final tasks = await repo.findByFilter(userId, TaskFilter.active);
    expect(tasks, hasLength(1));
    expect(tasks.single.title, '写产品方案');

    final day = await repo.schedulesForDay(userId, '2026-10-07');
    expect(day, hasLength(1),
        reason: 'the switch promised a placement and has to produce one');
    expect(day.single.title, '写产品方案');
    expect(day.single.schedule.taskId, tasks.single.id);
    expect(day.single.schedule.startAt, DateTime(2026, 10, 7, 8, 30));
    // The length comes from the estimate chip that is on screen.
    expect(day.single.schedule.plannedSeconds, 25 * 60);
  });

  testWidgets(
      'saving with the switch off writes no placement, and the task '
      'is still in 今天', (tester) async {
    await pump(tester, container());
    await fillTitle(tester, '临时想到的事');

    // The switch sits below the fold on a test-sized screen, so it has to be
    // scrolled to before it can be hit. A tap on an off-screen widget silently
    // lands nowhere, which would make this test pass for the wrong reason.
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('只保存任务，稍后再安排时间。'), findsOneWidget);

    await tester.tap(find.text('保存任务'));
    await tester.pumpAndSettle();

    expect(await repo.schedulesForDay(userId, '2026-10-07'), isEmpty,
        reason: 'off has to mean off');
    expect(await repo.findByFilter(userId, TaskFilter.active), hasLength(1));
    // And it is not lost: the today tab's second rule keeps a task written down
    // today with no plan.
    expect(
      (await repo.findByFilter(userId, TaskFilter.today)).map((t) => t.title),
      ['临时想到的事'],
    );
  });

  testWidgets('the chosen estimate is the length that gets planned',
      (tester) async {
    await pump(tester, container());
    await fillTitle(tester, '健身');

    await tester.tap(find.text('40 分钟'));
    await tester.pump();
    await tester.tap(find.text('保存任务'));
    await tester.pumpAndSettle();

    final day = await repo.schedulesForDay(userId, '2026-10-07');
    expect(day.single.schedule.plannedSeconds, 40 * 60);
  });

  testWidgets('an empty title cannot be saved', (tester) async {
    await pump(tester, container());

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存任务'),
    );
    expect(save.onPressed, isNull,
        reason: 'the disabled button is the validation, so it has to be real');

    expect(await repo.findByFilter(userId, TaskFilter.active), isEmpty);
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
