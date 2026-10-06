import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule, FocusSession, FocusRecord;
import 'package:cozy_focus_app/data/repositories/drift_focus_record_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_distraction_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_task_repository.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/models/task.dart';
import 'package:cozy_focus_app/domain/repositories/i_distraction_repository.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/today_plan_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// P6 — the timeline tab, against a real database.
///
/// ## What these tests are for
///
/// The projection's own tests prove the ordering and the detail lines. These
/// prove the screen is wired to it: that a plan, a focus and a captured thought
/// all appear, that the session in flight is the highlighted row, and that the
/// legend only names what is on the day.
void main() {
  late AppDatabase db;
  late DriftTaskRepository tasks;
  late DriftFocusRecordRepository records;
  late DriftDistractionRepository notes;
  late _FixedClock clock;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _FixedClock(DateTime(2026, 10, 8, 12));
    tasks = DriftTaskRepository(db.taskDao, clock: clock);
    records = DriftFocusRecordRepository(db.focusRecordDao);
    notes = DriftDistractionRepository(db.distractionDao);
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
        GoRoute(
          path: '/focus/setup',
          builder: (context, state) => const Scaffold(body: Text('setup')),
        ),
        GoRoute(
          path: '/focus/complete',
          builder: (context, state) => const Scaffold(body: Text('complete')),
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

  /// Switches to the timeline tab and lets the projection's query settle.
  Future<void> showTimeline(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('plan_view_timeline')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));
  }

  Future<String> task(String title, {String? category}) async {
    final id = 'task_$title';
    await tasks.insert(Task(
      id: id,
      userId: userId,
      title: title,
      categoryId: category,
      estimatedSeconds: 25 * 60,
      createdAt: DateTime(2026, 10, 8, 7),
    ));
    return id;
  }

  Future<void> place(String taskId, DateTime at, {int minutes = 25}) =>
      tasks.schedule(
        taskId: taskId,
        userId: userId,
        startAt: at,
        plannedSeconds: minutes * 60,
      );

  Future<void> focusRecord({
    required String sessionId,
    required DateTime startAt,
    int minutes = 25,
    String? taskName,
  }) =>
      records.insert(FocusRecord(
        id: 'rec_$sessionId',
        sessionId: sessionId,
        userId: userId,
        taskName: taskName,
        durationSeconds: minutes * 60,
        startAt: startAt,
        endAt: startAt.add(Duration(minutes: minutes)),
        recordedAt: startAt,
        isCountedForReward: true,
      ));

  testWidgets('an empty day says the timeline is empty', (tester) async {
    final c = container();
    await pump(tester, c);
    await showTimeline(tester);

    expect(find.text('这一天还没有任何记录'), findsOneWidget);
  });

  testWidgets('plans, focus and notes all appear on the axis', (tester) async {
    final id = await task('写产品方案', category: 'work');
    await place(id, DateTime(2026, 10, 8, 9));
    await focusRecord(
      sessionId: 'sess1',
      startAt: DateTime(2026, 10, 8, 10, 30),
      taskName: '专题阅读',
    );
    await captureDistractionNote(
      repository: notes,
      userId: userId,
      text: '买充电线',
      id: 'n1',
      createdAt: DateTime(2026, 10, 8, 12),
    );

    final c = container();
    await pump(tester, c);
    await showTimeline(tester);

    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('写产品方案'), findsOneWidget);
    expect(find.text('10:30'), findsOneWidget);
    expect(find.text('专题阅读'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('买充电线'), findsOneWidget);
    // The plan row shows its category; the focus row shows its length.
    expect(find.text('工作'), findsOneWidget);
    expect(find.text('25 分钟'), findsOneWidget);
  });

  testWidgets('the legend names only the kinds the day has', (tester) async {
    final id = await task('写产品方案');
    await place(id, DateTime(2026, 10, 8, 9));

    final c = container();
    await pump(tester, c);
    await showTimeline(tester);

    expect(find.text('任务'), findsOneWidget);
    expect(find.text('专注'), findsNothing,
        reason: 'a key to nothing is not a legend');
    expect(find.text('快速记录'), findsNothing);
  });

  testWidgets('a running session is the highlighted row with a stop control',
      (tester) async {
    final c = container();
    await pump(tester, c);

    // A real session, through the real controller, so the row is built from the
    // same live state the focus screen uses.
    // The clock starts at 12:00, so the session begins then and 25 minutes pass
    // into it — the same direction time moves in production.
    await c.read(focusSessionControllerProvider.notifier).startSession(
          userId: userId,
          plannedSeconds: 50 * 60,
          mode: FocusMode.focus,
          taskName: '专题阅读',
        );
    clock.set(DateTime(2026, 10, 8, 12, 25));
    await tester.pump(const Duration(seconds: 1));

    await showTimeline(tester);

    expect(find.text('专注中：专题阅读'), findsOneWidget);
    expect(find.text('50 分钟 · 剩余 25 分钟'), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline_stop_running')), findsOneWidget);

    await c.read(focusSessionControllerProvider.notifier).cancelSession();
  });

  testWidgets('the plan rows are not duplicated between the two tabs',
      (tester) async {
    final id = await task('写产品方案');
    await place(id, DateTime(2026, 10, 8, 9));

    final c = container();
    await pump(tester, c);

    // The plan tab shows the card and the row.
    expect(find.text('写产品方案'), findsNWidgets(2));
    await showTimeline(tester);

    // The timeline shows the axis row only: the card belongs to the plan view.
    expect(find.text('下一个任务'), findsNothing);
    expect(find.text('写产品方案'), findsOneWidget);
  });

  testWidgets('a finished focus is a row, and its record is real',
      (tester) async {
    final c = container();
    await pump(tester, c);

    final session =
        await c.read(focusSessionControllerProvider.notifier).startSession(
              userId: userId,
              // Longer than the 25 minutes the clock advances: a 番茄钟 that reached
              // its target would complete itself, and this test is about ending a
              // session by hand.
              plannedSeconds: 50 * 60,
              mode: FocusMode.focus,
              taskName: '写产品方案',
            );
    clock.set(DateTime(2026, 10, 8, 12, 25));
    await tester.pump(const Duration(seconds: 1));
    await c.read(focusSessionControllerProvider.notifier).completeSession();
    await c.read(focusSessionControllerProvider.notifier).saveSession();

    await showTimeline(tester);

    // The record exists, and the row is drawn from it rather than from the live
    // session, which is gone.
    expect(await db.focusRecordDao.findBySessionId(session.id), isNotNull);
    expect(find.text('写产品方案'), findsOneWidget);
    expect(find.text('25 分钟'), findsOneWidget);
    expect(find.textContaining('专注中'), findsNothing);
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  DateTime _now;

  void set(DateTime value) => _now = value;

  @override
  DateTime now() => _now;
}
