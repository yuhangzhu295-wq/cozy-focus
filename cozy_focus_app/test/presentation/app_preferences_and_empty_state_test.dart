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
import 'package:cozy_focus_app/domain/models/task.dart';
import 'package:cozy_focus_app/domain/repositories/i_task_repository.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/app_preferences_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/create_task_page.dart';
import 'package:cozy_focus_app/presentation/pages/task_list_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// P10 — the default focus length, and the empty state's two ways out.
///
/// ## What these tests are for
///
/// The settings screen had a row that said, in its own subtitle, that the value
/// was not saved. It is saved now, and the assertions go to the database and to the
/// screen that reads it — a preference that only lives in memory is the thing this
/// replaces.
void main() {
  late AppDatabase db;
  late _FixedClock clock;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _FixedClock(DateTime(2026, 10, 8, 9));
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

  Widget app(ProviderContainer c, Widget home) => UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: AppTheme.lightTheme, home: home),
      );

  Widget routedApp(ProviderContainer c) {
    final router = GoRouter(
      initialLocation: '/records/tasks',
      routes: [
        GoRoute(
          path: '/records/tasks',
          builder: (context, state) => const TaskListPage(),
        ),
        GoRoute(
          path: '/records/tasks/new',
          builder: (context, state) => const CreateTaskPage(),
        ),
        GoRoute(
          path: '/focus/setup',
          builder: (context, state) => const Scaffold(body: Text('setup')),
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

  group('the default focus length', () {
    test('starts at the value the create screen already used', () async {
      final c = container();
      await c.read(appPreferencesProvider.notifier).load();
      expect(c.read(appPreferencesProvider).defaultFocusSeconds,
          AppPreferences.fallbackFocusSeconds);
      expect(c.read(defaultTaskEstimateProvider), taskEstimatePresets.first);
    });

    test('is written to the database, not to memory', () async {
      final c = container();
      await c
          .read(appPreferencesProvider.notifier)
          .setDefaultFocusSeconds(40 * 60);

      expect(c.read(appPreferencesProvider).defaultFocusSeconds, 40 * 60);
      expect(await db.settingsDao.read(AppPreferences.defaultFocusKey), '2400');
    });

    test('survives a restart', () async {
      final first = container();
      await first
          .read(appPreferencesProvider.notifier)
          .setDefaultFocusSeconds(50 * 60);

      // A fresh container over the same database is what a relaunch looks like.
      final reopened = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider.overrideWithValue(clock),
        currentUserIdProvider.overrideWithValue(userId),
      ]);
      addTearDown(reopened.dispose);
      await reopened.read(appPreferencesProvider.notifier).load();

      expect(
          reopened.read(appPreferencesProvider).defaultFocusSeconds, 50 * 60);
      expect(reopened.read(defaultTaskEstimateProvider), 50 * 60);
    });

    test('a stored value that is not a length is ignored', () async {
      await db.settingsDao
          .write(AppPreferences.defaultFocusKey, 'not a number');
      final c = container();
      await c.read(appPreferencesProvider.notifier).load();

      expect(c.read(appPreferencesProvider).defaultFocusSeconds,
          AppPreferences.fallbackFocusSeconds,
          reason: 'an unusable value falls back rather than becoming a default '
              'the user never chose');
    });

    test('a value that is not a length cannot be stored', () async {
      final c = container();
      await c.read(appPreferencesProvider.notifier).setDefaultFocusSeconds(0);
      expect(await db.settingsDao.read(AppPreferences.defaultFocusKey), isNull);
    });

    test('resetting clears the row rather than writing the default', () async {
      final c = container();
      await c
          .read(appPreferencesProvider.notifier)
          .setDefaultFocusSeconds(15 * 60);
      await c.read(appPreferencesProvider.notifier).resetDefaultFocusSeconds();

      expect(await db.settingsDao.read(AppPreferences.defaultFocusKey), isNull,
          reason: 'unset is the honest state, not a value that looks chosen');
      expect(c.read(appPreferencesProvider).defaultFocusSeconds,
          AppPreferences.fallbackFocusSeconds);
    });

    testWidgets('the create screen opens on the stored default',
        (tester) async {
      final c = container();
      await c
          .read(appPreferencesProvider.notifier)
          .setDefaultFocusSeconds(50 * 60);

      await tester.pumpWidget(app(c, const CreateTaskPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      // 50 minutes is one of the presets, so it shows as the selected chip and
      // saving with no other change plans for fifty minutes.
      expect(find.text('50 分钟'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '写产品方案');
      await tester.pump();
      await tester.tap(find.text('保存任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final tasks = await c
          .read(taskRepositoryProvider)
          .findByFilter(userId, TaskFilter.active);
      expect(tasks.single.estimatedSeconds, 50 * 60);
    });

    testWidgets('the choice the user makes on the screen wins', (tester) async {
      final c = container();
      await c
          .read(appPreferencesProvider.notifier)
          .setDefaultFocusSeconds(50 * 60);

      await tester.pumpWidget(app(c, const CreateTaskPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      // The default is a starting point, not a lock.
      await tester.tap(find.text('25 分钟'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, '写产品方案');
      await tester.pump();
      await tester.tap(find.text('保存任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final tasks = await c
          .read(taskRepositoryProvider)
          .findByFilter(userId, TaskFilter.active);
      expect(tasks.single.estimatedSeconds, 25 * 60);
    });
  });

  group('the empty state', () {
    testWidgets('offers both ways out, as the design shows', (tester) async {
      final c = container();
      await tester.pumpWidget(routedApp(c));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.text('还没有任务哦～'), findsOneWidget);
      expect(find.byKey(const ValueKey('empty_new_task')), findsOneWidget);
      expect(find.byKey(const ValueKey('empty_start_focus')), findsOneWidget);
    });

    testWidgets('新建任务 leads to the create screen', (tester) async {
      final c = container();
      await tester.pumpWidget(routedApp(c));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      await tester.tap(find.byKey(const ValueKey('empty_new_task')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('新建任务'), findsWidgets);
      expect(find.text('保存任务'), findsOneWidget);
    });

    testWidgets('开始第一次专注 leads to the focus setup', (tester) async {
      final c = container();
      await tester.pumpWidget(routedApp(c));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      await tester.tap(find.byKey(const ValueKey('empty_start_focus')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('setup'), findsOneWidget,
          reason: 'focusing without a task is a first-class way in, not the '
              'lesser option');
    });
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
