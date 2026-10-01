/// Where the companion can stand in the room.
///
/// ## Why this is a registry and not a coordinate
///
/// The brief is explicit: *do not hardcode coordinates*. An anchor is a **named
/// point** — `sofa_anchor`, `desk_anchor` — whose position is derived from the
/// furniture the player actually placed, not from a constant in this file.
///
/// That matters for three reasons:
///
/// 1. The player can drag furniture anywhere, so a hardcoded point would leave
///    the companion standing where the sofa *used* to be.
/// 2. Adding a piece of furniture must not require editing a map of coordinates.
/// 3. Removal must be automatic: an anchor only exists while its item is placed.
///
/// So an anchor is a *view* over real placement truth, rebuilt whenever the
/// placement changes.
library;

import '../../../domain/models/craft_models.dart';

/// A named point in the room the companion can occupy.
///
/// Coordinates are in the same normalised `[0.0, 1.0]` canvas space as
/// [RoomItem.positionX] / [RoomItem.positionY], so the room canvas can place the
/// companion with the arithmetic it already uses for furniture.
class AnchorPoint {
  /// The stable anchor id, e.g. `desk_anchor`.
  ///
  /// Derived as `<itemId>_anchor` so it is predictable from the furnished
  /// catalog rather than invented per item.
  final String id;

  /// The furniture this anchor belongs to, e.g. `desk`.
  final String itemId;

  /// The placed row this anchor came from. Two sofas give two anchors, and this
  /// is what tells them apart.
  final String roomItemId;

  /// The companion's **feet** position on the canvas, already corrected for the
  /// item's own surface line. See [AnchorPoint.surfaceFraction].
  final double x;
  final double y;

  /// The item's sitting surface as a fraction of its sprite height, measured
  /// from the top. Used by the canvas to convert a centre-anchored item into a
  /// feet position; carried here so the conversion happens once, from data.
  final double surfaceFraction;

  /// The item's render scale, so the canvas does not have to look the row up
  /// again to compute the surface offset.
  final double scale;

  const AnchorPoint({
    required this.id,
    required this.itemId,
    required this.roomItemId,
    required this.x,
    required this.y,
    this.surfaceFraction = 0.5,
    this.scale = 1.0,
  });

  @override
  String toString() =>
      'AnchorPoint($id @ ${x.toStringAsFixed(2)},${y.toStringAsFixed(2)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnchorPoint &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          itemId == other.itemId &&
          roomItemId == other.roomItemId &&
          x == other.x &&
          y == other.y &&
          surfaceFraction == other.surfaceFraction &&
          scale == other.scale;

  @override
  int get hashCode =>
      Object.hash(id, itemId, roomItemId, x, y, surfaceFraction, scale);
}

/// The anchor the companion rests at when nothing is placed.
///
/// A room with no furniture still shows the companion *in* the room rather than
/// pinned to a corner or invisible. This is a presentation-only choice, and it
/// is deliberately the same floor spot [PetRoomPresenceResolver] has always
/// used, so an empty room looks unchanged.
const AnchorPoint floorAnchor = AnchorPoint(
  id: 'floor_anchor',
  itemId: '',
  roomItemId: '',
  x: 0.5,
  y: 0.70,
);

/// Builds the anchor set from real placement truth.
///
/// ## It is a pure projection
///
/// Given the same placed rows, this always produces the same anchors. Nothing
/// is cached across calls and nothing is stored, because the anchors are not
/// independent truth — they are what the placement *means*. That is what keeps
/// this from becoming a second source of truth that can drift from the database.
abstract final class FurnitureAnchorRegistry {
  const FurnitureAnchorRegistry._();

  /// The anchor id for [itemId]. Predictable, so the manifest can name anchors
  /// without a registry lookup.
  static String anchorIdFor(String itemId) => '${itemId}_anchor';

  /// Every anchor the current placement defines, keyed by anchor id.
  ///
  /// [eligibleItemIds] is the set of items that may be interacted with, which
  /// the caller supplies from the interaction recipes. An item with no recipe
  /// gets no anchor: a decoration is not somewhere the companion can live, and
  /// deriving an anchor for one would let the companion path to a wall hanging.
  ///
  /// [surfaceFractionFor] resolves the item's sitting surface, which the room
  /// geometry needs and which is a per-item-id fact rather than a per-placement
  /// one.
  static Map<String, AnchorPoint> build({
    required List<RoomItem> placed,
    required Set<String> eligibleItemIds,
    required List<InventoryItem> owned,
    double Function(String itemId) surfaceFractionFor = _half,
    Set<String> visibleOnly = const {},
  }) {
    final ownedWithStock = <String>{
      for (final item in owned)
        if (item.quantity > 0) item.itemId,
    };

    final anchors = <String, AnchorPoint>{};
    for (final item in placed) {
      if (!eligibleItemIds.contains(item.itemId)) continue;
      if (!item.isVisible) continue;
      // Ownership is redundant while the only write path is consume-then-place,
      // but it is enforced anyway: an anchor is a claim that the player has this
      // furniture, and a future direct-write path must not be able to fake it.
      if (!ownedWithStock.contains(item.itemId)) continue;

      anchors['${anchorIdFor(item.itemId)}:${item.id}'] = AnchorPoint(
        id: anchorIdFor(item.itemId),
        itemId: item.itemId,
        roomItemId: item.id,
        x: item.positionX,
        y: item.positionY,
        surfaceFraction: surfaceFractionFor(item.itemId),
        scale: item.scale,
      );
    }
    return anchors;
  }

  /// The anchor for a specific placed row, or `null`.
  ///
  /// Used when the player taps one of two identical items: the tap carries the
  /// row id, so the answer is the anchor for *that* sofa rather than for sofas
  /// in general.
  static AnchorPoint? forRoomItem(
    Map<String, AnchorPoint> anchors,
    String roomItemId,
  ) {
    for (final anchor in anchors.values) {
      if (anchor.roomItemId == roomItemId) return anchor;
    }
    return null;
  }

  /// The anchor for an item id, preferring the topmost placement.
  ///
  /// The tie-break matches the resolver's: the answer must not depend on the
  /// order the rows came back in.
  static AnchorPoint? forItemId(
    Map<String, AnchorPoint> anchors,
    String itemId, {
    List<RoomItem> placed = const [],
  }) {
    final matches = anchors.values.where((a) => a.itemId == itemId).toList();
    if (matches.isEmpty) return null;
    if (matches.length == 1) return matches.first;

    int zFor(String roomItemId) {
      for (final item in placed) {
        if (item.id == roomItemId) return item.zIndex;
      }
      return 0;
    }

    matches.sort((a, b) {
      final byZ = zFor(a.roomItemId).compareTo(zFor(b.roomItemId));
      if (byZ != 0) return byZ;
      return a.roomItemId.compareTo(b.roomItemId);
    });
    return matches.last;
  }

  static double _half(String _) => 0.5;
}
