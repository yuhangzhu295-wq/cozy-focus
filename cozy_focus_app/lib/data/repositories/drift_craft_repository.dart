import '../../domain/models/craft_models.dart';
import '../../domain/repositories/i_craft_repository.dart';
import '../local/daos/craft_dao.dart';

class DriftCraftRepository implements ICraftRepository {
  final CraftDao _dao;
  DriftCraftRepository(this._dao);

  @override
  Future<List<CraftRecipe>> findAllRecipes() => _dao.findAllRecipes();

  @override
  Future<CraftRecipe?> findRecipeById(String id) => _dao.findRecipeById(id);

  @override
  Future<void> saveJob(CraftJob job) => _dao.saveJob(job);

  @override
  Future<void> updateJob(CraftJob job) => _dao.saveJob(job);

  @override
  Future<CraftJob?> findJobById(String id) => _dao.findJobById(id);

  @override
  Future<List<CraftJob>> findJobsByUser(String userId) =>
      _dao.findJobsByUser(userId);

  @override
  Future<CraftJob?> findActiveJobByUser(String userId) =>
      _dao.findActiveJobByUser(userId);

  @override
  Future<void> upsertInventoryItem(InventoryItem item) =>
      _dao.upsertInventoryItem(item);

  @override
  Future<InventoryItem?> findInventoryItem(String userId, String itemId) =>
      _dao.findInventoryItem(userId, itemId);

  @override
  Future<List<InventoryItem>> findInventory(String userId) =>
      _dao.findInventory(userId);

  @override
  Future<void> placeRoomItem(RoomItem item) => _dao.upsertRoomItem(item);

  @override
  Future<void> updateRoomItem(RoomItem item) => _dao.upsertRoomItem(item);

  @override
  Future<void> removeRoomItem(String id) => _dao.removeRoomItem(id);

  @override
  Future<List<RoomItem>> findRoomItems(String userId) =>
      _dao.findRoomItems(userId);
}
