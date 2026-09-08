// StatisticsEngine — aggregates FocusRecords into reports and metrics.
//
// Conforms to ARCHITECTURE_GUARDRAILS.md:
// - All statistics are derived from real FocusRecord data via IFocusRecordRepository.
// - UI pages never query raw records to calculate their own totals.
// - All calculations are deterministic and time-zone safe.

import '../models/focus_record.dart';
import '../repositories/i_focus_record_repository.dart';

class DayProgressSummary {
  final int totalSeconds;
  final int sessionCount;
  final List<FocusRecord> records;

  const DayProgressSummary({
    required this.totalSeconds,
    required this.sessionCount,
    required this.records,
  });

  int get totalMinutes => (totalSeconds / 60).floor();
}

class CategoryBreakdown {
  final String categoryId;
  final int totalSeconds;
  final int sessionCount;
  final double percentage;

  const CategoryBreakdown({
    required this.categoryId,
    required this.totalSeconds,
    required this.sessionCount,
    required this.percentage,
  });

  int get totalMinutes => (totalSeconds / 60).floor();
}

class PeriodReport {
  final DateTime from;
  final DateTime to;
  final int totalSeconds;
  final int sessionCount;
  final int activeDaysCount;
  final Map<DateTime, int> dailySeconds;
  final List<CategoryBreakdown> categoryBreakdowns;
  final Map<String, int> moodCounts;
  final List<FocusRecord> records;
  final FocusRecord? longestSession;

  const PeriodReport({
    required this.from,
    required this.to,
    required this.totalSeconds,
    required this.sessionCount,
    required this.activeDaysCount,
    required this.dailySeconds,
    required this.categoryBreakdowns,
    required this.moodCounts,
    required this.records,
    this.longestSession,
  });

  int get totalMinutes => (totalSeconds / 60).floor();
  double get totalHours => (totalSeconds / 3600.0);
  int get averageSessionMinutes =>
      sessionCount > 0 ? (totalMinutes / sessionCount).round() : 0;
}

class PeriodComparison {
  final int currentSeconds;
  final int previousSeconds;
  final int currentSessionCount;
  final int previousSessionCount;

  const PeriodComparison({
    required this.currentSeconds,
    required this.previousSeconds,
    required this.currentSessionCount,
    required this.previousSessionCount,
  });

  /// Percentage change in duration (e.g. 28.0 means +28%, -15.5 means -15.5%).
  /// Returns 0.0 if previous is 0 and current is 0, or 100.0 if previous is 0 and current > 0.
  double get durationChangePercentage {
    if (previousSeconds == 0) {
      return currentSeconds > 0 ? 100.0 : 0.0;
    }
    return ((currentSeconds - previousSeconds) / previousSeconds) * 100.0;
  }

  int get sessionCountDiff => currentSessionCount - previousSessionCount;
}

class BestDaySummary {
  final DateTime date;
  final int totalSeconds;

  const BestDaySummary({
    required this.date,
    required this.totalSeconds,
  });

  double get totalHours => totalSeconds / 3600.0;
  int get totalMinutes => (totalSeconds / 60).floor();
}

class BestMonthSummary {
  final int year;
  final int month;
  final int totalSeconds;

  const BestMonthSummary({
    required this.year,
    required this.month,
    required this.totalSeconds,
  });

  double get totalHours => totalSeconds / 3600.0;
  int get totalMinutes => (totalSeconds / 60).floor();
}

class TimeSlotSummary {
  final String name; // e.g. '早晨', '下午', '晚上', '深夜'
  final String timeRange; // e.g. '06:00 - 12:00', '18:00 - 23:00'
  final int totalSeconds;
  final int sessionCount;

  const TimeSlotSummary({
    required this.name,
    required this.timeRange,
    required this.totalSeconds,
    required this.sessionCount,
  });
}

class StatisticsEngine {
  final IFocusRecordRepository _recordRepo;

  StatisticsEngine(this._recordRepo);

  /// Get summary and records for a specific day.
  Future<DayProgressSummary> getDaySummary(String userId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    final records = await _recordRepo.findByDateRange(
      userId,
      from: startOfDay,
      to: endOfDay,
    );

    final totalSeconds =
        records.fold<int>(0, (acc, r) => acc + r.durationSeconds);

    return DayProgressSummary(
      totalSeconds: totalSeconds,
      sessionCount: records.length,
      records: records,
    );
  }

