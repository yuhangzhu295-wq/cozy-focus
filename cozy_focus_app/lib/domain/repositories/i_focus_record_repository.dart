import '../models/focus_record.dart';

abstract interface class IFocusRecordRepository {
  Future<void> insert(FocusRecord record);

  Future<FocusRecord?> findBySessionId(String sessionId);

  /// All records for a date range (inclusive), for statistics aggregation.
  Future<List<FocusRecord>> findByDateRange(
    String userId, {
    required DateTime from,
    required DateTime to,
  });

  /// Total focus seconds for a given day (YYYY-MM-DD local date).
  Future<int> totalSecondsForDay(String userId, DateTime date);

  /// Daily totals for a calendar range — used for heatmap.
  Future<Map<DateTime, int>> dailyTotals(
    String userId, {
    required DateTime from,
    required DateTime to,
  });
}
