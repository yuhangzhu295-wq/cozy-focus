import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/task.dart';
import '../controllers/providers.dart';
import '../controllers/task_controller.dart';
import '../theme/app_theme.dart';
import 'task_list_page.dart' show formatTaskDuration;

/// Screen 11: create a task.
///
/// ## What is deliberately not here yet
///
/// The design shows an `加入今日计划` switch. Today planning is P2's domain — it
/// needs a schedule table that does not exist in this phase — and a switch that
/// saved nothing would be exactly the fake control the brief forbids. It arrives
/// in P2 with the table behind it.
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
  int _estimatedSeconds = taskEstimatePresets.first;
  bool _customDuration = false;
  bool _saving = false;
  String? _error;

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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
            const _SectionLabel(icon: Icons.local_offer_rounded, text: '任务分类'),
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
            const _SectionLabel(icon: Icons.schedule_rounded, text: '预计专注时间'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final seconds in taskEstimatePresets)
                  _ChoiceChip(
                    label: formatTaskDuration(seconds),
                    selected: !_customDuration && _estimatedSeconds == seconds,
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
                decoration: _fieldDecoration(hint: '输入分钟数', counter: null),
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
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                '保存失败：$_error',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.accentPeach),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
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
