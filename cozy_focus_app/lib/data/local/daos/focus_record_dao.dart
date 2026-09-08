import 'package:drift/drift.dart';
import '../../../domain/models/focus_record.dart' as domain;
import '../tables/focus_records_table.dart';
import '../app_database.dart' hide FocusRecord;

part 'focus_record_dao.g.dart';

@DriftAccessor(tables: [FocusRecords])
class FocusRecordDao extends DatabaseAccessor<AppDatabase>
    with _$FocusRecordDaoMixin {
  FocusRecordDao(super.db);

  Future<void> insert(domain.FocusRecord record) async {
    await into(focusRecords).insertOnConflictUpdate(
      FocusRecordsCompanion(
        id: Value(record.id),
        sessionId: Value(record.sessionId),
        userId: Value(record.userId),
        categoryId: Value(record.categoryId),
        taskName: Value(record.taskName),
        mood: Value(record.mood),
        durationSeconds: Value(record.durationSeconds),
        startAt: Value(record.startAt),
        endAt: Value(record.endAt),
        recordedAt: Value(record.recordedAt),
        isCountedForReward: Value(record.isCountedForReward),
        note: Value(record.note),
      ),
    );
  }

  Future<domain.FocusRecord?> findBySessionId(String sessionId) async {
    final row = await (select(focusRecords)
          ..where((t) => t.sessionId.equals(sessionId)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  Future<List<domain.FocusRecord>> findByDateRange(
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
    final records = await findByDateRange(userId, from: dayStart, to: dayEnd);
    return records.fold<int>(0, (acc, r) => acc + r.durationSeconds);
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

  domain.FocusRecord _map(dynamic row) {
    return domain.FocusRecord(
      id: row.id as String,
      sessionId: row.sessionId as String,
      userId: row.userId as String,
      categoryId: row.categoryId as String?,
      taskName: row.taskName as String?,
      mood: row.mood as String?,
      durationSeconds: row.durationSeconds as int,
      startAt: row.startAt as DateTime,
      endAt: row.endAt as DateTime,
      recordedAt: row.recordedAt as DateTime,
      isCountedForReward: row.isCountedForReward as bool,
      note: row.note as String?,
    );
  }
}