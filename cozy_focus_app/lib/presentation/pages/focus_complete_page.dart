import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/enums.dart';
import '../controllers/focus_session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_avatar_widget.dart';

/// Screen 04: Focus Completed Screen (04 专注完成)
/// Shown immediately after session completes (auto countdown end or early finish).
/// Displays:
/// - Actual elapsed focus time from real session
/// - Estimated Focus XP & Craft progress preview
/// - Buttons: Continue to Save Record (04A) or View Record directly
class FocusCompletePage extends ConsumerWidget {
  const FocusCompletePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(focusSessionControllerProvider);

    final elapsedSeconds = sessionState.elapsedSeconds;
    final minutes = (elapsedSeconds / 60).floor();
    final earnedXp = minutes * 5; // Matches RewardService._xpPerMinute

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        title: const Text('专注完成'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Headline & Time
              const Text(
                'Great Work!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primarySage,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '你已专注了',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$minutes 分钟！',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Pet Visual State: celebrate
              const PetAvatarWidget(
                visualState: PetVisualState.celebrate,
                size: 170,
                message: '太棒了！Mochi 为你鼓掌 ♡',
              ),
              const SizedBox(height: 24),

              // XP Summary Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accentPeachLight,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                      color: AppColors.accentPeach.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.accentPeach,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+$earnedXp Focus XP',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentPeach,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '“Progress happens, one focus at a time.”',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textTertiary,
                ),
              ),

              const SizedBox(height: 28),

              // Continue Button -> 04A Save Record
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    context.go('/focus/save');
                  },
                  child: const Text(
                    '继续保存记录',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Skip directly / View Details
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
                    context.go('/focus/save');
                  },
                  child: const Text('查看记录详情'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
