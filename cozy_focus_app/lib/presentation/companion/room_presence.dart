import '../../domain/models/craft_models.dart';

/// Where Mochi is standing in the room, and what it is sitting on.
///
/// ## Why this is resolved rather than hard-coded
///
/// `designs/pages/09_房间.png` shows Mochi sitting on a plush cushion *in the
/// room*, not floating beside it. Making that literal — "Mochi sits on whatever
/// seat the user has actually placed" — is what turns the room from a static
/// furniture list into a room Mochi lives in.
///
/// It also makes the room's behaviour **gated on real data**: the seat comes
/// from the same `room_items` rows the canvas draws and the same `inventory`
/// rows the placement panel counts, so Mochi cannot be shown sitting on
/// something the user does not own or has not put down.
class PetRoomPresence {
  /// The real, placed item Mochi is sitting on.
  ///
  /// `null` means Mochi is on the floor. There is deliberately no separate
  /// `isOnSeat` flag: two sources for one fact is how they end up disagreeing.
  final String? seatItemId;

  /// The anchor Mochi is placed at, `0.0 … 1.0` on each axis.
  ///
  /// Same coordinate space as [RoomItem.positionX] / [RoomItem.positionY], so
  /// the room canvas can position Mochi with the arithmetic it already uses for
  /// furniture.
  ///
  /// On a seat this is the **item's own anchor**, which the canvas treats as the
  /// item's centre — not the surface Mochi's feet rest on. Converting it into a
  /// feet position is [PetSeatPlacement]'s job, because it needs the item's
  /// rendered size and the avatar's own geometry. On the floor it is already
  /// the standing point.
  final double x;
  final double y;

  const PetRoomPresence({
    required this.seatItemId,
    required this.x,
    required this.y,
  });

  /// Whether Mochi found something to sit on.
  bool get isOnSeat => seatItemId != null;

  @override
  String toString() => isOnSeat
      ? 'PetRoomPresence(on $seatItemId at ${x.toStringAsFixed(2)}, '
          '${y.toStringAsFixed(2)})'
      : 'PetRoomPresence(floor at ${x.toStringAsFixed(2)}, '
          '${y.toStringAsFixed(2)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetRoomPresence &&
          runtimeType == other.runtimeType &&
          seatItemId == other.seatItemId &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(seatItemId, x, y);
}

/// Resolves Mochi's place in the room from the real ownership and placement
/// truth.
///
/// ## Status of the choices in this file
///
/// V4.1's room reference shows Mochi on a cushion and names no item ids, so two
/// things here are **presentation-only choices**, marked as such below: which
/// item ids count as a seat, and where Mochi stands when nothing is placed.
/// Everything else is read from the database.
abstract final class PetRoomPresenceResolver {
  const PetRoomPresenceResolver._();

  /// The item ids Mochi will sit on. **Presentation-only choice.**
  ///
  /// The reference's cushion does not exist in the shipped catalog, so the three
  /// seat-shaped items that do are listed here: 温馨沙发 `sofa`, 小床 `bed` and
  /// 地毯 `rug`.
  ///
  /// This is a positive list on purpose. If it were "anything not obviously a
  /// wall decoration", a new item added to the catalog would silently become
  /// something Mochi climbs on, and the first person to notice would be a user
  /// looking at a pet sitting on a bookshelf.
  static const Set<String> seatItemIds = {'sofa', 'bed', 'rug'};

  /// Where Mochi stands when nothing to sit on has been placed.
  /// **Presentation-only choice.**
  ///
  /// Lower centre, in front of the wall: an empty room still shows Mochi *in*
  /// the room rather than pinned to a corner, and the spot is clear of the
  /// default placement position `placeItem` uses (`0.3 + n * 0.05`), so a first
  /// piece of furniture does not land exactly on top of it.
  static const double floorX = 0.5;
  static const double floorY = 0.70;

  /// Where each seat's *sitting surface* is, as a fraction of the sprite's
  /// height measured from its top. **Presentation-only choice.**
  ///
  /// Read off `CozyFurnitureArtwork`'s own painter, which works in a 100-unit
  /// space so its coordinates are already percentages:
  ///
  /// * `_sofa`'s cream seat cushions are `Rect.fromLTWH(25, 48, 24, 21)` →
  ///   `y = 48`;
  /// * `_bed`'s cream mattress is `Rect.fromLTWH(21, 42, 58, 26)` → `y = 42`.
  ///
  /// They matter because the canvas positions furniture by its **centre**
  /// (`_PlacedItemWidget` offsets by `renderedSize / 2`), so a pet anchored to
  /// the item's position would sink `(0.5 - 0.42) = 8 %` of the sprite into a
  /// bed.
  ///
  /// Seats with no sitting line are absent and fall back to
  /// [defaultSeatSurfaceFraction]: a rug is flat on the floor, so Mochi simply
  /// stands in the middle of it.
  ///
  /// `room_seat_geometry_test` re-reads those two `Rect`s from the painter and
  /// fails if these numbers stop matching, so re-drawing a sofa cannot silently
  /// leave Mochi floating above it.
  static const Map<String, double> seatSurfaceFractions = {
    'sofa': 0.48,
    'bed': 0.42,
  };

