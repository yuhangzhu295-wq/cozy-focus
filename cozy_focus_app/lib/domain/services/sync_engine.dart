import '../models/sync_models.dart';
import '../models/enums.dart';
import '../repositories/i_sync_outbox_repository.dart';
import 'package:uuid/uuid.dart';

/// SyncEngine — drains the local outbox and pushes changes to Supabase.
///
/// This is a skeleton for Phase 1. Full Supabase integration is in Phase 7.
/// Local writes enqueue to sync_outbox. SyncEngine processes the queue
/// when connectivity is available.
///
/// Outbox pattern:
///   Local write → enqueue(SyncOutbox) → SyncEngine.flush() → Supabase upsert
///   On failure: mark as failed, exponential backoff, retry
abstract interface class ISyncEngine {
  /// Enqueue a local change for later sync.
  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required String operation,
    required Map<String, dynamic> payload,
  });

  /// Attempt to sync all pending outbox entries.
  Future<void> flush();

  /// Whether the device currently has network connectivity.
  bool get isOnline;
}

/// Offline-first stub — stores everything in outbox, flush() is a no-op
/// until Phase 7 wires in the real Supabase calls.
class LocalOnlySyncEngine implements ISyncEngine {
  final ISyncOutboxRepository _outboxRepo;
  final Uuid _uuid;

  LocalOnlySyncEngine({
    required ISyncOutboxRepository outboxRepo,
    Uuid? uuid,
  })  : _outboxRepo = outboxRepo,
        _uuid = uuid ?? const Uuid();

  @override
  bool get isOnline => false; // Phase 7: replace with connectivity_plus check

  @override
  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    await _outboxRepo.enqueue(SyncOutbox(
      id: _uuid.v4(),
      tableName: tableName,
      recordId: recordId,
      operation: operation,
      payload: payload,
      status: SyncStatus.pending,
      attemptCount: 0,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<void> flush() async {
    // Phase 7: implement real Supabase sync here.
    // For now: no-op. Records stay local.
  }
}
