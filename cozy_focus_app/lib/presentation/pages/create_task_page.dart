import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/task.dart';
import '../../domain/services/today_planner.dart';
import '../controllers/providers.dart';
import '../controllers/task_controller.dart';
import '../controllers/app_preferences_controller.dart';
import '../controllers/today_plan_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/task_duration.dart';

/// Screen 11: create a task.
///
/// ## 加入今日计划
///
/// On by default, and it does what it says: saving places the task on today's
/// plan through the same repository call the schedule page uses. The switch's
/// subtitle names the time it will be placed at, because "自动添加" that does not
/// say when is a promise the user cannot check.
///
/// ## Validation
///
/// The save button is disabled until there is a title, rather than accepting an
/// empty one and failing later. The counters are limits the field enforces, not
/// decoration: the design shows `0/30` and `0/100`, and a counter that does not
/// stop anything is a lie.
class CreateTaskPage extends ConsumerStatefulWidget {
  const CreateTaskPage({super.key});

  @override
  ConsumerState<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends ConsumerState<CreateTaskPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _customMinutes = TextEditingController();

  String? _categoryId;

  /// The design's 默认专注时长, from settings. Assigned once in `initState` rather
  /// than read on every build: the field is the user's working value, and a
  /// rebuild must not overwrite a choice they have already made on this screen.
  late int _estimatedSeconds = taskEstimatePresets.first;
  bool _customDuration = false;
  bool _joinToday = true;
  bool _saving = false;
  String? _error;

  /// Where 加入今日计划 would put the task.
  ///
  /// Computed from the clock and the day's existing plan, so the switch's
  /// subtitle and the placement that actually happens are the same value rather
  /// than two calculations that could drift.
  DateTime get _defaultStart => defaultStartFor(
        day: _today,
        now: ref.read(focusClockProvider).now(),
      );

  DateTime get _today {
    final now = ref.read(focusClockProvider).now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _estimatedSeconds = ref.read(defaultTaskEstimateProvider);
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _customMinutes.dispose();
    super.dispose();
  }

  int get _effectiveSeconds {
    if (!_customDuration) return _estimatedSeconds;
    final minutes = int.tryParse(_customMinutes.text.trim());
    if (minutes == null || minutes <= 0) return 0;
    return minutes * 60;
  }

  bool get _canSave =>
      _title.text.trim().isNotEmpty && _effectiveSeconds > 0 && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await createTask(
        repository: ref.read(taskRepositoryProvider),
        userId: ref.read(currentUserIdProvider),
        title: _title.text,
        categoryId: _categoryId,
        estimatedSeconds: _effectiveSeconds,
        note: _note.text,
      );
      if (_joinToday) {
        // Placed after the task exists, because a placement is a foreign key to
        // it. If this fails the task is still created and the error surfaces,
        // rather than the whole save being rolled back over the plan.
        await ref.read(todayPlanControllerProvider.notifier).place(
              taskId: id,
              day: _today,
              startAt: _defaultStart,
              plannedSeconds: _effectiveSeconds,
            );
      }
      if (mounted) context.pop(id);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text(
          '新建任务',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  const _SectionLabel(icon: Icons.edit_rounded, text: '任务名称'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _title,
                    maxLength: Task.maxTitleLength,
                    onChanged: (_) => setState(() {}),
                    decoration: _fieldDecoration(
                      hint: '输入任务名称...',
                      counter:
                          '${_title.text.characters.length}/${Task.maxTitleLength}',
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel(
                      icon: Icons.local_offer_rounded, text: '任务分类'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in taskCategories)
                        _ChoiceChip(
                          label: category.label,
                          selected: _categoryId == category.id,
                          onTap: () => setState(() => _categoryId =
                              _categoryId == category.id ? null : category.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel(
                      icon: Icons.schedule_rounded, text: '预计专注时间'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final seconds in taskEstimatePresets)
                        _ChoiceChip(
                          label: formatTaskDuration(seconds),
                          selected:
                              !_customDuration && _estimatedSeconds == seconds,
                          onTap: () => setState(() {
                            _customDuration = false;
                            _estimatedSeconds = seconds;
                          }),
                        ),
                      _ChoiceChip(
                        label: '自定义',
                        selected: _customDuration,
                        onTap: () => setState(() => _customDuration = true),
                      ),
                    ],
                  ),
                  if (_customDuration) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customMinutes,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration:
                          _fieldDecoration(hint: '输入分钟数', counter: null),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const _SectionLabel(
                      icon: Icons.sticky_note_2_rounded, text: '任务备注（可选）'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _note,
                    maxLength: Task.maxNoteLength,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: _fieldDecoration(
                      hint: '添加一些备注，帮助自己更专注...',
                      counter:
                          '${_note.text.characters.length}/${Task.maxNoteLength}',
                    ),
                  ),
                  const SizedBox(height: 18),
                  _JoinTodaySwitch(
                    value: _joinToday,
                    onChanged: (value) => setState(() => _joinToday = value),
                    subtitle: _joinToday
                        ? '保存后会自动添加到今天 ${_timeLabel(_defaultStart)} 的计划里。'
                        : '只保存任务，稍后再安排时间。',
                  ),
                ],
              ),
            ),
            // Pinned rather than the last row of the scroll: the design puts it
            // at the foot of the screen, and a save button that can be scrolled
            // out of reach is a save button a user has to hunt for.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null) ...[
                    Text(
                      '保存失败：$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.accentPeach),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _canSave ? _save : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primarySage,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.textLight),
                            )
                          : const Text(
                              '保存任务',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hint, String? counter}) =>
      InputDecoration(
        hintText: hint,
        counterText: counter ?? '',
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );
}

String _timeLabel(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

/// 加入今日计划, as a row rather than a bare switch: the design pairs it with the
/// sentence that says what turning it on does.
class _JoinTodaySwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String subtitle;

  const _JoinTodaySwitch({
    required this.value,
    required this.onChanged,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_rounded,
              size: 18, color: AppColors.primarySage),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '加入今日计划',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primarySage,
          ),
        ],
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
        Icon(icon, size: 16, color: AppColors.primarySage),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.primarySage : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primaryDark : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
