import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/focus_session_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/craft_controller.dart';
import '../controllers/providers.dart';
import '../theme/app_theme.dart';

/// Screen 04B: Reward Screen
/// Shows real Focus Coins and Pet XP from RewardLedger.
/// Shows real active craft job progress if one exists (Phase 4).
class FocusRewardPage extends ConsumerStatefulWidget {
  const FocusRewardPage({super.key});

  @override
  ConsumerState<FocusRewardPage> createState() => _FocusRewardPageState();
}

class _FocusRewardPageState extends ConsumerState<FocusRewardPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(craftControllerProvider.notifier).refreshInventoryAndRoom());
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(focusSessionControllerProvider);
    final craft = ref.watch(craftControllerProvider);
    final sessionId = sessionState.session?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            ref.read(homeControllerProvider.notifier).loadHomeData();
            context.go('/');
          },
        ),
        title: const Text('获得奖励'),
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: sessionId != null
              ? ref
                  .read(rewardLedgerRepositoryProvider)
                  .findBySessionId(sessionId)
              : Future.value(null),
          builder: (context, snapshot) {
            final ledger = snapshot.data;
            final coins = ledger?.focusCoinsEarned ?? 0;
            final xp = ledger?.experienceEarned ?? 0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 1),

                  // Header
                  const Text(
                    '专注完成！',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primarySage,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '专注时间转化为了经验值与专注币',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Real reward chips from RewardLedger
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRewardChip(
                        icon: '🪙',
                        label: '+$coins 专注币',
                        color: AppColors.accentGoldLight,
                        textColor: const Color(0xFFB07D1C),
                      ),
                      const SizedBox(width: 12),
                      _buildRewardChip(
                        icon: '⭐',
                        label: '+$xp Pet XP',
                        color: AppColors.primaryLight,
                        textColor: AppColors.primaryDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Craft progress section — real data from CraftEngine
                  _buildCraftSection(context, craft),

                  const Spacer(flex: 2),

                  // Return home
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        ref
                            .read(homeControllerProvider.notifier)
                            .loadHomeData();
                        context.go('/');
                      },
                      child: const Text(
                        '返回首页',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCraftSection(BuildContext context, CraftState craft) {
    // Active job exists — show real progress
    if (craft.activeJob != null && craft.activeRecipe != null) {
      final job = craft.activeJob!;
      final recipe = craft.activeRecipe!;
      final progress = recipe.requiredSeconds > 0
          ? (job.progressSeconds / recipe.requiredSeconds).clamp(0.0, 1.0)
          : 0.0;
      final progressMin = (job.progressSeconds / 60).floor();

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.accentGoldLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border:
              Border.all(color: AppColors.accentGold.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(recipe.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '正在制作：${recipe.name}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '$progressMin / ${recipe.requiredMinutes} min',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.border,
                color: AppColors.accentGold,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                onPressed: () => context.go('/craft/detail/${job.recipeId}'),
                child: const Text('查看制作进度'),
              ),
            ),
          ],
        ),
      );
    }

    // No active job — show craft workshop entry (not locked, Phase 4 available)
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.handyman_outlined,
                  size: 18, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text(
                '制作工坊',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '用专注时间制作家具，装饰 Mochi 的小房间',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.handyman_outlined, size: 16),
              label: const Text('前往制作工坊'),
              onPressed: () => context.go('/craft'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardChip({
    required String icon,
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
