import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/craft_models.dart';
import '../../domain/repositories/i_craft_repository.dart';
import '../../domain/services/craft_engine.dart';
import '../../domain/services/focus_clock.dart';
import 'providers.dart';

class CraftState {
  final List<CraftRecipe> recipes;
  final CraftJob? activeJob;
  final CraftRecipe? activeRecipe;
  final List<InventoryItem> inventory;
  final List<RoomItem> roomItems;
  final bool isLoading;
  final String? error;

  const CraftState({
    this.recipes = const [],
    this.activeJob,
    this.activeRecipe,
    this.inventory = const [],
    this.roomItems = const [],
    this.isLoading = false,
    this.error,
  });

  CraftState copyWith({
    List<CraftRecipe>? recipes,
    CraftJob? activeJob,
    CraftRecipe? activeRecipe,
    List<InventoryItem>? inventory,
    List<RoomItem>? roomItems,
    bool? isLoading,
    String? error,
    bool clearActiveJob = false,
    bool clearError = false,
  }) {
    return CraftState(
      recipes: recipes ?? this.recipes,
      activeJob: clearActiveJob ? null : (activeJob ?? this.activeJob),
      activeRecipe: clearActiveJob ? null : (activeRecipe ?? this.activeRecipe),
      inventory: inventory ?? this.inventory,
      roomItems: roomItems ?? this.roomItems,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CraftController extends StateNotifier<CraftState> {
  final ICraftRepository _repo;
  final CraftEngine _engine;
  final FocusClock _clock;
  final String _userId;
  static const _uuid = Uuid();

  CraftController({
    required ICraftRepository repo,
    required CraftEngine engine,
    required FocusClock clock,
    required String userId,
  })  : _repo = repo,
        _engine = engine,
        _clock = clock,
        _userId = userId,
        super(const CraftState());

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final recipes = await _repo.findAllRecipes();
      final active = await _engine.getActiveCraftJob(_userId);
      final inventory = await _repo.findInventory(_userId);
      final roomItems = await _repo.findRoomItems(_userId);
      state = state.copyWith(
        recipes: recipes,
        activeJob: active?.job,
        activeRecipe: active?.recipe,
        inventory: inventory,
        roomItems: roomItems,
        isLoading: false,
        clearActiveJob: active == null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> startJob(String recipeId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final job = await _engine.startJob(_userId, recipeId);
      final recipe = await _repo.findRecipeById(recipeId);
      state = state.copyWith(
        activeJob: job,
        activeRecipe: recipe,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> cancelJob() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _engine.cancelActiveJob(_userId);
      state = state.copyWith(isLoading: false, clearActiveJob: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Place an inventory item in the room.
  ///
  /// Domain-level validation:
  ///   • The item must exist in inventory with quantity > 0.
  ///   • The number of already-placed instances must be < inventory quantity.
  ///
  /// The timestamp is provided by [_clock] (never DateTime.now()).
  Future<void> placeItem(String itemId, double x, double y) async {
    try {
      // Domain validation: re-read inventory from DB.
      final invItem = await _repo.findInventoryItem(_userId, itemId);
      if (invItem == null || invItem.quantity <= 0) {
        state = state.copyWith(error: 'Item not available in inventory');
        return;
      }

      // Count current placements for this item.
      final placedCount =
          state.roomItems.where((r) => r.itemId == itemId).length;
      if (placedCount >= invItem.quantity) {
        state =
            state.copyWith(error: 'All copies of this item are already placed');
        return;
      }

      final now = _clock.now();
      final roomItem = RoomItem(
        id: _uuid.v4(),
        userId: _userId,
        itemId: itemId,
        positionX: x,
        positionY: y,
        scale: 1.0,
        zIndex: state.roomItems.length,
        isVisible: true,
        placedAt: now,
      );
      await _repo.placeRoomItem(roomItem);
      final updated = [...state.roomItems, roomItem];
      state = state.copyWith(roomItems: updated);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Persist the final position of a room item (called on drag end only).
  Future<void> moveRoomItem(String id, double x, double y) async {
    try {
      final idx = state.roomItems.indexWhere((r) => r.id == id);
      if (idx < 0) return;
      final updated = state.roomItems[idx].copyWith(positionX: x, positionY: y);
      await _repo.updateRoomItem(updated);
      final list = [...state.roomItems];
      list[idx] = updated;
      state = state.copyWith(roomItems: list);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> removeRoomItem(String id) async {
    try {
      await _repo.removeRoomItem(id);
      state = state.copyWith(
        roomItems: state.roomItems.where((r) => r.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Reload inventory + room after external changes (e.g. after focus reward).
  Future<void> refreshInventoryAndRoom() async {
    try {
      final inventory = await _repo.findInventory(_userId);
      final roomItems = await _repo.findRoomItems(_userId);
      final active = await _engine.getActiveCraftJob(_userId);
      state = state.copyWith(
        inventory: inventory,
        roomItems: roomItems,
        activeJob: active?.job,
        activeRecipe: active?.recipe,
        clearActiveJob: active == null,
      );
    } catch (_) {}
  }
}

final craftControllerProvider =
    StateNotifierProvider<CraftController, CraftState>((ref) {
  final repo = ref.watch(craftRepositoryProvider);
  final engine = ref.watch(craftEngineProvider);
  final clock = ref.watch(focusClockProvider);
  final userId = ref.watch(currentUserIdProvider);
  return CraftController(
    repo: repo,
    engine: engine,
    clock: clock,
    userId: userId,
  );
});
