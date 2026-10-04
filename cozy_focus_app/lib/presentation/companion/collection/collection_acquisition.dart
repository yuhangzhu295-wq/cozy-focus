import 'package:flutter/foundation.dart';

import '../../../domain/models/craft_models.dart';

/// What the player can do about one collection item, derived from real truth.
///
/// ## Why this is a projection and not state
///
/// P29.1: the collection must not become a second copy of the craft system. The
/// recipe's duration, the job's progress and the owned quantity all already have
/// authoritative homes — `CraftRecipe`, `CraftJob`, `InventoryItem` and the
/// placed `RoomItem` rows. Copying any of them into the collection catalog would
/// create two answers to one question, and the collection's would be the stale
/// one.
///
/// So nothing here is stored. [CollectionAcquisitionViewModel.from] reads the
/// real values on every build, which is also what makes P29's requirement true:
/// change a recipe's duration and the collection detail changes with it, with no
/// edit to the catalog.
///
/// ## The status is derived, never persisted
///
/// P29.2 asks for the five states without adding business state. There is no
/// `collectionStatus` column and no provider holding this enum; it is computed
/// from the four inputs each time the page builds.
enum CollectionAcquisitionStatus {
  /// No recipe can deliver this item, so it cannot be obtained at all.
  unavailable,

  /// A real recipe exists and the player has not started it.
  craftable,

  /// A real job for this item's recipe is in progress.
  crafting,

  /// The item is in the inventory, not currently placed.
  owned,

  /// The item is placed in the room.
  placed,
}

/// One collection item, joined against the real craft, inventory and room truth.
@immutable
class CollectionAcquisitionViewModel {
  final String itemId;
  final String itemName;
  final CollectionAcquisitionStatus status;

  /// The real recipe that delivers this item, or null when none does.
  final CraftRecipe? recipe;

  /// How many the player owns right now.
  final int ownedQuantity;

  /// How many are placed in the room right now.
  final int placedCount;

  /// Progress on the running job, when [status] is [crafting].
  final int progressSeconds;

  const CollectionAcquisitionViewModel({
    required this.itemId,
    required this.itemName,
    required this.status,
    this.recipe,
    this.ownedQuantity = 0,
    this.placedCount = 0,
    this.progressSeconds = 0,
  });

  /// Joins [item] against the real craft, inventory and room state.
  ///
  /// [recipes] is the live recipe list, [activeJob] and [activeRecipe] are the
  /// running job (if any), [ownedQuantity] comes from the inventory rows and
  /// [placedCount] from the placed room rows.
  factory CollectionAcquisitionViewModel.from({
    required String itemId,
    required String itemName,
    required bool obtainable,
    required List<CraftRecipe> recipes,
    required CraftJob? activeJob,
    required CraftRecipe? activeRecipe,
    required int ownedQuantity,
    required int placedCount,
  }) {
    final recipe = recipes.where((r) => r.outputItemId == itemId).firstOrNull;

    // A preview entry, or an entry the recipe table cannot deliver, is
    // unavailable. The two disagreeing is a configuration problem, and the
    // honest answer is "not obtainable" rather than implying a path exists.
    if (!obtainable || recipe == null) {
      return CollectionAcquisitionViewModel(
        itemId: itemId,
        itemName: itemName,
        status: CollectionAcquisitionStatus.unavailable,
        ownedQuantity: ownedQuantity,
        placedCount: placedCount,
      );
    }

    final jobIsForThisItem =
        activeJob != null && activeRecipe?.outputItemId == itemId;

    // Placed only when there is nothing left to place.
    //
    // An item owned twice with one copy in the room is *both* owned and placed,
    // and a single status has to pick. It reports 已拥有 x2, because the player
    // still has a copy to put down and that is the actionable half — "已摆放"
    // would hide it. Once every owned copy is placed there is nothing left to
    // do but look at it, and that is what 已摆放 says.
    final status = jobIsForThisItem
        ? CollectionAcquisitionStatus.crafting
        : ownedQuantity > 0 && placedCount >= ownedQuantity
            ? CollectionAcquisitionStatus.placed
            : ownedQuantity > 0
                ? CollectionAcquisitionStatus.owned
                : CollectionAcquisitionStatus.craftable;

    return CollectionAcquisitionViewModel(
      itemId: itemId,
      itemName: itemName,
      status: status,
      recipe: recipe,
      ownedQuantity: ownedQuantity,
      placedCount: placedCount,
      progressSeconds: jobIsForThisItem ? activeJob.progressSeconds : 0,
    );
  }

