import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/analytics_range.dart';
import '../../domain/services/analytics_summary.dart';
import '../../domain/services/duration_text.dart';
import '../controllers/analytics_controller.dart';
import '../theme/app_theme.dart';

/// Screen 07: 统计分析, as the today screen's third view.
///
/// ## What it shows, and what it refuses to
///
/// Three numbers — total, count, mean — a bar per day, and the share of the time
/// each task took. Every one is a sum, a count or a division of the records in the
/// window, computed by [buildAnalyticsSummary]. There is no score, no trend, no
/// projection, and nothing that could show a number the database does not contain.
/// The design's own figures are examples; none of them are written down here.
class StatisticsView extends ConsumerStatefulWidget {
  final DateTime day;

  const StatisticsView({super.key, required this.day});

  @override
  ConsumerState<StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends ConsumerState<StatisticsView> {
  AnalyticsRangeKind _kind = AnalyticsRangeKind.week;

  /// How many steps the user has moved the window from the one containing today.
  ///
  /// An offset rather than a stored date, so the window keeps following the day
  /// the page is showing: changing the day on the header cannot leave the
  /// statistics pointing at a window that no longer contains it.
  int _offset = 0;

  AnalyticsRange get _range {
    var range = AnalyticsRange.containing(_kind, widget.day);
    for (var i = 0; i < _offset.abs(); i++) {
      range = range.step(_offset.sign);
    }
    return range;
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(analyticsSummaryProvider(_range));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KindSelector(
          kind: _kind,
          onChanged: (kind) => setState(() {
            _kind = kind;
            _offset = 0;
          }),
        ),
        _RangeHeader(
          range: _range,
          onStep: (direction) => setState(() => _offset += direction),
          onToday: _offset == 0 ? null : () => setState(() => _offset = 0),
        ),
        const SizedBox(height: 12),
        switch (summary) {
          AsyncData(:final value) => _SummaryBody(summary: value),
          AsyncError(:final error) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '统计没能读出来：$error',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.accentPeach),
              ),
            ),
          _ => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
        },
      ],
    );
  }
}

class _SummaryBody extends StatelessWidget {
  final AnalyticsSummary summary;

  const _SummaryBody({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) return const _NoData();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.access_time_rounded,
                value: formatDurationText(summary.totalSeconds),
                label: '专注总时长',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.check_circle_outline,
                value: '${summary.sessionCount}',
                label: '专注次数',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.bar_chart_rounded,
                value: formatDurationText(summary.averageSeconds),
                label: '平均时长',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionLabel(text: '每日专注时长'),
        const SizedBox(height: 10),
        _DailyChart(
          daily: summary.daily,
          busiest: summary.busiestDaySeconds,
        ),
        const SizedBox(height: 20),
        const _SectionLabel(text: '任务专注时长分布'),
        const SizedBox(height: 10),
        for (final share in summary.shares) _ShareRow(share: share),
      ],
    );
  }
}

class _KindSelector extends StatelessWidget {
  final AnalyticsRangeKind kind;
  final ValueChanged<AnalyticsRangeKind> onChanged;

  const _KindSelector({required this.kind, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (final option in AnalyticsRangeKind.values)
            Expanded(
              child: Semantics(
                key: ValueKey('stats_range_${option.id}'),
                button: true,
                selected: option == kind,
                label: option.label,
                child: GestureDetector(
                  onTap: () => onChanged(option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: option == kind
                          ? AppColors.primarySage
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      option.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            option == kind ? FontWeight.w700 : FontWeight.w500,
                        color: option == kind
                            ? AppColors.textLight
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeHeader extends StatelessWidget {
  final AnalyticsRange range;
  final ValueChanged<int> onStep;
  final VoidCallback? onToday;

  const _RangeHeader({
    required this.range,
    required this.onStep,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: '上一段',
            child: IconButton(
              key: const ValueKey('stats_previous'),
              onPressed: () => onStep(-1),
              icon: const Icon(Icons.chevron_left_rounded,
                  color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onToday,
              child: Text(
                range.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: '下一段',
            child: IconButton(
              key: const ValueKey('stats_next'),
              onPressed: () => onStep(1),
              icon: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primarySage),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// One bar per day in the window, scaled to the tallest.
///
/// The axis is labelled in hours only when something in the window reaches an
/// hour; a chart that always said 小时 over four-minute bars would be a scale
/// nobody can read.
class _DailyChart extends StatelessWidget {
  final List<DailyFocusBucket> daily;
  final int busiest;

  const _DailyChart({required this.daily, required this.busiest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            busiest >= 3600 ? '小时' : '分钟',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final bucket in daily)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Semantics(
                            readOnly: true,
                            label: '${bucket.weekdayLabel} '
                                '${formatDurationText(bucket.seconds)}',
                            child: Container(
                              // A day with nothing on it gets a hairline rather
                              // than nothing, so the axis keeps its rhythm.
                              height: busiest == 0
                                  ? 2
                                  : (bucket.seconds / busiest * 76)
                                      .clamp(2.0, 76.0),
                              decoration: BoxDecoration(
                                color: bucket.seconds == 0
                                    ? AppColors.border
                                    : AppColors.primarySage,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            bucket.weekdayLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
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
}

class _ShareRow extends StatelessWidget {
  final TaskFocusShare share;

  const _ShareRow({required this.share});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primarySage,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              share.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatDurationText(share.seconds),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
            child: Text(
              share.percentLabel,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 40, color: AppColors.textTertiary),
          SizedBox(height: 12),
          Text(
            '这一段时间还没有专注记录',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '完成一次专注之后，这里会有时长、次数和每天的变化。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
