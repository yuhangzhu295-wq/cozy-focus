import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule;
import 'package:cozy_focus_app/data/repositories/drift_task_repository.dart';
import 'package:cozy_focus_app/domain/models/task.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/task_detail_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// Screen 12's subtask progress, and the way in to it.
///
/// ## Why this file did not exist before
///
/// The board draws the 任务进度 card with 2 / 3 in it. The card, its rows and
/// `TaskDetailController.addSubtask` were all built and tested — at the
/// repository and domain layers — and **nothing in the app ever called
/// `addSubtask`**. So the card rendered only for data no screen could create:
/// built, correct, and unreachable. No widget test existed for this page at all,
/// which is why that went unnoticed; the page's own comment claimed the bar
/// "counts subtasks that are actually in the database", which was true and
/// useless, because no database could get one.
///
/// Every assertion below therefore ends at the database or at what the screen
/// shows, never at "the row was tapped".
void main() {
  late AppDatabase db;
  late DriftTaskRepository repo;
  late _FixedClock clock;

  const userId = 'default_user';
  const taskId = 'task_1';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _FixedClock(DateTime(2026, 10, 8, 9));
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
      initialLocation: '/records/tasks/$taskId',
      routes: [
        GoRoute(
          path: '/records/tasks/:id',
          builder: (context, state) =>
              TaskDetailPage(taskId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/records/tasks',
          builder: (context, state) => const Scaffold(body: Text('task list')),
        ),
        GoRoute(
          path: '/records/tasks/:id/schedule',
          builder: (context, state) =>
              const Scaffold(body: Text('schedule form')),
        ),
        GoRoute(
          path: '/focus/setup',
          builder: (context, state) =>
              const Scaffold(body: Text('focus setup')),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: c,
      child:
          MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
  }

  Future<void> seedTask() => repo.insert(Task(
        id: taskId,
        userId: userId,
        title: '写产品方案',
        categoryId: 'work',
        estimatedSeconds: 25 * 60,
        createdAt: DateTime(2026, 10, 7, 7),
      ));

  Future<void> pump(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(app(c));
    await tester.pump();
    // The page loads the task, its subtasks and its focus totals, then the
    // schedule. Fixed pumps rather than pumpAndSettle: the companion animation
    // on this app never settles.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// Types a title into the dialog and confirms it.
  Future<void> addSubtask(WidgetTester tester, String title) async {
    await tester.tap(find.text('添加子任务'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), title);
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
  }

  testWidgets('the way in exists even when there is nothing to count',
      (tester) async {
    await seedTask();
    final c = container();
    await pump(tester, c);

    // The entrance has to be here BEFORE there is anything to count: an entrance
    // inside the progress card could never add the first subtask, because the
    // card is hidden until a subtask exists.
    expect(find.text('添加子任务'), findsOneWidget);

    // And the card is still absent, not an empty 0 / 0 bar.
    expect(find.text('任务进度'), findsNothing);
    expect(find.text('0 / 0'), findsNothing);
  });

  testWidgets('adding one writes it, and the card appears counting it',
      (tester) async {
    await seedTask();
    final c = container();
    await pump(tester, c);

    await addSubtask(tester, '整理需求');

    // The database, not the screen, is the claim.
    final rows = await repo.subtasksFor(taskId);
    expect(rows, hasLength(1));
    expect(rows.single.title, '整理需求');
    expect(rows.single.isDone, isFalse);

    // And the screen shows what the database has.
    expect(find.text('任务进度'), findsOneWidget);
    expect(find.text('0 / 1'), findsOneWidget);
    expect(find.text('整理需求'), findsOneWidget);
  });

  testWidgets('a blank title is not a subtask', (tester) async {
    await seedTask();
    final c = container();
    await pump(tester, c);

    await addSubtask(tester, '   ');

    // An unnamed row would move the fraction for nothing and put a blank line in
    // the list, so it must not reach the database at all.
    expect(await repo.subtasksFor(taskId), isEmpty);
    expect(find.text('任务进度'), findsNothing);
  });

  testWidgets('cancelling adds nothing', (tester) async {
    await seedTask();
    final c = container();
    await pump(tester, c);

    await tester.tap(find.text('添加子任务'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '不该被保存');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(await repo.subtasksFor(taskId), isEmpty);
  });

  testWidgets('ticking one moves the fraction, and it comes from the database',
      (tester) async {
    await seedTask();
    final c = container();
    await pump(tester, c);

    await addSubtask(tester, '第一步');
    await addSubtask(tester, '第二步');
    expect(find.text('0 / 2'), findsOneWidget);

    await tester.tap(find.text('第一步'));
    await tester.pumpAndSettle();

    final rows = await repo.subtasksFor(taskId);
    expect(rows.where((r) => r.isDone), hasLength(1),
        reason: 'the tick has to be a write, not a local flag');
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('the note editor saves, and does not read a disposed controller',
      (tester) async {
    await seedTask();
    final c = container();
    await pump(tester, c);

    // This path carried the same defect the subtask prompt surfaced - a
    // TextEditingController disposed the moment `showDialog` returned, while the
    // route was still animating out - and it had no test at all, which is why
    // the subtask prompt was the one that found it.
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '初版包含核心功能与用户流程');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'the dialog must dispose its own controller, not the caller');
    final saved = await repo.findById(taskId);
    expect(saved!.note, '初版包含核心功能与用户流程');
  });
}

class _FixedClock implements FocusClock {
  final DateTime _now;
  _FixedClock(this._now);
  @override
  DateTime now() => _now;
}
