import '../models/craft_models.dart';

/// Result of an atomic room-placement attempt.
enum RoomPlacementResult {
  /// Item was successfully placed.
  placed,

  /// The inventory record does not exist for this user + itemId.
  inventoryMissing,

  /// All copies of the item are already placed in the room.
  inventoryExhausted,
}

abstract interface class ICraftRepository {
  // Recipes
  Future<List<CraftRecipe>> findAllRecipes();
  Future<CraftRecipe?> findRecipeById(String id);

  // Jobs
  Future<void> saveJob(CraftJob job);
  Future<void> updateJob(CraftJob job);
  Future<CraftJob?> findJobById(String id);
  Future<List<CraftJob>> findJobsByUser(String userId);
  Future<CraftJob?> findActiveJobByUser(String userId);

  /// Atomically start a new job only when no active job exists for [userId].
  ///
  /// Returns [true] if the job was inserted (caller obtained the slot).
  /// Returns [false] if another active job already exists (no-op).
  Future<bool> startJobIfNoneActive(String userId, CraftJob newJob);

  // Inventory
  Future<void> upsertInventoryItem(InventoryItem item);
  Future<InventoryItem?> findInventoryItem(String userId, String itemId);
  Future<List<InventoryItem>> findInventory(String userId);

  // Room
  Future<void> placeRoomItem(RoomItem item);
  Future<void> updateRoomItem(RoomItem item);
  Future<void> removeRoomItem(String id);
  Future<List<RoomItem>> findRoomItems(String userId);

  /// Atomically verifies inventory availability and places the item in the room.
  ///
  /// All DB reads (inventory count, placed count) and the INSERT happen inside
  /// a single Drift transaction, preventing concurrent over-placement.
  ///
  /// The [item.zIndex] supplied by the caller is ignored; the DAO assigns
  /// MAX(z_index)+1 inside the transaction.
  Future<RoomPlacementResult> placeRoomItemIfAvailable(RoomItem item);
}
