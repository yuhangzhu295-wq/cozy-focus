import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/task.dart';
import '../../domain/services/today_planner.dart';
import '../controllers/providers.dart';
import '../controllers/today_plan_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/task_category_chip.dart';
import '../widgets/task_duration.dart';

/// Screen 14: 安排到今日计划 — giving a task a time and a length.
///
/// ## Why it is a page and not a sheet
///
/// The design draws it as a page with a back arrow, and the content justifies it:
/// four decisions (which day, which time, how long, and confirming) do not fit a
/// half-height sheet without scrolling the confirm button off screen.
///
/// ## What 推荐时段 actually means
///
/// The times offered are computed from the day's existing plan — half-hour
/// starts, minus the ones that collide with something already placed, minus the
/// ones already past. There is no habit model behind them and the UI does not
/// claim one.
class ScheduleToTodayPage extends ConsumerStatefulWidget {
  const ScheduleToTodayPage({super.key, required this.taskId, this.initialDay});

  final String taskId;

  /// The day to open on. Defaults to today.
  final DateTime? initialDay;

  @override
  ConsumerState<ScheduleToTodayPage> createState() =>
      _ScheduleToTodayPageState();
}

class _ScheduleToTodayPageState extends ConsumerState<ScheduleToTodayPage> {
  @override
  Widget build(BuildContext context) {
    final task = ref.watch(schedulingTaskProvider(widget.taskId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text(
          '安排到今日计划',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: switch (task) {
        AsyncData(:final value) when value != null => _Form(
            key: ValueKey('schedule_form_${widget.taskId}'),
            task: value,
            initialDay: widget.initialDay,
          ),
        AsyncData() => const _MissingTask(),
        AsyncError(:final error) => _LoadFailure(message: '$error'),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// The form itself, holding the four choices until 添加到今日计划 is pressed.
class _Form extends ConsumerStatefulWidget {
  const _Form({super.key, required this.task, this.initialDay});

  final Task task;
  final DateTime? initialDay;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late DateTime _day;
  late TimeOfDay _start;
  late int _seconds;
  bool _saving = false;
  String? _error;

  static const List<int> _presets = [25, 40, 50, 60];

  @override
  void initState() {
    super.initState();
    final now = ref.read(focusClockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    _day = widget.initialDay ?? today;
    final defaultStart = defaultStartFor(day: _day, now: now);
    _start = TimeOfDay(hour: defaultStart.hour, minute: defaultStart.minute);
    // The task's own estimate is the first answer, because the user already said
    // how long they think it takes. 25 minutes is the fallback for a task with no
    // estimate, not a number invented here.
    _seconds = widget.task.estimatedSeconds > 0
        ? widget.task.estimatedSeconds
        : 25 * 60;
  }

  bool get _isToday {
    final now = ref.read(focusClockProvider).now();
    return _day.year == now.year &&
        _day.month == now.month &&
        _day.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(recommendedSlotsProvider(
      (taskId: widget.task.id, day: _day, durationSeconds: _seconds),
    ));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              _TaskCard(task: widget.task),
              const SizedBox(height: 18),
              const _SectionLabel(
                  icon: Icons.calendar_today_rounded, text: '选择日期'),
              const SizedBox(height: 8),
              _DateField(day: _day, isToday: _isToday, onPick: _pickDay),
              const SizedBox(height: 18),
              const _SectionLabel(icon: Icons.schedule_rounded, text: '推荐时段'),
              const SizedBox(height: 8),
              switch (slots) {
                AsyncData(:final value) when value.isNotEmpty => _SlotChips(
                    slots: value,
                    selected: _start,
                    onPick: (slot) =>
                        setState(() => _start = TimeOfDay.fromDateTime(slot)),
                  ),
                AsyncData() => const _SlotNote('今天剩下的时间都排满了，可以直接选一个时间。'),
                AsyncError() => const _SlotNote('暂时算不出空闲时段，可以直接选一个时间。'),
                _ => const SizedBox(height: 44),
              },
              const SizedBox(height: 18),
              const _SectionLabel(
                  icon: Icons.access_time_rounded, text: '开始时间'),
              const SizedBox(height: 8),
              _StartTimeField(start: _start, onPick: _pickStart),
              const SizedBox(height: 18),
              const _SectionLabel(icon: Icons.timer_outlined, text: '专注时长'),
              const SizedBox(height: 8),
              _DurationChips(
                seconds: _seconds,
                presets: _presets,
                onPick: (seconds) => setState(() => _seconds = seconds),
                onCustom: _pickCustomDuration,
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Above the button rather than at the end of the scroll: an error
                // about the value being saved has to be next to the thing that
                // saves it, not somewhere the user has to scroll back to find.
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accentPeach,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primarySage,
                      foregroundColor: AppColors.textLight,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textLight,
                            ),
                          )
                        : const Text('添加到今日计划',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(_day.year - 1),
      lastDate: DateTime(_day.year + 2),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _day = DateTime(picked.year, picked.month, picked.day);
      // The old start time may be in the past on the newly chosen day.
      final start = defaultStartFor(
        day: _day,
        now: ref.read(focusClockProvider).now(),
      );
      _start = TimeOfDay(hour: start.hour, minute: start.minute);
    });
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(context: context, initialTime: _start);
    if (picked == null || !mounted) return;
    setState(() => _start = picked);
  }

  Future<void> _pickCustomDuration() async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (_) => _CustomDurationDialog(minutes: _seconds ~/ 60),
    );
    if (minutes == null || !mounted) return;
    // Refused rather than clamped: silently turning "0" into 1 minute, or "9999"
    // into 600, would save a plan the user did not ask for.
    if (minutes < 1 || minutes > 600) {
      setState(() => _error = '时长需要在 1 到 600 分钟之间。');
      return;
    }
    setState(() {
      _error = null;
      _seconds = minutes * 60;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await ref.read(todayPlanControllerProvider.notifier).place(
            taskId: widget.task.id,
            day: _day,
            startAt: DateTime(0, 1, 1, _start.hour, _start.minute),
            plannedSeconds: _seconds,
          );
      if (!mounted) return;
      context.pop(id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '没能保存这个安排：$error';
      });
    }
  }
}

/// The 自定义 duration dialog.
///
/// A widget rather than an inline `AlertDialog` so the text controller's lifetime
/// is the dialog's: disposing it in the caller as soon as `showDialog` returns
/// leaves the field listening to a disposed controller while the dialog is still
/// animating out, which throws.
class _CustomDurationDialog extends StatefulWidget {
  final int minutes;

  const _CustomDurationDialog({required this.minutes});

  @override
  State<_CustomDurationDialog> createState() => _CustomDurationDialogState();
}

class _CustomDurationDialogState extends State<_CustomDurationDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.minutes.toString());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('自定义时长'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: '分钟',
          helperText: '1 到 600 分钟',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(int.tryParse(_controller.text.trim())),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final category = taskCategoryFor(task.categoryId);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => context.push('/records/tasks/${task.id}'),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.task_alt_rounded,
                    size: 20, color: AppColors.primarySage),
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (task.note != null && task.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (category != null) ...[
                      const SizedBox(height: 8),
                      TaskCategoryChip(
                          categoryId: category.id, label: category.label),
                    ],
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

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primarySage),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// `今天 10 月 8 日 · 周三`.
class _DateField extends StatelessWidget {
  final DateTime day;

  /// Whether [day] is today, decided by the form from the app's clock rather
  /// than from a second `DateTime.now()` read here.
  final bool isToday;
  final VoidCallback onPick;

  const _DateField({
    required this.day,
    required this.isToday,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final label = '${isToday ? '今天 ' : ''}${day.month} 月 ${day.day} 日 · '
        '周${weekdays[day.weekday - 1]}';

    return Semantics(
      button: true,
      label: '选择日期 $label',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotChips extends StatelessWidget {
  final List<DateTime> slots;
  final TimeOfDay selected;
  final ValueChanged<DateTime> onPick;

  const _SlotChips({
    required this.slots,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: slots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final slot = slots[index];
          final active =
              slot.hour == selected.hour && slot.minute == selected.minute;
          final label = '${slot.hour.toString().padLeft(2, '0')}:'
              '${slot.minute.toString().padLeft(2, '0')}';
          return Semantics(
            button: true,
            selected: active,
            label: index == 0 ? '$label 推荐' : label,
            child: GestureDetector(
              onTap: () => onPick(slot),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? AppColors.primaryLight : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: active ? AppColors.primarySage : AppColors.border,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? AppColors.primaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (index == 0)
                      const Text(
                        '推荐',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primarySage,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SlotNote extends StatelessWidget {
  final String text;

  const _SlotNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
    );
  }
}

/// The chosen start, big, with a picker behind it.
class _StartTimeField extends StatelessWidget {
  final TimeOfDay start;
  final VoidCallback onPick;

  const _StartTimeField({required this.start, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final hour = start.hour.toString().padLeft(2, '0');
    final minute = start.minute.toString().padLeft(2, '0');
    return Semantics(
      button: true,
      label: '开始时间 $hour:$minute',
      child: Material(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  hour,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  minute,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationChips extends StatelessWidget {
  final int seconds;
  final List<int> presets;
  final ValueChanged<int> onPick;
  final VoidCallback onCustom;

  const _DurationChips({
    required this.seconds,
    required this.presets,
    required this.onPick,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final isPreset = presets.any((minutes) => minutes * 60 == seconds);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final minutes in presets)
          _chip(
            label: minutes == 60 ? '1 小时' : '$minutes 分钟',
            active: seconds == minutes * 60,
            onTap: () => onPick(minutes * 60),
          ),
        _chip(
          label: isPreset ? '自定义' : formatTaskDuration(seconds),
          active: !isPreset,
          onTap: onCustom,
        ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: active ? AppColors.primarySage : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.primaryDark : AppColors.textPrimary,
            ),
          ),
        ),
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
        child: Text(
          '这个任务已经不在了。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  final String message;

  const _LoadFailure({required this.message});

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
          ],
        ),
      ),
    );
  }
}
