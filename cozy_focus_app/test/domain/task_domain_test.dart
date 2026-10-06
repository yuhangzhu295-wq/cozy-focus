import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// The generated row classes are named after the tables and collide with the
// domain models, which are what these tests are about.
import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask;
import 'package:cozy_focus_app/data/repositories/drift_task_repository.dart';
import 'package:cozy_focus_app/domain/models/focus_record.dart' as domain;
import 'package:cozy_focus_app/domain/models/task.dart';
import 'package:cozy_focus_app/domain/repositories/i_task_repository.dart';

/// P1 — the task domain, against a real database.
///
/// ## Why these run on a real database rather than a fake repository
///
/// The claim this phase has to earn is that a task survives and that the time
/// focused on it is *counted from the records* rather than stored twice. Both of
/// those are properties of the schema and the join, so a fake repository would
/// assert nothing: it would prove that a map can hold a value.
void main() {
  late AppDatabase db;
  late DriftTaskRepository repo;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftTaskRepository(db.taskDao);
  });

  tearDown(() async => db.close());

  Task task({
    String id = 't1',
    String title = '写产品方案',
    String? categoryId = 'work',
    int estimatedSeconds = 25 * 60,
    String? note,
  }) =>
      Task(
        id: id,
        userId: userId,
        title: title,
        categoryId: categoryId,
        estimatedSeconds: estimatedSeconds,
        note: note,
        createdAt: DateTime(2026, 10, 7, 9),
      );

  /// A focus record against [taskId], as the engine writes one.
  Future<void> recordFocus(
    String id,
    String? taskId, {
    int seconds = 600,
    DateTime? startAt,
  }) async {
    final start = startAt ?? DateTime(2026, 10, 7, 10);
    await db.focusRecordDao.insert(domain.FocusRecord(
      id: id,
      sessionId: 'session-$id',
      userId: userId,
      taskId: taskId,
      taskName: '写产品方案',
      durationSeconds: seconds,
      startAt: start,
      endAt: start.add(Duration(seconds: seconds)),
      recordedAt: start.add(Duration(seconds: seconds)),
      isCountedForReward: true,
    ));
  }

  group('a task is stored and read back', () {
    test('insert then read by id', () async {
      await repo.insert(task(note: '初稿'));

      final read = await repo.findById('t1');
      expect(read, isNotNull);
      expect(read!.title, '写产品方案');
      expect(read.categoryId, 'work');
      expect(read.estimatedSeconds, 25 * 60);
      expect(read.note, '初稿');
      expect(read.status, TaskStatus.open);
    });

    test('an unknown id is null rather than a throw', () async {
      // A deep link to a deleted task is an ordinary event.
      expect(await repo.findById('nope'), isNull);
      expect(await repo.findWithProgress('nope'), isNull);
    });

    test('editing writes through', () async {
      await repo.insert(task());
      final current = (await repo.findById('t1'))!;
      await repo.update(current.copyWith(
        title: '写产品方案 V2',
        estimatedSeconds: 40 * 60,
        note: () => '改过了',
      ));

      final read = (await repo.findById('t1'))!;
      expect(read.title, '写产品方案 V2');
      expect(read.estimatedSeconds, 40 * 60);
      expect(read.note, '改过了');
    });

    test('completing stamps the time, reopening clears it', () async {
      await repo.insert(task());
      await repo.setStatus('t1', TaskStatus.done,
          at: DateTime(2026, 10, 7, 15));
      var read = (await repo.findById('t1'))!;
      expect(read.isDone, isTrue);
      expect(read.completedAt, DateTime(2026, 10, 7, 15));

      await repo.setStatus('t1', TaskStatus.open);
      read = (await repo.findById('t1'))!;
      expect(read.isDone, isFalse);
      expect(read.completedAt, isNull,
          reason: 'a reopened task is not still finished');
    });

    test('the filters answer the three tabs', () async {
      await repo.insert(task(id: 't1', title: '进行中的'));
      await repo.insert(task(id: 't2', title: '已完成的'));
      await repo.setStatus('t2', TaskStatus.done,
          at: DateTime(2026, 10, 7, 12));

      final active = await repo.findByFilter(userId, TaskFilter.active);
      expect(active.map((t) => t.id), ['t1']);

      final done = await repo.findByFilter(userId, TaskFilter.done);
      expect(done.map((t) => t.id), ['t2']);

      expect(await repo.countOpen(userId), 1);
    });

    test('deleting takes the subtasks with it', () async {
      await repo.insert(task());
      await repo.insertSubtask(
          const TaskSubtask(id: 's1', taskId: 't1', title: '第一步'));
      await repo.insertSubtask(
          const TaskSubtask(id: 's2', taskId: 't1', title: '第二步'));
      expect(await repo.subtasksFor('t1'), hasLength(2));

      await repo.deleteById('t1');

      expect(await repo.findById('t1'), isNull);
      expect(await repo.subtasksFor('t1'), isEmpty,
          reason: 'the foreign key must cascade, or a deleted task leaves '
              'subtasks nothing can reach');
    });
  });

  group('progress counts subtasks that are really there', () {
    test('no subtasks means no progress, not zero over zero', () async {
      await repo.insert(task());
      final progress = (await repo.findWithProgress('t1'))!;

      expect(progress.hasSubtasks, isFalse);
      expect(progress.progressLabel, isNull,
          reason: 'a `0 / 0` bar is a progress indicator for nothing');
      expect(progress.progressFraction, isNull);
    });

    test('the counts follow the stored rows', () async {
      await repo.insert(task());
      await repo.insertSubtask(
          const TaskSubtask(id: 's1', taskId: 't1', title: '一', isDone: true));
      await repo
          .insertSubtask(const TaskSubtask(id: 's2', taskId: 't1', title: '二'));
      await repo
          .insertSubtask(const TaskSubtask(id: 's3', taskId: 't1', title: '三'));

      final progress = (await repo.findWithProgress('t1'))!;
      expect(progress.progressLabel, '1 / 3');
      expect(progress.progressFraction, closeTo(1 / 3, 1e-9));
    });

    test('ticking one updates the fraction', () async {
      await repo.insert(task());
      await repo
          .insertSubtask(const TaskSubtask(id: 's1', taskId: 't1', title: '一'));
      await repo
          .insertSubtask(const TaskSubtask(id: 's2', taskId: 't1', title: '二'));

      final first = (await repo.subtasksFor('t1')).first;
      await repo.updateSubtask(first.copyWith(isDone: true));

      expect((await repo.findWithProgress('t1'))!.progressLabel, '1 / 2');
    });
  });

  group('focused time is counted from the records, not stored twice', () {
    test('a task with no records is zero, not unknown', () async {
      await repo.insert(task());
      final progress = (await repo.findWithProgress('t1'))!;

      expect(progress.focusedSeconds, 0);
      expect(progress.sessionCount, 0);
    });

    test('records against the task add up', () async {
      await repo.insert(task());
      await recordFocus('r1', 't1', seconds: 600);
      await recordFocus('r2', 't1', seconds: 900);
      // And one that belongs to no task, which must not be counted anywhere.
      await recordFocus('r3', null, seconds: 1200);

      final progress = (await repo.findWithProgress('t1'))!;
      expect(progress.focusedSeconds, 1500);
      expect(progress.sessionCount, 2);
    });

    test('a task deleted keeps its records', () async {
      // The history is a fact about time the user spent. Deleting the task it
      // was filed under must not delete the time.
      await repo.insert(task());
      await recordFocus('r1', 't1', seconds: 600);
      await repo.deleteById('t1');

      final rows = await db.focusRecordDao.findById('r1');
      expect(rows, isNotNull,
          reason: 'a record must outlive the task it was filed under');
      expect(rows!.taskId, 't1',
          reason: 'and keep the id, so it stops counting rather than being '
              'silently re-filed');
    });

    test('the batch totals agree with the per-task totals', () async {
      // Two code paths answer "how long on this task": the detail screen asks
      // per task and the list asks for a page at once. If they disagree, one of
      // the two screens is wrong.
      await repo.insert(task(id: 't1'));
      await repo.insert(task(id: 't2'));
      await recordFocus('r1', 't1', seconds: 600);
      await recordFocus('r2', 't1', seconds: 300);
      await recordFocus('r3', 't2', seconds: 900);

      final batch = await repo.focusTotalsByTask(userId);

      for (final id in ['t1', 't2']) {
        final single = await db.taskDao.focusTotalsFor(id);
        expect(batch[id]?.seconds, single.seconds, reason: id);
        expect(batch[id]?.sessions, single.sessions, reason: id);
      }
      expect(batch['t1']?.seconds, 900);
      expect(batch['t2']?.seconds, 900);
    });

    test('the recent list is newest first and capped', () async {
      await repo.insert(task());
      for (var i = 0; i < 7; i++) {
        await recordFocus('r$i', 't1',
            seconds: 60,
            startAt: DateTime(2026, 10, 7, 8).add(Duration(hours: i)));
      }

      final progress = (await repo.findWithProgress('t1'))!;
      expect(progress.recentFocus, hasLength(5),
          reason: 'the screen shows the most recent few');
      expect(progress.recentFocus.first.startAt.hour, 14,
          reason: 'newest first');
      // But the totals still count all seven.
      expect(progress.sessionCount, 7);
    });

    test('over-estimate is reported rather than hidden', () async {
      await repo.insert(task(estimatedSeconds: 600));
      await recordFocus('r1', 't1', seconds: 900);

      final progress = (await repo.findWithProgress('t1'))!;
      expect(progress.isOverEstimate, isTrue);
    });
  });

  group('the category vocabulary', () {
    test('every shipped category resolves', () {
      for (final category in taskCategories) {
        expect(taskCategoryFor(category.id), isNotNull);
        expect(taskCategoryLabel(category.id), category.label);
      }
    });

    test('an unknown or absent category resolves to nothing', () {
      // Not to 其他: showing a task as 其他 when it says something else would
      // hide the data problem rather than surfacing it.
      expect(taskCategoryFor('nonsense'), isNull);
      expect(taskCategoryFor(null), isNull);
      expect(taskCategoryLabel('nonsense'), isNull);
    });
  });
}
