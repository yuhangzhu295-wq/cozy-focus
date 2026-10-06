import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule, DistractionNote;
import 'package:cozy_focus_app/data/repositories/drift_distraction_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_task_repository.dart';
import 'package:cozy_focus_app/domain/models/distraction_note.dart';
import 'package:cozy_focus_app/domain/models/task_schedule.dart';
import 'package:cozy_focus_app/domain/repositories/i_distraction_repository.dart';
import 'package:cozy_focus_app/domain/repositories/i_task_repository.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/distraction_inbox_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// P4 — the inbox screen, against a real database and a real router.
///
/// ## What these tests are for
///
/// The screen's job is to turn a captured thought into either a task or a
/// deletion, so every action ends at a row: the task that was created, the
/// placement that was scheduled, the note that left the inbox. A test that only
/// checked the sheet closed would pass on a version whose buttons did nothing.
void main() {
  late AppDatabase db;
  late DriftDistractionRepository notes;
  late DriftTaskRepository tasks;
  late _FixedClock clock;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _FixedClock(DateTime(2026, 10, 8, 9));
    notes = DriftDistractionRepository(db.distractionDao);
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
      initialLocation: '/records/inbox',
      routes: [
        GoRoute(
          path: '/records/inbox',
          builder: (context, state) => const DistractionInboxPage(),
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

  Future<String> note(
    String text, {
    String? categoryId,
    DateTime? at,
  }) =>
      captureDistractionNote(
        repository: notes,
        userId: userId,
        text: text,
        id: 'note_$text',
        categoryId: categoryId,
        createdAt: at ?? DateTime(2026, 10, 8, 10, 15),
      );

  Future<void> openActions(WidgetTester tester, String text) async {
    await tester.tap(find.bySemanticsLabel('$text 的操作'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('an empty inbox says so, and says what it is for',
      (tester) async {
    final c = container();
    await pump(tester, c);

    expect(find.text('分心箱是空的'), findsOneWidget);
    expect(find.textContaining('记一下'), findsOneWidget);
  });

  testWidgets('a note shows its text, its tag and when it arrived',
      (tester) async {
    await note('买充电线', categoryId: 'life');
    final c = container();
    await pump(tester, c);

    expect(find.text('买充电线'), findsOneWidget);
    expect(find.text('生活'), findsWidgets);
    expect(find.text('今天 10:15'), findsOneWidget);
  });

  testWidgets('the 待处理 chip carries the real count', (tester) async {
    await note('一');
    await note('二');
    await note('三');
    final c = container();
    await pump(tester, c);

    expect(find.text('待处理 (3)'), findsOneWidget);
  });

  testWidgets('ticking a note takes it out of the inbox, and it can come back',
      (tester) async {
    await note('买充电线');
    final c = container();
    await pump(tester, c);

    await tester.tap(find.byIcon(Icons.radio_button_unchecked));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(await notes.countOpen(userId), 0);
    expect(find.text('分心箱是空的'), findsOneWidget);

    // 已处理 still has it, which is where the user can change their mind.
    await tester.tap(find.byKey(const ValueKey('inbox_filter_handled')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('买充电线'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_circle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(await notes.countOpen(userId), 1);
  });

  testWidgets('转成任务 creates a real task and files the note', (tester) async {
    await note('买充电线', categoryId: 'life');
    final c = container();
    await pump(tester, c);

    await openActions(tester, '买充电线');
    expect(find.text('转成任务'), findsOneWidget);
    expect(find.text('安排到今天'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.text('转成任务'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final created = await tasks.findByFilter(userId, TaskFilter.active);
    expect(created, hasLength(1));
    expect(created.single.title, '买充电线');
    expect(created.single.categoryId, 'life');

    final stored = await notes.findById('note_买充电线');
    expect(stored!.isOpen, isFalse);
    expect(stored.convertedTaskId, created.single.id);
    // Not scheduled: 转成任务 files it, 安排到今天 schedules it.
    expect(await tasks.schedulesForDay(userId, '2026-10-08'), isEmpty);
  });

  testWidgets('安排到今天 creates the task and puts it on the plan', (tester) async {
    await note('准备下周的汇报资料', categoryId: 'work');
    final c = container();
    await pump(tester, c);

    await openActions(tester, '准备下周的汇报资料');
    await tester.tap(find.text('安排到今天'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final created = await tasks.findByFilter(userId, TaskFilter.active);
    expect(created, hasLength(1));

    final day = await tasks.schedulesForDay(userId, '2026-10-08');
    expect(day, hasLength(1), reason: '安排到今天 has to actually put it on today');
    expect(day.single.title, '准备下周的汇报资料');
    expect(day.single.schedule.taskId, created.single.id);
    expect(day.single.schedule.startAt, DateTime(2026, 10, 8, 9, 30),
        reason: 'the next free half hour, from the app clock at 09:00');
    expect(day.single.schedule.plannedSeconds,
        DistractionNote.defaultPlacementSeconds);
    expect(day.single.schedule.status, TaskScheduleStatus.planned);

    expect((await notes.findById('note_准备下周的汇报资料'))!.isOpen, isFalse);
  });

  testWidgets('删除 removes it and leaves the task list alone', (tester) async {
    await note('不值得留下的想法');
    final c = container();
    await pump(tester, c);

    await openActions(tester, '不值得留下的想法');
    await tester.tap(find.text('删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(await notes.findByFilter(userId, DistractionFilter.all), isEmpty);
    expect(await tasks.findByFilter(userId, TaskFilter.active), isEmpty);
  });

  testWidgets('a long note becomes a title the create screen would accept',
      (tester) async {
    final long = '把这件事情的前因后果和所有需要考虑的细节都写下来' * 3;
    await note(long);
    final c = container();
    await pump(tester, c);

    await openActions(tester, long);
    await tester.tap(find.text('转成任务'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final created = await tasks.findByFilter(userId, TaskFilter.active);
    expect(created.single.title.runes.length, lessThanOrEqualTo(30));
    // The whole thought is kept as the task's note, so nothing typed is lost.
    expect(created.single.note, long);
  });

  testWidgets('the category chips filter for real', (tester) async {
    await note('买充电线', categoryId: 'life');
    await note('准备汇报资料', categoryId: 'work');
    final c = container();
    await pump(tester, c);

    expect(find.byKey(const ValueKey('inbox_category_life')), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox_category_work')), findsOneWidget);
    // 学习 has nothing in it, so it has no chip: an empty tab is not offered.
    expect(find.byKey(const ValueKey('inbox_category_study')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('inbox_category_life')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('买充电线'), findsOneWidget);
    expect(find.text('准备汇报资料'), findsNothing);

    // Tapping the same chip again clears it, so the filter can be undone.
    await tester.tap(find.byKey(const ValueKey('inbox_category_life')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('准备汇报资料'), findsOneWidget);
  });

  testWidgets('the counts do not change when the filter does', (tester) async {
    await note('一', categoryId: 'life');
    await note('二', categoryId: 'life');
    final c = container();
    await pump(tester, c);

    await tester.tap(find.byKey(const ValueKey('inbox_category_life')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('待处理 (2)'), findsOneWidget,
        reason: 'the chips say how much is waiting, not how much is shown');
    expect(find.text('生活 (2)'), findsOneWidget);
  });

  testWidgets('已处理 says something true about itself', (tester) async {
    final c = container();
    await pump(tester, c);

    await tester.tap(find.byKey(const ValueKey('inbox_filter_handled')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('还没有处理过的想法'), findsOneWidget);
    expect(find.text('分心箱是空的'), findsNothing);
  });

  testWidgets('a converted note says so when it is looked at again',
      (tester) async {
    await note('买充电线');
    final c = container();
    await pump(tester, c);
    await openActions(tester, '买充电线');
    await tester.tap(find.text('转成任务'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('inbox_filter_handled')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('已转成任务'), findsOneWidget);
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
