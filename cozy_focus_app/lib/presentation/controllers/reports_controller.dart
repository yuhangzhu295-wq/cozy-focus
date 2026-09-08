import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/pet_models.dart';
import '../../domain/repositories/i_pet_repository.dart';
import '../../domain/services/statistics_engine.dart';
import 'providers.dart';

class ReportsState {
  final bool isLoading;

  // Weekly Report
  final DateTime selectedWeekStart;
  final PeriodReport? weeklyReport;
  final PeriodComparison? weeklyComparison;
  final BestDaySummary? weeklyBestDay;

  // Monthly Report
  final int monthlyYear;
  final int monthlyMonth;
  final PeriodReport? monthlyReport;
  final PeriodComparison? monthlyComparison;
  final TimeSlotSummary? monthlyPeakSlot;
  final PetProgress? petProgress;

  // Yearly Report
  final int yearlyYear;
  final PeriodReport? yearlyReport;
  final PeriodComparison? yearlyComparison;
  final BestMonthSummary? yearlyBestMonth;
  final TimeSlotSummary? yearlyPeakSlot;

  const ReportsState({
    this.isLoading = false,
    required this.selectedWeekStart,
    this.weeklyReport,
    this.weeklyComparison,
    this.weeklyBestDay,
    required this.monthlyYear,
    required this.monthlyMonth,
    this.monthlyReport,
    this.monthlyComparison,
    this.monthlyPeakSlot,
    this.petProgress,
    required this.yearlyYear,
    this.yearlyReport,
    this.yearlyComparison,
    this.yearlyBestMonth,
    this.yearlyPeakSlot,
  });

  ReportsState copyWith({
    bool? isLoading,
    DateTime? selectedWeekStart,
    PeriodReport? weeklyReport,
    PeriodComparison? weeklyComparison,
    BestDaySummary? weeklyBestDay,
    int? monthlyYear,
    int? monthlyMonth,
    PeriodReport? monthlyReport,
    PeriodComparison? monthlyComparison,
    TimeSlotSummary? monthlyPeakSlot,
    PetProgress? petProgress,
    int? yearlyYear,
    PeriodReport? yearlyReport,
    PeriodComparison? yearlyComparison,
    BestMonthSummary? yearlyBestMonth,
    TimeSlotSummary? yearlyPeakSlot,
  }) {
    return ReportsState(
      isLoading: isLoading ?? this.isLoading,
      selectedWeekStart: selectedWeekStart ?? this.selectedWeekStart,
      weeklyReport: weeklyReport ?? this.weeklyReport,
      weeklyComparison: weeklyComparison ?? this.weeklyComparison,
      weeklyBestDay: weeklyBestDay ?? this.weeklyBestDay,
      monthlyYear: monthlyYear ?? this.monthlyYear,
      monthlyMonth: monthlyMonth ?? this.monthlyMonth,
      monthlyReport: monthlyReport ?? this.monthlyReport,
      monthlyComparison: monthlyComparison ?? this.monthlyComparison,
      monthlyPeakSlot: monthlyPeakSlot ?? this.monthlyPeakSlot,
      petProgress: petProgress ?? this.petProgress,
      yearlyYear: yearlyYear ?? this.yearlyYear,
      yearlyReport: yearlyReport ?? this.yearlyReport,
      yearlyComparison: yearlyComparison ?? this.yearlyComparison,
      yearlyBestMonth: yearlyBestMonth ?? this.yearlyBestMonth,
      yearlyPeakSlot: yearlyPeakSlot ?? this.yearlyPeakSlot,
    );
  }
}

class ReportsController extends StateNotifier<ReportsState> {
  final StatisticsEngine _statsEngine;
  final IPetRepository _petRepo;
  final String userId;

