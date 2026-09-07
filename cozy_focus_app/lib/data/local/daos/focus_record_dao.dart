import 'package:drift/drift.dart';
import '../../../domain/models/focus_record.dart';
import '../tables/focus_records_table.dart';
import '../app_database.dart';

part 'focus_record_dao.g.dart';

@DriftAccessor(tables: [FocusRecords])
class FocusRecordDao extends DatabaseAccessor<AppDatabase>
    with _$FocusRecordDaoMixin {
  FocusRecordDao(super.db);

  Future<void> insert(FocusRecord record) async {
    await into(focusRecords).insertOnConflictUpdate(
      FocusRecordsCompanion.insert(
        id: record.id,
        sessionId: record.sessionId,
        userId: record.userId,
        categoryId: Value(record.categoryId),
        durationSeconds: record.durationSeconds,
        startAt: record.startAt,
        endAt: record.endAt,
        recordedAt: record.recordedAt,
        isCountedForReward: Value(record.isCountedForReward),
        note: Value(record.note),
      ),
    );
  }

  Future<FocusRecord?> findBySessionId(String sessionId) async {
    final row = await (select(focusRecords)
          ..where((t) => t.sessionId.equals(sessionId)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  Future<List<FocusRecord>> findByDateRange(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await (select(focusRecords)
          ..where((t) =>
              t.userId.equals(userId) &
              t.startAt.isBiggerOrEqualValue(from) &
              t.startAt.isSmallerOrEqualValue(to))
          ..orderBy([(t) => OrderingTerm.asc(t.startAt)]))
        .get();
    return rows.map(_map).toList();
  }

  Future<int> totalSecondsForDay(String userId, DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final rows = await findByDateRange(userId, from: dayStart, to: dayEnd);
    return rows.fold(0, (acc, r) => acc + r.durationSeconds);
  }

  Future<Map<DateTime, int>> dailyTotals(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final records = await findByDateRange(userId, from: from, to: to);
    final map = <DateTime, int>{};
    for (final r in records) {
      final day = DateTime(r.startAt.year, r.startAt.month, r.startAt.day);
      map[day] = (map[day] ?? 0) + r.durationSeconds;
    }
    return map;
  }

  FocusRecord _map(FocusRecordsData row) {
    return FocusRecord(
      id: row.id,
      sessionId: row.sessionId,
      userId: row.userId,
      categoryId: row.categoryId,
      durationSeconds: row.durationSeconds,
      startAt: row.startAt,
      endAt: row.endAt,
      recordedAt: row.recordedAt,
      isCountedForReward: row.isCountedForReward,
      note: row.note,
    );
  }
}
