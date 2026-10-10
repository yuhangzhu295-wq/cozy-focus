import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/craft_models.dart';
import '../../domain/models/enums.dart';
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

  /// The crafts that finished, newest first — design 10's 最近解锁.
  ///
  /// Derived from `craft_jobs` rows whose status is `completed`, joined to the
  /// recipe that produced them. Nothing here is invented: if no craft has
  /// finished the list is empty, and the section does not render.
  final List<CraftUnlock> recentUnlocks;

  final bool isLoading;
  final String? error;

  const CraftState({
    this.recipes = const [],
    this.activeJob,
    this.activeRecipe,
    this.inventory = const [],
    this.roomItems = const [],
    this.recentUnlocks = const [],
    this.isLoading = false,
    this.error,
  });

  CraftState copyWith({
    List<CraftRecipe>? recipes,
    CraftJob? activeJob,
    CraftRecipe? activeRecipe,
    List<InventoryItem>? inventory,
    List<RoomItem>? roomItems,
    List<CraftUnlock>? recentUnlocks,
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
      recentUnlocks: recentUnlocks ?? this.recentUnlocks,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// One finished craft: what it was, and when it finished.
class CraftUnlock {
  final String name;
  final DateTime at;

  /// The item the recipe produces, so the row can draw the app's own artwork for
  /// it rather than a placeholder.
  final String itemId;

  const CraftUnlock(this.name, this.at, this.itemId);
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
      final jobs = await _repo.findJobsByUser(_userId);
      state = state.copyWith(
        recipes: recipes,
        activeJob: active?.job,
        activeRecipe: active?.recipe,
        inventory: inventory,
        roomItems: roomItems,
        recentUnlocks: recentUnlocksFrom(jobs, recipes),
        isLoading: false,
        clearActiveJob: active == null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// The last three finished crafts, newest first.
  ///
  /// A finished job whose recipe is no longer in the catalogue is skipped rather
  /// than given a placeholder name: the row's whole content is what was unlocked,
  /// and a row that cannot say what it was is worse than no row.
  static List<CraftUnlock> recentUnlocksFrom(
    List<CraftJob> jobs,
    List<CraftRecipe> recipes,
  ) {
    final byId = {for (final recipe in recipes) recipe.id: recipe};
    final unlocks = <CraftUnlock>[
      for (final job in jobs)
        if (job.status == CraftJobStatus.completed &&
            job.completedAt != null &&
            byId[job.recipeId] != null)
          CraftUnlock(
            byId[job.recipeId]!.name,
            job.completedAt!,
            byId[job.recipeId]!.outputItemId,
          ),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return unlocks.take(3).toList(growable: false);
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
  /// Delegates to [ICraftRepository.placeRoomItemIfAvailable] which performs
  /// inventory + placed-count checks inside a single DB transaction.
  /// After a successful placement the room list is reloaded from the DB so
  /// the UI always reflects the authoritative persisted state.
  ///
  /// The timestamp is provided by [_clock] (never DateTime.now()).
  Future<void> placeItem(String itemId, double x, double y) async {
    try {
      final now = _clock.now();
      final roomItem = RoomItem(
        id: _uuid.v4(),
        userId: _userId,
        itemId: itemId,
        positionX: x,
        positionY: y,
        scale: 1.0,
        zIndex: 0, // overwritten by the DAO inside the transaction
        isVisible: true,
        placedAt: now,
      );
      final result = await _repo.placeRoomItemIfAvailable(roomItem);
      switch (result) {
        case RoomPlacementResult.placed:
          // Re-read from DB so UI reflects authoritative persisted state.
          final fresh = await _repo.findRoomItems(_userId);
          state = state.copyWith(roomItems: fresh, clearError: true);
        case RoomPlacementResult.inventoryExhausted:
          state = state.copyWith(
              error: 'All copies of this item are already placed');
        case RoomPlacementResult.inventoryMissing:
          state = state.copyWith(error: 'Item not available in inventory');
      }
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

  // ── Placement control ─────────────────────────────────────
  //
  // The three attributes below are already persisted by
  // [ICraftRepository.updateRoomItem] and already consumed by the anchor registry
  // and the companion's feet maths. These methods are the missing write path:
  // without them the fields exist but the player can never change them.
  //
  // They write placement rows and nothing else. No session, reward, ledger or
  // inventory quantity is reachable from here, so the business-isolation rule
  // holds structurally rather than by convention.

  /// The smallest render scale a placed item may be set to.
  static const double minRoomItemScale = 0.6;

  /// The largest render scale a placed item may be set to.
  static const double maxRoomItemScale = 1.8;

  /// Resize a placed item.
  ///
  /// [scale] is clamped rather than rejected: a value that is merely out of
  /// range is a UI slip, not a reason to refuse the change, and clamping keeps
  /// the item visible instead of producing a zero- or giant-sized sprite.
  Future<void> setRoomItemScale(String id, double scale) async {
    final clamped = scale.clamp(minRoomItemScale, maxRoomItemScale);
    await _replaceRoomItem(id, (item) => item.copyWith(scale: clamped));
  }

  /// Show or hide a placed item without removing it.
  ///
  /// A hidden item keeps its row, its position and its z-order, but
  /// [FurnitureAnchorRegistry] stops deriving an anchor for it — so the
  /// companion no longer walks to furniture the player has stowed away.
  Future<void> setRoomItemVisible(String id, bool visible) async {
    await _replaceRoomItem(id, (item) => item.copyWith(isVisible: visible));
  }

  /// Raise a placed item above every other item.
  Future<void> bringRoomItemToFront(String id) =>
      _restackRoomItem(id, toFront: true);

  /// Send a placed item behind every other item.
  Future<void> sendRoomItemToBack(String id) =>
      _restackRoomItem(id, toFront: false);

  /// Replaces one row in place, preserving list order.
  ///
  /// Used by the attribute changes, which cannot affect draw order. The row is
  /// persisted first and only then mirrored into state, so a failed write leaves
  /// the UI showing what the database still holds.
  Future<void> _replaceRoomItem(
    String id,
    RoomItem Function(RoomItem) transform,
  ) async {
    try {
      final idx = state.roomItems.indexWhere((r) => r.id == id);
      if (idx < 0) return;
      final updated = transform(state.roomItems[idx]);
      await _repo.updateRoomItem(updated);
      final list = [...state.roomItems];
      list[idx] = updated;
      state = state.copyWith(roomItems: list);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Moves [id] to the front or back of the draw order.
  ///
  /// `findRoomItems` returns rows `ORDER BY z_index ASC` and the canvas draws
  /// the list in order, so list position *is* z-order. The list is re-sorted by
  /// the current values (stable, so equal z values keep their relative order),
  /// the target is moved to one end, and `zIndex` is reassigned as a dense
  /// `0..n-1`. Only rows whose value actually changed are written, and the list
  /// is re-read afterwards so state comes from the database rather than from the
  /// arithmetic here.
  Future<void> _restackRoomItem(String id, {required bool toFront}) async {
    try {
      final ordered = [...state.roomItems]
        ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
      final idx = ordered.indexWhere((r) => r.id == id);
      if (idx < 0) return;

      final target = ordered.removeAt(idx);
      if (toFront) {
        ordered.add(target);
      } else {
        ordered.insert(0, target);
      }

      for (var i = 0; i < ordered.length; i++) {
        if (ordered[i].zIndex == i) continue;
        ordered[i] = ordered[i].copyWith(zIndex: i);
        await _repo.updateRoomItem(ordered[i]);
      }

      final fresh = await _repo.findRoomItems(_userId);
      state = state.copyWith(roomItems: fresh, clearError: true);
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

/// Design 10's 最近解锁, loaded on its own.
///
/// A provider of its own because the growth page must not depend on the craft
/// page having been opened first: [craftControllerProvider] does not load on
/// creation, so watching its state alone showed an empty shelf on a fresh launch
/// even when crafts had finished. Found on the device, where the section stayed
/// absent with two finished jobs in the database.
final recentCraftUnlocksProvider =
    FutureProvider<List<CraftUnlock>>((ref) async {
  final repo = ref.watch(craftRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  final recipes = await repo.findAllRecipes();
  final jobs = await repo.findJobsByUser(userId);
  return CraftController.recentUnlocksFrom(jobs, recipes);
});

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
