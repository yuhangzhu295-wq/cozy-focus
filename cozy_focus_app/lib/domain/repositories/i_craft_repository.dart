import '../models/craft_models.dart';

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
}
