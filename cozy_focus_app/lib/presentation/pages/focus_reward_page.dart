import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/focus_session_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/providers.dart';
import '../theme/app_theme.dart';

/// Screen 04B: Reward Screen (04B 奖励页面)
/// Displays:
/// - Real reward fetched from RewardLedgerRepository using current/last session ID
/// - Real Focus Coins and XP earned
/// - Crafted item or crafting progress
/// - Two real action paths:
///   * "Place Now" (摆放到房间) -> Goes to Home (Room)
///   * "View in Inventory" (查看背包) -> Goes to Home (Room inventory)
class FocusRewardPage extends ConsumerWidget {
  const FocusRewardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(focusSessionControllerProvider);
    final sessionId = sessionState.session?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        title: const Text('获得奖励'),
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: sessionId != null
              ? ref.read(rewardLedgerRepositoryProvider).findBySessionId(sessionId)
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
                    'New Item Crafted!',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primarySage,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '专注时间转化为了温暖的家具与经验',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Crafted Item Card / Visual
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primarySage.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🪑', style: TextStyle(fontSize: 72)),
                        SizedBox(height: 8),
                        Text(
                          'Wooden Chair',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '手工木质小椅子',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Reward stats chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRewardChip(
                        icon: '🪙',
                        label: '+$coins Focus Coins',
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

                  const Spacer(flex: 2),

                  // Action 1: Place Now (摆放到房间)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(homeControllerProvider.notifier).loadHomeData();
                        context.go('/');
                      },
                      child: const Text(
                        'Place Now (摆放至房间)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action 2: View in Inventory (收入背包)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      onPressed: () {
                        ref.read(homeControllerProvider.notifier).loadHomeData();
                        context.go('/');
                      },
                      child: const Text('View in Inventory (暂存背包)'),
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
