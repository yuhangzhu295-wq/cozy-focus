import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/task.dart';
import '../../domain/models/task_schedule.dart';
import '../controllers/today_plan_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/task_category_chip.dart';
import '../widgets/task_duration.dart';

/// Screen 03: 今日计划, reached from 记录 > 今日计划.
///
/// ## Why it is a view of the plan rather than a second task list
///
/// The task list answers "what have I written down"; this answers "what am I
/// doing today, and in what order". The rows come from `task_schedules`, so a
/// task with no time on it is not here — which is what makes the two screens
/// worth having separately rather than a filter apart.
///
/// ## Why 时间线 is a second layout of the same list
///
/// The segment switches how the same placements are drawn: a plain list, or a
/// vertical axis where the gap between rows is the gap between their times. It
/// is not a second data source and it does not query anything the list does not.
class TodayPlanPage extends ConsumerStatefulWidget {
  const TodayPlanPage({super.key});

  @override
  ConsumerState<TodayPlanPage> createState() => _TodayPlanPageState();
}

class _TodayPlanPageState extends ConsumerState<TodayPlanPage> {
  bool _timeline = false;

  @override
  void initState() {
    super.initState();
    // The controller may already exist — the records tab watches it for its
    // count — and its state would then be from whenever that tab was built. A
    // plan screen that opens on a stale day is worse than one that costs a query.
    Future.microtask(
      () => ref.read(todayPlanControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todayPlanControllerProvider);
    final controller = ref.read(todayPlanControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '今天',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              _dayLabel(state.day),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '选择日期',
            onPressed: () => _pickDay(context, state.day),
            icon: const Icon(Icons.calendar_month_rounded,
                color: AppColors.primarySage),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _Segments(
            timeline: _timeline,
            onChanged: (value) => setState(() => _timeline = value),
          ),
          Expanded(
            child: switch (state) {
              TodayPlanState(isLoading: true, placements: []) =>
                const Center(child: CircularProgressIndicator()),
              TodayPlanState(error: final String error) => _ErrorState(
                  message: error,
                  onRetry: controller.load,
                ),
              TodayPlanState(placements: final List<PlannedTask> placements)
                  when placements.isEmpty =>
                const _EmptyState(),
              _ => RefreshIndicator(
                  onRefresh: controller.load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    children: [
                      if (state.next case final PlannedTask next) ...[
                        _NextTaskCard(
                          placement: next,
                          onStart: () => _start(context, next),
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (_timeline)
                        _TimelineView(
                          placements: state.placements,
                          onOpen: (placement) => _open(context, placement),
                          onLongPress: (placement) =>
                              _placementActions(context, placement),
                        )
                      else
                        for (final placement in state.placements) ...[
                          _PlanRow(
                            placement: placement,
                            onOpen: () => _open(context, placement),
                            onLongPress: () =>
                                _placementActions(context, placement),
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickDay(BuildContext context, DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 1),
      lastDate: DateTime(current.year + 2),
    );
    if (picked == null) return;
    await ref.read(todayPlanControllerProvider.notifier).showDay(picked);
  }

  /// Starts the focus flow for a placement.
  ///
  /// The same `/focus/setup?taskId=` route the task detail screen uses, so a
  /// session started from the plan is a session started from anywhere: one focus
  /// engine, one place the session is created.
  Future<void> _start(BuildContext context, PlannedTask placement) async {
    await context.push('/focus/setup?taskId=${placement.schedule.taskId}');
    await ref.read(todayPlanControllerProvider.notifier).load();
  }

  Future<void> _open(BuildContext context, PlannedTask placement) async {
    await context.push('/records/tasks/${placement.schedule.taskId}');
    await ref.read(todayPlanControllerProvider.notifier).load();
  }

  /// What a long press on a placement offers: finish it, or take it off the day.
  ///
  /// Both write to the database. Neither deletes the task — the sheet says 从今日
  /// 移除 rather than 删除 because that is what it does.
  Future<void> _placementActions(
    BuildContext context,
    PlannedTask placement,
  ) async {
    final controller = ref.read(todayPlanControllerProvider.notifier);
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
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  placement.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                placement.schedule.isPlanned
                    ? Icons.check_circle_outline
                    : Icons.undo_rounded,
                color: AppColors.primarySage,
              ),
              title: Text(placement.schedule.isPlanned ? '标记为已完成' : '标记为未完成'),
              onTap: () => Navigator.of(sheetContext).pop(
                placement.schedule.isPlanned ? 'done' : 'planned',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.event_busy_rounded,
                  color: AppColors.accentPeach),
              title: const Text('从今日移除'),
              onTap: () => Navigator.of(sheetContext).pop('remove'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    switch (action) {
      case 'done':
        await controller.setStatus(
            placement.schedule.id, TaskScheduleStatus.done);
      case 'planned':
        await controller.setStatus(
            placement.schedule.id, TaskScheduleStatus.planned);
      case 'remove':
        await controller.removePlacement(placement.schedule.id);
    }
  }
}

/// `10 月 8 日 · 周三`, the way the design writes a day.
String _dayLabel(DateTime day) {
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  return '${day.month} 月 ${day.day} 日 · 周${weekdays[day.weekday - 1]}';
}

/// `09:00`.
String _timeLabel(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

class _Segments extends StatelessWidget {
  final bool timeline;
  final ValueChanged<bool> onChanged;

  const _Segments({required this.timeline, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          children: [
            _segment('列表', !timeline, () => onChanged(false), 'plan_view_list'),
            _segment(
                '时间线', timeline, () => onChanged(true), 'plan_view_timeline'),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label, bool active, VoidCallback onTap, String key) {
    return Expanded(
      child: Semantics(
        key: ValueKey(key),
        button: true,
        selected: active,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 下一个任务 card, with the one button that starts it.
class _NextTaskCard extends StatelessWidget {
  final PlannedTask placement;
  final VoidCallback onStart;

  const _NextTaskCard({required this.placement, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final category = taskCategoryFor(placement.categoryId);
    final subtitle = [
      formatTaskDuration(placement.schedule.plannedSeconds),
      if (category != null) category.label,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '下一个任务',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primarySage,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  placement.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('开始'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primarySage,
              foregroundColor: AppColors.textLight,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One placement as a list row: time, title, duration, category.
class _PlanRow extends StatelessWidget {
  final PlannedTask placement;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;

  const _PlanRow({
    required this.placement,
    required this.onOpen,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final done = !placement.schedule.isPlanned;
    final color = taskCategoryColor(placement.categoryId);
    final chip = TaskCategoryChip.maybe(placement.categoryId);

    return Material(
      color: done ? AppColors.primaryLight : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onOpen,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  _timeLabel(placement.schedule.startAt),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 12),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placement.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatTaskDuration(placement.schedule.plannedSeconds),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (done)
                const Icon(Icons.check_circle,
                    size: 18, color: AppColors.primarySage)
              else if (chip != null)
                chip,
            ],
          ),
        ),
      ),
    );
  }
}

/// The same placements on a vertical axis, where the distance between two rows
/// is the distance between their times.
///
/// Capped so a six-hour gap does not push the rest of the day off screen: the
/// axis is a hint about spacing, not a scale drawing, and the times are written
/// on every row anyway.
class _TimelineView extends StatelessWidget {
  final List<PlannedTask> placements;
  final ValueChanged<PlannedTask> onOpen;
  final ValueChanged<PlannedTask> onLongPress;

  const _TimelineView({
    required this.placements,
    required this.onOpen,
    required this.onLongPress,
  });

  static const double _maxGap = 56;
  static const double _minGap = 26;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < placements.length; i++) ...[
          if (i > 0)
            SizedBox(
              height: _gapBetween(placements[i - 1], placements[i]),
              child: Padding(
                padding: const EdgeInsets.only(left: 60),
                child: Container(width: 1, color: AppColors.border),
              ),
            ),
          _TimelineRow(
            placement: placements[i],
            onTap: () => onOpen(placements[i]),
            onLongPress: () => onLongPress(placements[i]),
          ),
        ],
      ],
    );
  }

  double _gapBetween(PlannedTask earlier, PlannedTask later) {
    final minutes =
        later.schedule.startAt.difference(earlier.schedule.startAt).inMinutes;
    return (minutes.toDouble()).clamp(_minGap, _maxGap);
  }
}

class _TimelineRow extends StatelessWidget {
  final PlannedTask placement;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TimelineRow({
    required this.placement,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final done = !placement.schedule.isPlanned;
    final chip = TaskCategoryChip.maybe(placement.categoryId);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 46,
            child: Text(
              _timeLabel(placement.schedule.startAt),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 0),
            decoration: BoxDecoration(
              color: done
                  ? AppColors.surface
                  : taskCategoryColor(placement.categoryId),
              border: Border.all(
                color: taskCategoryColor(placement.categoryId),
                width: 2,
              ),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    placement.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatTaskDuration(placement.schedule.plannedSeconds),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (chip != null) chip,
        ],
      ),
    );
  }
}

/// A day with nothing planned.
///
/// The button goes to the task list rather than opening the schedule form,
/// because there is nothing to schedule yet: the form needs a task to place.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_note_rounded,
                size: 44, color: AppColors.textTertiary),
            const SizedBox(height: 14),
            const Text(
              '今天还没有安排',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '从任务里挑一件事，给它一个时间，它就会出现在这里。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => context.push('/records/tasks'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primarySage,
                foregroundColor: AppColors.textLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              child: const Text('去安排任务'),
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
              '今日计划没能读出来',
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
