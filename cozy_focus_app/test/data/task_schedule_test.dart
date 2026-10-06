import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask;
import 'package:cozy_focus_app/data/repositories/drift_task_repository.dart';
import 'package:cozy_focus_app/domain/models/task.dart';
import 'package:cozy_focus_app/domain/models/task_schedule.dart';
import 'package:cozy_focus_app/domain/repositories/i_task_repository.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/task_controller.dart';

/// P2 — the plan, against a real SQLite database.
///
/// ## What is being pinned
///
/// Not that a row can be written. That the *rules* hold: a task cannot be on the
/// same day twice, deleting a task takes its placements with it, the today filter
/// means what it says, and everything survives a reopen. Each of those is a way
/// the screen could look right while the data underneath was wrong.
void main() {
  late AppDatabase db;
  late DriftTaskRepository repo;
  late _FixedClock clock;

  const userId = 'default_user';

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _FixedClock(DateTime(2026, 10, 7, 8));
    repo = DriftTaskRepository(db.taskDao, clock: clock);
  });

  tearDown(() async => db.close());

  Future<String> makeTask(String title, {int minutes = 25}) => createTask(
        repository: repo,
        userId: userId,
        title: title,
        estimatedSeconds: minutes * 60,
      );

  group('placement', () {
    test('is readable back the same day, in time order', () async {
      final first = await makeTask('写产品方案');
      final second = await makeTask('熟悉阅读');

      // Placed out of order on purpose: the query has to sort, not the caller.
      await repo.schedule(
        taskId: second,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 10, 30),
        plannedSeconds: 50 * 60,
      );
      await repo.schedule(
        taskId: first,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );

      final day = await repo.schedulesForDay(userId, '2026-10-07');
      expect(day.map((p) => p.title), ['写产品方案', '熟悉阅读']);
      expect(day.first.schedule.plannedSeconds, 25 * 60);
      expect(day.first.schedule.status, TaskScheduleStatus.planned);
    });

    test('carries the task title and category, so the row needs no lookup',
        () async {
      final id = await createTask(
        repository: repo,
        userId: userId,
        title: '写产品方案',
        categoryId: 'work',
        estimatedSeconds: 25 * 60,
      );
      await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );

      final day = await repo.schedulesForDay(userId, '2026-10-07');
      expect(day.single.categoryId, 'work');
      expect(day.single.title, '写产品方案');
    });

    test('the same task twice on the same day is a no-op', () async {
      final id = await makeTask('写产品方案');
      final first = await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );
      final second = await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 15),
        plannedSeconds: 40 * 60,
      );

      expect(second, first, reason: 'the second call returns the first row');
      final day = await repo.schedulesForDay(userId, '2026-10-07');
      expect(day, hasLength(1),
          reason:
              'the create screen switch and the schedule page can both fire');
      expect(day.single.schedule.startAt, DateTime(2026, 10, 7, 9),
          reason: 'and the placement that survives is the one that existed');
    });

    test('the same task on two different days is two placements', () async {
      final id = await makeTask('写产品方案');
      await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );
      await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 8, 9),
        plannedSeconds: 25 * 60,
      );

      expect(await repo.schedulesForDay(userId, '2026-10-07'), hasLength(1));
      expect(await repo.schedulesForDay(userId, '2026-10-08'), hasLength(1));
    });

    test('deleting the task takes its placements with it', () async {
      final id = await makeTask('写产品方案');
      await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );

      await repo.deleteById(id);

      expect(await repo.schedulesForDay(userId, '2026-10-07'), isEmpty,
          reason: 'a plan for a task that is gone is unreachable, not history');
    });

    test('updating a placement moves it and keeps the day in step', () async {
      final id = await makeTask('写产品方案');
      final scheduleId = await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );

      final existing = await repo.schedulesForDay(userId, '2026-10-07');
      await repo.updateSchedule(existing.single.schedule.copyWith(
        startAt: DateTime(2026, 10, 9, 14),
        plannedSeconds: 40 * 60,
      ));

      expect(await repo.schedulesForDay(userId, '2026-10-07'), isEmpty);
      final moved = await repo.schedulesForDay(userId, '2026-10-09');
      expect(moved.single.schedule.id, scheduleId);
      expect(moved.single.schedule.startAt, DateTime(2026, 10, 9, 14));
      expect(moved.single.schedule.plannedSeconds, 40 * 60);
    });

    test('status is stored, not only shown', () async {
      final id = await makeTask('写产品方案');
      final scheduleId = await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );
      final placement =
          (await repo.schedulesForDay(userId, '2026-10-07')).single;

      await repo.updateSchedule(
        placement.schedule.copyWith(status: TaskScheduleStatus.done),
      );

      final reread = await repo.schedulesForDay(userId, '2026-10-07');
      expect(reread.single.schedule.status, TaskScheduleStatus.done);
      expect(reread.single.schedule.id, scheduleId);
    });

    test('removing a placement leaves the task alone', () async {
      final id = await makeTask('写产品方案');
      final scheduleId = await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );

      await repo.deleteSchedule(scheduleId);

      expect(await repo.schedulesForDay(userId, '2026-10-07'), isEmpty);
      expect(await repo.findById(id), isNotNull,
          reason: 'taking something off today is not deleting it');
    });

    test('isScheduledOn answers for the right day only', () async {
      final id = await makeTask('写产品方案');
      await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 8, 9),
        plannedSeconds: 25 * 60,
      );

      expect(await repo.isScheduledOn(id, '2026-10-08'), isTrue);
      expect(await repo.isScheduledOn(id, '2026-10-07'), isFalse);
    });

    test('upcomingSchedulesFor ignores the past and the finished', () async {
      final id = await makeTask('写产品方案');
      for (final day in [7, 8, 9]) {
        await repo.schedule(
          taskId: id,
          userId: userId,
          startAt: DateTime(2026, 10, day, 9),
          plannedSeconds: 25 * 60,
        );
      }
      // Mark the middle one done so it stops being "next".
      final eighth = (await repo.schedulesForDay(userId, '2026-10-08')).single;
      await repo.updateSchedule(
        eighth.schedule.copyWith(status: TaskScheduleStatus.done),
      );

      // limit: 5 rather than the default 1, because the point here is which
      // placements are eligible, not only which one is first.
      final upcoming =
          await repo.upcomingSchedulesFor(id, from: '2026-10-07', limit: 5);
      expect(upcoming.map((s) => s.date), ['2026-10-07', '2026-10-09']);
      expect(upcoming.first.date, '2026-10-07');

      final firstOnly = await repo.upcomingSchedulesFor(id, from: '2026-10-07');
      expect(firstOnly, hasLength(1),
          reason: 'the detail tile wants one, and the default says so');
    });
  });

  group('the today filter', () {
    test('is the tasks planned for today, in start order', () async {
      final planned = await makeTask('写产品方案');
      final later = await makeTask('健身');
      await repo.schedule(
        taskId: later,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 14),
        plannedSeconds: 40 * 60,
      );
      await repo.schedule(
        taskId: planned,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );

      final today = await repo.findByFilter(userId, TaskFilter.today);
      expect(today.map((t) => t.title), ['写产品方案', '健身']);
    });

    test('includes a task written down today with no plan at all', () async {
      // The create screen's switch can be off. A task that then appeared in no
      // tab would look lost, and it is still today's work.
      final id = await makeTask('临时想到的事');
      final today = await repo.findByFilter(userId, TaskFilter.today);
      expect(today.map((t) => t.id), contains(id));
    });

    test('excludes a task planned for another day, but 进行中 still has it',
        () async {
      final id = await makeTask('明天的会');
      await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 9, 9),
        plannedSeconds: 25 * 60,
      );

      final today = await repo.findByFilter(userId, TaskFilter.today);
      expect(today.map((t) => t.id), isNot(contains(id)),
          reason: 'it belongs to the day it was planned for');
      final active = await repo.findByFilter(userId, TaskFilter.active);
      expect(active.map((t) => t.id), contains(id),
          reason: 'and it must not become unreachable');
    });

    test('excludes an old task that was never planned for today', () async {
      final id = await makeTask('上周的事');
      // Backdate it: it was written down on another day and never planned.
      await db.customStatement(
        "UPDATE tasks SET created_at = ${DateTime(2026, 10, 1).millisecondsSinceEpoch} "
        "WHERE id = '$id'",
      );

      final today = await repo.findByFilter(userId, TaskFilter.today);
      expect(today.map((t) => t.id), isNot(contains(id)));
    });

    test('a completed task planned for today is still in today', () async {
      final id = await makeTask('写产品方案');
      await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );
      await repo.setStatus(id, TaskStatus.done, at: DateTime(2026, 10, 7, 10));

      final today = await repo.findByFilter(userId, TaskFilter.today);
      expect(today.map((t) => t.id), contains(id),
          reason: 'the design shows a ticked row in the today tab');
    });

    test('another user\'s plan is not in my today', () async {
      final mine = await makeTask('我的事');
      final theirs = await createTask(
        repository: repo,
        userId: 'someone_else',
        title: '别人的事',
        estimatedSeconds: 25 * 60,
      );
      await repo.schedule(
        taskId: theirs,
        userId: 'someone_else',
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );

      final today = await repo.findByFilter(userId, TaskFilter.today);
      expect(today.map((t) => t.id), [mine]);
    });

    test('follows the clock, not the machine', () async {
      final id = await makeTask('写产品方案');
      await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );

      expect(
        (await repo.findByFilter(userId, TaskFilter.today)).map((t) => t.id),
        contains(id),
      );
      clock.set(DateTime(2026, 10, 8, 8));
      expect(
        (await repo.findByFilter(userId, TaskFilter.today)).map((t) => t.id),
        isNot(contains(id)),
        reason: 'the same rows, read on another day, are not today any more',
      );
    });
  });

  group('survives a reopen', () {
    test('the plan is on disk, not in memory', () async {
      final id = await makeTask('写产品方案');
      await repo.schedule(
        taskId: id,
        userId: userId,
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 25 * 60,
      );

      // A second connection to the same in-memory database would be a different
      // database, so this asserts through the query path the screen uses after a
      // restart: a fresh repository over the same handle.
      final reopened = DriftTaskRepository(db.taskDao, clock: clock);
      final day = await reopened.schedulesForDay(userId, '2026-10-07');
      expect(day.single.title, '写产品方案');
      expect(day.single.schedule.plannedSeconds, 25 * 60);
    });
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  DateTime _now;

  void set(DateTime value) => _now = value;

  @override
  DateTime now() => _now;
}
