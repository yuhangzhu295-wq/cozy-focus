import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/enums.dart';
import '../controllers/home_controller.dart';
import '../controllers/focus_session_controller.dart';
import '../../core/auth/current_user.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_avatar_widget.dart';

/// Screen 01: Home Page — V4.1 redesign
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedMinutes = 25;
  int _currentNavIndex = 0;
  static const List<int> _quickChips = [5, 25, 50, 90];
  void _increment() {
    setState(() {
      _selectedMinutes = (_selectedMinutes + 5).clamp(5, 180);
    });
  }

  void _decrement() {
    setState(() {
      _selectedMinutes = (_selectedMinutes - 5).clamp(5, 180);
    });
  }

  Future<void> _handleStartFocus() async {
    final homeState = ref.read(homeControllerProvider);
    if (homeState.hasActiveSession) {
      context.go('/focus/active');
      return;
    }
    await ref.read(focusSessionControllerProvider.notifier).startSession(
          userId: localMvpUserId,
          plannedSeconds: _selectedMinutes * 60,
          mode: FocusMode.focus,
          taskName: '专注任务',
          categoryName: '学习',
        );
    if (mounted) context.go('/focus/active');
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeControllerProvider);
    final todayMinutes = homeState.todayMinutes;
    final streakDays = homeState.streakDays;
    final hasActive = homeState.hasActiveSession;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeroArea(hasActive)),
            SliverToBoxAdapter(child: _buildFocusPanel(hasActive)),
            SliverToBoxAdapter(
              child: _buildStatsPanel(todayMinutes, streakDays),
            ),
            SliverToBoxAdapter(child: _buildMochiQuote()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildHeroArea(bool hasActive) {
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppColors.backgroundWarm,
            ),
          ),
          const Positioned(
            top: 24,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '和 Mochi 一起',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                Text(
                  '专注吧！🌱',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primarySage,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '每一次专注都有意义',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 20,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              color: AppColors.textSecondary,
              onPressed: () {},
            ),
          ),
          Positioned(
            top: 60,
            right: 16,
            child: Container(
              width: 110,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentGoldLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                '每一次专注\n都是在靠近\n想要的自己 💚',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 120,
            child: Center(
              child: PetAvatarWidget(
                visualState:
                    hasActive ? PetVisualState.focus : PetVisualState.idle,
                size: 180,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusPanel(bool hasActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🌱 ', style: TextStyle(fontSize: 16)),
                  Text(
                    '专注时长',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.go('/focus/setup'),
                child: const Text(
                  '自定义 >',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primarySage,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepButton(icon: Icons.remove, onTap: _decrement),
              const SizedBox(width: 24),
              Text(
                '$_selectedMinutes:00',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 24),
              _StepButton(icon: Icons.add, onTap: _increment),
            ],
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              '专注，让美好的事情发生',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _quickChips.map((mins) {
              final selected = _selectedMinutes == mins;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('$mins 分钟'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedMinutes = mins),
                  selectedColor: AppColors.primaryLight,
                  backgroundColor: AppColors.surfaceMuted,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _handleStartFocus,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primarySage,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: Icon(
                hasActive
                    ? Icons.play_circle_outline
                    : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
              label: Text(
                hasActive ? '恢复专注' : '开始专注',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel(int todayMinutes, int streakDays) {
    final progress = (todayMinutes / 240).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📊 今天的专注',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/records'),
                child: const Text(
                  '查看详情 >',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primarySage,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      backgroundColor: AppColors.primaryLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primarySage,
                      ),
                    ),
                    const Text('🌱', style: TextStyle(fontSize: 24)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$todayMinutes 分钟',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    '今日专注时长',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('🔥 ', style: TextStyle(fontSize: 14)),
                      Text(
                        '$streakDays 天  连续专注',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentPeach,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMochiQuote() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Text(
        '🌱 小小的坚持，会让 Mochi 和你一起，遇见更棒的明天。♥',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _currentNavIndex,
      selectedItemColor: AppColors.primarySage,
      unselectedItemColor: AppColors.textTertiary,
      backgroundColor: AppColors.surface,
      onTap: (index) {
        if (index == _currentNavIndex) return;
        setState(() => _currentNavIndex = index);
        switch (index) {
          case 1:
            context.go('/records');
          case 2:
            context.go('/growth');
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: '首页',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_rounded),
          label: '记录',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.eco_outlined),
          label: '成长',
        ),
      ],
    );
  }
}

/// Small circular step button.
class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.primaryLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primaryDark, size: 20),
      ),
    );
  }
}
