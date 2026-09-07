import '../models/sync_models.dart';

abstract interface class IRewardLedgerRepository {
  /// Insert reward entry. If session_id already exists, does nothing (idempotent).
  Future<bool> settleReward(RewardLedger entry);

  /// Returns existing entry if already settled, otherwise null.
  Future<RewardLedger?> findBySessionId(String sessionId);
}
