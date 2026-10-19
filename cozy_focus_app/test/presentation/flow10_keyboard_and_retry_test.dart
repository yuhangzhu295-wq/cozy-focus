import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart' hide Task;
import 'package:cozy_focus_app/data/repositories/drift_task_repository.dart';
import 'package:cozy_focus_app/domain/models/task.dart';
import 'package:cozy_focus_app/domain/repositories/i_task_repository.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/navigation/app_router.dart';
import 'package:cozy_focus_app/presentation/pages/task_list_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// FLOW-10's two closable gaps: the soft keyboard, and a failed load.
///
/// Both were listed as PARTIAL because nothing asserted them. They are
/// engineering-closable, so they are closed here rather than left in the
/// matrix as an open question.
class _FixedClock implements FocusClock {
  @override
  DateTime now() => DateTime(2026, 10, 12, 10);
}

/// Fails the first read, then delegates. The point is the retry: an error state
/// that cannot recover is a dead end with a button on it.
class _FlakyTaskRepository extends DriftTaskRepository {
  _FlakyTaskRepository(super.dao, {super.clock});

  int reads = 0;

  @override
  Future<List<Task>> findByFilter(String userId, TaskFilter filter) {
    reads++;
    if (reads == 1) {
      throw StateError('the database was busy');
    }
    return super.findByFilter(userId, filter);
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  ProviderContainer container({ITaskRepository? tasks}) {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(_FixedClock()),
      if (tasks != null) taskRepositoryProvider.overrideWithValue(tasks),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  testWidgets('a failed load says so, and the retry actually recovers',
      (tester) async {
    final repo = _FlakyTaskRepository(db.taskDao, clock: _FixedClock());
    await repo.insert(Task(
      id: 'task_1',
      userId: 'default_user',
      title: '写周报',
      createdAt: DateTime(2026, 10, 12, 9),
    ));
    // insert() does not go through findByFilter, so the first read is still the
    // one the controller makes.
    final c = container(tasks: repo);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child:
          MaterialApp(theme: AppTheme.lightTheme, home: const TaskListPage()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('任务没能读出来'), findsOneWidget);
    expect(find.text('再试一次'), findsOneWidget);
    expect(find.text('写周报'), findsNothing);

    await tester.tap(find.text('再试一次'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('任务没能读出来'), findsNothing,
        reason: 'a successful retry must replace the error, not sit under it');
    expect(find.text('写周报'), findsOneWidget);
  });

  testWidgets('the create-task screen survives the keyboard at 360x800',
      (tester) async {
    // The soft keyboard takes ~300dp off a 360x800 phone. The page has to
    // re-lay-out inside what is left: no overflow, and the save button still
    // reachable rather than pinned under the keyboard.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    final c = container();
    final router = createAppRouter();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ));
    router.go('/records/tasks/new');
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(find.text('任务名称', skipOffstage: false), findsWidgets,
        reason: 'the create-task screen must render with the keyboard up');
    expect(tester.takeException(), isNull,
        reason: 'the keyboard must not overflow the form');

    // The button has to be reachable, not merely built somewhere below the fold.
    final save = find.text('保存任务');
    var seen = save.evaluate().isNotEmpty;
    for (var step = 0; step < 8 && !seen; step++) {
      final scrollable = find.byType(Scrollable).evaluate().isNotEmpty
          ? find.byType(Scrollable).first
          : null;
      if (scrollable == null) break;
      await tester.drag(scrollable, const Offset(0, -400), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 60));
      seen = save.evaluate().isNotEmpty;
    }
    expect(seen, isTrue,
        reason: 'the save button must be reachable with the keyboard open');
    // Reachable means visible above the keyboard, not merely built. The
    // keyboard covers the bottom 300dp, so the button's bottom edge has to sit
    // above y = 500 or the user cannot press it without dismissing the keyboard.
    final rect = tester.getRect(save);
    expect(rect.bottom, lessThanOrEqualTo(500),
        reason:
            'the save button is under the keyboard (bottom ${rect.bottom})');
    expect(tester.takeException(), isNull,
        reason: 'scrolling under the keyboard must not overflow');
  });
}
