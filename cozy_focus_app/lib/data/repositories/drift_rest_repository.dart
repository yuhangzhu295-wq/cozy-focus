import '../../domain/models/rest_session.dart' as domain;
import '../../domain/repositories/i_rest_repository.dart';
import '../local/daos/rest_dao.dart';

/// The rest repository, backed by Drift.
class DriftRestRepository implements IRestRepository {
  final RestDao _dao;

  DriftRestRepository(this._dao);

  @override
  Future<domain.RestSession?> findRunning(String userId) =>
      _dao.findRunning(userId);

  @override
  Future<domain.RestSession?> findById(String id) => _dao.findById(id);

  @override
  Future<List<domain.RestSession>> findBetween(
    String userId,
    DateTime from,
    DateTime to,
  ) =>
      _dao.findBetween(userId, from, to);

  @override
  Future<int> totalSecondsBetween(
    String userId,
    DateTime from,
    DateTime to,
  ) =>
      _dao.totalSecondsBetween(userId, from, to);

  @override
  Future<void> insert(domain.RestSession session) => _dao.insert(session);

  @override
  Future<void> updateSession(domain.RestSession session) =>
      _dao.updateSession(session);
}