  /// The sitting surface assumed for a seat with no line of its own: the
  /// sprite's vertical centre, which is also where the item is anchored.
  static const double defaultSeatSurfaceFraction = 0.5;

  /// The sitting surface for [itemId]. Never null — see
  /// [defaultSeatSurfaceFraction].
  static double seatSurfaceFraction(String itemId) =>
      seatSurfaceFractions[itemId.toLowerCase()] ?? defaultSeatSurfaceFraction;

  /// Resolves where Mochi is.
  ///
  /// A seat must satisfy **all** of:
  ///
  /// 1. its id is in [seatItemIds];
  /// 2. it is actually placed — a row in [placed] — not merely owned;
  /// 3. it is visible, since an invisible placed item is not on the floor;
  /// 4. it is actually owned — a positive quantity in [owned].
  ///
  /// (4) is redundant today, because `CraftController.placeItem` only places
  /// from inventory and `removeRoomItem` deletes the row. It is enforced anyway:
  /// it is the literal half of "gated on real ownership **and** placement", and
  /// it is what stops a future grant path that writes a room row directly from
  /// putting Mochi on furniture the user never acquired.
  ///
  /// When several seats qualify, the topmost wins: highest `zIndex`, then the
  /// newer placement, then the larger id. The id tie-break exists so the answer
  /// never depends on the order the rows came back in.
  /// [eligibleItemIds] lets the caller supply the eligible set from the recipe
  /// catalog. When omitted the historical positive list is used, so existing
  /// callers and tests keep their behaviour.
  static PetRoomPresence resolve({
    required List<RoomItem> placed,
    required List<InventoryItem> owned,
    Set<String>? eligibleItemIds,
  }) {
    final eligible = eligibleItemIds ?? seatItemIds;
    final ownedItemIds = <String>{
      for (final item in owned)
        if (item.quantity > 0) item.itemId,
    };

    final candidates = placed
        .where((item) =>
            eligible.contains(item.itemId) &&
            item.isVisible &&
            ownedItemIds.contains(item.itemId))
        .toList();

    if (candidates.isEmpty) {
      return const PetRoomPresence(
        seatItemId: null,
        x: floorX,
        y: floorY,
      );
    }

    candidates.sort((a, b) {
      final byZ = a.zIndex.compareTo(b.zIndex);
      if (byZ != 0) return byZ;
      final byPlacedAt = a.placedAt.compareTo(b.placedAt);
      if (byPlacedAt != 0) return byPlacedAt;
      return a.id.compareTo(b.id);
    });

    final seat = candidates.last;
    return PetRoomPresence(
      seatItemId: seat.itemId,
      x: seat.positionX,
      y: seat.positionY,
    );
  }
}

/// Turns a resolved seat into the pixel geometry of the avatar's box.
///
/// Two corrections stack here, and both err in the same direction — the pet
/// ends up **floating** — which is why this is a pure function with a test
/// rather than inline arithmetic in the room page:
///
/// 1. **Furniture is positioned by its centre.** The canvas draws an item at
///    `positionY - renderedSize / 2`, so [PetRoomPresence.y] is the middle of
///    the sprite. The surface Mochi sits on is above that by
///    `0.5 - seatSurfaceFraction` of the item's rendered height — 1.2 px on a
///    scale-1 sofa, 4.8 px on a scale-1 bed.
/// 2. **The avatar's box is square and the character is centred inside it**, so
///    the box's bottom edge sits
///    [MochiLayerAssets.feetInsetFraction] of the box *below* the paws. On the
///    room's 92 pt avatar that is 15.8 pt, and it dominates: anchoring the box
///    by its bottom edge — which is what "put the pet on the sofa" naturally
///    reads as — leaves Mochi hovering about 15 pt above the cushions.
///
/// Both were measured rather than assumed; see the constants' own docs.
abstract final class PetSeatPlacement {
  const PetSeatPlacement._();

  /// The canvas y the character's feet must land on.
  ///
  /// [seatAnchorY] is the seat item's own `positionY` in canvas pixels and
  /// [seatRenderedSize] its rendered height. On the floor there is no seat:
  /// pass `0` for the size and the anchor is returned unchanged, which is what
  /// the floor point already means.
  static double feetY({
    required double seatAnchorY,
    required double seatRenderedSize,
    required double seatSurfaceFraction,
  }) =>
      seatAnchorY -
      seatRenderedSize *
          (PetRoomPresenceResolver.defaultSeatSurfaceFraction -
              seatSurfaceFraction);

  /// The `Positioned.top` for an avatar of [avatarSize] whose feet are at
  /// [feetY].
  static double boxTop({
    required double feetY,
    required double avatarSize,
    required double feetInsetFraction,
  }) =>
      feetY - avatarSize * (1 - feetInsetFraction);
}
