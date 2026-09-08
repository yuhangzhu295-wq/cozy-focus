import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/enums.dart';
import '../controllers/focus_session_controller.dart';
import '../controllers/home_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_avatar_widget.dart';

/// Screen 04A: Save Focus Record (04A 保存专注记录)
/// Allows user to review and customize:
/// - Task Name
/// - Category (学习 / 工作 / 阅读 / 生活 / 其他)
/// - Mood (5 cozy emojis)
/// - Notes / Reflections (up to 200 chars)
/// - Summary cards: Actual duration & Estimated Reward
/// On save: Calls FocusSessionEngine.save() -> writes immutable FocusRecord -> settles RewardLedger -> routes to 04B.
class FocusSavePage extends ConsumerStatefulWidget {
  const FocusSavePage({super.key});

  @override
  ConsumerState<FocusSavePage> createState() => _FocusSavePageState();
}

class _FocusSavePageState extends ConsumerState<FocusSavePage> {
  late TextEditingController _taskController;
  final TextEditingController _noteController = TextEditingController();
  String _selectedCategory = '学习';
  int _selectedMoodIndex = 2; // Default cheerful/content
  bool _isSaving = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': '学习', 'color': AppColors.catStudy},
    {'name': '工作', 'color': AppColors.catWork},
    {'name': '阅读', 'color': AppColors.catReading},
    {'name': '生活', 'color': AppColors.catLife},
    {'name': '其他', 'color': AppColors.catOther},
  ];

  final List<String> _moods = ['😆', '🙂', '😊', '😐', '🥺', '🥰'];

  @override
  void initState() {
    super.initState();
    final sessionState = ref.read(focusSessionControllerProvider);
    _taskController = TextEditingController(text: sessionState.taskName ?? '专注任务');
    if (sessionState.categoryName != null) {
      _selectedCategory = sessionState.categoryName!;
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(focusSessionControllerProvider.notifier);
      final moodStr = _moods[_selectedMoodIndex];
      final fullNote = _noteController.text.trim().isEmpty
          ? '心情: $moodStr'
          : '心情: $moodStr | ${_noteController.text.trim()}';

      // Writes immutable FocusRecord and settles RewardLedger
      await notifier.saveSession(note: fullNote);

      // Refresh home data so today focus reflects immediately
      await ref.read(homeControllerProvider.notifier).loadHomeData();

      if (mounted) {
        context.go('/focus/reward');
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
          icon: const Icon(Icons.close_rounded, size: 26),
          onPressed: () => context.go('/'),
        ),
        title: const Text('保存本次记录'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                          PetAvatarWidget(
                            visualState: PetVisualState.celebrate,
                            size: 64,
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.cancel_rounded, size: 20, color: AppColors.textTertiary),
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
                            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedCategory = cat['name'] as String);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Mood Selector
                    _buildSectionHeader('心情'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(_moods.length, (idx) {
                          final isSelected = _selectedMoodIndex == idx;
                          return InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            onTap: () => setState(() => _selectedMoodIndex = idx),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryLight : Colors.transparent,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: AppColors.primarySage, width: 2)
                                    : null,
                              ),
                              child: Text(
                                _moods[idx],
                                style: const TextStyle(fontSize: 26),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Notes / Thoughts
                    _buildSectionHeader('备注'),
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
                            maxLines: 3,
                            maxLength: 200,
                            decoration: const InputDecoration(
                              hintText: '记录这一刻的心情、感悟或收获...',
                              border: InputBorder.none,
                              counterText: '',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              '${_noteController.text.length}/200',
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
                                  '获得奖励',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('🪵', style: TextStyle(fontSize: 18)),
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
                                  '制作进度已同步积累 ♡',
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '保存记录',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
