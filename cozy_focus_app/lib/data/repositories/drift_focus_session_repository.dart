import '../../domain/models/focus_session.dart' as domain;
import '../../domain/repositories/i_focus_session_repository.dart';
import '../local/daos/focus_session_dao.dart';

class DriftFocusSessionRepository implements IFocusSessionRepository {
  final FocusSessionDao _dao;
  DriftFocusSessionRepository(this._dao);

  @override
  Future<void> save(domain.FocusSession session) => _dao.upsertSession(session);

  @override
  Future<void> update(domain.FocusSession session) => _dao.upsertSession(session);

  @override
  Future<domain.FocusSession?> findById(String id) => _dao.findById(id);

  @override
  Future<List<domain.FocusSession>> findActive(String userId) =>
      _dao.findActive(userId);

  @override
  Future<List<domain.FocusSession>> findRecent(String userId, {int limit = 20}) =>
      _dao.findRecent(userId, limit: limit);

  @override
  Future<void> delete(String id) => _dao.deleteById(id);
}
