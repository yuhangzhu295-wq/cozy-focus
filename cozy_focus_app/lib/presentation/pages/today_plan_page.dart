import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/task.dart';
import '../../domain/models/task_schedule.dart';
import '../../domain/models/timeline_entry.dart';
import '../controllers/focus_session_controller.dart';
import '../controllers/timeline_controller.dart';
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
              // Only the plan view has this empty state. On an empty day the
              // timeline still has something to say — it may hold focus records
              // and captured thoughts that no plan row accounts for — so the
              // guard asks which view is showing, not only whether the plan is
              // empty. Without it, switching to 时间线 on a day with no
              // placements showed the plan's empty state and the timeline tab
              // was unreachable.
              TodayPlanState(placements: final List<PlannedTask> placements)
                  when placements.isEmpty && !_timeline =>
                const _EmptyState(),
              _ => RefreshIndicator(
                  onRefresh: controller.load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    children: [
                      // The card belongs to the plan view. The timeline is a
                      // record of the day rather than a prompt about it, and the
                      // design puts no 下一个任务 on it — the running session is
                      // the row it highlights instead.
                      if (_timeline)
                        _DayTimeline(
                          day: state.day,
                          onStopRunning: _stopRunningSession,
                        )
                      else ...[
                        if (state.next case final PlannedTask next) ...[
                          _NextTaskCard(
                            placement: next,
                            onStart: () => _start(context, next),
                          ),
                          const SizedBox(height: 18),
                        ],
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

  /// Ends the session that is running, from its timeline row.
  ///
  /// Goes through the focus controller, so the session is completed and saved the
  /// same way it is from the focus screen — the timeline reads facts, it does not
  /// write them.
  Future<void> _stopRunningSession(String sessionId) async {
    await ref.read(focusSessionControllerProvider.notifier).completeSession();
    await ref.read(todayPlanControllerProvider.notifier).load();
    if (mounted) context.go('/focus/complete');
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
            _segment('计划', !timeline, () => onChanged(false), 'plan_view_list'),
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

/// The day as a timeline: plans, focus and captured thoughts on one axis.
///
/// ## Why the rows are not the plan rows again
///
/// The plan view answers "what did I intend"; this answers "what does the day
/// actually look like". A plan and the focus that followed it are two rows,
/// because they are two facts — the gap between them is the interesting part.
///
/// The projection lives in `timeline_projection.dart`; this widget only draws it.
class _DayTimeline extends ConsumerWidget {
  final DateTime day;
  final Future<void> Function(String sessionId) onStopRunning;

  const _DayTimeline({required this.day, required this.onStopRunning});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(dayTimelineProvider(day));

    return switch (entries) {
      AsyncData(:final value) when value.isEmpty => const _TimelineEmpty(),
      AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TimelineLegend(kinds: {for (final e in value) e.kind}),
            const SizedBox(height: 12),
            for (var i = 0; i < value.length; i++)
              _TimelineRow(
                entry: value[i],
                last: i == value.length - 1,
                onStopRunning: onStopRunning,
              ),
          ],
        ),
      AsyncError(:final error) => Text(
          '时间线没能读出来：$error',
          style: const TextStyle(fontSize: 12, color: AppColors.accentPeach),
        ),
      _ => const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
    };
  }
}

/// The legend, built from the kinds the day actually has.
///
/// A legend listing 休息 on a day with no rest would be a key to nothing, so it
/// only names what is on screen.
class _TimelineLegend extends StatelessWidget {
  final Set<TimelineKind> kinds;

  const _TimelineLegend({required this.kinds});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final kind in TimelineKind.values)
          if (kinds.contains(kind))
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _kindColor(kind),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  kind.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
      ],
    );
  }
}

Color _kindColor(TimelineKind kind) => switch (kind) {
      TimelineKind.plan => AppColors.primarySage,
      TimelineKind.focus => AppColors.primaryDark,
      TimelineKind.rest => AppColors.catStudy,
      TimelineKind.note => AppColors.accentGold,
    };

IconData _kindIcon(TimelineKind kind) => switch (kind) {
      TimelineKind.plan => Icons.check_circle_outline,
      TimelineKind.focus => Icons.adjust_rounded,
      TimelineKind.rest => Icons.local_cafe_outlined,
      TimelineKind.note => Icons.edit_note_rounded,
    };

/// One row: the time, a dot on the axis, and what happened.
class _TimelineRow extends StatelessWidget {
  final TimelineEntry entry;
  final bool last;
  final Future<void> Function(String sessionId) onStopRunning;

  const _TimelineRow({
    required this.entry,
    required this.last,
    required this.onStopRunning,
  });

  @override
  Widget build(BuildContext context) {
    final color = _kindColor(entry.kind);
    final detail = entry.detail;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 46,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                entry.clock,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          // The axis: a dot for this row, and the line down to the next one.
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Container(
                  width: entry.isRunning ? 13 : 10,
                  height: entry.isRunning ? 13 : 10,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: entry.isDone ? AppColors.surface : color,
                    border: Border.all(color: color, width: 2),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 1.5, color: AppColors.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 18),
              child: _TimelineCard(
                entry: entry,
                color: color,
                detail: detail,
                onStopRunning: onStopRunning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final TimelineEntry entry;
  final Color color;
  final String? detail;
  final Future<void> Function(String sessionId) onStopRunning;

  const _TimelineCard({
    required this.entry,
    required this.color,
    required this.detail,
    required this.onStopRunning,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Icon(
          _kindIcon(entry.kind),
          size: 18,
          color: entry.isDone ? AppColors.textTertiary : color,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.isRunning ? '专注中：${entry.title}' : entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      entry.isRunning ? FontWeight.w700 : FontWeight.w600,
                  color: AppColors.textPrimary,
                  decoration: entry.isDone ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.textTertiary,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 3),
                Text(
                  detail!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Only the running session has a control here. It is the one row the
        // user can act on, and stopping it goes through the focus controller
        // rather than touching a record.
        if (entry.isRunning)
          Semantics(
            key: const ValueKey('timeline_stop_running'),
            button: true,
            label: '结束这次专注',
            child: IconButton(
              onPressed: () => onStopRunning(entry.sourceId!),
              icon: const Icon(Icons.stop_circle_rounded,
                  size: 26, color: AppColors.primaryDark),
            ),
          ),
      ],
    );

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, entry.isRunning ? 4 : 12, 10),
      decoration: BoxDecoration(
        color: entry.isRunning ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: entry.isRunning ? AppColors.primarySage : AppColors.border,
        ),
      ),
      child: content,
    );
  }
}

class _TimelineEmpty extends StatelessWidget {
  const _TimelineEmpty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.timeline_rounded, size: 40, color: AppColors.textTertiary),
          SizedBox(height: 12),
          Text(
            '这一天还没有任何记录',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '安排一件事、开始一次专注，或者随手记下一个想法，\n它们都会出现在这条时间线上。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
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
