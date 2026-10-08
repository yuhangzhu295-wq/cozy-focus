import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/distraction_note.dart';
import '../../domain/models/task.dart';
import '../controllers/distraction_controller.dart';
import '../theme/app_theme.dart';
import 'task_category_chip.dart';

/// Screen 05: 分心收集箱 — the sheet that opens over a running session.
///
/// ## Why it is a sheet
///
/// The whole point is that capturing a thought does not cost the user their
/// focus. A page would mean navigating away from a running timer; a sheet over
/// the timer leaves it visible behind, and the session keeps running because its
/// elapsed time comes from timestamps rather than from the screen being open.
///
/// Returns the new note's id, or null when the user closed it without saving.
Future<String?> showDistractionCaptureSheet(
  BuildContext context, {
  String? sessionId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => _CaptureSheet(sessionId: sessionId),
  );
}

class _CaptureSheet extends ConsumerStatefulWidget {
  final String? sessionId;

  const _CaptureSheet({this.sessionId});

  @override
  ConsumerState<_CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends ConsumerState<_CaptureSheet> {
  final TextEditingController _text = TextEditingController();
  String? _categoryId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _canSave => _text.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id =
          await ref.read(distractionInboxControllerProvider.notifier).capture(
                text: _text.text,
                categoryId: _categoryId,
                sessionId: widget.sessionId,
              );
      if (mounted) Navigator.of(context).pop(id);
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
    // The keyboard is up while this is open, so the sheet has to move with it or
    // the save button ends up underneath it.
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '分心收集箱',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('distraction_close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        semanticLabel: '关闭',
                        size: 20,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _text,
                autofocus: true,
                maxLength: DistractionNote.maxTextLength,
                maxLines: 3,
                minLines: 2,
                onChanged: (_) => setState(() {}),
                style:
                    const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '想到什么，先记下来…',
                  hintStyle: const TextStyle(
                      fontSize: 14, color: AppColors.textTertiary),
                  counterText:
                      '${_text.text.characters.length}/${DistractionNote.maxTextLength}',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(
                        color: AppColors.primarySage, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Optional, and the design says so: a thought that fits no category
              // is still a thought worth keeping, so tapping the chosen one again
              // clears it.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in taskCategories)
                    _TagChip(
                      key: ValueKey('distraction_tag_${category.id}'),
                      category: category,
                      selected: _categoryId == category.id,
                      onTap: () => setState(() => _categoryId =
                          _categoryId == category.id ? null : category.id),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  '没能记下来：$_error',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.accentPeach),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primarySage,
                    foregroundColor: AppColors.textLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.textLight),
                        )
                      : const Text(
                          '记下，继续专注',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final TaskCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = taskCategoryColor(category.id);
    return Semantics(
      excludeSemantics: true,
      button: true,
      selected: selected,
      label: '标签 ${category.label}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color:
                selected ? color.withValues(alpha: 0.14) : AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? color : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.sell_rounded : Icons.sell_outlined,
                size: 14,
                color: selected ? color : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                category.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
