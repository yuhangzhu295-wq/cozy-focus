import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/task.dart';
import '../../domain/repositories/i_task_repository.dart';
import '../controllers/providers.dart';
import '../controllers/task_controller.dart';
import '../../domain/models/enums.dart';
import '../companion/companion_avatar.dart';
import '../theme/app_theme.dart';
import '../widgets/task_category_chip.dart';
import '../widgets/task_duration.dart';

/// Screen 02: the task list.
///
/// ## Why it is under 记录 and not a fourth tab
///
/// Tasks are what a focus session is *about*, and the records domain is where
/// the app already keeps "what I did with my time". A fourth bottom tab would
/// make the product have two places to look for the same thing, and the design
/// brief keeps the bottom navigation at three.
///
/// ## The three tabs
///
/// 今天 / 进行中 / 已完成. They are a filter over the same list rather than three
/// screens, because the row is identical in all three and only the set differs.
class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskListControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text(
          '任务',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '新建任务',
            onPressed: () async {
              final created = await context.push<String>('/records/tasks/new');
              if (created != null) {
                await ref.read(taskListControllerProvider.notifier).load();
              }
            },
            icon: const Icon(Icons.add_circle,
                semanticLabel: '新建任务', color: AppColors.primarySage),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _FilterTabs(
            active: state.filter,
            onChanged: (filter) =>
                ref.read(taskListControllerProvider.notifier).setFilter(filter),
          ),
          Expanded(
            child: switch (state) {
              TaskListState(isLoading: true, tasks: []) =>
                const Center(child: CircularProgressIndicator()),
              TaskListState(error: final String error) => _ErrorState(
                  message: error,
                  onRetry: () =>
                      ref.read(taskListControllerProvider.notifier).load(),
                ),
              TaskListState(tasks: final List<Task> tasks) when tasks.isEmpty =>
                _EmptyState(filter: state.filter),
              TaskListState(tasks: final List<Task> tasks) =>
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _TaskRow(
                      task: task,
                      focusedSeconds: state.secondsFor(task.id),
                      onOpen: () async {
                        await context.push('/records/tasks/${task.id}');
                        await ref
                            .read(taskListControllerProvider.notifier)
                            .load();
                      },
                      onToggle: () => ref
                          .read(taskListControllerProvider.notifier)
                          .toggleDone(task),
                    );
                  },
                ),
            },
          ),
        ],
      ),
    );
  }
}

/// The three filter chips.
class _FilterTabs extends StatelessWidget {
  final TaskFilter active;
  final ValueChanged<TaskFilter> onChanged;

  const _FilterTabs({required this.active, required this.onChanged});

  static const Map<TaskFilter, String> _labels = {
    TaskFilter.today: '今天',
    TaskFilter.active: '进行中',
    TaskFilter.done: '已完成',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          for (final filter in TaskFilter.values)
            Expanded(
              child: Semantics(
                // Keyed so a test can address one tab without matching its
                // prose, which also appears in the empty state.
                key: ValueKey('task_filter_${filter.id}'),
                // The wrapper supplies the whole name, so it excludes the chip's
                // own text. Without this the device tree read `今天\n今天` for
                // each of the three — a screen reader saying every filter twice.
                // It survived the earlier accessibility sweep because the label
                // is written `_labels[filter]` and the text `_labels[filter]!`,
                // and the null-assertion was enough to hide the match from the
                // scan while the device showed it plainly.
                excludeSemantics: true,
                button: true,
                selected: filter == active,
                label: _labels[filter],
                child: GestureDetector(
                  onTap: () => onChanged(filter),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: filter == active
                          ? AppColors.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: filter == active
                            ? AppColors.border
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      _labels[filter]!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: filter == active
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: filter == active
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One row: a tick, a title, its category and how long it is expected to take.
class _TaskRow extends StatelessWidget {
  final Task task;
  final int focusedSeconds;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  const _TaskRow({
    required this.task,
    required this.focusedSeconds,
    required this.onOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final category = taskCategoryFor(task.categoryId);
    // The row shows the estimate, which is what the design shows. Once there is
    // real focus time it shows that instead, because "how long I said" is less
    // interesting than "how long it took".
    final duration = focusedSeconds > 0
        ? formatTaskDuration(focusedSeconds)
        : formatTaskDuration(task.estimatedSeconds);

    return Material(
      color: task.isDone ? AppColors.primaryLight : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: task.isDone ? '标记为未完成' : '标记为已完成',
                child: GestureDetector(
                  onTap: onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Icon(
                    task.isDone
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 24,
                    color: task.isDone
                        ? AppColors.primarySage
                        : AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        decoration:
                            task.isDone ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (category != null) ...[
                          TaskCategoryChip(
                            categoryId: category.id,
                            label: category.label,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          duration,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A task list with nothing in it.
///
/// The copy follows the tab rather than being one generic sentence: "no tasks"
/// and "nothing finished yet" are different situations and a user who has
/// completed nothing should be told that, not told the app is empty.
class _EmptyState extends ConsumerWidget {
  final TaskFilter filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (title, body) = switch (filter) {
      // The design's first-run copy on the tab the list opens on: a user with
      // nothing planned is a user who has not started yet, and the screen's job
      // is to invite the first step rather than to report an empty list.
      TaskFilter.today => ('还没有任务哦～', '从一个小目标开始，让专注成为更好的日常吧！'),
      TaskFilter.active => ('还没有任务哦～', '从一个小目标开始，让专注成为更好的日常吧！'),
      TaskFilter.done => ('还没有完成的任务', '完成一个任务后，它会出现在这里。'),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The design's companion rather than an icon: the empty state is the
            // first thing a new user sees, and a grey glyph is the cold version
            // of a screen that is meant to feel like an invitation.
            const CompanionAvatar(
              size: 120,
              visualStateOverride: PetVisualState.greeting,
              showStateBadge: false,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            // Both ways out, as the design shows them: creating a task, and
            // starting a session without one — which is a first-class way to
            // focus and must not look like the lesser option.
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('empty_new_task'),
                onPressed: () async {
                  final created =
                      await context.push<String>('/records/tasks/new');
                  if (created != null) {
                    await ref.read(taskListControllerProvider.notifier).load();
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primarySage,
                  foregroundColor: AppColors.textLight,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('新建任务',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('empty_start_focus'),
                onPressed: () => context.push('/focus/setup'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primarySage),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('开始第一次专注',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: AppColors.accentPeach),
            const SizedBox(height: 12),
            const Text(
              '任务没能读出来',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('再试一次')),
          ],
        ),
      ),
    );
  }
}
