import 'package:drift/drift.dart';
import '../../../domain/growth/growth_level_curve.dart';
import '../../../domain/models/sync_models.dart' show RewardLedger;
import '../../../domain/models/enums.dart';
import '../../../domain/services/companion_memory.dart';
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
  PetMemories,
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
          final newXp = progress.experiencePoints + entry.experienceEarned;
          await (update(petProgressTable)
                ..where((t) => t.id.equals(progress.id)))
              .write(PetProgressTableCompanion(
            // `level` is derived from the new XP rather than carried through.
            // It shipped as a dead field that settlement wrote back unchanged,
            // so it never left its seeded value — see
            // MOCHI_GROWTH_STAGE0_AUDIT.md §A. Deriving it here keeps the
            // stored truth and the displayed truth the same thing.
            level: Value(GrowthLevelCurve.levelForXp(newXp)),
            experiencePoints: Value(newXp),
            totalFocusMinutes: Value(progress.totalFocusMinutes + addedMinutes),
            happinessScore: Value((progress.happinessScore + 5).clamp(0, 100)),
            updatedAt: Value(now),
          ));

          // 2b. Memories. Recorded here, inside the same transaction that
          // settled the fact, so a memory can never describe something that was
          // rolled back — and so it inherits this method's exactly-once gate
          // above: a duplicate settlement returns before reaching this line.
          await _recordMemories(
            userId: entry.userId,
            petId: petRow.id,
            previousXp: progress.experiencePoints,
            newXp: newXp,
            now: now,
          );
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

  /// Appends the memories this settlement earned, inside the enclosing
  /// transaction.
  ///
  /// The decision of *what* is memorable lives in [CompanionMemory] so this
  /// path and the sequential one in `RewardService` cannot drift apart; this
  /// method only supplies the two facts the decision needs and inserts what it
  /// returns.
  ///
  /// Both facts are already established here: the ledger row for this session
  /// was inserted one step above and passed the `changes() == 1` gate, so the
  /// count now tells us whether this was the first; and the previous XP was
  /// read before the award, so the level comparison needs no extra query.
  ///
  /// ## What it may not do
  ///
  /// It writes `pet_memories` rows and nothing else. It awards no XP, coins or
  /// items, and cannot reach any of them: the only write below is an insert
  /// into [petMemories]. Recording that something happened therefore cannot
  /// change what happened.
  Future<void> _recordMemories({
    required String userId,
    required String petId,
    required int previousXp,
    required int newXp,
    required DateTime now,
  }) async {
    final settledCount = await (selectOnly(rewardLedgerTable)
          ..addColumns([rewardLedgerTable.sessionId.count()])
          ..where(rewardLedgerTable.userId.equals(userId)))
        .map((row) => row.read(rewardLedgerTable.sessionId.count()) ?? 0)
        .getSingle();

    final memories = CompanionMemory.earnedBy(
      petId: petId,
      settledCount: settledCount,
      previousXp: previousXp,
      newXp: newXp,
      at: now,
    );

    for (final memory in memories) {
      await into(petMemories).insert(
        PetMemoriesCompanion.insert(
          id: memory.id,
          petId: memory.petId,
          memoryType: memory.memoryType,
          content: memory.content,
          happenedAt: memory.happenedAt,
        ),
        // The id is derived, so a repeat at the same microsecond is the same
        // memory rather than a second one.
        mode: InsertMode.insertOrIgnore,
      );
    }
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
