import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/pet_models.dart';
import '../controllers/craft_controller.dart';
import '../controllers/growth_controller.dart';
import '../theme/app_theme.dart';
import '../companion/companion_avatar.dart';
import '../companion/companion_selection.dart';
import '../widgets/cozy_furniture_artwork.dart';
import '../widgets/growth_sub_nav.dart';
import '../widgets/app_bottom_nav.dart';

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

    // The displayed name comes from the *selected* companion's profile, not from
    // the stored pet row. Progress is shared, so a stored name would keep saying
    // "Mochi" after the user chose the cat — presentation must follow the
    // selection while the shared business progress stays exactly where it is.
    final companionName = ref
        .watch(companionCatalogProvider)
        .profileFor(ref.watch(companionSelectionProvider))
        .displayName;

    if (progress == null) {
      return _buildMissingProgressState(context, pet);
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildHeader(context, companionName),
        ),
        const SliverToBoxAdapter(
          child: GrowthSubNav(active: GrowthSection.companion),
        ),
        SliverToBoxAdapter(
          child: _buildPetHero(companionName, progress),
        ),
        SliverToBoxAdapter(
          child: _buildGrowthStatsGrid(progress),
        ),
        SliverToBoxAdapter(
          child: _buildRecentUnlocks(context, ref),
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
            key: const Key('growth_companion_picker_button'),
            onPressed: () => context.push('/companions'),
            icon: const Icon(
              Icons.pets_outlined,
              size: 18,
              color: AppColors.primaryDark,
            ),
            label: const Text(
              '伙伴',
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
          const SizedBox(width: 8),
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
          CompanionAvatar(
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
                    // The right-hand side carries a total that grows with the
                    // player, and it used to be an unbounded Text in a
                    // spaceBetween Row: nothing could shrink, so a long total on
                    // a narrow screen overflowed. A 360dp test found it; the
                    // app's own data never did, because its totals are small.
                    // Scaled down rather than ellipsised - a truncated XP total
                    // is a wrong number.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$currentLevelXp / $xpPerLevel XP (总计 $xp XP)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
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

  /// Design 10's stat tiles: three of them, in the one row the board draws.
  ///
  /// Three and not four. The board annotates 只保留最关键的 3 项数据 and then
  /// names them — 当前等级 / 累计经验 / 陪伴时长 — so this was never a choice
  /// between unnamed candidates. The fourth tile was 心情指数, showing
  /// `progress.happinessScore`; the 幸福感 card further down the same page shows
  /// that same number. Dropping the tile therefore loses no information, and the
  /// page stops printing one value twice.
  Widget _buildGrowthStatsGrid(PetProgress progress) {
    final level = progress.level;
    final xp = progress.experiencePoints;
    final focusMinutes = progress.totalFocusMinutes;

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
          // IntrinsicHeight plus stretch, so the three tiles are the same height
          // whatever their contents do. Without it a value that has to shrink to
          // fit makes its own tile shorter, and the Row centres the short one -
          // the three titles then sit on three different lines, which is not
          // what the board draws.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatTile(
                    title: '陪伴专注',
                    value: '$focusMinutes 分钟',
                    icon: Icons.timer_outlined,
                    iconColor: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Design 10's 最近解锁: the last three finished crafts, newest first.
  ///
  /// Only rendered when something has actually been unlocked. The board draws it
  /// populated; an empty frame would be a shelf for achievements that have not
  /// happened, which is the thing the contract forbids. The artwork is the app's
  /// own furniture renderer for the item the recipe produces — the board's three
  /// item names are its own and are not in this catalogue.
  Widget _buildRecentUnlocks(BuildContext context, WidgetRef ref) {
    final unlocks = ref.watch(recentCraftUnlocksProvider).valueOrNull ??
        const <CraftUnlock>[];
    if (unlocks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '最近解锁',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/growth/collection'),
                child: const Text('查看全部 >',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final unlock in unlocks) ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        CozyFurnitureArtwork(itemId: unlock.itemId, size: 44),
                        const SizedBox(height: 6),
                        Text(
                          unlock.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${unlock.at.month}月${unlock.at.day}日',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// One stat tile, shaped the way the board draws it.
  ///
  /// The icon sits above the label in its own tinted square rather than inline
  /// beside it. That is the board's anatomy, and it is also what lets three
  /// tiles share a 360dp screen: an inline icon plus a four-character label
  /// needs about 72dp, and a third of 360dp minus the padding is less than that.
  ///
  /// The value is in a [FittedBox] because the board's own example is 8 小时 35 分
  /// — the design expects a value that is long, and a narrow tile must shrink it
  /// rather than clip it or ellipsise it. A truncated number would be a wrong
  /// number, which is worse than a smaller one.
  Widget _buildStatTile({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
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
    final companionName = ref.watch(companionDisplayNameProvider);
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
            Text(
              '开始第一次专注，领养你的专属 $companionName 吧！',
              style: const TextStyle(
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
                  CompanionAvatar(
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
    return const AppBottomNav(currentIndex: 2);
  }
}
