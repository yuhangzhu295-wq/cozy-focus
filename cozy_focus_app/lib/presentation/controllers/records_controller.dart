import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/focus_record.dart';
import '../../domain/repositories/i_focus_record_repository.dart';
import '../../domain/services/statistics_engine.dart';
import 'providers.dart';

class RecordsState {
  final bool isLoading;
  final DayProgressSummary? todaySummary;
  final int yesterdaySeconds;
  final List<FocusRecord> allRecords;
  final String? selectedCategoryFilter;
  final String searchQuery;
  final DateTime currentMonth;
  final DateTime selectedCalendarDate;
  final DayProgressSummary? selectedDaySummary;
  final Map<DateTime, int> monthlyHeatmap;

  const RecordsState({
    this.isLoading = false,
    this.todaySummary,
    this.yesterdaySeconds = 0,
    this.allRecords = const [],
    this.selectedCategoryFilter,
    this.searchQuery = '',
    required this.currentMonth,
    required this.selectedCalendarDate,
    this.selectedDaySummary,
    this.monthlyHeatmap = const {},
  });

  RecordsState copyWith({
    bool? isLoading,
    DayProgressSummary? todaySummary,
    int? yesterdaySeconds,
    List<FocusRecord>? allRecords,
    String? Function()? selectedCategoryFilter,
    String? searchQuery,
    DateTime? currentMonth,
    DateTime? selectedCalendarDate,
    DayProgressSummary? selectedDaySummary,
    Map<DateTime, int>? monthlyHeatmap,
  }) {
    return RecordsState(
      isLoading: isLoading ?? this.isLoading,
      todaySummary: todaySummary ?? this.todaySummary,
      yesterdaySeconds: yesterdaySeconds ?? this.yesterdaySeconds,
      allRecords: allRecords ?? this.allRecords,
      selectedCategoryFilter: selectedCategoryFilter != null
          ? selectedCategoryFilter()
          : this.selectedCategoryFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      currentMonth: currentMonth ?? this.currentMonth,
      selectedCalendarDate: selectedCalendarDate ?? this.selectedCalendarDate,
      selectedDaySummary: selectedDaySummary ?? this.selectedDaySummary,
      monthlyHeatmap: monthlyHeatmap ?? this.monthlyHeatmap,
    );
  }

  /// Filtered records for History view (05B)
  List<FocusRecord> get filteredHistoryRecords {
    return allRecords.where((r) {
      if (selectedCategoryFilter != null &&
          selectedCategoryFilter!.isNotEmpty &&
          r.categoryId != selectedCategoryFilter) {
        return false;
      }
      if (searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        final taskMatch = (r.taskName ?? '').toLowerCase().contains(query);
        final noteMatch = (r.note ?? '').toLowerCase().contains(query);
        final catMatch = (r.categoryId ?? '').toLowerCase().contains(query);
        if (!taskMatch && !noteMatch && !catMatch) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Difference vs yesterday in minutes (positive = more today)
  int get todayVsYesterdayMinutes {
    final todaySec = todaySummary?.totalSeconds ?? 0;
    return ((todaySec - yesterdaySeconds) / 60).round();
  }
}

class RecordsController extends StateNotifier<RecordsState> {
  final IFocusRecordRepository _recordRepo;
  final StatisticsEngine _statsEngine;
  final String _userId;

  RecordsController({
    required IFocusRecordRepository recordRepo,
    required StatisticsEngine statsEngine,
    String userId = 'default_user',
  })  : _recordRepo = recordRepo,
        _statsEngine = statsEngine,
        _userId = userId,
        super(RecordsState(
          currentMonth: DateTime(DateTime.now().year, DateTime.now().month),
          selectedCalendarDate: DateTime.now(),
        ));

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true);
    final now = DateTime.now();

    // 1. Today summary
    final todaySummary = await _statsEngine.getDaySummary(_userId, now);

    // 2. Yesterday comparison
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdaySummary =
        await _statsEngine.getDaySummary(_userId, yesterday);

    // 3. All records for history (ordered latest first)
    final fromPast = now.subtract(const Duration(days: 365));
    final allRecords = await _recordRepo.findByDateRange(
      _userId,
      from: fromPast,
      to: now.add(const Duration(days: 1)),
    );
    // Sort descending by startAt
    allRecords.sort((a, b) => b.startAt.compareTo(a.startAt));

    // 4. Monthly heatmap for calendar (05D)
    await _loadMonthHeatmap(state.currentMonth);

    // 5. Selected day summary
    final selectedDaySummary =
        await _statsEngine.getDaySummary(_userId, state.selectedCalendarDate);

    state = state.copyWith(
      isLoading: false,
      todaySummary: todaySummary,
      yesterdaySeconds: yesterdaySummary.totalSeconds,
      allRecords: allRecords,
      selectedDaySummary: selectedDaySummary,
    );
  }

  Future<void> _loadMonthHeatmap(DateTime month) async {
    final from = DateTime(month.year, month.month, 1);
    final nextMonth = month.month == 12
        ? DateTime(month.year + 1, 1, 1)
        : DateTime(month.year, month.month + 1, 1);
    final to = nextMonth.subtract(const Duration(milliseconds: 1));

    final map = await _recordRepo.dailyTotals(_userId, from: from, to: to);
    state = state.copyWith(monthlyHeatmap: map);
  }

  void setCategoryFilter(String? categoryId) {
    state = state.copyWith(selectedCategoryFilter: () => categoryId);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> changeCalendarMonth(int delta) async {
    final newMonth =
        DateTime(state.currentMonth.year, state.currentMonth.month + delta, 1);
    state = state.copyWith(currentMonth: newMonth);
    await _loadMonthHeatmap(newMonth);
  }

  Future<void> selectCalendarDate(DateTime date) async {
    final summary = await _statsEngine.getDaySummary(_userId, date);
    state = state.copyWith(
      selectedCalendarDate: date,
      selectedDaySummary: summary,
    );
  }

  Future<FocusRecord?> getRecordById(String id) async {
    return _recordRepo.findById(id);
  }

  Future<void> updateRecord(FocusRecord record) async {
    await _recordRepo.update(record);
    await loadData();
  }

  Future<void> deleteRecord(String id) async {
    await _recordRepo.deleteById(id);
    await loadData();
  }
}

final recordsControllerProvider =
    StateNotifierProvider<RecordsController, RecordsState>((ref) {
  final recordRepo = ref.watch(focusRecordRepositoryProvider);
  final statsEngine = ref.watch(statisticsEngineProvider);
  return RecordsController(
    recordRepo: recordRepo,
    statsEngine: statsEngine,
  );
});