  /// How long the real recipe asks for. Null when there is no recipe.
  int? get requiredMinutes => recipe?.requiredMinutes;

  /// The real required seconds, which the progress is measured against.
  int? get requiredSeconds => recipe?.requiredSeconds;

  /// Whether the recipe asks for materials.
  ///
  /// Every shipped recipe seeds `ingredientCosts` as `'{}'` and the DAO parses
  /// it to an empty map, so crafting costs **time only**. The detail says so
  /// rather than showing an empty materials list, and it reads the field rather
  /// than asserting the constant — a recipe that one day costs something will
  /// show it here with no change to this class.
  bool get requiresMaterials => (recipe?.ingredientCosts.isNotEmpty) ?? false;

  /// The materials, when there are any.
  Map<String, int> get ingredientCosts => recipe?.ingredientCosts ?? const {};

  /// What the player is told about how to get this item.
  ///
  /// P29.6: the loop in one sentence, so the page is understandable without
  /// prior product knowledge.
  String get howToObtain => switch (status) {
        CollectionAcquisitionStatus.unavailable => '当前版本尚未开放',
        CollectionAcquisitionStatus.craftable => '在制作工坊开始制作，专注时间会变成制作进度',
        CollectionAcquisitionStatus.crafting => '制作进行中，继续专注即可推进',
        CollectionAcquisitionStatus.owned => '已经做好啦，可以摆到房间里',
        CollectionAcquisitionStatus.placed => '已经摆在房间里了',
      };

  /// The real route the CTA navigates to, or null when there is no CTA.
  ///
  /// P29.5: every target is an existing route. An unavailable item gets none —
  /// a disabled button implying future support would be a fake affordance.
  String? get ctaRoute => switch (status) {
        CollectionAcquisitionStatus.unavailable => null,
        CollectionAcquisitionStatus.craftable => '/craft/detail/${recipe!.id}',
        CollectionAcquisitionStatus.crafting => '/craft/detail/${recipe!.id}',
        // Placement starts from the inventory, which owns the "put it in the
        // room" action. Sending the player to the room would be a button that
        // does not do what it says.
        CollectionAcquisitionStatus.owned => '/inventory',
        CollectionAcquisitionStatus.placed => '/room',
      };

  /// The CTA's label, or null when there is no CTA.
  String? get ctaLabel => switch (status) {
        CollectionAcquisitionStatus.unavailable => null,
        CollectionAcquisitionStatus.craftable => '开始制作',
        CollectionAcquisitionStatus.crafting => '继续专注',
        CollectionAcquisitionStatus.owned => '去房间摆放',
        CollectionAcquisitionStatus.placed => '查看房间',
      };

  /// The short state line the card shows.
  String get statusLine => switch (status) {
        CollectionAcquisitionStatus.unavailable => '未开放',
        CollectionAcquisitionStatus.craftable => '未收集',
        CollectionAcquisitionStatus.crafting => '制作中',
        CollectionAcquisitionStatus.placed => '已摆放',
        CollectionAcquisitionStatus.owned => '已拥有 x$ownedQuantity',
      };

  /// Whether tapping the card opens the acquisition detail.
  bool get isTappable => status != CollectionAcquisitionStatus.unavailable;

  /// How far along the running job is, 0..1. Zero when not crafting.
  double get progressFraction {
    final target = requiredSeconds;
    if (target == null || target <= 0) return 0;
    return (progressSeconds / target).clamp(0.0, 1.0);
  }
}
