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
import 'package:cozy_focus_app/data/repositories/drift_task_repository.dart';
import 'package:cozy_focus_app/domain/models/task.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/focus_setup_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// Starting focus from a task carried the id and not the name.
///
/// ## Found by walking the plan into a session on a device
///
/// The plan row says 写产品方案, the user taps 开始, and the session calls itself
/// 专注任务: `FocusSetupPage` took a `taskId` and never read the task, so the name
/// field stayed empty and `startSession` was handed the placeholder. The paused
/// screen showed 本次任务：专注任务 and the record kept that name.
///
/// The id travelled, so the time was attributed to the right task — which is why
/// no existing test caught it: the business link was correct and only the words
/// were wrong.
///
/// The category was dropped the same way: it is not chosen on this screen, so
/// without carrying it from the task the record came back as 未分类.
void main() {
  late AppDatabase db;
  late DriftTaskRepository tasks;
  late ProviderContainer container;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tasks = DriftTaskRepository(db.taskDao, clock: _FixedClock());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(_FixedClock()),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> seedTask({String? categoryId}) => tasks.insert(Task(
        id: 't1',
        userId: userId,
        title: '写产品方案',
        categoryId: categoryId,
        estimatedSeconds: 25 * 60,
        createdAt: DateTime(2026, 10, 7, 9),
      ));

  Widget app({String? taskId}) {
    final router = GoRouter(
      initialLocation: '/focus/setup',
      routes: [
        GoRoute(
          path: '/focus/setup',
          builder: (context, state) => FocusSetupPage(taskId: taskId),
        ),
        GoRoute(
          path: '/focus/active',
          builder: (context, state) => const Scaffold(body: Text('active')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('home')),
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

  /// Fixed frames: the companion's idle animation repeats forever, so
  /// `pumpAndSettle` never returns on this screen.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('the name field is prefilled from the task', (tester) async {
    await seedTask();
    await tester.pumpWidget(app(taskId: 't1'));
    await settle(tester);

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, '写产品方案',
        reason: 'the plan row names the task; the session has to as well');
  });

  testWidgets('and starting the session keeps it, with the category',
      (tester) async {
    await seedTask(categoryId: 'work');
    await tester.pumpWidget(app(taskId: 't1'));
    await settle(tester);

    await tester.ensureVisible(find.text('开始专注'));
    await settle(tester);
    await tester.tap(find.text('开始专注'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final session = container.read(focusSessionControllerProvider).session;
    expect(session, isNotNull);
    expect(session!.taskName, '写产品方案',
        reason: 'the paused screen and the record both read this');
    expect(session.taskId, 't1');
    expect(session.categoryId, 'work',
        reason: 'without it, time on a 工作 task comes back as 未分类');

    // A running session holds a one-second display ticker, and a test that ends
    // with it pending fails the harness rather than the assertion.
    await container
        .read(focusSessionControllerProvider.notifier)
        .cancelSession();
  });

  testWidgets('a session with no task still falls back to the placeholder',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.ensureVisible(find.text('开始专注'));
    await settle(tester);
    await tester.tap(find.text('开始专注'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final session = container.read(focusSessionControllerProvider).session;
    expect(session!.taskName, '专注任务',
        reason:
            'focusing without a task stays a first-class way in, and it has '
            'no name to borrow');
    expect(session.taskId, isNull);

    await container
        .read(focusSessionControllerProvider.notifier)
        .cancelSession();
  });

  testWidgets('a task that is gone does not break the screen', (tester) async {
    await tester.pumpWidget(app(taskId: 'no_such_task'));
    await settle(tester);

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, isEmpty);
    expect(find.text('开始专注'), findsOneWidget);
  });
}

class _FixedClock implements FocusClock {
  @override
  DateTime now() => DateTime(2026, 10, 7, 16, 10);
}
