import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/enums.dart';
import '../controllers/focus_session_controller.dart';
import '../controllers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_avatar_widget.dart';

/// Screen 02: Focus Setup — V4.1 visual redesign
/// Design ref: docs/cozy_focus_v4_1/designs/pages_ascii/02_focus_setup.png
class FocusSetupPage extends ConsumerStatefulWidget {
  const FocusSetupPage({super.key});

  @override
  ConsumerState<FocusSetupPage> createState() => _FocusSetupPageState();
}

class _FocusSetupPageState extends ConsumerState<FocusSetupPage> {
  final TextEditingController _taskController = TextEditingController();
  int _selectedMinutes = 25;
  bool _reminderOn = true;

  static const List<int> _quickDurations = [5, 25, 50, 90];

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  int get _plannedSeconds => _selectedMinutes * 60;
  FocusMode get _focusMode => FocusMode.focus;

  Future<void> _startFocus() async {
    final taskName = _taskController.text.trim().isEmpty
        ? '专注任务'
        : _taskController.text.trim();
    try {
      final userId = ref.read(currentUserIdProvider);
      await ref.read(focusSessionControllerProvider.notifier).startSession(
            userId: userId,
            plannedSeconds: _plannedSeconds,
            mode: _focusMode,
            taskName: taskName,
          );
      if (mounted) context.go('/focus/active');
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
      body: Column(
        children: [
          // ── Hero area ──────────────────────────────────────────
          Expanded(
            flex: 45,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Warm gradient background
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.backgroundWarm, AppColors.background],
                    ),
                  ),
                ),
                // Back button
                Positioned(
                  top: 44,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textPrimary, size: 20),
                    onPressed: () => context.go('/'),
                  ),
                ),
                // Centre top title
                const Positioned(
                  top: 44,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        '专注设置',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '为这一次专注做一个轻轻的开始',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Left hero text
                const Positioned(
                  left: 20,
                  top: 100,
                  child: Text(
                    '和 Mochi 一起\n专注吧！🌱',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
                const Positioned(
                  left: 20,
                  top: 158,
                  child: Text(
                    '专注当下，\n让更好的自己慢慢长大。',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.5),
                  ),
                ),
                // Sticky note – top right
                Positioned(
                  right: 20,
                  top: 96,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      '选一个时间\n我们开始吧！♡',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryDark,
                          height: 1.4),
                    ),
                  ),
                ),
                // Pet avatar
                const Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: PetAvatarWidget(
                        visualState: PetVisualState.idle,
                        size: 130,
                        message: '选好了我们就出发！'),
                  ),
                ),
              ],
            ),
          ),

          // ── Settings panel ─────────────────────────────────────
          Expanded(
            flex: 55,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Duration header
                    Row(
                      children: [
                        const Text('🌱 ', style: TextStyle(fontSize: 16)),
                        const Text(
                          '选择专注时长',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                        ),
                        const Spacer(),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primarySage,
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: null,
                          child: const Text('自定义 >',
                              style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Quick duration chips
                    Row(
                      children: _quickDurations.asMap().entries.map((entry) {
                        final mins = entry.value;
                        final isLast = entry.key == _quickDurations.length - 1;
                        final isSelected = _selectedMinutes == mins;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: isLast ? 0 : 8),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedMinutes = mins),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryLight
                                      : AppColors.background,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primarySage
                                        : AppColors.border,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '$mins',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? AppColors.primaryDark
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '分钟',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSelected
                                            ? AppColors.primarySage
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Task input
                    const Row(
                      children: [
                        Text('🌱 ', style: TextStyle(fontSize: 16)),
                        Text(
                          '专注任务（可选）',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _taskController,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: '例如：写作、看书、准备考试…',
                        hintStyle: const TextStyle(
                            color: AppColors.textTertiary, fontSize: 14),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
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
                    const SizedBox(height: 20),

                    // White noise row (honestly non-interactive UI)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.music_note_rounded,
                              color: AppColors.primarySage, size: 20),
                          SizedBox(width: 10),
                          Text('专注白噪音',
                              style: TextStyle(
                                  fontSize: 15, color: AppColors.textPrimary)),
                          Spacer(),
                          Text('森林  >',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const Divider(color: AppColors.borderLight),

                    // Reminder toggle (UI only)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_outlined,
                              color: AppColors.primarySage, size: 20),
                          const SizedBox(width: 10),
                          const Text('专注结束提醒',
                              style: TextStyle(
                                  fontSize: 15, color: AppColors.textPrimary)),
                          const Spacer(),
                          Switch(
                            value: _reminderOn,
                            activeColor: AppColors.primarySage,
                            onChanged: (v) => setState(() => _reminderOn = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Start button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded, size: 24),
                        label: const Text('开始专注',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        onPressed: _startFocus,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        '"专注的每一分钟，都是在靠近更好的自己。"',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // ── Bottom nav (3 tabs) ────────────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: AppColors.primarySage,
        unselectedItemColor: AppColors.textTertiary,
        backgroundColor: AppColors.surface,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        onTap: (idx) {
          if (idx == 1) context.go('/records');
          if (idx == 2) context.go('/growth');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '首页'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded), label: '记录'),
          BottomNavigationBarItem(icon: Icon(Icons.eco_outlined), label: '成长'),
        ],
      ),
    );
  }
}
