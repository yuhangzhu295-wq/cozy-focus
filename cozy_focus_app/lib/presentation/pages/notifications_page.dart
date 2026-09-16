import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/enums.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_avatar_widget.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '通知设置',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 12),
            _HeroSection(),
            SizedBox(height: 20),
            _NotificationInfoCard(
              title: '每日专注提醒',
              icon: Icons.notifications_none_outlined,
              iconColor: AppColors.primarySage,
              iconBgColor: AppColors.primaryLight,
            ),
            _NotificationInfoCard(
              title: '睡前关怀提醒',
              icon: Icons.bedtime_outlined,
              iconColor: AppColors.catStudy,
              iconBgColor: Color(0xFFEBF1F9),
            ),
            _NotificationInfoCard(
              title: '周报提醒',
              icon: Icons.bar_chart_outlined,
              iconColor: AppColors.catReading,
              iconBgColor: Color(0xFFEAF5F2),
            ),
            _NotificationInfoCard(
              title: '成长里程碑',
              icon: Icons.star_outline,
              iconColor: AppColors.accentGold,
              iconBgColor: AppColors.accentGoldLight,
            ),
            _NotificationInfoCard(
              title: '静音时段',
              icon: Icons.notifications_off_outlined,
              iconColor: AppColors.catWork,
              iconBgColor: AppColors.accentPeachLight,
            ),
            _NotificationInfoCard(
              title: '提醒方式',
              icon: Icons.smartphone_outlined,
              iconColor: AppColors.catOther,
              iconBgColor: AppColors.surfaceMuted,
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: const Row(
        children: [
          PetAvatarWidget(visualState: PetVisualState.idle, size: 72),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '小小提醒\n大大进步！',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '让 Mochi 在合适的时间陪伴你，养成更好的专注习惯。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationInfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const _NotificationInfoCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '当前版本尚未接入系统通知',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '不可配置',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
