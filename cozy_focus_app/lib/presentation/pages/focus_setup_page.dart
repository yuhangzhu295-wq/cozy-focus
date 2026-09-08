import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/enums.dart';
import '../controllers/focus_session_controller.dart';
import '../theme/app_theme.dart';

/// Screen 02: Focus Setup / Task Setup
/// Directly aligned with designs/02_开始专注_任务设置.png and prompts/02*
class FocusSetupPage extends ConsumerStatefulWidget {
  const FocusSetupPage({super.key});

  @override
  ConsumerState<FocusSetupPage> createState() => _FocusSetupPageState();
}

class _FocusSetupPageState extends ConsumerState<FocusSetupPage> {
  final TextEditingController _taskController = TextEditingController();
  String _selectedCategory = '学习';
  int _selectedModeIndex = 1; // 0 = Flow, 1 = Pomodoro (25/5), 2 = Custom
  final int _customMinutes = 30;
  int _minGoalMinutes = 5;

  final List<Map<String, dynamic>> _categories = [
    {'name': '学习', 'icon': Icons.school_rounded, 'color': AppColors.catStudy},
    {
      'name': '工作',
      'icon': Icons.business_center_rounded,
      'color': AppColors.catWork
    },
    {
      'name': '阅读',
      'icon': Icons.menu_book_rounded,
      'color': AppColors.catReading
    },
    {'name': '生活', 'icon': Icons.spa_rounded, 'color': AppColors.catLife},
  ];

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  int get _plannedSeconds {
    if (_selectedModeIndex == 0) return 0; // Flow: open ended
    if (_selectedModeIndex == 1) return 25 * 60; // Pomodoro: 25 min
    return _customMinutes * 60;
  }

  FocusMode get _focusMode {
    return FocusMode.focus;
  }

  Future<void> _startFocus() async {
    final taskName = _taskController.text.trim().isEmpty
        ? '专注任务'
        : _taskController.text.trim();

    try {
      await ref.read(focusSessionControllerProvider.notifier).startSession(
            userId: 'default_user',
            plannedSeconds: _plannedSeconds,
            mode: _focusMode,
            taskName: taskName,
            categoryName: _selectedCategory,
          );
      if (mounted) {
        context.go('/focus/active');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动专注失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => context.go('/'),
        ),
        title: const Text('设置专注'),
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
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '选一个适合你的方式吧！\nMochi 会一直陪着你！♡',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.accentPeachLight,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.accentPeach),
                            ),
                            child: const Icon(
                              Icons.pets_rounded,
                              color: AppColors.accentPeach,
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Task Content Input Card
                    _buildCard(
                      title: '任务内容',
                      child: TextField(
                        controller: _taskController,
                        decoration: InputDecoration(
                          hintText: '输入你要专注的任务...',
                          hintStyle: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(Icons.edit_note_rounded,
                              color: AppColors.primarySage),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            borderSide: const BorderSide(
                                color: AppColors.primarySage, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Select Category Card
                    _buildCard(
                      title: '选择分类',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((cat) {
                          final isSelected = _selectedCategory == cat['name'];
                          final Color catColor = cat['color'] as Color;
                          return ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat['icon'] as IconData,
                                  size: 15,
                                  color: isSelected ? Colors.white : catColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  cat['name'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            selected: isSelected,
                            selectedColor: catColor,
                            backgroundColor: catColor.withValues(alpha: 0.12),
                            side: BorderSide(
                              color: isSelected ? catColor : Colors.transparent,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            onSelected: (_) {
                              setState(() =>
                                  _selectedCategory = cat['name'] as String);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Focus Mode Card
                    _buildCard(
                      title: '专注时长模式',
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildModeOption(
                              index: 0,
                              title: '正计时\n(Flow)',
                              subtitle: '不设上限',
                              icon: Icons.all_inclusive_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildModeOption(
                              index: 1,
                              title: '番茄钟\n25 / 5',
                              subtitle: '经典专注',
                              icon: Icons.timer_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildModeOption(
                              index: 2,
                              title: '自定义\n时长',
                              subtitle: '$_customMinutes 分钟',
                              icon: Icons.tune_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Min Goal Dropdown
                    _buildCard(
                      title: '最小目标 (可选)',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundWarm,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _minGoalMinutes,
                                items: const [
                                  DropdownMenuItem(
                                      value: 5, child: Text('⏳ 5 分钟')),
                                  DropdownMenuItem(
                                      value: 10, child: Text('⏳ 10 分钟')),
                                  DropdownMenuItem(
                                      value: 15, child: Text('⏳ 15 分钟')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _minGoalMinutes = val);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              '不用追求完美，\n先专注 5 分钟也很棒！♡',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Start Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  label: const Text(
                    '开始专注',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _startFocus,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedModeIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () {
        setState(() => _selectedModeIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected ? AppColors.primarySage : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color:
                  isSelected ? AppColors.primarySage : AppColors.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color:
                    isSelected ? AppColors.primaryDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
