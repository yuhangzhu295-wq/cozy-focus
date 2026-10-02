import '../models/sync_models.dart';

abstract interface class IRewardLedgerRepository {
  /// Insert reward entry. If session_id already exists, does nothing (idempotent).
  Future<bool> settleReward(RewardLedger entry);

  /// Returns existing entry if already settled, otherwise null.
  Future<RewardLedger?> findBySessionId(String sessionId);

  /// How many sessions this user has ever had settled.
  ///
  /// The only thing `first_focus` means is "this was the first", and both
  /// settlement paths need to answer it: the atomic path counts the rows inside
  /// its transaction, the sequential path asks here.
  Future<int> countForUser(String userId);
}
