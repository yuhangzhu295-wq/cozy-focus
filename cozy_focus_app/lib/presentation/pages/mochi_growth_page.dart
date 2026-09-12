import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/pet_models.dart';
import '../controllers/growth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_avatar_widget.dart';

/// Screen: Growth > Mochi Page
/// Real data-backed pet growth screen for Mochi
class MochiGrowthPage extends ConsumerWidget {
  const MochiGrowthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(growthControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: _buildBody(context, ref, state),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, GrowthState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primarySage),
        ),
      );
    }

    if (state.pet == null) {
      return _buildEmptyState(context, ref);
    }

    final pet = state.pet!;
    final progress = state.progress;

    if (progress == null) {
      return _buildMissingProgressState(context, pet);
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildHeader(context, pet.name),
        ),
        SliverToBoxAdapter(
          child: _buildPetHero(pet.name, progress),
        ),
        SliverToBoxAdapter(
          child: _buildGrowthStatsGrid(progress),
        ),
        SliverToBoxAdapter(
          child: _buildHappinessCard(progress),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, String petName) {
    return Container(
      color: AppColors.backgroundWarm,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          const Text(
            '成长',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
              height: 1.1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              petName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const Spacer(),
          TextButton.icon(
            key: const Key('growth_collection_button'),
            onPressed: () => context.go('/growth/collection'),
            icon: const Icon(
              Icons.collections_bookmark_outlined,
              size: 18,
              color: AppColors.primaryDark,
            ),
            label: const Text(
              '图鉴',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetHero(String petName, PetProgress progress) {
    final level = progress.level;
    final xp = progress.experiencePoints;
    const xpPerLevel = 100;
    final currentLevelXp = xp % xpPerLevel;
    final xpRatio = (currentLevelXp / xpPerLevel).clamp(0.0, 1.0);

    return Container(
      color: AppColors.backgroundWarm,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          PetAvatarWidget(
            visualState: PetVisualState.idle,
            size: 160,
            message: '$petName 正在陪伴你成长 🌱',
          ),
          const SizedBox(height: 16),
          Text(
            petName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lv.$level 伙伴',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primarySage,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '经验值 (XP)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '$currentLevelXp / $xpPerLevel XP (总计 $xp XP)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: xpRatio,
                    minHeight: 8,
                    backgroundColor: AppColors.primaryLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primarySage,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthStatsGrid(PetProgress progress) {
    final level = progress.level;
    final xp = progress.experiencePoints;
    final focusMinutes = progress.totalFocusMinutes;
    final happiness = progress.happinessScore;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '成长属性',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  title: '当前等级',
                  value: 'Lv.$level',
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppColors.accentGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatTile(
                  title: '累计经验',
                  value: '$xp XP',
                  icon: Icons.bolt_rounded,
                  iconColor: AppColors.primarySage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  title: '陪伴专注',
                  value: '$focusMinutes 分钟',
                  icon: Icons.timer_outlined,
                  iconColor: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatTile(
                  title: '心情指数',
                  value: '$happiness / 100',
                  icon: Icons.favorite_rounded,
                  iconColor: AppColors.accentPeach,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHappinessCard(PetProgress progress) {
    final happiness = progress.happinessScore;
    final happinessRatio = (happiness / 100.0).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.sentiment_satisfied_alt_rounded,
                    color: AppColors.accentPeach,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '幸福感',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '$happiness%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentPeach,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: happinessRatio,
              minHeight: 8,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.accentPeach,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '保持专注与陪伴，让小狗保持快乐满满的状态吧！',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.pets_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            const Text(
              '暂未领养宠物',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '开始第一次专注，领养你的专属 Mochi 吧！',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('前往首页'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primarySage,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingProgressState(BuildContext context, Pet pet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, pet.name),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PetAvatarWidget(
                    visualState: PetVisualState.idle,
                    size: 140,
                    message: '${pet.name} 等待开启成长记录 🌱',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    pet.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '暂无成长数据',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '完成一次专注，记录你的陪伴时光与经验成长。',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('前往首页'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primarySage,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 2,
      selectedItemColor: AppColors.primarySage,
      unselectedItemColor: AppColors.textTertiary,
      backgroundColor: AppColors.surface,
      onTap: (index) {
        if (index == 2) return;
        switch (index) {
          case 0:
            context.go('/');
          case 1:
            context.go('/records');
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