  /// Build a report for any arbitrary date range (used for Week, Month, Year).
  Future<PeriodReport> getPeriodReport({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final records = await _recordRepo.findByDateRange(
      userId,
      from: from,
      to: to,
    );

    int totalSeconds = 0;
    final dailySeconds = <DateTime, int>{};
    final catSeconds = <String, int>{};
    final catCounts = <String, int>{};
    final moodCounts = <String, int>{};
    FocusRecord? longest;

    for (final r in records) {
      totalSeconds += r.durationSeconds;

      // Group by calendar day (midnight normalized)
      final dayKey = DateTime(r.startAt.year, r.startAt.month, r.startAt.day);
      dailySeconds[dayKey] = (dailySeconds[dayKey] ?? 0) + r.durationSeconds;

      // Category aggregation
      final cat = r.categoryId ?? 'default';
      catSeconds[cat] = (catSeconds[cat] ?? 0) + r.durationSeconds;
      catCounts[cat] = (catCounts[cat] ?? 0) + 1;

      // Mood aggregation
      if (r.mood != null && r.mood!.isNotEmpty) {
        moodCounts[r.mood!] = (moodCounts[r.mood!] ?? 0) + 1;
      }

      // Longest session
      if (longest == null || r.durationSeconds > longest.durationSeconds) {
        longest = r;
      }
    }

    // Build category breakdowns with percentage
    final categoryBreakdowns = <CategoryBreakdown>[];
    for (final entry in catSeconds.entries) {
      final percentage = totalSeconds > 0 ? (entry.value / totalSeconds) : 0.0;
      categoryBreakdowns.add(CategoryBreakdown(
        categoryId: entry.key,
        totalSeconds: entry.value,
        sessionCount: catCounts[entry.key] ?? 0,
        percentage: percentage,
      ));
    }
    // Sort descending by seconds
    categoryBreakdowns.sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));

