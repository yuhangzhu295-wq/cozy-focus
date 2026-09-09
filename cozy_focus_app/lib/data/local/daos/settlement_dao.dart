import 'package:drift/drift.dart';
import '../../../domain/models/sync_models.dart' show RewardLedger;
import '../../../domain/models/pet_models.dart' show PetProgress;
import '../../../domain/models/craft_models.dart' show CraftJob, CraftRecipe;
import '../../../domain/models/enums.dart';
import '../../../domain/repositories/i_atomic_settlement.dart';
import '../tables/sync_tables.dart';
import '../tables/pet_tables.dart';
import '../tables/craft_tables.dart';
import '../app_database.dart' hide CraftJob, CraftRecipe;

part 'settlement_dao.g.dart';

/// Implements [IAtomicSettlement] via a single Drift transaction that writes:
///   1. RewardLedger (idempotency gate — unique on session_id)
///   2. PetProgress  (XP + focus minutes + happiness)
///   3. CraftJob     (progress accumulation, completion flag)
///   4. InventoryItem (quantity increment on job completion)
///
/// SQLite serialises all callers inside the transaction, so concurrent
/// settle() calls cannot both pass the idempotency check.
@DriftAccessor(
    tables: [RewardLedgerTable, PetProgressTable, CraftJobs, InventoryItems])
class SettlementDao extends DatabaseAccessor<AppDatabase>
    with _$SettlementDaoMixin
    implements IAtomicSettlement {
  SettlementDao(super.db);

  @override
  Future<bool> settleAtomically({
    required RewardLedger entry,
    required PetProgress? currentProgress,
    required int addedFocusSeconds,
    required CraftJob? activeJob,
    required CraftRecipe? activeRecipe,
    required DateTime now,
  }) async {
    return transaction(() async {
      // --- 1. Idempotency gate (serialised by surrounding transaction) ---
      final existing = await (select(rewardLedgerTable)
            ..where((t) => t.sessionId.equals(entry.sessionId)))
          .getSingleOrNull();
      if (existing != null) return false;

      // --- 2. Insert ledger entry ---
      await into(rewardLedgerTable).insert(
        RewardLedgerTableCompanion.insert(
          sessionId: entry.sessionId,
          userId: entry.userId,
          focusCoinsEarned: entry.focusCoinsEarned,
          experienceEarned: entry.experienceEarned,
          craftRecipeUnlocked: Value(entry.craftRecipeUnlocked),
          settledAt: entry.settledAt,
        ),
      );

      // --- 3. Update pet XP ---
      if (currentProgress != null) {
        final addedMinutes = (addedFocusSeconds / 60).floor();
        await (update(petProgressTable)
              ..where((t) => t.id.equals(currentProgress.id)))
            .write(PetProgressTableCompanion(
          experiencePoints:
              Value(currentProgress.experiencePoints + entry.experienceEarned),
          totalFocusMinutes:
              Value(currentProgress.totalFocusMinutes + addedMinutes),
          happinessScore: Value(
              ((currentProgress.happinessScore + 5).clamp(0, 100) as num)
                  .toInt()),
          updatedAt: Value(now),
        ));
      }

      // --- 4. Accumulate craft progress ---
      if (activeJob != null && activeRecipe != null) {
        final newProgress = activeJob.progressSeconds + addedFocusSeconds;
        final required = activeRecipe.requiredSeconds;
        final completed = newProgress >= required;

        await (update(craftJobs)..where((t) => t.id.equals(activeJob.id)))
            .write(CraftJobsCompanion(
          progressSeconds: Value(newProgress),
          status: Value(completed
              ? CraftJobStatus.completed.name
              : activeJob.status.name),
          completedAt: completed ? Value(now) : const Value.absent(),
        ));

        if (completed) {
          await _atomicInventoryIncrement(
              activeJob.userId, activeRecipe.outputItemId, now);
        }
      }

      return true;
    });
  }

  Future<void> _atomicInventoryIncrement(
      String userId, String itemId, DateTime now) async {
    final existing = await (select(inventoryItems)
          ..where((t) => t.userId.equals(userId) & t.itemId.equals(itemId)))
        .getSingleOrNull();
    if (existing != null) {
      await (update(inventoryItems)..where((t) => t.id.equals(existing.id)))
          .write(InventoryItemsCompanion(
        quantity: Value(existing.quantity + 1),
        updatedAt: Value(now),
      ));
    } else {
      await into(inventoryItems).insert(InventoryItemsCompanion.insert(
        id: 'inv_${userId}_${itemId}_${now.millisecondsSinceEpoch}',
        userId: userId,
        itemId: itemId,
        quantity: const Value(1),
        updatedAt: now,
      ));
    }
  }
}
