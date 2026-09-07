import '../models/sync_models.dart';
import '../models/enums.dart';

abstract interface class ISyncOutboxRepository {
  Future<void> enqueue(SyncOutbox entry);
  Future<List<SyncOutbox>> findPending({int limit = 100});
  Future<void> markSynced(String id);
  Future<void> markFailed(String id, String errorMessage);
  Future<void> delete(String id);
}
