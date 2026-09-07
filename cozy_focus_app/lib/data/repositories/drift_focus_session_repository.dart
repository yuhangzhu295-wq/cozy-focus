import '../../domain/models/focus_session.dart';
import '../../domain/repositories/i_focus_session_repository.dart';
import '../local/daos/focus_session_dao.dart';

class DriftFocusSessionRepository implements IFocusSessionRepository {
  final FocusSessionDao _dao;
  DriftFocusSessionRepository(this._dao);

  @override
  Future<void> save(FocusSession session) => _dao.upsertSession(session);

  @override
  Future<void> update(FocusSession session) => _dao.upsertSession(session);

  @override
  Future<FocusSession?> findById(String id) => _dao.findById(id);

  @override
  Future<List<FocusSession>> findActive(String userId) =>
      _dao.findActive(userId);

  @override
  Future<List<FocusSession>> findRecent(String userId, {int limit = 20}) =>
      _dao.findRecent(userId, limit: limit);

  @override
  Future<void> delete(String id) => _dao.deleteById(id);
}
