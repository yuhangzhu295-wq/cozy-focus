import '../../domain/models/focus_record.dart';
import '../../domain/repositories/i_focus_record_repository.dart';
import '../local/daos/focus_record_dao.dart';

class DriftFocusRecordRepository implements IFocusRecordRepository {
  final FocusRecordDao _dao;
  DriftFocusRecordRepository(this._dao);

  @override
  Future<void> insert(FocusRecord record) => _dao.insert(record);

  @override
  Future<FocusRecord?> findBySessionId(String sessionId) =>
      _dao.findBySessionId(sessionId);

  @override
  Future<List<FocusRecord>> findByDateRange(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) =>
      _dao.findByDateRange(userId, from: from, to: to);

  @override
  Future<int> totalSecondsForDay(String userId, DateTime date) =>
      _dao.totalSecondsForDay(userId, date);

  @override
  Future<Map<DateTime, int>> dailyTotals(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) =>
      _dao.dailyTotals(userId, from: from, to: to);
}
