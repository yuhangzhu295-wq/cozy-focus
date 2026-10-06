import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/distraction_note.dart';
import '../../domain/models/task.dart';
import '../controllers/distraction_controller.dart';
import '../controllers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/task_category_chip.dart';

/// Screen 13: 分心箱清单 — what the focus sessions collected, waiting to be dealt
/// with.
///
/// ## Why the rows are not tasks
///
/// A note is a thought the user had while working, not something they agreed to
/// do. It sits here until they decide, and the two ways out — 转成任务 and 安排到
/// 今天 — are the only paths from this list into the task domain. That is why
/// nothing here appears in the task list or on today's plan until it is converted.
class DistractionInboxPage extends ConsumerWidget {
  const DistractionInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(distractionInboxControllerProvider);
    final controller = ref.read(distractionInboxControllerProvider.notifier);
    // Read once per build rather than per row, so every row in one frame is dated
    // against the same "now" and two notes from the same minute cannot disagree.
    final now = ref.read(focusClockProvider).now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text(
          '分心箱清单',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // The design's ⋯. It is a real menu: it explains what the list is and
          // offers the one bulk action that exists, clearing what has been dealt
          // with. A menu with nothing behind it would be decoration.
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(Icons.more_horiz_rounded,
                color: AppColors.textSecondary),
            onSelected: (value) async {
              if (value != 'explain') return;
              await showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('分心箱是什么'),
                  content: const Text(
                    '专注时想到的事情会先收到这里，不必马上处理。\n'
                    '专注结束后，可以把它转成任务、安排到今天，或者直接删掉。',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('知道了'),
                    ),
                  ],
                ),
              );
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'explain', child: Text('分心箱是什么')),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _FilterChips(
            active: state.filter,
            activeCategory: state.categoryFilter,
            openTotal: state.openTotal,
            counts: state.openCounts,
            onChanged: controller.setFilter,
            onCategory: controller.setCategoryFilter,
          ),
          Expanded(
            child: switch (state) {
              DistractionInboxState(isLoading: true, notes: []) =>
                const Center(child: CircularProgressIndicator()),
              DistractionInboxState(error: final String error) => _ErrorState(
                  message: error,
                  onRetry: controller.load,
                ),
              DistractionInboxState(notes: final List<DistractionNote> notes)
                  when notes.isEmpty =>
                _EmptyState(filter: state.filter),
              _ => RefreshIndicator(
                  onRefresh: controller.load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    itemCount: state.notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _NoteRow(
                      note: state.notes[index],
                      now: now,
                      onToggle: () => _toggle(ref, state.notes[index]),
                      onActions: () =>
                          _showActions(context, ref, state.notes[index]),
                    ),
                  ),
                ),
            },
          ),
        ],
      ),
    );
  }

  /// The tick: handled, or back to waiting.
  ///
  /// One control for both directions, because the inbox shows both states and a
  /// user who ticked the wrong row has to be able to undo it from here.
  Future<void> _toggle(WidgetRef ref, DistractionNote note) async {
    final controller = ref.read(distractionInboxControllerProvider.notifier);
    if (note.isOpen) {
      await controller.markHandled(note);
    } else {
      await controller.reopen(note);
    }
  }

  /// The row's ⋯: 转成任务 / 安排到今天 / 删除.
  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    DistractionNote note,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      note.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (TaskCategoryChip.maybe(note.categoryId)
                      case final Widget chip)
                    chip,
                ],
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.playlist_add_check_rounded,
                  color: AppColors.primarySage),
              title: const Text('转成任务'),
              subtitle:
                  const Text('创建为任务，方便后续管理', style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.of(sheetContext).pop('task'),
            ),
            ListTile(
              leading: const Icon(Icons.event_available_rounded,
                  color: AppColors.primarySage),
              title: const Text('安排到今天'),
              subtitle: const Text('添加到今日计划', style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.of(sheetContext).pop('today'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.accentPeach),
              title: const Text('删除',
                  style: TextStyle(color: AppColors.accentPeach)),
              subtitle: const Text('从分心箱中移除', style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;
    final controller = ref.read(distractionInboxControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    switch (action) {
      case 'task':
        final taskId = await controller.convertToTask(note);
        // Says what happened to the note, not what the row will say about it:
        // the row keeps 已转成任务 as a state, and two places saying the same
        // words about two different things is how a user reads one as the other.
        messenger.showSnackBar(SnackBar(
          content: const Text('已加入任务列表'),
          action: SnackBarAction(
            label: '查看',
            onPressed: () => context.push('/records/tasks/$taskId'),
          ),
        ));
      case 'today':
        final taskId =
            await controller.convertToTask(note, alsoPlaceToday: true);
        messenger.showSnackBar(SnackBar(
          content: const Text('已安排到今天'),
          action: SnackBarAction(
            label: '查看',
            onPressed: () => context.push('/records/tasks/$taskId'),
          ),
        ));
      case 'delete':
        await controller.delete(note);
    }
  }
}

/// 全部 / 生活 / 工作 / 学习, with the counts the design shows.
///
/// The counts are of the whole inbox rather than of the current filter, so
/// switching filter does not renumber the chips — they say how much is waiting,
/// which is the thing the user is deciding about.
class _FilterChips extends StatelessWidget {
  final DistractionFilter active;
  final String? activeCategory;
  final int openTotal;
  final Map<String, int> counts;
  final ValueChanged<DistractionFilter> onChanged;
  final ValueChanged<String> onCategory;

  const _FilterChips({
    required this.active,
    required this.activeCategory,
    required this.openTotal,
    required this.counts,
    required this.onChanged,
    required this.onCategory,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <(DistractionFilter, String, int)>[
      (DistractionFilter.open, '待处理', openTotal),
      (DistractionFilter.handled, '已处理', 0),
      (DistractionFilter.all, '全部', 0),
    ];
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        children: [
          for (final (filter, label, count) in chips) ...[
            _Chip(
              key: ValueKey('inbox_filter_${filter.id}'),
              label: count > 0 ? '$label ($count)' : label,
              selected: filter == active,
              onTap: () => onChanged(filter),
            ),
            const SizedBox(width: 8),
          ],
          // Then one chip per category that actually has something in it, so the
          // row never grows empty tabs for categories the user has not used.
          for (final category in taskCategories)
            if ((counts[category.id] ?? 0) > 0) ...[
              _Chip(
                key: ValueKey('inbox_category_${category.id}'),
                label: '${category.label} (${counts[category.id]})',
                selected: activeCategory == category.id,
                onTap: () => onCategory(category.id),
              ),
              const SizedBox(width: 8),
            ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.primarySage : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primaryDark : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// One note: a tick, its text, its tag, and when it arrived.
class _NoteRow extends StatelessWidget {
  final DistractionNote note;
  final DateTime now;
  final VoidCallback onToggle;
  final VoidCallback onActions;

  const _NoteRow({
    required this.note,
    required this.now,
    required this.onToggle,
    required this.onActions,
  });

  @override
  Widget build(BuildContext context) {
    final handled = !note.isOpen;
    return Material(
      color: handled ? AppColors.surfaceMuted : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: handled ? '标记为待处理' : '标记为已处理',
              child: GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Icon(
                    handled ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 22,
                    color: handled
                        ? AppColors.primarySage
                        : AppColors.textTertiary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      decoration: handled ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (TaskCategoryChip.maybe(note.categoryId)
                          case final Widget chip) ...[
                        chip,
                        const SizedBox(width: 8),
                      ],
                      const Icon(Icons.schedule_rounded,
                          size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        formatNoteMoment(note.createdAt, now),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  if (note.wasConverted) ...[
                    const SizedBox(height: 6),
                    const Text(
                      '已转成任务',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.primarySage),
                    ),
                  ],
                ],
              ),
            ),
            Semantics(
              button: true,
              label: '${note.text} 的操作',
              child: IconButton(
                onPressed: onActions,
                icon: const Icon(Icons.more_horiz_rounded,
                    size: 20, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `10 月 8 日 14:23`, or `今天 14:23` when it is from today.
String formatNoteMoment(DateTime at, DateTime now) {
  final time =
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final difference = day.difference(today).inDays;
  if (difference == 0) return '今天 $time';
  if (difference == -1) return '昨天 $time';
  return '${at.month} 月 ${at.day} 日 $time';
}

/// An inbox with nothing under the current filter.
class _EmptyState extends StatelessWidget {
  final DistractionFilter filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (filter) {
      DistractionFilter.open => ('分心箱是空的', '专注时想到别的事情，点「记一下」把它收进来，\n不用打断手上的事。'),
      DistractionFilter.handled => ('还没有处理过的想法', '处理过的想法会留在这里，方便回头看。'),
      DistractionFilter.all => ('分心箱是空的', '专注时想到的事情会先收到这里。'),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded,
                size: 44, color: AppColors.textTertiary),
            const SizedBox(height: 14),
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
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

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
              '分心箱没能读出来',
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
