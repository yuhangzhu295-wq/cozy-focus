import 'package:flutter/material.dart';
// `OverflowBoxFit`, for the chart's day labels. `material.dart` does not put the
// rendering enums in scope.
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../companion/companion_selection.dart';
import '../../domain/models/pet_models.dart';
import '../../domain/services/statistics_engine.dart';
import '../controllers/reports_controller.dart';
import '../theme/app_theme.dart';

/// Screen 07: Monthly Report (07 月报)
/// Real features:
/// - Month selector (< YYYY年M月 > with prev/next navigation)
/// - Top banner: Total focus time (X小时 Y分钟), MoM comparison (+X%), Mochi encouragement
/// - 31-day trend bar chart (总时长 Xh Ym +X%)
/// - Peak focus time slot matrix (7 weekdays x 12 time chunks, 0-24h) with peak slot tag
/// - Average session duration & longest session card
/// - Mochi growth card (level, XP progress bar, focus days together)
/// - Category breakdown distribution
/// - Bottom quote & 分享月度成就 CTA (via SharePlus)
class MonthlyReportPage extends ConsumerStatefulWidget {
  const MonthlyReportPage({super.key});

  @override
  ConsumerState<MonthlyReportPage> createState() => _MonthlyReportPageState();
}

class _MonthlyReportPageState extends ConsumerState<MonthlyReportPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(reportsControllerProvider.notifier).loadAllReports();
    });
  }

  /// `6 分钟` under an hour, `1.5h` above it — the unit follows the magnitude.
  String _formatShortDuration(int seconds) {
    if (seconds < 3600) {
      return '${(seconds / 60).round()} 分钟';
    }
    return '${(seconds / 3600).toStringAsFixed(1)}h';
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
        // `其他` is a category the user can pick; a record with no category has
        // not been put in it. Same rule as the weekly report, and the same one the
        // task domain follows.
        return '未分类';
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

  Future<void> _shareMonthlyAchievement(
      PeriodReport report, PeriodComparison? comp, int year, int month) async {
    final companionName = ref.watch(companionDisplayNameProvider);
    final hours = (report.totalSeconds / 3600).toStringAsFixed(1);
    final text =
        '$year年$month月，我和 $companionName 一起专注了 $hours 小时，共 ${report.sessionCount} 次！🌱\n每一个专注的日子，都在靠近更喜欢的自己 ♡';
    await SharePlus.instance
        .share(ShareParams(text: text, subject: 'Cozy Focus 月度成就分享'));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsControllerProvider);
    final report = state.monthlyReport;
    final comp = state.monthlyComparison;
    final peakSlot = state.monthlyPeakSlot;
    final petProg = state.petProgress;

    final year = state.monthlyYear;
    final month = state.monthlyMonth;

    final totalSec = report?.totalSeconds ?? 0;
    final totalHours = totalSec ~/ 3600;
    final totalMins = (totalSec % 3600) ~/ 60;
    final pctComp = comp?.durationChangePercentage;

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
          '专注记录',
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
            // Segmented Tabs: 周报 / 月报 (Active) / 年报
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
                      child: GestureDetector(
                        onTap: () => context.pushReplacement('/reports/weekly'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          child: const Text('周报',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        alignment: Alignment.center,
                        child: const Text('月报',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primarySage)),
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

            // Scrollable Content
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primarySage))
                  : ListView(
                      // Centred on a wide screen, so a landscape phone does not
                      // stretch every card across it — see AppLayout.
                      padding: EdgeInsets.symmetric(
                        horizontal: AppLayout.reportGutter(
                            MediaQuery.sizeOf(context).width),
                        vertical: 20,
                      ),
                      children: [
                        // Month Selector
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded,
                                  color: AppColors.textSecondary),
                              onPressed: () => ref
                                  .read(reportsControllerProvider.notifier)
                                  .previousMonth(),
                            ),
                            Text(
                              '$year年$month月',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded,
                                  color: AppColors.textSecondary),
                              onPressed: () => ref
                                  .read(reportsControllerProvider.notifier)
                                  .nextMonth(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Top Summary Banner
                        _buildHeroBanner(totalHours, totalMins, pctComp),
                        const SizedBox(height: 16),

                        // Monthly Trend Bar Chart
                        _buildMonthlyTrendChart(report, year, month, pctComp),
                        const SizedBox(height: 16),

                        // Peak Focus Time Slot Heatmap Matrix
                        _buildPeakTimeSlotMatrix(report, peakSlot),
                        const SizedBox(height: 16),

                        // Average & Longest Session Card
                        _buildAverageAndLongestCard(report),
                        const SizedBox(height: 16),

                        // Mochi Growth Card
                        _buildMochiGrowthCard(report, petProg),
                        const SizedBox(height: 16),

                        // Category Breakdown Card
                        if (report != null &&
                            report.categoryBreakdowns.isNotEmpty) ...[
                          _buildCategoryBreakdown(report),
                          const SizedBox(height: 16),
                        ],

                        // Bottom Quote
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 20),
                          alignment: Alignment.center,
                          child: const Text(
                            '“ 每一个专注的日子，\n都在靠近更喜欢的自己。 ”',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Share Monthly Achievement CTA
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
                            label: const Text('分享月度成就',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            onPressed:
                                (report != null && report.totalSeconds > 0)
                                    ? () => _shareMonthlyAchievement(
                                        report, comp, year, month)
                                    : null,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(int hours, int mins, double? pctComp) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2E8),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primarySage.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '这个月，\n你一共专注了',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$hours',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(' 小时 ',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    Text(
                      '$mins',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(' 分钟',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 6),
                if (pctComp != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '比上个月 ${pctComp >= 0 ? '↑' : '↓'} ${pctComp.abs().toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: pctComp >= 0
                            ? AppColors.primarySage
                            : AppColors.accentPeach,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Text('🐶', style: TextStyle(fontSize: 36)),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Text(
                  '继续加油！\n你已经做得很好了 ♡',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendChart(
      PeriodReport? report, int year, int month, double? pctComp) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final dayTotals = <int, int>{}; // 1..daysInMonth -> seconds
    for (int i = 1; i <= daysInMonth; i++) {
      dayTotals[i] = 0;
    }
    if (report != null) {
      for (final r in report.records) {
        dayTotals[r.startAt.day] =
            (dayTotals[r.startAt.day] ?? 0) + r.durationSeconds;
      }
    }

    int maxSec = 0;
    for (final s in dayTotals.values) {
      if (s > maxSec) maxSec = s;
    }
    if (maxSec == 0) maxSec = 3600;

    final totalH = (report?.totalSeconds ?? 0) ~/ 3600;
    final totalM = ((report?.totalSeconds ?? 0) % 3600) ~/ 60;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('📊', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text(
                    '专注趋势',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '总时长 ${totalH}h ${totalM}m ${pctComp != null ? (pctComp >= 0 ? '+${pctComp.toStringAsFixed(0)}%' : '${pctComp.toStringAsFixed(0)}%') : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primarySage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chart area: 31 day columns
          SizedBox(
            height: 125,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(daysInMonth, (index) {
                final day = index + 1;
                final sec = dayTotals[day] ?? 0;
                final ratio = (sec / maxSec).clamp(0.0, 1.0);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Tooltip(
                          message: '$day日: ${(sec / 60).toStringAsFixed(0)}分钟',
                          child: Container(
                            height:
                                (ratio * 95).clamp(sec > 0 ? 6.0 : 2.0, 95.0),
                            decoration: BoxDecoration(
                              color: sec > 0
                                  ? AppColors.primarySage
                                  : AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (day == 1 ||
                            day == 7 ||
                            day == 14 ||
                            day == 21 ||
                            day == 28)
                          // The day alone, on one line. `10/28` inside a
                          // one-thirty-first column wrapped to three stacked
                          // lines and the labels overlapped each other into an
                          // unreadable smear — found by walking the app on a
                          // device. The month is already in the header above.
                          //
                          // Given its own width, because the column cannot give
                          // it one: on a 360dp phone each of the 31 columns is
                          // about 7dp and a two-digit label needs 9, so `14`,
                          // `21` and `28` were drawn as one digit and a sliver
                          // of the next. Found by walking the reports on a small
                          // screen. The labelled days are six apart, so the
                          // couple of dp of spill has nothing to overlap.
                          OverflowBox(
                            maxWidth: 40,
                            maxHeight: 20,
                            // Sized to the label rather than to the column it is
                            // escaping: the default `max` fit asks the parent for
                            // as much as it will give, and a Column hands its
                            // non-flex children an unbounded main axis.
                            fit: OverflowBoxFit.deferToChild,
                            alignment: Alignment.center,
                            child: Text(
                              '$day',
                              maxLines: 1,
                              softWrap: false,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 8,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 10),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeakTimeSlotMatrix(
      PeriodReport? report, TimeSlotSummary? peakSlot) {
    final matrix = List.generate(7, (_) => List.generate(12, (_) => 0));
    if (report != null) {
      for (final r in report.records) {
        final w = (r.startAt.weekday - 1).clamp(0, 6);
        final hChunk = (r.startAt.hour ~/ 2).clamp(0, 11);
        matrix[w][hChunk] += r.durationSeconds;
      }
    }

    int maxCell = 0;
    for (final row in matrix) {
      for (final cell in row) {
        if (cell > maxCell) maxCell = cell;
      }
    }
    if (maxCell == 0) maxCell = 1800;

    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('⏰', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 6),
                        Text(
                          '最佳专注时间段',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (peakSlot != null && peakSlot.totalSeconds > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentPeachLight,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                        color: AppColors.accentPeach.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '你在${peakSlot.name}最容易专注！🌙',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentPeach,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Heatmap grid (7 rows x 12 cols)
          Column(
            children: List.generate(7, (wIndex) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        weekdays[wIndex],
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Row(
                        children: List.generate(12, (hIndex) {
                          final sec = matrix[wIndex][hIndex];
                          final intensity = (sec / maxCell).clamp(0.0, 1.0);
                          Color cellColor = AppColors.surfaceMuted;
                          if (sec > 0) {
                            if (intensity > 0.6) {
                              cellColor = AppColors.primarySage;
                            } else if (intensity > 0.3) {
                              cellColor =
                                  AppColors.primarySage.withValues(alpha: 0.6);
                            } else {
                              cellColor =
                                  AppColors.primarySage.withValues(alpha: 0.3);
                            }
                          }
                          return Expanded(
                            child: Container(
                              height: 12,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: cellColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
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
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 34),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0时',
                    style:
                        TextStyle(fontSize: 9, color: AppColors.textTertiary)),
                Text('6时',
                    style:
                        TextStyle(fontSize: 9, color: AppColors.textTertiary)),
                Text('12时',
                    style:
                        TextStyle(fontSize: 9, color: AppColors.textTertiary)),
                Text('18时',
                    style:
                        TextStyle(fontSize: 9, color: AppColors.textTertiary)),
                Text('24时',
                    style:
                        TextStyle(fontSize: 9, color: AppColors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAverageAndLongestCard(PeriodReport? report) {
    final avgMins = report?.averageSessionMinutes ?? 0;
    final longestSec = report?.longestSession?.durationSeconds ?? 0;
    final longestH = longestSec ~/ 3600;
    final longestM = (longestSec % 3600) ~/ 60;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('平均专注时长',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$avgMins',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(' 分钟',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                  ],
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
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('最长一次专注',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (longestH > 0) ...[
                      Text(
                        '$longestH',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Text(' 小时 ',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                    ],
                    Text(
                      '$longestM',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(' 分钟',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMochiGrowthCard(PeriodReport? report, PetProgress? petProg) {
    final companionName = ref.watch(companionDisplayNameProvider);
    final activeDays = report?.activeDaysCount ?? 0;
    final level = petProg?.level ?? 1;
    // Same leveling convention as mochi_growth_page: 100 XP per level,
    // progress bar reflects XP earned within the current level.
    const xpPerLevel = 100;
    final currentXp = (petProg?.experiencePoints ?? 0) % xpPerLevel;
    const targetXp = xpPerLevel;
    final ratio = targetXp > 0 ? (currentXp / targetXp).clamp(0.0, 1.0) : 0.0;

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
          Row(
            children: [
              const Text('🤎', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                '$companionName 的成长',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundWarm,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Text('🐶', style: TextStyle(fontSize: 36)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '这个月 $companionName 又长大了！',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Lv.$level',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primarySage,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceMuted,
                        color: AppColors.primarySage,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$currentXp / $targetXp',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '和你一度过了 $activeDays 天的专注时光，$companionName 感到好幸福！ ♡',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(PeriodReport report) {
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
            '分类结构',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 12,
              child: Row(
                children: report.categoryBreakdowns.map((cat) {
                  return Expanded(
                    flex: (cat.percentage * 1000).toInt().clamp(1, 1000),
                    child: Container(
                      color: _categoryColor(cat.categoryId),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Column(
            children: report.categoryBreakdowns.map((cat) {
              final amount = _formatShortDuration(cat.totalSeconds);
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
                    Expanded(
                      child: Text(
                        _categoryLabel(cat.categoryId),
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                    Text(
                      '$amount (${(cat.percentage * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