    return PeriodReport(
      from: from,
      to: to,
      totalSeconds: totalSeconds,
      sessionCount: records.length,
      activeDaysCount: dailySeconds.keys.length,
      dailySeconds: dailySeconds,
      categoryBreakdowns: categoryBreakdowns,
      moodCounts: moodCounts,
      longestSession: longest,
      records: records,
    );
  }

  /// Weekly report: 7 days starting from weekStart.
  Future<PeriodReport> getWeeklyReport(String userId, DateTime weekStart) {
    final from = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final to = from
        .add(const Duration(days: 7))
        .subtract(const Duration(milliseconds: 1));
    return getPeriodReport(userId: userId, from: from, to: to);
  }

  /// Monthly report: calendar month.
  Future<PeriodReport> getMonthlyReport(String userId, int year, int month) {
    final from = DateTime(year, month, 1);
    final nextMonth =
        month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final to = nextMonth.subtract(const Duration(milliseconds: 1));
    return getPeriodReport(userId: userId, from: from, to: to);
  }

  /// Yearly report: calendar year.
  Future<PeriodReport> getYearlyReport(String userId, int year) {
    final from = DateTime(year, 1, 1);
    final to =
        DateTime(year + 1, 1, 1).subtract(const Duration(milliseconds: 1));
    return getPeriodReport(userId: userId, from: from, to: to);
  }

  /// Compare a week with the immediately preceding 7-day week.
  Future<PeriodComparison> getWeeklyComparison(
      String userId, DateTime weekStart) async {
    final currentReport = await getWeeklyReport(userId, weekStart);
    final prevStart = weekStart.subtract(const Duration(days: 7));
    final prevReport = await getWeeklyReport(userId, prevStart);

    return PeriodComparison(
      currentSeconds: currentReport.totalSeconds,
      previousSeconds: prevReport.totalSeconds,
      currentSessionCount: currentReport.sessionCount,
      previousSessionCount: prevReport.sessionCount,
    );
  }

  /// Compare a month with the previous month.
  Future<PeriodComparison> getMonthlyComparison(
      String userId, int year, int month) async {
    final currentReport = await getMonthlyReport(userId, year, month);
    final prevYear = month == 1 ? year - 1 : year;
    final prevMonth = month == 1 ? 12 : month - 1;
    final prevReport = await getMonthlyReport(userId, prevYear, prevMonth);

    return PeriodComparison(
      currentSeconds: currentReport.totalSeconds,
      previousSeconds: prevReport.totalSeconds,
      currentSessionCount: currentReport.sessionCount,
      previousSessionCount: prevReport.sessionCount,
    );
  }

  /// Compare a year with the previous year.
  Future<PeriodComparison> getYearlyComparison(String userId, int year) async {
    final currentReport = await getYearlyReport(userId, year);
    final prevReport = await getYearlyReport(userId, year - 1);

    return PeriodComparison(
      currentSeconds: currentReport.totalSeconds,
      previousSeconds: prevReport.totalSeconds,
      currentSessionCount: currentReport.sessionCount,
      previousSessionCount: prevReport.sessionCount,
    );
  }

  /// Find the best day in a period report.
  BestDaySummary? getBestDay(PeriodReport report) {
    if (report.dailySeconds.isEmpty) return null;
    DateTime? bestDay;
    int maxSec = -1;
    for (final entry in report.dailySeconds.entries) {
      if (entry.value > maxSec) {
        maxSec = entry.value;
        bestDay = entry.key;
      }
    }
    if (bestDay == null || maxSec <= 0) return null;
    return BestDaySummary(date: bestDay, totalSeconds: maxSec);
  }

  /// Find the best month in a yearly report.
  BestMonthSummary? getBestMonth(PeriodReport report) {
    if (report.records.isEmpty) return null;
    final monthSeconds = <int, int>{};
    final year = report.from.year;
    for (final r in report.records) {
      monthSeconds[r.startAt.month] =
          (monthSeconds[r.startAt.month] ?? 0) + r.durationSeconds;
    }
    int bestMonth = 1;
    int maxSec = -1;
    for (final entry in monthSeconds.entries) {
      if (entry.value > maxSec) {
        maxSec = entry.value;
        bestMonth = entry.key;
      }
    }
    if (maxSec <= 0) return null;
    return BestMonthSummary(year: year, month: bestMonth, totalSeconds: maxSec);
  }

  /// Calculate peak time-slot (Morning, Afternoon, Evening, Night) based on session start hours.
  TimeSlotSummary getPeakTimeSlot(List<FocusRecord> records) {
    if (records.isEmpty) {
      return const TimeSlotSummary(
        name: '\u6682\u65e0',
        timeRange: '--:-- - --:--',
        totalSeconds: 0,
        sessionCount: 0,
      );
    }
    const morning = '\u6e05\u6668'; // 清晨
    const afternoon = '\u4e0b\u5348'; // 下午
    const evening = '\u665a\u4e0a'; // 晚上
    const night = '\u6df1\u591c'; // 深夜

    final slotSeconds = <String, int>{
      morning: 0,
      afternoon: 0,
      evening: 0,
      night: 0
    };
    final slotRanges = <String, String>{
      morning: '06:00 - 12:00',
      afternoon: '12:00 - 18:00',
      evening: '18:00 - 23:00',
      night: '23:00 - 06:00',
    };
    final slotCounts = <String, int>{
      morning: 0,
      afternoon: 0,
      evening: 0,
      night: 0
    };

    for (final r in records) {
      final h = r.startAt.hour;
      String slot;
      if (h >= 6 && h < 12) {
        slot = morning;
      } else if (h >= 12 && h < 18) {
        slot = afternoon;
      } else if (h >= 18 && h < 23) {
        slot = evening;
      } else {
        slot = night;
      }
      slotSeconds[slot] = (slotSeconds[slot] ?? 0) + r.durationSeconds;
      slotCounts[slot] = (slotCounts[slot] ?? 0) + 1;
    }

    String bestSlot = evening;
    int maxSec = -1;
    for (final e in slotSeconds.entries) {
      if (e.value > maxSec) {
        maxSec = e.value;
        bestSlot = e.key;
      }
    }

    return TimeSlotSummary(
      name: bestSlot,
      timeRange: slotRanges[bestSlot] ?? '',
      totalSeconds: slotSeconds[bestSlot] ?? 0,
      sessionCount: slotCounts[bestSlot] ?? 0,
    );
  }
}
