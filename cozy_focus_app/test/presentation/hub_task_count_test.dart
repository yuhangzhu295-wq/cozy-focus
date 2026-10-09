import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule, FocusSession, FocusRecord;
import 'package:cozy_focus_app/domain/models/task.dart';
import 'package:cozy_focus_app/domain/repositories/i_task_repository.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';

/// The records hub's task summary must not be a view of the tab you left open.
///
/// ## What this is for
///
/// The hub read `taskListControllerProvider.tasks` — the **filtered** list — so
/// its number changed with whichever tab the task list was last left on. Left on
/// 已完成 it read 还没有任务 while three tasks were open. Found by walking the
/// distraction flow: capture a thought, convert it to a task, come back to the
/// hub, and the summary had not moved.
///
/// `openCount` is loaded from the 进行中 filter whatever tab is on screen, so the
/// summary describes the user's tasks rather than their last tap.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  Future<void> seed() async {
    final repo = container.read(taskRepositoryProvider);
    await repo.insert(Task(
      id: 'open_a',
      userId: userId,
      title: 'Alpha',
      estimatedSeconds: 1500,
      createdAt: DateTime(2026, 10, 9, 9),
    ));
    await repo.insert(Task(
      id: 'open_b',
      userId: userId,
      title: 'Beta',
      estimatedSeconds: 1500,
      createdAt: DateTime(2026, 10, 9, 10),
    ));
    await repo.insert(Task(
      id: 'done_c',
      userId: userId,
      title: 'Gamma',
      estimatedSeconds: 1500,
      createdAt: DateTime(2026, 10, 9, 11),
    ));
    await repo.setStatus('done_c', TaskStatus.done);
  }

  test('counts the open tasks whatever tab is on screen', () async {
    await seed();
    final controller = container.read(taskListControllerProvider.notifier);
    // The controller loads on construction; let it settle.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(container.read(taskListControllerProvider).openCount, 2);

    await controller.setFilter(TaskFilter.done);
    expect(
      container.read(taskListControllerProvider).openCount,
      2,
      reason: 'the tab on screen changed; the number of open tasks did not',
    );

    await controller.setFilter(TaskFilter.active);
    expect(container.read(taskListControllerProvider).openCount, 2);
  });

  test('and the list itself does follow the tab', () async {
    await seed();
    final controller = container.read(taskListControllerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await controller.setFilter(TaskFilter.done);
    final done = container.read(taskListControllerProvider).tasks;
    expect(done.map((t) => t.id), ['done_c']);

    // Which is exactly why the summary could not read it: on this tab the list
    // holds one finished task and no open ones at all.
    expect(done.where((t) => !t.isDone), isEmpty);
  });
}
