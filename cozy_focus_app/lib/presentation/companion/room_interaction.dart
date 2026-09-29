import '../../domain/models/craft_models.dart';
import 'runtime/companion_catalog.dart';
import 'runtime/room_interaction_recipe.dart';

/// A placed piece of furniture the companion can interact with.
///
/// `anchor` is a *presentation* anchor id (`seat` / `lie` / `front` / `work`).
/// The business `RoomItem` position stays authoritative — nothing here rewrites
/// a coordinate.
class RoomInteractionTarget {
  final String itemId;
  final String anchor;

  /// The business row id, so the caller can look up the placed item it came from.
  final String roomItemId;

  const RoomInteractionTarget({
    required this.itemId,
    required this.anchor,
    required this.roomItemId,
  });

  @override
  String toString() => 'RoomInteractionTarget($itemId @ $anchor)';
}

/// Chooses which piece of furniture the companion uses, from the recipe catalog.
///
/// ## The gate is the manifest's, not this file's
///
/// `docs/06_Room_Craft_Collection_Recipe_SPEC.md` requires
/// `owned && placed && visible`. That triple is declared as data in
/// `assets/companion/room_interaction_recipes.json` and applied here, so an item
/// the recipe does not list simply cannot be chosen — a page cannot forget one of
/// the three conditions, because it never states them.
///
/// ## Why a positive list
///
/// Only items with a recipe are eligible. If eligibility were "anything placed",
/// a new catalog item would silently become something the companion climbs on,
/// and the first person to notice would be a user looking at a pet sitting on a
/// bookshelf.
abstract final class RoomInteractionResolver {
  const RoomInteractionResolver._();

  /// Resolves the target for [placed] furniture, or `null` when none qualifies.
  ///
  /// When several qualify the topmost wins: highest `zIndex`, then the newer
  /// placement, then the larger id. The id tie-break exists so the answer never
  /// depends on the order the rows came back in.
  static RoomInteractionTarget? resolve({
    required CompanionCatalog catalog,
    required List<RoomItem> placed,
    required List<InventoryItem> owned,
  }) {
    final ownedWithStock = <String>{
      for (final item in owned)
        if (item.quantity > 0) item.itemId,
    };

    final candidates = <(RoomItem, RoomInteractionRecipe)>[];
    for (final item in placed) {
      final recipe = catalog.roomRecipeFor(item.itemId);
      if (recipe == null) continue;
      if (!_meets(recipe, item: item, ownedWithStock: ownedWithStock)) {
        continue;
      }
      candidates.add((item, recipe));
    }
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final byZ = a.$1.zIndex.compareTo(b.$1.zIndex);
      if (byZ != 0) return byZ;
      final byPlacedAt = a.$1.placedAt.compareTo(b.$1.placedAt);
      if (byPlacedAt != 0) return byPlacedAt;
      return a.$1.id.compareTo(b.$1.id);
    });

    final (item, recipe) = candidates.last;
    return RoomInteractionTarget(
      itemId: item.itemId,
      anchor: recipe.anchor,
      roomItemId: item.id,
    );
  }

  /// Whether [item] satisfies every predicate the recipe requires.
  static bool _meets(
    RoomInteractionRecipe recipe, {
    required RoomItem item,
    required Set<String> ownedWithStock,
  }) {
    for (final requirement in recipe.requires) {
      switch (requirement) {
        case 'owned':
          if (!ownedWithStock.contains(item.itemId)) return false;
        case 'placed':
          // Being in the placed list *is* being placed.
          break;
        case 'visible':
          if (!item.isVisible) return false;
        default:
          // An unknown predicate is not satisfied by default. A manifest that
          // asks for something this build does not understand must fail closed
          // rather than grant an interaction it cannot justify.
          return false;
      }
    }
    return true;
  }

  /// The item ids the catalog lets the companion use, for diagnostics.
  static Set<String> eligibleItemIds(CompanionCatalog catalog) =>
      catalog.roomRecipes.keys.toSet();
}
