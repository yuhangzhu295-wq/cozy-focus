import 'package:flutter_test/flutter_test.dart';
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/repositories/i_focus_record_repository.dart';
import 'package:cozy_focus_app/domain/services/statistics_engine.dart';

class _MockRecordRepo implements IFocusRecordRepository {
  final List<FocusRecord> records = [];

  @override
  Future<void> insert(FocusRecord record) async => records.add(record);

  @override
  Future<FocusRecord?> findBySessionId(String sessionId) async =>
      records.where((r) => r.sessionId == sessionId).firstOrNull;

  @override
  Future<FocusRecord?> findById(String id) async =>
      records.where((r) => r.id == id).firstOrNull;

  @override
  Future<void> update(FocusRecord record) async {
    final idx = records.indexWhere((r) => r.id == record.id);
    if (idx != -1) records[idx] = record;
  }

  @override
  Future<void> deleteById(String id) async =>
      records.removeWhere((r) => r.id == id);

  @override
  Future<List<FocusRecord>> findByDateRange(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    return records
        .where((r) =>
            r.userId == userId &&
            r.startAt.isAfter(from.subtract(const Duration(milliseconds: 1))) &&
            r.startAt.isBefore(to.add(const Duration(milliseconds: 1))))
        .toList();
  }

  @override
  Future<int> totalSecondsForDay(String userId, DateTime date) async {
    final list = await findByDateRange(userId,
        from: DateTime(date.year, date.month, date.day),
        to: DateTime(date.year, date.month, date.day, 23, 59, 59));
    return list.fold<int>(0, (acc, r) => acc + r.durationSeconds);
  }

  @override
  Future<Map<DateTime, int>> dailyTotals(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final list = await findByDateRange(userId, from: from, to: to);
    final map = <DateTime, int>{};
    for (final r in list) {
      final day = DateTime(r.startAt.year, r.startAt.month, r.startAt.day);
      map[day] = (map[day] ?? 0) + r.durationSeconds;
    }
    return map;
  }
}

