import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask;
import 'package:cozy_focus_app/data/repositories/drift_task_repository.dart';
import 'package:cozy_focus_app/domain/models/task.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/task_list_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// P1 — the task list screen, against a real database.
///
/// ## What a widget test can prove here that the domain tests cannot
///
/// That the screen shows what is stored. The domain tests prove a row exists;
/// these prove a user sees it, sees the right empty state when there is nothing,
/// and that tapping the tick writes through rather than only changing a colour.
void main() {
  late AppDatabase db;
  late DriftTaskRepository repo;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftTaskRepository(db.taskDao);
  });

  tearDown(() async => db.close());

  Widget app(ProviderContainer container) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const TaskListPage(),
        ),
      );

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> pump(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(app(c));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  testWidgets('an empty list says so per tab, not generically', (tester) async {
    final c = container();
    await pump(tester, c);

    // The 今天 tab is the default, and its empty state is about today.
    expect(find.text('今天还没有安排'), findsOneWidget);

    await tester.tap(find.text('已完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    // A different tab says something true about *that* tab.
    expect(find.text('还没有完成的任务'), findsOneWidget);
    expect(find.text('今天还没有安排'), findsNothing);
  });

  testWidgets('a stored task appears with its category and duration',
      (tester) async {
    await repo.insert(Task(
      id: 't1',
      userId: userId,
      title: '写产品方案',
      categoryId: 'work',
      estimatedSeconds: 25 * 60,
      createdAt: DateTime(2026, 10, 7, 9),
    ));

    await pump(tester, container());

    expect(find.text('写产品方案'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
    expect(find.text('25 分钟'), findsOneWidget);
  });

  testWidgets('tapping the tick marks it done and moves it to that tab',
      (tester) async {
    await repo.insert(Task(
      id: 't1',
      userId: userId,
      title: '写产品方案',
      createdAt: DateTime(2026, 10, 7, 9),
    ));
    await pump(tester, container());
    expect(find.text('写产品方案'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.radio_button_unchecked));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    // It left the open list, because the filter says it is not there any more.
    expect(find.text('写产品方案'), findsNothing);
    // And the database agrees, which is the part that matters.
    expect((await repo.findById('t1'))!.isDone, isTrue);

    await tester.tap(find.text('已完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('写产品方案'), findsOneWidget);
  });

  testWidgets('the plus button is a real action, not decoration',
      (tester) async {
    // It has to be enabled and reachable. What it does is a navigation this
    // widget test cannot follow without a router; the create screen has its own
    // tests. An IconButton with no onPressed would be the fake control the
    // brief forbids, and this asserts it is not one.
    await pump(tester, container());

    final plus = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.add_circle),
    );
    expect(plus.onPressed, isNotNull);
  });

  testWidgets('the filter tabs announce which one is active', (tester) async {
    await pump(tester, container());

    // A screen reader user has to know which list they are looking at, and the
    // active one has to say it is active rather than only looking different.
    // Addressed by key rather than by label, because the tab's prose also
    // appears in the empty state underneath it.
    final today =
        tester.getSemantics(find.byKey(const ValueKey('task_filter_today')));
    expect(today.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(today.hasFlag(SemanticsFlag.isButton), isTrue);

    for (final id in const ['active', 'done']) {
      final other =
          tester.getSemantics(find.byKey(ValueKey('task_filter_$id')));
      expect(other.hasFlag(SemanticsFlag.isSelected), isFalse, reason: id);
      expect(other.hasFlag(SemanticsFlag.isButton), isTrue, reason: id);
    }
  });

  testWidgets('the duration reads the way the design writes it',
      (tester) async {
    // Three shapes, one function: minutes, whole hours, and hours with minutes.
    expect(formatTaskDuration(25 * 60), '25 分钟');
    expect(formatTaskDuration(60 * 60), '1 小时');
    expect(formatTaskDuration(75 * 60), '1 小时 15 分钟');
    expect(formatTaskDuration(0), '未设置');
  });
}
