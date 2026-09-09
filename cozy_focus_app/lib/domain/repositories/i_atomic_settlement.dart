import '../models/sync_models.dart';
import '../models/pet_models.dart';
import '../models/craft_models.dart';

/// Optional interface injected into [RewardService] to wrap the ledger +
/// pet XP + craft progress writes in a single atomic DB transaction.
///
/// Production code provides a [SettlementDao]-backed implementation.
/// Unit tests that do not need transaction semantics may omit this.
abstract interface class IAtomicSettlement {
  /// Settle reward atomically.
  ///
  /// Returns [true] if this call performed the settlement (session was not
  /// previously settled), [false] if the session was already settled.
  Future<bool> settleAtomically({
    required RewardLedger entry,
    required PetProgress? currentProgress,
    required int addedFocusSeconds,
    required CraftJob? activeJob,
    required CraftRecipe? activeRecipe,
    required DateTime now,
  });
}
