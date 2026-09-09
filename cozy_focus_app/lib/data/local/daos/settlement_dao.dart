import 'package:drift/drift.dart';
import '../../../domain/models/sync_models.dart' show RewardLedger;
import '../../../domain/models/enums.dart';
import '../../../domain/repositories/i_atomic_settlement.dart';
import '../tables/sync_tables.dart';
import '../tables/pet_tables.dart';
import '../tables/craft_tables.dart';
import '../app_database.dart' hide CraftJob, CraftRecipe, Pet;

part 'settlement_dao.g.dart';

/// Implements [IAtomicSettlement] via a single Drift transaction.
///
/// ALL database reads happen INSIDE the transaction:
///   * RewardLedger idempotency gate -- uses raw SQL INSERT OR IGNORE + changes()
///     because Drift typed insert() returns the existing rowId (not -1) on conflict.
///   * PetProgress  -- re-read fresh, then written atomically
///   * CraftJob     -- re-read fresh; only inProgress jobs accumulate
///   * CraftRecipe  -- re-read to get requiredSeconds
///   * InventoryItem -- incremented atomically on job completion
@DriftAccessor(tables: [
  RewardLedgerTable,
  Pets,
  PetProgressTable,
  CraftRecipes,
  CraftJobs,
  InventoryItems,
])
class SettlementDao extends DatabaseAccessor<AppDatabase>
    with _$SettlementDaoMixin
    implements IAtomicSettlement {
  SettlementDao(super.db);

  @override
  Future<bool> settleAtomically({
    required RewardLedger entry,
    required int addedFocusSeconds,
    required DateTime now,
  }) async {
    return transaction(() async {
      // 1. Idempotency gate via raw SQL INSERT OR IGNORE + changes().
      //
      // Drift typed insert() with InsertMode.insertOrIgnore returns the
      // *existing* rowId on PK conflict -- it does NOT return -1. Using raw
      // SQL followed by SELECT changes() is the only reliable approach:
      //   changes() == 0 => row already existed, we are NOT the owner
      //   changes() == 1 => row was just inserted, we ARE the settlement owner
      //
      // Drift stores DateTimeColumn as microseconds since epoch (integer).
      await customStatement(
        'INSERT OR IGNORE INTO reward_ledger '
        '(session_id, user_id, focus_coins_earned, experience_earned, '
        'craft_recipe_unlocked, settled_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [
          entry.sessionId,
          entry.userId,
          entry.focusCoinsEarned,
          entry.experienceEarned,
          entry.craftRecipeUnlocked,
          entry.settledAt.millisecondsSinceEpoch ~/ 1000,
        ],
      );

      final changesRow =
          await customSelect('SELECT changes() AS c').getSingle();
      final wasInserted = changesRow.read<int>('c') == 1;
      if (!wasInserted) return false;

      final addedMinutes = (addedFocusSeconds / 60).floor();

      // 2. Pet XP -- re-read inside transaction, write atomically.
      // PetProgressTable is keyed by petId, not userId; resolve via Pets first.
      final petRow = await (select(pets)
            ..where((t) => t.userId.equals(entry.userId)))
          .getSingleOrNull();
      if (petRow != null) {
        final progressRows = await (select(petProgressTable)
              ..where((t) => t.petId.equals(petRow.id)))
            .get();
        if (progressRows.isNotEmpty) {
          final progress = progressRows.first;
          await (update(petProgressTable)
                ..where((t) => t.id.equals(progress.id)))
              .write(PetProgressTableCompanion(
            experiencePoints:
                Value(progress.experiencePoints + entry.experienceEarned),
            totalFocusMinutes: Value(progress.totalFocusMinutes + addedMinutes),
            happinessScore: Value((progress.happinessScore + 5).clamp(0, 100)),
            updatedAt: Value(now),
          ));
        }
      }

      // 3. Craft progress -- re-read inside transaction.
      if (addedFocusSeconds > 0) {
        final activeJobs = await (select(craftJobs)
              ..where((t) =>
                  t.userId.equals(entry.userId) &
                  t.status.equals(CraftJobStatus.inProgress.name)))
            .get();

        if (activeJobs.isNotEmpty) {
          final job = activeJobs.first;
          final recipeRows = await (select(craftRecipes)
                ..where((t) => t.id.equals(job.recipeId)))
              .get();

          if (recipeRows.isNotEmpty) {
            final recipe = recipeRows.first;
            final newProgress = job.progressSeconds + addedFocusSeconds;
            // CraftRecipes stores requiredMinutes; convert to seconds here.
            final requiredSecs = recipe.requiredMinutes * 60;
            final completed = newProgress >= requiredSecs;

            await (update(craftJobs)..where((t) => t.id.equals(job.id)))
                .write(CraftJobsCompanion(
              progressSeconds: Value(newProgress),
              status: Value(completed
                  ? CraftJobStatus.completed.name
                  : CraftJobStatus.inProgress.name),
              completedAt: completed ? Value(now) : const Value.absent(),
            ));

            if (completed) {
              await _incrementInventory(entry.userId, recipe.outputItemId, now);
            }
          }
        }
      }

      return true;
    });
  }

  /// Increment (or create) an inventory slot within the enclosing transaction.
  Future<void> _incrementInventory(
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