void main() {
  const userId = 'u1';
  late _MockRecordRepo repo;
  late StatisticsEngine engine;

  setUp(() {
    repo = _MockRecordRepo();
    engine = StatisticsEngine(repo);
  });

  test('getDaySummary aggregates seconds and count accurately', () async {
    final today = DateTime(2026, 9, 8, 14, 0);
    repo.records.add(FocusRecord(
      id: 'r1',
      sessionId: 's1',
      userId: userId,
      categoryId: 'work',
      durationSeconds: 1500,
      startAt: today,
      endAt: today.add(const Duration(seconds: 1500)),
      recordedAt: today,
      isCountedForReward: true,
    ));
    repo.records.add(FocusRecord(
      id: 'r2',
      sessionId: 's2',
      userId: userId,
      categoryId: 'study',
      durationSeconds: 1800,
      startAt: today.add(const Duration(hours: 2)),
      endAt: today.add(const Duration(hours: 2, seconds: 1800)),
      recordedAt: today,
      isCountedForReward: true,
    ));

    final summary = await engine.getDaySummary(userId, today);
    expect(summary.totalSeconds, equals(3300));
    expect(summary.totalMinutes, equals(55));
    expect(summary.sessionCount, equals(2));
    expect(summary.records.length, equals(2));
  });

  test(
      'getPeriodReport computes categories, moods, active days, and longest session',
      () async {
    final day1 = DateTime(2026, 9, 1, 10, 0);
    final day2 = DateTime(2026, 9, 2, 11, 0);

    repo.records.addAll([
      FocusRecord(
        id: 'r1',
        sessionId: 's1',
        userId: userId,
        categoryId: 'work',
        mood: 'happy',
        durationSeconds: 1200,
        startAt: day1,
        endAt: day1.add(const Duration(seconds: 1200)),
        recordedAt: day1,
        isCountedForReward: true,
      ),
      FocusRecord(
        id: 'r2',
        sessionId: 's2',
        userId: userId,
        categoryId: 'work',
        mood: 'calm',
        durationSeconds: 2400, // Longest
        startAt: day1.add(const Duration(hours: 3)),
        endAt: day1.add(const Duration(hours: 3, seconds: 2400)),
        recordedAt: day1,
        isCountedForReward: true,
      ),
      FocusRecord(
        id: 'r3',
        sessionId: 's3',
        userId: userId,
        categoryId: 'reading',
        mood: 'calm',
        durationSeconds: 600,
        startAt: day2,
        endAt: day2.add(const Duration(seconds: 600)),
        recordedAt: day2,
        isCountedForReward: true,
      ),
    ]);

    final report = await engine.getPeriodReport(
      userId: userId,
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 9, 7),
    );

    expect(report.totalSeconds, equals(4200));
    expect(report.totalMinutes, equals(70));
    expect(report.sessionCount, equals(3));
    expect(report.activeDaysCount, equals(2));
    expect(report.longestSession?.id, equals('r2'));

    // Category breakdown
    expect(report.categoryBreakdowns.length, equals(2));
    expect(report.categoryBreakdowns[0].categoryId, equals('work'));
    expect(report.categoryBreakdowns[0].totalSeconds, equals(3600));
    expect(
        report.categoryBreakdowns[0].percentage, closeTo(3600 / 4200, 0.001));

    // Mood counts
    expect(report.moodCounts['happy'], equals(1));
    expect(report.moodCounts['calm'], equals(2));
  });

  test('weekly, monthly, yearly report helpers set proper boundaries',
      () async {
    final report = await engine.getWeeklyReport(userId, DateTime(2026, 9, 7));
    expect(report.from, equals(DateTime(2026, 9, 7)));
    expect(report.to.day, equals(13)); // 7 days (7th to 13th end)

    final monthReport = await engine.getMonthlyReport(userId, 2026, 2);
    expect(monthReport.from, equals(DateTime(2026, 2, 1)));
    expect(monthReport.to.month, equals(2));
    expect(monthReport.to.day, equals(28)); // Non-leap year 2026

    final yearReport = await engine.getYearlyReport(userId, 2026);
    expect(yearReport.from, equals(DateTime(2026, 1, 1)));
    expect(yearReport.to.year, equals(2026));
    expect(yearReport.to.month, equals(12));
    expect(yearReport.to.day, equals(31));
  });

  test(
      'weekly comparison calculates duration percentage and session count difference',
      () async {
    final prevWeekStart = DateTime(2026, 8, 31);
    final currWeekStart = DateTime(2026, 9, 7);

    // Prev week: 1 session 3600s
    repo.records.add(FocusRecord(
      id: 'pw1',
      sessionId: 's_pw1',
      userId: userId,
      durationSeconds: 3600,
      startAt: prevWeekStart.add(const Duration(hours: 10)),
      endAt: prevWeekStart.add(const Duration(hours: 11)),
      recordedAt: prevWeekStart,
      isCountedForReward: true,
    ));

    // Curr week: 2 sessions 4608s (which is +28% of 3600)
    repo.records.add(FocusRecord(
      id: 'cw1',
      sessionId: 's_cw1',
      userId: userId,
      durationSeconds: 4608,
      startAt: currWeekStart.add(const Duration(hours: 10)),
      endAt: currWeekStart.add(const Duration(hours: 11, seconds: 1008)),
      recordedAt: currWeekStart,
      isCountedForReward: true,
    ));

    final comparison = await engine.getWeeklyComparison(userId, currWeekStart);
    expect(comparison.currentSeconds, equals(4608));
    expect(comparison.previousSeconds, equals(3600));
    expect(comparison.durationChangePercentage, closeTo(28.0, 0.01));
    expect(comparison.sessionCountDiff, equals(0)); // 1 vs 1
  });

  test('getBestDay and getPeakTimeSlot work accurately on records', () async {
    final morning = DateTime(2026, 9, 8, 9, 30);
    final evening = DateTime(2026, 9, 8, 20, 15);

    repo.records.addAll([
      FocusRecord(
        id: 'r_m',
        sessionId: 'sm',
        userId: userId,
        durationSeconds: 1800,
        startAt: morning,
        endAt: morning.add(const Duration(minutes: 30)),
        recordedAt: morning,
        isCountedForReward: true,
      ),
      FocusRecord(
        id: 'r_e',
        sessionId: 'se',
        userId: userId,
        durationSeconds: 3600,
        startAt: evening,
        endAt: evening.add(const Duration(minutes: 60)),
        recordedAt: evening,
        isCountedForReward: true,
      ),
    ]);

    final report = await engine.getDaySummary(userId, DateTime(2026, 9, 8));
    final peakSlot = engine.getPeakTimeSlot(report.records);
    expect(peakSlot.name, equals('晚上'));
    expect(peakSlot.totalSeconds, equals(3600));
    expect(peakSlot.sessionCount, equals(1));

    final period = await engine.getWeeklyReport(userId, DateTime(2026, 9, 7));
    final bestDay = engine.getBestDay(period);
    expect(bestDay?.totalSeconds, equals(5400));
    expect(bestDay?.date.day, equals(8));
  });
}
