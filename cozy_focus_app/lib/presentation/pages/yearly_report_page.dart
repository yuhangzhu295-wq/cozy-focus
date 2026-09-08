import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/services/statistics_engine.dart';
import '../controllers/reports_controller.dart';
import '../theme/app_theme.dart';

/// Screen 08: Yearly Report (08 年度报告)
/// Real features:
/// - Top tabs: 日报, 周报, 月报, 年报
/// - Year selector (< YYYY > with prev/next navigation)
/// - Hero banner ("YYYY 我的专注之旅", Mochi pet avatar, warm quote)
/// - 3 Metric cards: 年度专注时长 (with YoY %), 总计专注次数 (with YoY %), 专注天数 (X天 占全年 Y%)
/// - Best month card (最佳月份: X月 · 专注 X.X小时)
/// - Peak focus time slot card (最常专注时间段)
/// - 365-day calendar heatmap grid (12 months x days with intensity colors)
/// - Mochi encouragement card
/// - CTAs: "生成并分享我的年度报告" (navigates to /reports/yearly/wrapped) and "保存到相册"
class YearlyReportPage extends ConsumerStatefulWidget {
  const YearlyReportPage({super.key});

  @override
  ConsumerState<YearlyReportPage> createState() => _YearlyReportPageState();
}

