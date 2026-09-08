import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/focus_session_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/providers.dart';
import '../theme/app_theme.dart';

/// Screen 04B: Reward Screen (04B 奖励页面)
///
/// Shows real Focus Coins and Pet XP from RewardLedger.
/// Craft / Room / Inventory are Phase 4+ and shown as legitimately locked.
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

                  // Craft / Room section — Phase 4 not yet implemented
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 18, color: AppColors.textTertiary),
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
                        SizedBox(height: 8),
                        Text(
                          '制作系统将在 Phase 4 解锁。\n专注币已积累，届时可用于制作家具。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Single honest action: return to home
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
