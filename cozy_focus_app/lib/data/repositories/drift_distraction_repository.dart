import '../../domain/models/distraction_note.dart' as domain;
import '../../domain/repositories/i_distraction_repository.dart';
import '../local/daos/distraction_dao.dart';

/// The distraction repository, backed by Drift.
///
/// Thin on purpose: the queries live in the DAO, and this exists so the domain
/// depends on [IDistractionRepository] rather than on a Drift accessor.
class DriftDistractionRepository implements IDistractionRepository {
  final DistractionDao _dao;

  DriftDistractionRepository(this._dao);

  @override
  Future<List<domain.DistractionNote>> findByFilter(
    String userId,
    domain.DistractionFilter filter, {
    String? categoryId,
  }) =>
      _dao.findByFilter(userId, filter, categoryId: categoryId);

  @override
  Future<domain.DistractionNote?> findById(String id) => _dao.findById(id);

  @override
  Future<int> countOpen(String userId) => _dao.countOpen(userId);

  @override
  Future<Map<String, int>> openCountsByCategory(String userId) =>
      _dao.openCountsByCategory(userId);

  @override
  Future<void> insert(domain.DistractionNote note) => _dao.insert(note);

  @override
  Future<void> markHandled(
    String id, {
    required DateTime at,
    String? convertedTaskId,
  }) =>
      _dao.markHandled(id, at: at, convertedTaskId: convertedTaskId);

  @override
  Future<void> reopen(String id) => _dao.reopen(id);

  @override
  Future<void> deleteById(String id) => _dao.deleteById(id);

  @override
  Future<List<domain.DistractionNote>> notesForSession(String sessionId) =>
      _dao.notesForSession(sessionId);

  @override
  Future<List<domain.DistractionNote>> notesBetween(
    String userId,
    DateTime from,
    DateTime to,
  ) =>
      _dao.notesBetween(userId, from, to);
}
