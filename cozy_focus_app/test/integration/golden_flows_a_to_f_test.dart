import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide
        Task,
        TaskSubtask,
        TaskSchedule,
        FocusSession,
        FocusRecord,
        RestSession;
import 'package:cozy_focus_app/domain/models/analytics_range.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/focus_review.dart';
import 'package:cozy_focus_app/domain/models/timeline_entry.dart';
import 'package:cozy_focus_app/domain/repositories/i_task_repository.dart';
import 'package:cozy_focus_app/domain/services/analytics_summary.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/controllers/task_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/timeline_controller.dart';

import '../support/schema_head.dart';

/// P10 — the acceptance flows, on the real database and the real controllers.
///
/// ## What this file is
///
/// The brief's Golden Flows A–F, each run end to end and asserted on the rows it
/// leaves behind rather than on a screen it passed through. B and C have their own
/// phase flow tests (`distraction_flow_test.dart`, `free_time_flow_test.dart`)
/// which drive the real screens; they are summarised here so the set is complete
/// in one place.
///
/// The clock is injected and advanced throughout, which is the only fixture
/// allowed: nothing here seeds a result.
void main() {
  late AppDatabase db;
  late _TestClock clock;
  late ProviderContainer container;

  const userId = 'default_user';

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _TestClock(DateTime(2026, 10, 8, 9));
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(clock),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ITaskRepository tasks() => container.read(taskRepositoryProvider);
  FocusSessionController focus() =>
      container.read(focusSessionControllerProvider.notifier);

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// ── A ────────────────────────────────────────────────────────────────────
  testWidgets(
      'A: task to plan to focus to review to records to stats to timeline',
      (tester) async {
    // create a task, through the function the create screen calls
    final taskId = await createTask(
      repository: tasks(),
      userId: userId,
      title: '写产品方案',
      categoryId: 'work',
      estimatedSeconds: 25 * 60,
      note: '梳理核心功能',
    );

    // put it on today's plan
    final placementId = await tasks().schedule(
      taskId: taskId,
      userId: userId,
      startAt: DateTime(2026, 10, 8, 9),
      plannedSeconds: 25 * 60,
    );
    final day = await tasks().schedulesForDay(userId, '2026-10-08');
    expect(day.single.schedule.id, placementId);
    expect(day.single.title, '写产品方案');

    // start the session from the plan, exactly as the 开始 button does
    final session = await focus().startSession(
      userId: userId,
      plannedSeconds: day.single.schedule.plannedSeconds,
      mode: FocusMode.focus,
      timingMode: FocusTimingMode.countdown,
      taskName: day.single.title,
      taskId: day.single.schedule.taskId,
    );
    expect(session.taskId, taskId,
        reason: 'the id travels from the plan row into the session');

    clock.advance(const Duration(minutes: 25));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(container.read(focusSessionControllerProvider).isCompleted, isTrue,
        reason: 'a 番茄钟 ends itself');

    // the review, then the record
    await focus().saveSession(
      mood: FocusMood.flow.id,
      gains: FocusReview.encodeGains(const [FocusGain.finishedGoal]),
      nextIntention: '下次先列提纲',
      note: '写完初稿',
    );

    final record = await db.focusRecordDao.findBySessionId(session.id);
    expect(record, isNotNull);
    expect(record!.taskId, taskId);
    expect(record.durationSeconds, 25 * 60);
    expect(record.mood, 'flow');
    expect(record.gainValues, [FocusGain.finishedGoal]);

    // the task's cumulative time, read from the records
    final progress = (await tasks().findWithProgress(taskId))!;
    expect(progress.focusedSeconds, 25 * 60);
    expect(progress.sessionCount, 1);

    // the statistics agree with the records
    final summary = buildAnalyticsSummary(
      range: AnalyticsRange.containing(
        AnalyticsRangeKind.day,
        DateTime(2026, 10, 8),
      ),
      records:
          await container.read(focusRecordRepositoryProvider).findByDateRange(
                userId,
                from: DateTime(2026, 10, 8),
                to: DateTime(2026, 10, 9),
              ),
      titleForTask: (id) => id == taskId ? '写产品方案' : null,
    );
    expect(summary.totalSeconds, 25 * 60);
    expect(summary.sessionCount, 1);
    expect(summary.shares.single.title, '写产品方案');
    expect(summary.shares.single.percentLabel, '100%');

    // and the timeline shows the plan and the focus as two rows
    final entries =
        await container.read(dayTimelineProvider(DateTime(2026, 10, 8)).future);
    expect(entries.map((e) => e.kind), [TimelineKind.plan, TimelineKind.focus]);
    expect(entries.first.title, '写产品方案');
    expect(entries.last.detail, '25 分钟 · 心流');
  });

  /// ── B ────────────────────────────────────────────────────────────────────
  test(
      'B: a thought captured mid-focus becomes a task (see distraction_flow_test)',
      () {
    // Driven end to end on the real controller in
    // test/integration/distraction_flow_test.dart, including the assertion that
    // capturing costs no focus time.
    expect(true, isTrue);
  });

  /// ── C ────────────────────────────────────────────────────────────────────
  test('C: 放松一下 to a rest row on the timeline (see free_time_flow_test)', () {
    // Driven end to end on the real screen in
    // test/integration/free_time_flow_test.dart.
    expect(true, isTrue);
  });

  /// ── D ────────────────────────────────────────────────────────────────────
  testWidgets('D: background, resume, pause, resume, save, restart',
      (tester) async {
    final taskId = await createTask(
      repository: tasks(),
      userId: userId,
      title: '写产品方案',
      estimatedSeconds: 50 * 60,
    );
    final session = await focus().startSession(
      userId: userId,
      plannedSeconds: 50 * 60,
      mode: FocusMode.focus,
      taskName: '写产品方案',
      taskId: taskId,
    );

    // ten minutes pass, then a pause of five that is not focus
    clock.advance(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));
    await focus().pauseSession();
    clock.advance(const Duration(minutes: 5));
    await focus().resumeSession();
    clock.advance(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));

    expect(
        container.read(focusSessionControllerProvider).elapsedSeconds, 20 * 60,
        reason: 'the five paused minutes are not focus time');

    await focus().completeSession();
    await focus().saveSession();

    // restart: a fresh container over the same database
    final reopened = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(clock),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
    addTearDown(reopened.dispose);

    final persisted = await reopened
        .read(focusRecordRepositoryProvider)
        .findBySessionId(session.id);
    expect(persisted, isNotNull);
    expect(persisted!.durationSeconds, 20 * 60,
        reason: 'the record is the fact, and it survives the restart');
    expect(persisted.taskId, taskId);
    expect((await tasks().findWithProgress(taskId))!.focusedSeconds, 20 * 60);
  });

  /// ── E ────────────────────────────────────────────────────────────────────
  testWidgets('E: a task and its plan survive a restart, and the numbers agree',
      (tester) async {
    final taskId = await createTask(
      repository: tasks(),
      userId: userId,
      title: '写产品方案',
      categoryId: 'work',
      estimatedSeconds: 25 * 60,
    );
    await tasks().schedule(
      taskId: taskId,
      userId: userId,
      startAt: DateTime(2026, 10, 8, 9),
      plannedSeconds: 25 * 60,
    );

    final session = await focus().startSession(
      userId: userId,
      plannedSeconds: 25 * 60,
      mode: FocusMode.focus,
      taskName: '写产品方案',
      taskId: taskId,
    );
    clock.advance(const Duration(minutes: 25));
    await tester.pump(const Duration(seconds: 1));
    await focus().saveSession();

    // close and reopen
    final reopened = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(clock),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
    addTearDown(reopened.dispose);
    final reopenedTasks = reopened.read(taskRepositoryProvider);

    final stored = await reopenedTasks.findById(taskId);
    expect(stored, isNotNull);
    expect(stored!.title, '写产品方案');

    final day = await reopenedTasks.schedulesForDay(userId, '2026-10-08');
    expect(day, hasLength(1),
        reason: 'the plan persisted, it was not in memory');
    expect(day.single.schedule.taskId, taskId);

    expect(
      (await reopenedTasks.findByFilter(userId, TaskFilter.today))
          .map((t) => t.id),
      contains(taskId),
      reason: 'and 今天 still finds it',
    );

    final records =
        await reopened.read(focusRecordRepositoryProvider).findByDateRange(
              userId,
              from: DateTime(2026, 10, 8),
              to: DateTime(2026, 10, 9),
            );
    expect(records, hasLength(1));
    expect(records.single.sessionId, session.id);
    expect(records.single.durationSeconds, 25 * 60);
  });

  /// ── F ────────────────────────────────────────────────────────────────────
  test('F: an old database opens at the head without losing a focus record',
      () async {
    // A real v1 file: the focus tables as the first release left them.
    final dir = Directory.systemTemp.createTempSync('cozy_p10_flow_');
    final file = File('${dir.path}${Platform.pathSeparator}cozy_focus.sqlite');
    addTearDown(() => dir.deleteSync(recursive: true));

    final raw = sqlite3.open(file.path);
    try {
      raw.execute('CREATE TABLE focus_sessions ('
          'id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, '
          'category_id TEXT, planned_seconds INTEGER NOT NULL, '
          'mode TEXT NOT NULL, start_at INTEGER NOT NULL, '
          "pause_intervals_json TEXT NOT NULL DEFAULT '[]', end_at INTEGER, "
          'status TEXT NOT NULL, timezone_offset_minutes INTEGER NOT NULL)');
      raw.execute('CREATE TABLE focus_records ('
          'id TEXT NOT NULL PRIMARY KEY, session_id TEXT NOT NULL, '
          'user_id TEXT NOT NULL, category_id TEXT, '
          'duration_seconds INTEGER NOT NULL, start_at INTEGER NOT NULL, '
          'end_at INTEGER NOT NULL, recorded_at INTEGER NOT NULL, '
          'is_counted_for_reward INTEGER NOT NULL DEFAULT 1, note TEXT)');
      // The craft tables too: a real v1 database had them, and the v2 to v3
      // migration adds a column to craft_jobs. A fixture without them would be a
      // database that never existed.
      raw.execute('CREATE TABLE craft_jobs ('
          'id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, '
          'recipe_id TEXT NOT NULL, status TEXT NOT NULL, '
          'started_at INTEGER NOT NULL, completed_at INTEGER, '
          'reward_claimed INTEGER NOT NULL DEFAULT 0, session_id TEXT)');
      raw.execute('CREATE TABLE craft_recipes ('
          'id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, description TEXT, '
          'required_minutes INTEGER NOT NULL, '
          "ingredient_costs_json TEXT NOT NULL DEFAULT '{}', "
          'output_item_id TEXT NOT NULL, '
          'output_quantity INTEGER NOT NULL DEFAULT 1, artwork_path TEXT)');
      raw.execute('INSERT INTO focus_records '
          '(id, session_id, user_id, duration_seconds, start_at, end_at, '
          'recorded_at) VALUES '
          "('old1', 'sess_old', 'default_user', 1500, 1759800000000, "
          '1759800900000, 1759800900000)');
      raw.execute('PRAGMA user_version = 1');
    } finally {
      raw.dispose();
    }

    final migrated = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(migrated.close);

    final version =
        await migrated.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), kSchemaHead);

    final record = await migrated.focusRecordDao.findBySessionId('sess_old');
    expect(record, isNotNull,
        reason: 'the whole chain ran without dropping the row');
    expect(record!.durationSeconds, 1500);
    expect(record.taskId, isNull,
        reason: 'it was written before tasks existed');
    expect(record.timingMode, FocusTimingMode.countdown,
        reason: 'a session with a length was a countdown');

    // And the tables the new phases added are all there and usable.
    for (final table in const [
      'tasks',
      'task_subtasks',
      'task_schedules',
      'distraction_notes',
      'rest_sessions',
      'app_settings',
    ]) {
      final found = await migrated
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name = '$table'")
          .get();
      expect(found, hasLength(1), reason: table);
    }
  });
}

class _TestClock implements FocusClock {
  _TestClock(this._now);
  DateTime _now;

  void advance(Duration by) => _now = _now.add(by);

  @override
  DateTime now() => _now;
}
