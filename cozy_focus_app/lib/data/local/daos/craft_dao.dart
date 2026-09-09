import 'package:drift/drift.dart';
import '../../../domain/models/craft_models.dart' as domain;
import '../../../domain/models/enums.dart';
import '../../../domain/repositories/i_craft_repository.dart';
import '../tables/craft_tables.dart';
import '../app_database.dart';

part 'craft_dao.g.dart';

@DriftAccessor(tables: [CraftRecipes, CraftJobs, InventoryItems, RoomItems])
class CraftDao extends DatabaseAccessor<AppDatabase> with _$CraftDaoMixin {
  CraftDao(super.db);

  // ── Recipes ──────────────────────────────────────────────
  Future<List<domain.CraftRecipe>> findAllRecipes() async {
    final rows = await select(craftRecipes).get();
    return rows.map(_mapRecipe).toList();
  }

  Future<domain.CraftRecipe?> findRecipeById(String id) async {
    final row = await (select(craftRecipes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _mapRecipe(row);
  }

  Future<void> upsertRecipe(domain.CraftRecipe recipe) async {
    await into(craftRecipes).insertOnConflictUpdate(CraftRecipesCompanion(
      id: Value(recipe.id),
      name: Value(recipe.name),
      description: Value(recipe.description),
      requiredMinutes: Value(recipe.requiredMinutes),
      ingredientCostsJson: const Value('{}'),
      outputItemId: Value(recipe.outputItemId),
      outputQuantity: Value(recipe.outputQuantity),
      artworkPath: Value(recipe.artworkPath),
    ));
  }

  // ── Jobs ─────────────────────────────────────────────────
  Future<void> saveJob(domain.CraftJob job) async {
    await into(craftJobs).insertOnConflictUpdate(CraftJobsCompanion(
      id: Value(job.id),
      userId: Value(job.userId),
      recipeId: Value(job.recipeId),
      status: Value(job.status.name),
      progressSeconds: Value(job.progressSeconds),
      startedAt: Value(job.startedAt),
      completedAt: Value(job.completedAt),
      rewardClaimed: Value(job.rewardClaimed),
      sessionId: Value(job.sessionId),
    ));
  }

  Future<domain.CraftJob?> findJobById(String id) async {
    final row = await (select(craftJobs)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _mapJob(row);
  }

  Future<List<domain.CraftJob>> findJobsByUser(String userId) async {
    final rows = await (select(craftJobs)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
    return rows.map(_mapJob).toList();
  }

  Future<domain.CraftJob?> findActiveJobByUser(String userId) async {
    final row = await (select(craftJobs)
          ..where((t) =>
              t.userId.equals(userId) &
              t.status.isIn(['pending', 'inProgress']))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _mapJob(row);
  }

  /// Atomically inserts [newJob] only when no active job exists for [userId].
  /// All reads and writes run inside a single Drift transaction so concurrent
  /// callers cannot both pass the active-job check simultaneously.
  Future<bool> startJobIfNoneActive(
      String userId, domain.CraftJob newJob) async {
    return transaction(() async {
      final existing = await (select(craftJobs)
            ..where((t) =>
                t.userId.equals(userId) &
                t.status.isIn(['pending', 'inProgress']))
            ..limit(1))
          .getSingleOrNull();
      if (existing != null) return false;

      await into(craftJobs).insert(CraftJobsCompanion(
        id: Value(newJob.id),
        userId: Value(newJob.userId),
        recipeId: Value(newJob.recipeId),
        status: Value(newJob.status.name),
        progressSeconds: Value(newJob.progressSeconds),
        startedAt: Value(newJob.startedAt),
        completedAt: Value(newJob.completedAt),
        rewardClaimed: Value(newJob.rewardClaimed),
        sessionId: Value(newJob.sessionId),
      ));
      return true;
    });
  }

  // ── Inventory ─────────────────────────────────────────────
  Future<void> upsertInventoryItem(domain.InventoryItem item) async {
    await into(inventoryItems).insertOnConflictUpdate(InventoryItemsCompanion(
      id: Value(item.id),
      userId: Value(item.userId),
      itemId: Value(item.itemId),
      quantity: Value(item.quantity),
      updatedAt: Value(item.updatedAt),
    ));
  }

  Future<domain.InventoryItem?> findInventoryItem(
      String userId, String itemId) async {
    final row = await (select(inventoryItems)
          ..where((t) => t.userId.equals(userId) & t.itemId.equals(itemId)))
        .getSingleOrNull();
    return row == null ? null : _mapInventory(row);
  }

  Future<List<domain.InventoryItem>> findInventory(String userId) async {
    final rows = await (select(inventoryItems)
          ..where((t) => t.userId.equals(userId)))
        .get();
    return rows.map(_mapInventory).toList();
  }

  // ── Room ─────────────────────────────────────────────────
  Future<void> upsertRoomItem(domain.RoomItem item) async {
    await into(roomItems).insertOnConflictUpdate(RoomItemsCompanion(
      id: Value(item.id),
      userId: Value(item.userId),
      itemId: Value(item.itemId),
      positionX: Value(item.positionX),
      positionY: Value(item.positionY),
      scale: Value(item.scale),
      zIndex: Value(item.zIndex),
      isVisible: Value(item.isVisible),
      placedAt: Value(item.placedAt),
    ));
  }

  Future<void> removeRoomItem(String id) async {
    await (delete(roomItems)..where((t) => t.id.equals(id))).go();
  }

  Future<List<domain.RoomItem>> findRoomItems(String userId) async {
    final rows = await (select(roomItems)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.asc(t.zIndex)]))
        .get();
    return rows.map(_mapRoom).toList();
  }

  /// Atomically place [item] in the room, checking inventory availability.
  ///
  /// Inside a single SQLite transaction:
  ///   1. Reads the latest InventoryItem for this user + itemId.
  ///   2. Counts existing RoomItems for this user + itemId.
  ///   3. Rejects if inventory missing or all copies already placed.
  ///   4. Assigns zIndex = MAX(z_index)+1 from current room items.
  ///   5. Inserts the new RoomItem.
  Future<RoomPlacementResult> placeRoomItemIfAvailable(
      domain.RoomItem item) async {
    return transaction(() async {
      // 1. Verify inventory ownership.
      final invRow = await (select(inventoryItems)
            ..where((t) =>
                t.userId.equals(item.userId) & t.itemId.equals(item.itemId)))
          .getSingleOrNull();
      if (invRow == null || invRow.quantity <= 0) {
        return RoomPlacementResult.inventoryMissing;
      }

      // 2. Count how many copies are already placed.
      final countExpr = roomItems.id.count();
      final placedCountRow = await (selectOnly(roomItems)
            ..addColumns([countExpr])
            ..where(roomItems.userId.equals(item.userId) &
                roomItems.itemId.equals(item.itemId)))
          .getSingle();
      final placedCount = placedCountRow.read(countExpr) ?? 0;

      if (placedCount >= invRow.quantity) {
        return RoomPlacementResult.inventoryExhausted;
      }

      // 3. Compute next zIndex = MAX(z_index) + 1 (0 when room is empty).
      final zExpr = roomItems.zIndex.max();
      final zRow = await (selectOnly(roomItems)
            ..addColumns([zExpr])
            ..where(roomItems.userId.equals(item.userId)))
          .getSingle();
      final nextZIndex = (zRow.read(zExpr) ?? -1) + 1;

      // 4. Insert the new RoomItem with the DB-assigned zIndex.
      await into(roomItems).insert(RoomItemsCompanion(
        id: Value(item.id),
        userId: Value(item.userId),
        itemId: Value(item.itemId),
        positionX: Value(item.positionX),
        positionY: Value(item.positionY),
        scale: Value(item.scale),
        zIndex: Value(nextZIndex),
        isVisible: Value(item.isVisible),
        placedAt: Value(item.placedAt),
      ));

      return RoomPlacementResult.placed;
    });
  }

  // ── Mappers ──────────────────────────────────────────────

  // Static icon map keyed by recipe id (icon is not stored in DB)
  static const Map<String, String> _recipeIcons = {
    'sofa': '🛋️',
    'table': '🪵',
    'bookshelf': '📚',
    'bed': '🛏️',
    'rug': '🟫',
    'lamp': '💡',
    'cabinet': '🗄️',
    'desk': '🪑',
  };

  domain.CraftRecipe _mapRecipe(dynamic row) => domain.CraftRecipe(
        id: row.id as String,
        name: row.name as String,
        description: row.description as String?,
        requiredMinutes: row.requiredMinutes as int,
        ingredientCosts: const {},
        outputItemId: row.outputItemId as String,
        outputQuantity: row.outputQuantity as int,
        artworkPath: row.artworkPath as String?,
        icon: _recipeIcons[row.id as String] ?? '📦',
      );

  domain.CraftJob _mapJob(dynamic row) => domain.CraftJob(
        id: row.id as String,
        userId: row.userId as String,
        recipeId: row.recipeId as String,
        status: CraftJobStatus.values.firstWhere(
          (e) => e.name == (row.status as String),
          orElse: () => CraftJobStatus.pending,
        ),
        progressSeconds: row.progressSeconds as int,
        startedAt: row.startedAt as DateTime,
        completedAt: row.completedAt as DateTime?,
        rewardClaimed: row.rewardClaimed as bool,
        sessionId: row.sessionId as String?,
      );

  domain.InventoryItem _mapInventory(dynamic row) => domain.InventoryItem(
        id: row.id as String,
        userId: row.userId as String,
        itemId: row.itemId as String,
        quantity: row.quantity as int,
        updatedAt: row.updatedAt as DateTime,
      );

  domain.RoomItem _mapRoom(dynamic row) => domain.RoomItem(
        id: row.id as String,
        userId: row.userId as String,
        itemId: row.itemId as String,
        positionX: row.positionX as double,
        positionY: row.positionY as double,
        scale: row.scale as double,
        zIndex: row.zIndex as int,
        isVisible: row.isVisible as bool,
        placedAt: row.placedAt as DateTime,
      );
}
