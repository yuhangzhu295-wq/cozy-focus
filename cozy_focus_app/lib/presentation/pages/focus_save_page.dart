import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/focus_review.dart';
import '../controllers/focus_session_controller.dart';
import '../controllers/home_controller.dart';
import '../companion/companion_avatar.dart';
import '../theme/app_theme.dart';

/// Screen 06: 专注复盘 — the few seconds after a session ends.
///
/// ## What it collects, and what it refuses to invent
///
/// The mood is a four-value picker with **no default selected**. The screen it
/// replaced pre-selected the middle emoji, which recorded an answer the user
/// never gave; 分心较多 / 一般 / 不错 / 心流 is a judgement, and a judgement with a
/// default is a judgement the app made. Saving without choosing one stores null,
/// which is the truth.
///
/// The gains are optional and multiple, because a session that produced nothing
/// in particular is a normal session. 下次继续 is optional too.
///
/// The task name and category stay editable here: this is the last screen before
/// the record is written, and it was the only place they could be corrected.
class FocusSavePage extends ConsumerStatefulWidget {
  const FocusSavePage({super.key});

  @override
  ConsumerState<FocusSavePage> createState() => _FocusSavePageState();
}

class _FocusSavePageState extends ConsumerState<FocusSavePage> {
  late TextEditingController _taskController;
  final TextEditingController _noteController = TextEditingController();
  String _selectedCategory = '学习';
  String _selectedCategoryId = 'study';

