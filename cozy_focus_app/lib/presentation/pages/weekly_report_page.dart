import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/services/statistics_engine.dart';
import '../controllers/reports_controller.dart';
import '../theme/app_theme.dart';

/// Screen 06: Weekly Report (06 周报)
/// Real features:
/// - Date range selector (previous / next week)
/// - Total focus time & session count with WoW comparison indicator
/// - 7-day bar chart showing daily focus hours
/// - Strongest focus day highlight (e.g. "周四 · 3.4h")
/// - Focus category distribution breakdown with visual proportions
/// - Mochi customized encouragement feedback based on weekly performance
/// - Active share button triggering system share sheet
class WeeklyReportPage extends ConsumerStatefulWidget {
  const WeeklyReportPage({super.key});

  @override
  ConsumerState<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends ConsumerState<WeeklyReportPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(reportsControllerProvider.notifier).loadAllReports();
    });
  }

  String _categoryLabel(String id) {
    switch (id) {
      case 'study':
        return '学习';
      case 'work':
        return '工作';
      case 'reading':
        return '阅读';
      case 'life':
        return '生活';
      default:
        return '其他';
    }
  }

  Color _categoryColor(String id) {
    switch (id) {
      case 'study':
        return AppColors.catStudy;
      case 'work':
        return AppColors.catWork;
      case 'reading':
        return AppColors.catReading;
      case 'life':
        return AppColors.catLife;
      default:
        return AppColors.catOther;
    }
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return '周一';
      case 2:
        return '周二';
      case 3:
        return '周三';
      case 4:
        return '周四';
      case 5:
        return '周五';
      case 6:
        return '周六';
      case 7:
        return '周日';
      default:
        return '';
    }
  }

  Future<void> _shareWeeklyAchievement(
      PeriodReport report, PeriodComparison? comp) async {
    final hours = (report.totalSeconds / 3600).toStringAsFixed(1);
    final text =
        '这一周我在 Cozy Focus 和 Mochi 一起专注了 $hours 小时，共 ${report.sessionCount} 次！🌸\n保持温柔坚定的节奏，生活更温暖 ♡';
    await SharePlus.instance
        .share(ShareParams(text: text, subject: 'Cozy Focus 周成就分享'));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsControllerProvider);
    final report = state.weeklyReport;
    final comp = state.weeklyComparison;
    final bestDay = state.weeklyBestDay;

    final weekStart = state.selectedWeekStart;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final dateRangeStr =
        '${DateFormat('M月d日').format(weekStart)} - ${DateFormat('M月d日').format(weekEnd)}';

    final totalSec = report?.totalSeconds ?? 0;
    final totalHours = totalSec ~/ 3600;
    final totalMins = (totalSec % 3600) ~/ 60;
    final totalCount = report?.sessionCount ?? 0;

    final pctComp = comp?.durationChangePercentage;
    final sessDiff = comp?.sessionCountDiff ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '数据记录',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Segmented tabs: 周报 (active) / 月报 / 年报
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.backgroundWarm,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        alignment: Alignment.center,
                        child: const Text('周报',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primarySage)),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            context.pushReplacement('/reports/monthly'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          child: const Text('月报',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.pushReplacement('/reports/yearly'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          child: const Text('年报',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Report Body
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primarySage))
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Week Navigator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded,
                                  color: AppColors.primarySage),
                              onPressed: () => ref
                                  .read(reportsControllerProvider.notifier)
                                  .previousWeek(),
                            ),
                            Text(
                              dateRangeStr,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded,
                                  color: AppColors.primarySage),
                              onPressed: () => ref
                                  .read(reportsControllerProvider.notifier)
                                  .nextWeek(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Summary Cards (Total time & count with WoW comparison)
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.timer_outlined,
                                            size: 16,
                                            color: AppColors.primarySage),
                                        SizedBox(width: 4),
                                        Text('专注总时长',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.textSecondary)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      totalHours > 0
                                          ? '${totalHours}h ${totalMins}m'
                                          : '$totalMins 分钟',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      pctComp != null
                                          ? '比上周 ${pctComp >= 0 ? '+' : ''}${pctComp.toStringAsFixed(0)}% ${pctComp >= 0 ? '↑' : '↓'}'
                                          : '无上周数据对比',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: (pctComp ?? 0) >= 0
                                            ? AppColors.primarySage
                                            : AppColors.accentPeach,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.shield_outlined,
                                            size: 16,
                                            color: AppColors.accentPeach),
                                        SizedBox(width: 4),
                                        Text('专注次数',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.textSecondary)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$totalCount',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '比上周 ${sessDiff >= 0 ? '+' : ''}$sessDiff ${sessDiff >= 0 ? '↑' : '↓'}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primarySage,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Daily Bar Chart (7 days)
                        _buildDailyBarChart(report, weekStart),
                        const SizedBox(height: 18),

                        // Best Day Highlight Callout
                        if (bestDay != null && bestDay.totalSeconds > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.accentGoldLight,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                  color: AppColors.accentGold
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.emoji_events_rounded,
                                    color: AppColors.accentGold, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('本周最强专注日',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary)),
                                      Text(
                                        '${_weekdayName(bestDay.date.weekday)} · ${(bestDay.totalSeconds / 3600).toStringAsFixed(1)}h',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Text('继续保持吧！✨',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.accentGold,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 18),

                        // Category Breakdown
                        _buildCategoryBreakdown(report),
                        const SizedBox(height: 18),

                        // Mochi Companion Feedback Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundWarm,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                ),
                                child: const Text('🐶',
                                    style: TextStyle(fontSize: 32)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '这一周你专注了 ${totalHours}h ${totalMins}m！',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Mochi 为你感到骄傲！\n继续保持这种温柔而坚定的节奏，下周也一起加油吧！ ♡',
                                      style: TextStyle(
                                        fontSize: 12,
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
                        const SizedBox(height: 24),

                        // Share Achievement CTA
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primarySage,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: const Text('分享本周成就',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            onPressed: (report != null &&
                                    report.totalSeconds > 0)
                                ? () => _shareWeeklyAchievement(report, comp)
                                : null,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyBarChart(PeriodReport? report, DateTime weekStart) {
    final dayTotals = <int, int>{}; // weekday (1..7) -> seconds
    for (int i = 1; i <= 7; i++) {
      dayTotals[i] = 0;
    }

    if (report != null) {
      for (final r in report.records) {
        dayTotals[r.startAt.weekday] =
            (dayTotals[r.startAt.weekday] ?? 0) + r.durationSeconds;
      }
    }

    int maxSec = 0;
    for (final s in dayTotals.values) {
      if (s > maxSec) maxSec = s;
    }
    if (maxSec == 0) maxSec = 3600; // default 1 hour baseline

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '每日专注时长',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final weekday = i + 1;
                final sec = dayTotals[weekday] ?? 0;
                final hours = (sec / 3600);
                final heightRatio = (sec / maxSec).clamp(0.05, 1.0);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      sec > 0 ? '${hours.toStringAsFixed(1)}h' : '',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 24,
                      height: 90 * heightRatio,
                      decoration: BoxDecoration(
                        color: sec > 0
                            ? AppColors.primarySage
                            : AppColors.borderLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _weekdayName(weekday),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(PeriodReport? report) {
    final categories = report?.categoryBreakdowns ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '专注分类分布',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          if (categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('本周暂无专注分类数据',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),
            )
          else ...[
            // Proportional Multi-segment Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: categories.map((cat) {
                    return Expanded(
                      flex: (cat.percentage * 100).round().clamp(1, 10000),
                      child: Container(
                        color: _categoryColor(cat.categoryId),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend list
            ...categories.map((cat) {
              final pct = (cat.percentage * 100).toStringAsFixed(0);
              final mins = cat.totalSeconds ~/ 60;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _categoryColor(cat.categoryId),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _categoryLabel(cat.categoryId),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$mins 分钟 ($pct%)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
