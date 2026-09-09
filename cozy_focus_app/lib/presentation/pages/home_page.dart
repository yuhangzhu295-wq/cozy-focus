import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/enums.dart';
import '../controllers/home_controller.dart';
import '../controllers/focus_session_controller.dart';
import '../controllers/craft_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_avatar_widget.dart';

/// Screen 01: Home Page / Pet Room
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(homeControllerProvider.notifier).loadHomeData();
      ref.read(craftControllerProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeControllerProvider);
    final sessionUI = ref.watch(focusSessionControllerProvider);
    final craft = ref.watch(craftControllerProvider);
    final hasActiveSession = sessionUI.session?.isActive ?? false;

    final pet = homeState.pet;
    final progress = homeState.petProgress;
    final todayMinutes = homeState.todayMinutes;
    final level = progress?.level ?? 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cozy Focus',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hi, 今天也加油！♡',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  // Level Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pets_rounded,
                            size: 16, color: AppColors.primarySage),
                        const SizedBox(width: 6),
                        Text(
                          'Lv.$level ${pet?.name ?? 'Mochi'}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Today focus stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.timer_outlined,
                          size: 18, color: AppColors.primarySage),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        todayMinutes > 0
                            ? '今日累计专注 $todayMinutes 分钟 (${homeState.sessionCountToday} 次)'
                            : '今日尚未开启专注，和 Mochi 一起开始吧！',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Active Session Resume Banner
            if (hasActiveSession)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => context.go('/focus/active'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.accentPeachLight,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: AppColors.accentPeach.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.play_circle_fill_rounded,
                            color: AppColors.accentPeach, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '当前有进行中的专注',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentPeach,
                                ),
                              ),
                              Text(
                                '点击快速返回专注页面',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: AppColors.accentPeach),
                      ],
                    ),
                  ),
                ),
              ),

            // Active craft job banner (Phase 4)
            if (craft.activeJob != null && craft.activeRecipe != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () =>
                      context.go('/craft/detail/${craft.activeJob!.recipeId}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accentGoldLight,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: AppColors.accentGold.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Text(craft.activeRecipe!.icon,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '正在制作：${craft.activeRecipe!.name}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                child: LinearProgressIndicator(
                                  value: craft.activeRecipe!.requiredSeconds > 0
                                      ? (craft.activeJob!.progressSeconds /
                                              craft.activeRecipe!
                                                  .requiredSeconds)
                                          .clamp(0.0, 1.0)
                                      : 0.0,
                                  backgroundColor: AppColors.border,
                                  color: AppColors.accentGold,
                                  minHeight: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ),

            // Center Pet Room
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundWarm,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            PetAvatarWidget(
                              visualState: hasActiveSession
                                  ? PetVisualState.focus
                                  : PetVisualState.idle,
                              size: 190,
                              message: hasActiveSession
                                  ? 'Mochi 正在专注陪伴你...'
                                  : 'Mochi\n和你一起变更好 ♡',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Start Focus Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primarySage,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () {
                    if (hasActiveSession) {
                      context.go('/focus/active');
                    } else {
                      context.go('/focus/setup');
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.pets_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        hasActiveSession ? '恢复专注 >' : '开始专注 >',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Navigation Bar
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border:
                    Border(top: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentNavIndex,
                elevation: 0,
                backgroundColor: Colors.transparent,
                selectedItemColor: AppColors.primarySage,
                unselectedItemColor: AppColors.textTertiary,
                type: BottomNavigationBarType.fixed,
                onTap: (index) {
                  if (index == 0) {
                    setState(() => _currentNavIndex = 0);
                  } else if (index == 1) {
                    context.go('/focus/setup');
                  } else if (index == 2) {
                    context.push('/progress');
                  } else if (index == 3) {
                    // Phase 4: Room
                    setState(() => _currentNavIndex = 3);
                    context.push('/room');
                  } else {
                    // Phase 5+ placeholder
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('该功能将在后续版本开放，先和 Mochi 专注吧 ♡'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_rounded),
                    label: '首页',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.timer_outlined),
                    label: '专注',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bar_chart_rounded),
                    label: '进度',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.weekend_outlined),
                    label: '房间',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline_rounded),
                    label: '我的',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
