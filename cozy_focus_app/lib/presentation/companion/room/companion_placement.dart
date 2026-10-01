/// Turns a simulation decision into the pixel position of the companion's box.
///
/// ## Why this is separate from the simulation
///
/// The simulation decides *where the companion is* in semantic terms — "at the
/// desk anchor". Turning that into "`top: 231.4`" needs the canvas size, the
/// furniture's render scale and the avatar's own geometry, none of which the
/// simulation should know about. Keeping the conversion here means the
/// simulation is testable without a widget tree, and the arithmetic is testable
/// without a simulation.
library;

import 'anchor_point.dart';

/// The rendered size of a placed furniture sprite at `scale == 1`.
///
/// Shared with the room canvas, which draws items at this size; a second copy of
/// the number would let the companion's feet drift from the art.
const double kFurnitureItemSize = 60.0;

/// Where the companion's avatar box goes, in canvas pixels.
class CompanionBox {
  /// The box's left edge.
  final double left;

  /// The box's top edge.
  final double top;

  /// The box's edge length.
  final double size;

  const CompanionBox({
    required this.left,
    required this.top,
    required this.size,
  });

  @override
  String toString() => 'CompanionBox(left ${left.toStringAsFixed(1)}, '
      'top ${top.toStringAsFixed(1)}, size $size)';
}

/// Converts an anchor into an avatar box.
///
/// Three corrections stack, and all three were measured rather than assumed:
///
/// 1. **Furniture is positioned by its centre.** The canvas draws an item at
///    `positionY - renderedSize / 2`, so the anchor's `y` is the middle of the
///    sprite. The surface the companion sits on is above that by
///    `0.5 - surfaceFraction` of the item's rendered height.
/// 2. **The avatar's box is square with the character centred inside it**, so
///    the box's bottom edge sits `feetInsetFraction` of the box *below* the
///    paws. Anchoring by that edge leaves the companion hovering.
/// 3. **The floor anchor has no furniture**, so its `y` is already a feet
///    position and neither correction applies.
abstract final class CompanionPlacement {
  const CompanionPlacement._();

  /// The avatar box for [anchor] on a canvas of [canvasWidth] ×
  /// [canvasHeight], for an avatar of [avatarSize] whose paws sit
  /// [feetInsetFraction] of the box above its bottom edge.
  static CompanionBox boxFor({
    required AnchorPoint anchor,
    required double canvasWidth,
    required double canvasHeight,
    required double avatarSize,
    required double feetInsetFraction,
  }) {
    final feetY = feetYFor(
      anchor: anchor,
      canvasHeight: canvasHeight,
    );
    return CompanionBox(
      left: anchor.x * canvasWidth - avatarSize / 2,
      top: feetY - avatarSize * (1 - feetInsetFraction),
      size: avatarSize,
    );
  }

  /// The canvas y the companion's paws rest on.
  ///
  /// Exposed because a test can assert the feet land on the sofa's cushion
  /// without reconstructing the box.
  static double feetYFor({
    required AnchorPoint anchor,
    required double canvasHeight,
  }) {
    // The floor anchor means "standing on the ground", so its y is the feet
    // position already.
    if (anchor.itemId.isEmpty) return anchor.y * canvasHeight;

    final renderedSize = kFurnitureItemSize * anchor.scale;
    return anchor.y * canvasHeight -
        renderedSize * (0.5 - anchor.surfaceFraction);
  }
}
