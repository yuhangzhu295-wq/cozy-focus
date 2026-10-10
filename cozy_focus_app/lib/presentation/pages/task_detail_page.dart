import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/task.dart';
import '../../domain/models/task_schedule.dart';
import '../controllers/providers.dart';
import '../controllers/task_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/plan_moment.dart';
import '../widgets/task_duration.dart';

/// Screen 12: one task, in full.
///
/// ## What is real here
///
/// The progress bar counts subtasks that are actually in the database, the
/// cumulative time is a sum over `focus_records` joined by `taskId`, and the
/// recent list is those same rows. Nothing on this screen is a placeholder: if
/// the numbers are zero it is because nothing has been recorded.
///
/// ## The plan side
///
/// `下次计划` reads `task_schedules` for the next placement from today onward, and
/// `加入今日计划` opens the same schedule form the today view uses. Both write and
/// read the real table; the tile says 未安排 when the task is not planned, which
/// is a state the user can act on rather than a blank.
class TaskDetailPage extends ConsumerWidget {
  final String taskId;

  const TaskDetailPage({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskDetailControllerProvider(taskId));
    final controller = ref.read(taskDetailControllerProvider(taskId).notifier);

    final progress = state.progress;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(
          progress?.task.title ?? '任务',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (progress != null)
            PopupMenuButton<String>(
              tooltip: '更多操作',
              icon: const Icon(Icons.more_horiz_rounded,
                  semanticLabel: '更多操作', color: AppColors.textSecondary),
              onSelected: (value) async {
                switch (value) {
                  case 'toggle':
                    await controller.setStatus(progress.task.isDone
                        ? TaskStatus.open
                        : TaskStatus.done);
                  case 'delete':
                    final confirmed = await _confirmDelete(context);
                    if (!confirmed) return;
                    await controller.deleteTask();
                    if (context.mounted) context.pop();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(progress.task.isDone ? '标记为未完成' : '标记为已完成'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('删除任务')),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: switch (state) {
        TaskDetailState(isLoading: true, progress: null) =>
          const Center(child: CircularProgressIndicator()),
        TaskDetailState(progress: null) => const _MissingTask(),
        _ => _Body(
            taskId: taskId,
            progress: progress!,
            nextSchedule: state.nextSchedule,
          ),
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这个任务？'),
        content: const Text('删除后任务就不在列表里了。已经记录的专注时间会保留，只是不再归属到这个任务。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('先留着'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除',
                style: TextStyle(color: AppColors.accentPeach)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _Body extends ConsumerWidget {
  final String taskId;
  final TaskWithProgress progress;
  final TaskSchedule? nextSchedule;

  const _Body({
    required this.taskId,
    required this.progress,
    this.nextSchedule,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = progress.task;
    final category = taskCategoryFor(task.categoryId);
    final controller = ref.read(taskDetailControllerProvider(taskId).notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (category != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                category.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Progress, only when there is something to count. A `0 / 0` bar would
        // be a progress indicator for a thing that has no progress.
        if (progress.hasSubtasks) ...[
          _ProgressCard(progress: progress, onToggle: controller.toggleSubtask),
          const SizedBox(height: 12),
        ],

        // The way in. Deliberately outside the card above, which is hidden until
        // there is something to count - an entrance inside it could never add
        // the first subtask.
        _AddSubtaskRow(onTap: () => _addSubtask(context, controller)),
        const SizedBox(height: 12),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.timer_outlined,
                  label: '累计专注时长',
                  value: progress.focusedSeconds > 0
                      ? formatTaskDuration(progress.focusedSeconds)
                      : '还没有开始',
                  hint: progress.sessionCount > 0
                      ? '共 ${progress.sessionCount} 次专注'
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.event_available_rounded,
                  label: '下次计划',
                  value: nextSchedule == null
                      ? '未安排'
                      : formatPlanMoment(
                          nextSchedule!,
                          ref.read(focusClockProvider).now(),
                        ),
                  hint: nextSchedule == null ? '点这里安排时间' : null,
                  onTap: () => _openSchedule(context, ref),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _NoteCard(
            task: task, onEdit: () => _editNote(context, controller, task)),
        const SizedBox(height: 12),

        if (progress.recentFocus.isNotEmpty)
          _RecentFocusCard(entries: progress.recentFocus),
        if (progress.recentFocus.isNotEmpty) const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _openSchedule(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.primarySage),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  icon: const Icon(Icons.event_available_rounded, size: 20),
                  label: const Text(
                    '加入今日计划',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  // The task id travels with the session, which is what makes
                  // the record count towards this task afterwards.
                  onPressed: () => context.push('/focus/setup?taskId=$taskId'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primarySage,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    '开始专注',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Opens the schedule form and reloads afterwards, so the 下次计划 tile shows
  /// what was just saved rather than the value from before the trip.
  Future<void> _openSchedule(BuildContext context, WidgetRef ref) async {
    await context.push('/records/tasks/$taskId/schedule');
    await ref.read(taskDetailControllerProvider(taskId).notifier).load();
  }

  Future<void> _editNote(
    BuildContext context,
    TaskDetailController controller,
    Task task,
  ) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _TextPromptDialog(
        title: '任务备注',
        hint: '记录任务的具体内容、目标或注意事项',
        initial: task.note ?? '',
        maxLines: 4,
      ),
    );
    if (saved == null) return;
    await controller.updateNote(saved.trim().isEmpty ? null : saved.trim());
  }

  /// Adds one subtask.
  ///
  /// The board draws the 任务进度 card with 2 / 3 in it, but no way to say what
  /// the three are — and until this existed, nothing in the app called
  /// `addSubtask` at all. The card, its rows and its controller method were all
  /// built and tested and unreachable, which made them a card that could never
  /// render. This is the missing entrance, not a new feature: everything below
  /// it already existed.
  Future<void> _addSubtask(
    BuildContext context,
    TaskDetailController controller,
  ) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _TextPromptDialog(
        title: '添加子任务',
        hint: '这一步要做什么',
        confirmLabel: '添加',
      ),
    );

    // A blank title is not a subtask. Letting it through would put an unnamed
    // row in the progress count and move the fraction for nothing.
    final title = saved?.trim() ?? '';
    if (title.isEmpty) return;
    await controller.addSubtask(title);
  }
}

/// A one-field dialog that owns its own [TextEditingController].
///
/// The controller has to be disposed with the dialog, not after `showDialog`
/// returns. The route is still animating out when that future completes, the
/// `TextField` rebuilds once more on the way, and a controller disposed at that
/// point throws `A TextEditingController was used after being disposed` — in
/// debug it is a red screen, and in release it is a controller read after
/// disposal.
///
/// Both prompts on this page used to create and dispose their controller around
/// the `showDialog` call. The subtask prompt is what surfaced it, because the
/// note editor had no test at all; both are fixed by this widget, and the note
/// editor now has a test that would have caught it.
class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String initial;
  final String confirmLabel;
  final int maxLines;

  const _TextPromptDialog({
    required this.title,
    required this.hint,
    this.initial = '',
    this.confirmLabel = '保存',
    this.maxLines = 1,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _text =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        maxLines: widget.maxLines,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        // A single-line prompt can be confirmed from the keyboard; a multiline
        // one cannot, because Enter has to insert a newline there.
        onSubmitted: widget.maxLines == 1
            ? (value) => Navigator.of(context).pop(value)
            : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// The entrance to the subtask list: one row, tapping it asks for the title.
///
/// A row rather than a permanent text field, because the board's 任务详情 draws
/// no field on the page and an always-open input would be chrome the design does
/// not have. The label is the row's own text, so a screen reader reads the same
/// words the eye does and the tap stays on the row.
class _AddSubtaskRow extends StatelessWidget {
  final VoidCallback onTap;

  const _AddSubtaskRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.add_rounded,
                size: 18,
                color: AppColors.primarySage,
              ),
              SizedBox(width: 8),
              Text(
                '添加子任务',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final TaskWithProgress progress;
  final ValueChanged<TaskSubtask> onToggle;

  const _ProgressCard({required this.progress, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.donut_small_rounded,
                  size: 16, color: AppColors.primarySage),
              const SizedBox(width: 6),
              const Text(
                '任务进度',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                progress.progressLabel!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress.progressFraction,
              minHeight: 6,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: const AlwaysStoppedAnimation(AppColors.primarySage),
            ),
          ),
          const SizedBox(height: 12),
          for (final subtask in progress.subtasks)
            Semantics(
              excludeSemantics: true,
              onTap: () => onToggle(subtask),
              button: true,
              label: '${subtask.isDone ? '取消完成' : '完成'} ${subtask.title}',
              child: InkWell(
                onTap: () => onToggle(subtask),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        subtask.isDone
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: subtask.isDone
                            ? AppColors.primarySage
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          subtask.title,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            decoration: subtask.isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  /// Set when the card leads somewhere. The design's 下次计划 tile is a way into
  /// the schedule form, so it has to be tappable rather than a dead readout.
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.primarySage),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right,
                    size: 16, color: AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: card,
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Task task;
  final VoidCallback onEdit;

  const _NoteCard({required this.task, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final note = task.note;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sticky_note_2_rounded,
                  size: 15, color: AppColors.primarySage),
              const SizedBox(width: 6),
              const Text(
                '任务备注',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('编辑', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            note == null || note.isEmpty ? '还没有备注。' : note,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: note == null || note.isEmpty
                  ? AppColors.textTertiary
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentFocusCard extends StatelessWidget {
  final List<TaskFocusEntry> entries;

  const _RecentFocusCard({required this.entries});

  static String _clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 15, color: AppColors.primarySage),
              SizedBox(width: 6),
              Text(
                '最近专注记录',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${entry.startAt.month} 月 ${entry.startAt.day} 日  '
                      '${_clock(entry.startAt)} - ${_clock(entry.endAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    formatTaskDuration(entry.durationSeconds),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MissingTask extends StatelessWidget {
  const _MissingTask();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 40, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text(
              '这个任务不在了',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '它可能已经被删除了。返回列表看看其它任务吧。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
