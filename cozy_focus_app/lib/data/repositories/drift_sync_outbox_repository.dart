import '../../domain/models/sync_models.dart';
import '../../domain/repositories/i_sync_outbox_repository.dart';
import '../local/daos/sync_outbox_dao.dart';

class DriftSyncOutboxRepository implements ISyncOutboxRepository {
  final SyncOutboxDao _dao;
  DriftSyncOutboxRepository(this._dao);

  @override
  Future<void> enqueue(SyncOutbox entry) => _dao.enqueue(entry);

  @override
  Future<List<SyncOutbox>> findPending({int limit = 100}) =>
      _dao.findPending(limit: limit);

  @override
  Future<void> markSynced(String id) => _dao.markSynced(id);

  @override
  Future<void> markFailed(String id, String errorMessage) =>
      _dao.markFailed(id, errorMessage);

  @override
  Future<void> delete(String id) => _dao.deleteById(id);
}
