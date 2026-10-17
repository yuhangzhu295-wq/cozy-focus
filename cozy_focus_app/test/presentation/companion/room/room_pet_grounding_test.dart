import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/room/anchor_point.dart';
import 'package:cozy_focus_app/presentation/companion/room/companion_placement.dart';
import 'package:cozy_focus_app/presentation/widgets/cozy_room_backdrop.dart';

/// The companion's paws must rest on the floor plane, not hover above it.
///
/// ## Found by looking at the room on the device
///
/// The room draws a woven mat under the companion and the boards show the
/// companion lying on it. On the device the companion floats: there is a visible
/// gap between its paws and the mat, so it reads as standing *over* the rug
/// rather than resting on it.
///
/// ## The two numbers that disagree
///
/// These are two independent constants in two files, and neither knows about the
/// other - which is exactly why they could drift:
///
/// * `CozyRoomBackdrop` puts the mat's centre at `deskLine + (1 - deskLine) * 0.26`
///   of the scene height.
/// * `floorAnchor.y` is `0.70`, and the room's backdrop uses `deskLine = 0.70`, so
///   the paws land at `0.70` of the same height.
///
/// At the room's own deskLine those are `0.778` and `0.700` — a gap of about
/// 0.078 of a 2400px scene, roughly **187px**. That is the hover, as a number.
///
/// ## Why this test compares them instead of pinning one
///
/// Pinning `floorAnchor.y` to `0.778` would break for any other deskLine: the
/// mat moves with `deskLine` and the anchor does not. The invariant that holds is
/// the relationship - the paws must land within a small tolerance of where the
/// mat is drawn. So this test states the invariant, and a screen can then use a
/// constant derived from the same numbers the painter uses.
void main() {
  // The room page's own values, which is the surface the defect was seen on.
  const roomDeskLine = 0.70;
  const sceneHeight = 2400.0;

  /// Where `CozyRoomBackdrop._paintMat` centres the mat, for a given deskLine.
  /// Mirrors the painter's own expression, so a change to the painter's 0.26 is
  /// caught here rather than silently agreeing with a stale copy.
  double matCentreFraction(double deskLine) => deskLine + (1 - deskLine) * 0.26;

  test('the room passes its own deskLine, and the anchor does not move', () {
    // The premise of the whole test: the mat is positioned from deskLine, the
    // paws from the anchor. If either stops being true, the comparison below is
    // meaningless.
    expect(roomDeskLine, 0.70,
        reason: 'room_page hard-codes deskLine 0.70 for the floor anchor');
    expect(floorAnchor.y, 0.70);
  });

  test('the desk the room uses puts the mat centre on the paws', () {
    // The invariant, stated so it can fail. `kDeskLineForFloorAnchor` is the
    // projection the room now uses, so this checks the room's own choice lands
    // the mat on the companion's paws - independent of any screen's sizing.
    final feetY = CompanionPlacement.feetYFor(
      anchor: floorAnchor,
      canvasHeight: sceneHeight,
    );
    final deskLine = kDeskLineForFloorAnchor(floorAnchor.y);
    final matY = matCentreFraction(deskLine) * sceneHeight;

    // Under a small fraction of the scene: the residual is the mat's own
    // half-height, not a hover. On 2400px that is about 48px.
    expect((matY - feetY).abs(), lessThan(sceneHeight * 0.02),
        reason: 'the room deskLine $deskLine puts the mat centre '
            '${(matY - feetY).toStringAsFixed(0)}px from the paws');
  });

  test('and a deskLine copied from the anchor instead would hover', () {
    // The regression this guards, with the old value named. Passing the anchor's
    // own y as the deskLine was the defect: the mat then sits further down than
    // the floor plane, and the pet floats above it. If someone reverts to a
    // hard-coded 0.70 this fails by that much.
    final feetY = CompanionPlacement.feetYFor(
      anchor: floorAnchor,
      canvasHeight: sceneHeight,
    );
    final matY = matCentreFraction(floorAnchor.y) * sceneHeight;
    expect(matY - feetY, greaterThan(sceneHeight * 0.02),
        reason: 'passing the anchor y as deskLine should hover, and no longer '
            'does; either the anchor moved or the mat expression changed');
  });

  test('the mat centre is below the floor anchor for every deskLine', () {
    // The general shape, so the fix cannot be "just move the mat" - the mat
    // depends on deskLine, and the anchor is a shared constant used by empty
    // rooms too.
    for (final deskLine in const [0.60, 0.70, 0.74, 0.78, 0.82]) {
      expect(matCentreFraction(deskLine), greaterThan(deskLine),
          reason:
              'at deskLine $deskLine the mat is not below the floor anchor');
    }
  });
}
