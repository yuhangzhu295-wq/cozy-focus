import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../companion/companion_selection.dart';
import '../companion/companion_avatar.dart';
import '../theme/app_theme.dart';

/// Settings Page for Cozy Focus (PHASE-7A)
/// Honest personal-center / settings view with Mochi hero and noninteractive informational cards.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companionName = ref.watch(companionDisplayNameProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '设置',
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
              context.go('/');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // V4.1 Mochi hero card with exact primary heading and subtitle
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const CompanionAvatar(
                      size: 72,
                      showStateBadge: false,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '个人中心',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '和 $companionName 一起，专注更好的自己',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Exactly seven static settings rows as individually separated rounded visual cards
              const _SettingInfoCard(
                icon: Icons.timer_outlined,
                iconColor: AppColors.primarySage,
                iconBgColor: AppColors.primaryLight,
                title: '专注默认',
                subtitle: '标准 25 分钟番茄专注（内存默认设置，暂不持久化保存）',
              ),
              const _NavigableSettingCard(
                icon: Icons.notifications_none_outlined,
                iconColor: AppColors.catStudy,
                iconBgColor: Color(0xFFEBF1F9),
                title: '通知',
                subtitle: '专注结束与休息提醒（当前版本尚未接入系统通知）',
                route: '/settings/notifications',
              ),
              const _SettingInfoCard(
                icon: Icons.volume_up_outlined,
                iconColor: AppColors.catReading,
                iconBgColor: Color(0xFFEAF5F2),
                title: '声音与触感',
                subtitle: '轻柔白噪音与振动反馈（功能建设中，暂未启用）',
              ),
              const _SettingInfoCard(
                icon: Icons.palette_outlined,
                iconColor: AppColors.accentGold,
                iconBgColor: AppColors.accentGoldLight,
                title: '外观',
                subtitle: '柔和暖色主题（当前跟随系统浅色设计，不支持主题切换）',
              ),
              const _SettingInfoCard(
                icon: Icons.language_outlined,
                iconColor: AppColors.catWork,
                iconBgColor: AppColors.accentPeachLight,
                title: '语言',
                subtitle: '简体中文（多语言支持待后续版本规划）',
              ),
              const _NavigableSettingCard(
                icon: Icons.sync_outlined,
                iconColor: AppColors.catLife,
                iconBgColor: Color(0xFFFEF6EB),
                title: '数据与同步',
                subtitle: '当前应用为本地离线模式，云端同步暂不可用',
                route: '/settings/data-sync',
              ),
              const _SettingInfoCard(
                icon: Icons.security_outlined,
                iconColor: AppColors.catOther,
                iconBgColor: Color(0xFFF2ECE1),
                title: '隐私',
                subtitle: '权限与隐私细则尚未完备，当前仅维持基础本地运行',
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reference 12 draws every settings row at 59.67pt: a 24pt icon disc, a 14pt
/// title, a 3pt gap, an 11pt subtitle and 12pt of vertical padding. The rows
/// used to measure 70.47dp (and 87.24dp where the status subtitle wrapped),
/// which is what pushed the seventh row under the navigation bar.
class _SettingRowMetrics {
  const _SettingRowMetrics._();

  static const EdgeInsets padding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 12);
  static const EdgeInsets margin = EdgeInsets.only(bottom: 8);
  static const double iconDisc = 24;
  static const double iconGlyph = 14;
  static const double iconGap = 12;
  static const double titleSize = 14;
  static const double titleGap = 3;
  static const double subtitleSize = 11;
  static const double chevron = 14;
  static const double radius = AppRadius.md;
}

class _SettingInfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;

  const _SettingInfoCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: _SettingRowMetrics.margin,
      padding: _SettingRowMetrics.padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_SettingRowMetrics.radius),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: _SettingRowMetrics.iconDisc,
            height: _SettingRowMetrics.iconDisc,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: _SettingRowMetrics.iconGlyph,
              color: iconColor,
            ),
          ),
          const SizedBox(width: _SettingRowMetrics.iconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: _SettingRowMetrics.titleSize,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: _SettingRowMetrics.titleGap),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: _SettingRowMetrics.subtitleSize,
                    color: AppColors.textSecondary,
                    height: 1.3,
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

class _NavigableSettingCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String route;

  const _NavigableSettingCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        margin: _SettingRowMetrics.margin,
        padding: _SettingRowMetrics.padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(_SettingRowMetrics.radius),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: _SettingRowMetrics.iconDisc,
              height: _SettingRowMetrics.iconDisc,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: _SettingRowMetrics.iconGlyph,
                color: iconColor,
              ),
            ),
            const SizedBox(width: _SettingRowMetrics.iconGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: _SettingRowMetrics.titleSize,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: _SettingRowMetrics.titleGap),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: _SettingRowMetrics.subtitleSize,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: _SettingRowMetrics.chevron,
            ),
          ],
        ),
      ),
    );
  }
}