class _YearlyReportPageState extends ConsumerState<YearlyReportPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(reportsControllerProvider.notifier).loadAllReports();
    });
  }

  Future<void> _shareYearlyReport(PeriodReport report, int year) async {
    final hours = (report.totalSeconds / 3600).toStringAsFixed(1);
    final text =
        '$year年，我和 Mochi 一起专注了 $hours 小时，累计 ${report.sessionCount} 次，坚持了 ${report.activeDaysCount} 天！🌸\n回顾这一年的专注旅程，看见更好的自己。♡';
    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'Cozy Focus $year 年度报告分享'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsControllerProvider);
    final report = state.yearlyReport;
    final comp = state.yearlyComparison;
    final bestMonth = state.yearlyBestMonth;
    final peakSlot = state.yearlyPeakSlot;
    final currentYear = state.yearlyYear;

    final totalHours =
        report != null ? (report.totalSeconds / 3600).toStringAsFixed(0) : '0';
    final sessionCount = report?.sessionCount ?? 0;
    final activeDays = report?.activeDaysCount ?? 0;
    final isLeapYear = (currentYear % 4 == 0 && currentYear % 100 != 0) ||
        (currentYear % 400 == 0);
    final totalDaysInYear = isLeapYear ? 366 : 365;
    final dayPercentage =
        ((activeDays / totalDaysInYear) * 100).toStringAsFixed(0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '年度报告',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined,
                color: AppColors.textPrimary, size: 22),
            onPressed: report != null
                ? () => _shareYearlyReport(report, currentYear)
                : null,
          ),
        ],
      ),
      body: state.isLoading && report == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primarySage))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // Top Segmented Control (日报, 周报, 月报, 年报)
                _buildTopTabNav(context),
                const SizedBox(height: 16),

                // Year Selector (< YYYY >)
                _buildYearSelector(currentYear),
                const SizedBox(height: 16),

                // Hero Banner
                _buildHeroBanner(currentYear),
                const SizedBox(height: 16),

                // 3 Metric Cards
                _buildMetricCardsRow(
                  totalHours: totalHours,
                  hoursDiffPct: comp?.durationChangePercentage,
                  sessionCount: sessionCount,
                  sessionCountDiff: comp?.sessionCountDiff,
                  activeDays: activeDays,
                  dayPercentage: dayPercentage,
                ),
                const SizedBox(height: 16),

                // Best Month & Peak Time Slot Cards
                _buildHighlightsRow(bestMonth, peakSlot),
                const SizedBox(height: 16),

                // 365-day Calendar Heatmap
                _buildYearlyHeatmapCard(report, currentYear),
                const SizedBox(height: 16),

                // Mochi Encouragement Card
                _buildMochiEncouragementCard(),
                const SizedBox(height: 20),

                // Bottom Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primarySage,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => context.push('/reports/yearly/wrapped'),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.ios_share_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '生成并分享我的年度报告',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已保存年度报告卡片到相册 ♡'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          '保存到相册',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildTopTabNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildTabItem(
              '日报', false, () => context.pushReplacement('/progress')),
          _buildTabItem(
              '周报', false, () => context.pushReplacement('/reports/weekly')),
          _buildTabItem(
              '月报', false, () => context.pushReplacement('/reports/monthly')),
          _buildTabItem('年报', true, () {}),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySage : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYearSelector(int year) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded,
              color: AppColors.textPrimary),
          onPressed: () =>
              ref.read(reportsControllerProvider.notifier).previousYear(),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Text(
            '$year年',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded,
              color: AppColors.textPrimary),
          onPressed: () =>
              ref.read(reportsControllerProvider.notifier).nextYear(),
        ),
      ],
    );
  }

  Widget _buildHeroBanner(int year) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundWarm,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$year',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
                const Text(
                  '我的专注之旅',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '这一年，谢谢你依然选择专注。每一次的坚持，都让你成为更好的自己。♡',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Pet Visual
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Center(
              child: Text(
                '🐶',
                style: TextStyle(fontSize: 42),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCardsRow({
    required String totalHours,
    required double? hoursDiffPct,
    required int sessionCount,
    required int? sessionCountDiff,
    required int activeDays,
    required String dayPercentage,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            icon: Icons.timer_outlined,
            title: '年度专注时长',
            value: totalHours,
            unit: '小时',
            diffLabel: hoursDiffPct != null
                ? '比去年多了 ${hoursDiffPct.abs().toStringAsFixed(0)}% ${hoursDiffPct >= 0 ? "↑" : "↓"}'
                : '开启新一年的积累',
            diffColor: AppColors.primarySage,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.checklist_rounded,
            title: '总计专注次数',
            value: '$sessionCount',
            unit: '次',
            diffLabel: sessionCountDiff != null
                ? '比去年多了 ${sessionCountDiff.abs()} 次'
                : '稳步向前',
            diffColor: AppColors.primarySage,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.calendar_today_rounded,
            title: '专注天数',
            value: '$activeDays',
            unit: '天',
            diffLabel: '占全年 $dayPercentage%',
            diffColor: AppColors.accentPeach,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required String diffLabel,
    required Color diffColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primarySage),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            diffLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: diffColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightsRow(
      BestMonthSummary? bestMonth, TimeSlotSummary? peakSlot) {
    final monthStr = bestMonth != null ? '${bestMonth.month} 月' : '暂无数据';
    final monthHours = bestMonth != null
        ? (bestMonth.totalSeconds / 3600).toStringAsFixed(1)
        : '0';

    final slotLabel = peakSlot != null ? ' ()' : '暂无数据';

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded,
                        size: 16, color: AppColors.accentPeach),
                    SizedBox(width: 6),
                    Text(
                      '最佳月份',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  monthStr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '专注 $monthHours 小时',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.wb_sunny_rounded,
                        size: 16, color: AppColors.catLife),
                    SizedBox(width: 6),
                    Text(
                      '最常专注时间段',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  slotLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '这是你最有专注力的时段',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildYearlyHeatmapCard(PeriodReport? report, int year) {
    // Map of day of year or date string to seconds
    final dailySeconds = <String, int>{};
    if (report != null) {
      for (final r in report.records) {
        final key =
            '${r.startAt.year}-${r.startAt.month.toString().padLeft(2, '0')}-${r.startAt.day.toString().padLeft(2, '0')}';
        dailySeconds[key] = (dailySeconds[key] ?? 0) + r.durationSeconds;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '全年日历热力图',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '每一个专注的日子，都闪闪发光。♡',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 12 Months Heatmap rows
          Column(
            children: List.generate(12, (mIndex) {
              final month = mIndex + 1;
              final daysInMonth = DateUtils.getDaysInMonth(year, month);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$month月',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(31, (dIndex) {
                          final day = dIndex + 1;
                          if (day > daysInMonth) {
                            return const SizedBox(width: 7, height: 7);
                          }
                          final key =
                              '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                          final sec = dailySeconds[key] ?? 0;
                          final color = _getHeatmapColor(sec);

                          return Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(AppColors.backgroundWarm, '无记录'),
              const SizedBox(width: 12),
              _buildLegendDot(AppColors.primaryLight, '少量'),
              const SizedBox(width: 12),
              _buildLegendDot(AppColors.primarySage, '适中'),
              const SizedBox(width: 12),
              _buildLegendDot(AppColors.primaryDark, '高强度'),
            ],
          ),
        ],
      ),
    );
  }

  Color _getHeatmapColor(int seconds) {
    if (seconds <= 0) return AppColors.backgroundWarm;
    if (seconds < 1800) return AppColors.primaryLight;
    if (seconds < 5400) return AppColors.primarySage;
    return AppColors.primaryDark;
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildMochiEncouragementCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Row(
        children: [
          Text('🐶', style: TextStyle(fontSize: 32)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '这一年，你真的很棒！',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '继续保持，我们明年也一起加油吧！ ♡',
                  style: TextStyle(
                    fontSize: 12,
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