  ReportsController({
    required StatisticsEngine statsEngine,
    required IPetRepository petRepo,
    this.userId = 'default_user',
  })  : _statsEngine = statsEngine,
        _petRepo = petRepo,
        super(ReportsState(
          selectedWeekStart: _getMonday(DateTime.now()),
          monthlyYear: DateTime.now().year,
          monthlyMonth: DateTime.now().month,
          yearlyYear: DateTime.now().year,
        )) {
    loadAllReports();
  }

  static DateTime _getMonday(DateTime d) {
    final clean = DateTime(d.year, d.month, d.day);
    return clean.subtract(Duration(days: clean.weekday - 1));
  }

  Future<void> loadAllReports() async {
    state = state.copyWith(isLoading: true);
    await Future.wait([
      loadWeeklyReport(state.selectedWeekStart),
      loadMonthlyReport(state.monthlyYear, state.monthlyMonth),
      loadYearlyReport(state.yearlyYear),
      _loadPetProgress(),
    ]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadPetProgress() async {
    final pet = await _petRepo.findPetByUser(userId);
    if (pet != null) {
      final prog = await _petRepo.findPetProgress(pet.id);
      state = state.copyWith(petProgress: prog);
    }
  }

  Future<void> loadWeeklyReport(DateTime weekStart) async {
    final monday = _getMonday(weekStart);
    final report = await _statsEngine.getWeeklyReport(userId, monday);
    final comp = await _statsEngine.getWeeklyComparison(userId, monday);
    final best = _statsEngine.getBestDay(report);

    state = state.copyWith(
      selectedWeekStart: monday,
      weeklyReport: report,
      weeklyComparison: comp,
      weeklyBestDay: best,
    );
  }

  Future<void> previousWeek() async {
    final prev = state.selectedWeekStart.subtract(const Duration(days: 7));
    await loadWeeklyReport(prev);
  }

  Future<void> nextWeek() async {
    final next = state.selectedWeekStart.add(const Duration(days: 7));
    await loadWeeklyReport(next);
  }

  Future<void> loadMonthlyReport(int year, int month) async {
    final report = await _statsEngine.getMonthlyReport(userId, year, month);
    final comp = await _statsEngine.getMonthlyComparison(userId, year, month);
    final peak = _statsEngine.getPeakTimeSlot(report.records);

    state = state.copyWith(
      monthlyYear: year,
      monthlyMonth: month,
      monthlyReport: report,
      monthlyComparison: comp,
      monthlyPeakSlot: peak,
    );
  }

  Future<void> previousMonth() async {
    int y = state.monthlyYear;
    int m = state.monthlyMonth - 1;
    if (m < 1) {
      m = 12;
      y -= 1;
    }
    await loadMonthlyReport(y, m);
  }

  Future<void> nextMonth() async {
    int y = state.monthlyYear;
    int m = state.monthlyMonth + 1;
    if (m > 12) {
      m = 1;
      y += 1;
    }
    await loadMonthlyReport(y, m);
  }

  Future<void> loadYearlyReport(int year) async {
    final report = await _statsEngine.getYearlyReport(userId, year);
    final comp = await _statsEngine.getYearlyComparison(userId, year);
    final bestMonth = _statsEngine.getBestMonth(report);
    final peak = _statsEngine.getPeakTimeSlot(report.records);

    state = state.copyWith(
      yearlyYear: year,
      yearlyReport: report,
      yearlyComparison: comp,
      yearlyBestMonth: bestMonth,
      yearlyPeakSlot: peak,
    );
  }

  Future<void> previousYear() async {
    await loadYearlyReport(state.yearlyYear - 1);
  }

  Future<void> nextYear() async {
    await loadYearlyReport(state.yearlyYear + 1);
  }
}

final reportsControllerProvider =
    StateNotifierProvider<ReportsController, ReportsState>((ref) {
  final statsEngine = ref.watch(statisticsEngineProvider);
  final petRepo = ref.watch(petRepositoryProvider);
  return ReportsController(statsEngine: statsEngine, petRepo: petRepo);
});
