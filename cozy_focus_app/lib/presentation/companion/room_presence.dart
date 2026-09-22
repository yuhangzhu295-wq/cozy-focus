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

  /// Normalised centre of Mochi's feet, `0.0 … 1.0` on each axis.
  ///
  /// Same coordinate space as [RoomItem.positionX] / [RoomItem.positionY], so
  /// the room canvas can position Mochi with the arithmetic it already uses for
  /// furniture.
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
  static PetRoomPresence resolve({
    required List<RoomItem> placed,
    required List<InventoryItem> owned,
  }) {
    final ownedItemIds = <String>{
      for (final item in owned)
        if (item.quantity > 0) item.itemId,
    };

    final candidates = placed
        .where((item) =>
            seatItemIds.contains(item.itemId) &&
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