  /// Nothing is chosen to begin with. See the note on this class.
  FocusMood? _mood;
  final Set<FocusGain> _gains = {};
  final TextEditingController _nextController = TextEditingController();
  bool _isSaving = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': '学习', 'id': 'study', 'color': AppColors.catStudy},
    {'name': '工作', 'id': 'work', 'color': AppColors.catWork},
    {'name': '阅读', 'id': 'reading', 'color': AppColors.catReading},
    {'name': '生活', 'id': 'life', 'color': AppColors.catLife},
    {'name': '其他', 'id': 'other', 'color': AppColors.catOther},
  ];

  @override
  void initState() {
    super.initState();
    final sessionState = ref.read(focusSessionControllerProvider);
    _taskController =
        TextEditingController(text: sessionState.taskName ?? '专注任务');
    if (sessionState.categoryName != null) {
      _selectedCategory = sessionState.categoryName!;
    }
    if (sessionState.categoryId != null) {
      _selectedCategoryId = sessionState.categoryId!;
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    _noteController.dispose();
    _nextController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() => _persist(goToReward: true);

  /// Closing is NOT discarding.
  ///
  /// The session already ended before this page opened, and its FocusRecord is
  /// written only on save — so `context.go('/')` used to drop the focus time
  /// with no trace. Closing now saves with whatever the user has filled in and
  /// returns home. (The engine additionally recovers any session left in
  /// `finishing` on the next launch, for the paths that never reach this
  /// button: app killed, crash, force quit.)
  Future<void> _handleClose() => _persist(goToReward: false);

  Future<void> _persist({required bool goToReward}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(focusSessionControllerProvider.notifier);
      String? trimmed(TextEditingController controller) {
        final text = controller.text.trim();
        return text.isEmpty ? null : text;
      }

      // All user-edited fields are passed as structured parameters. Each is
      // stored as its own column, never concatenated into the note.
      final saved = await notifier.saveSession(
        taskName: _taskController.text.trim().isEmpty
            ? '专注任务'
            : _taskController.text.trim(),
        categoryId: _selectedCategoryId,
        // Null when the user did not choose, which is what the column means.
        mood: _mood?.id,
        note: trimmed(_noteController),
        gains: FocusReview.encodeGains(
          FocusGain.values.where(_gains.contains).toList(),
        ),
        nextIntention: trimmed(_nextController),
      );

      // Refresh home data so today focus reflects immediately
      await ref.read(homeControllerProvider.notifier).loadHomeData();

      if (!mounted) return;
      if (goToReward) {
        // The engine clears its current session while settling, so the reward
        // page is told which ledger row to show instead of looking it up.
        context.go('/focus/reward?sessionId=${saved.id}');
      } else {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(focusSessionControllerProvider);
    final elapsedSec = sessionState.elapsedSeconds;
    final minutes = (elapsedSec / 60).floor();
    final earnedXp = minutes * 5;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, semanticLabel: '关闭', size: 26),
          onPressed: _isSaving ? null : _handleClose,
        ),
        title: const Text('保存本次记录'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mochi Greeting Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        children: [
                          CompanionAvatar(
                            visualStateOverride: PetVisualState.celebrate,
                            size: 64,
                            showStateBadge: false,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '太棒了！',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '又完成一次专注！♡',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Task Name Input
                    _buildSectionHeader('任务名称'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _taskController,
                        decoration: InputDecoration(
                          hintText: '输入任务名称...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.cancel_rounded,
                                semanticLabel: '清空',
                                size: 20,
                                color: AppColors.textTertiary),
                            onPressed: () => _taskController.clear(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Selection Chips
                    _buildSectionHeader('分类'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat['name'];
                        final color = cat['color'] as Color;
                        return ChoiceChip(
                          label: Text(cat['name'] as String),
                          selected: isSelected,
                          selectedColor: color.withValues(alpha: 0.25),
                          backgroundColor: AppColors.surface,
                          side: BorderSide(
                            color: isSelected ? color : AppColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = cat['name'] as String;
                              _selectedCategoryId = cat['id'] as String;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // 这次感觉怎么样? — four answers, none chosen to begin with.
                    _buildSectionHeader('这次感觉怎么样？'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final mood in FocusMood.values)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: mood == FocusMood.values.last ? 0 : 8,
                              ),
                              child: Semantics(
                                excludeSemantics: true,
                                key: ValueKey('review_mood_${mood.id}'),
                                button: true,
                                selected: _mood == mood,
                                label: mood.label,
                                child: GestureDetector(
                                  onTap: () => setState(
                                    () => _mood = _mood == mood ? null : mood,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _mood == mood
                                          ? AppColors.primaryLight
                                          : AppColors.surface,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.sm),
                                      border: Border.all(
                                        color: _mood == mood
                                            ? AppColors.primarySage
                                            : AppColors.border,
                                        width: _mood == mood ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(mood.face,
                                            style:
                                                const TextStyle(fontSize: 22)),
                                        const SizedBox(height: 4),
                                        Text(
                                          mood.label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: _mood == mood
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: _mood == mood
                                                ? AppColors.primaryDark
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 这次做了什么？(可选)
                    _buildSectionHeader('这次做了什么？（可选）'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _noteController,
                            maxLines: 2,
                            maxLength: FocusReview.maxWhatLength,
                            decoration: const InputDecoration(
                              hintText: '例如：写产品方案、阅读资料、整理笔记…',
                              border: InputBorder.none,
                              counterText: '',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              '${_noteController.text.characters.length}'
                              '/${FocusReview.maxWhatLength}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 本次收获 (可选)
                    _buildSectionHeader('本次收获（可选）'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final gain in FocusGain.values)
                          Semantics(
                            excludeSemantics: true,
                            key: ValueKey('review_gain_${gain.id}'),
                            button: true,
                            selected: _gains.contains(gain),
                            label: gain.label,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                if (!_gains.remove(gain)) _gains.add(gain);
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: _gains.contains(gain)
                                      ? AppColors.primaryLight
                                      : AppColors.surface,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                  border: Border.all(
                                    color: _gains.contains(gain)
                                        ? AppColors.primarySage
                                        : AppColors.border,
                                  ),
                                ),
                                child: Text(
                                  gain.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _gains.contains(gain)
                                        ? AppColors.primaryDark
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 下次继续 (可选)
                    _buildSectionHeader('下次继续（可选）'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _nextController,
                            maxLines: 1,
                            maxLength: FocusReview.maxNextIntentionLength,
                            decoration: const InputDecoration(
                              hintText: '下次我想试试……',
                              border: InputBorder.none,
                              counterText: '',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              '${_nextController.text.characters.length}'
                              '/${FocusReview.maxNextIntentionLength}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Summary & Reward Cards Row
                    Row(
                      children: [
                        // Left Card: Actual Focus Duration
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '本次专注时长',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time_filled_rounded,
                                      color: AppColors.primarySage,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$minutes 分钟',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '专注让平凡的日子发光 ✨',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Right Card: Reward Preview
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '预计奖励',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('⭐',
                                        style: TextStyle(fontSize: 18)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '+$earnedXp XP',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accentPeach,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '将在保存后正式结算 ♡',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Save Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '保存记录',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}
