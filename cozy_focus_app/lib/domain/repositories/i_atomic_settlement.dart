import '../models/sync_models.dart';

/// Atomic settlement interface — all reads happen INSIDE the transaction.
///
/// The caller passes only primitive/value-type inputs. The implementation is
/// responsible for reading the latest PetProgress, CraftJob and CraftRecipe
/// from the database within the same transaction, preventing lost-update races.
abstract interface class IAtomicSettlement {
  /// Settle reward for [entry.sessionId] atomically.
  ///
  /// [addedFocusSeconds] — the actual elapsed focus seconds from the session.
  /// [now]               — clock value supplied by the caller (FocusClock).
  ///
  /// Returns [true] if this call performed the settlement (session was not
  /// previously settled), [false] if the session was already settled (safe
  /// no-op; all writes are skipped).
  Future<bool> settleAtomically({
    required RewardLedger entry,
    required int addedFocusSeconds,
    required DateTime now,
  });
}
