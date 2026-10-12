import 'package:cozy_focus_app/presentation/companion/mochi_visual_provider.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:flutter_test/flutter_test.dart';

/// The companion must not vanish for a frame when a tap swaps its renderer.
///
/// ## The defect this guards (42)
///
/// The hero draws the **layered rig** for `idle` - the only pose in
/// [MochiVisualProvider.layeredPoses] - and a **sprite** for everything else.
/// So the first tap changes the widget *type* at that position, Flutter builds a
/// brand-new sprite element, and a new element has no decoded image to show:
/// `gaplessPlayback` has nothing to hold. The companion drew nothing for one or
/// two frames. On the device that measured as the hero's ink collapsing from
/// 14932 to 631 and back in a single frame, with the rest of the page fully
/// drawn.
///
/// The fix decodes the interaction sequences while the rig is still on screen.
///
/// ## Why this test is not the whole story
///
/// Decode timing is not observable in a widget test - images do not decode here
/// at all - so no test in this file can watch the blank appear. The real check is
/// the device instrument `tools/qa/state_switch_flicker.py`, which measured the
/// blank before the fix and measures none after it, and whose reverse proof
/// (precache disabled) brings it back.
///
/// What this file can do is pin the two facts the fix rests on, so that removing
/// either one fails here rather than silently re-opening the blank on a device
/// nobody is looking at.
void main() {
  test('the interaction sequences are prepared, because the renderer swaps',
      () {
    // Fact 1: the swap really happens. `idle` is the only layered pose, so any
    // interaction pose is drawn by a different renderer - a different widget
    // type at the same position, which is what creates a fresh element.
    expect(MochiVisualProvider.layeredPoses, {'idle'},
        reason: 'if an interaction pose became layered the swap would stop '
            'happening, and this whole guard would be measuring nothing');

    // Fact 2: both interaction poses have sprite art to swap *to*, and the
    // fix's list covers them.
    for (final pose in const [CompanionPose.tapReact, CompanionPose.petReact]) {
      expect(MochiVisualProvider.spritePoses, contains(pose),
          reason: '$pose is drawn from a sprite, so a fresh element is created '
              'for it');
    }

    final specs = MochiVisualProvider.interactionSpriteSpecs();
    expect(specs, isNotEmpty,
        reason: 'an empty list is exactly the reverse proof: with it the '
            'companion blanks for a frame on the first tap');
    expect(
      specs.map((s) => s.actionId).toSet(),
      containsAll(<String>['tap_react', 'pet_react']),
      reason: 'both gestures have to be prepared, not just the tap',
    );
    for (final spec in specs) {
      expect(spec.frames, isNotEmpty,
          reason: '${spec.actionId} has nothing to decode');
    }
  });

  test('only the interaction sequences are prepared', () {
    // The player's contract is explicit that the caller picks what is *likely
    // next*, and the brief forbids holding every frame of every action in memory
    // at once. So this is a short list, not the whole pack.
    final prepared =
        MochiVisualProvider.interactionSpriteSpecs().map((s) => s.actionId);
    expect(prepared.length, lessThanOrEqualTo(3));
    expect(prepared, isNot(contains('idle')),
        reason: 'idle is drawn by the rig, so there is no sprite to prepare');
    expect(prepared, isNot(contains('celebrate')),
        reason: 'a celebration is a page change, not a gesture - preparing it '
            'here would be holding art for a moment this screen cannot reach');
  });

  test('the overlay poses the fix prepares are the ones the gestures raise',
      () {
    // Ties the prepared list to the enum the gestures actually trigger, so a
    // renamed or added overlay cannot quietly fall outside the list.
    const gestures = [CompanionOverlay.tapReact, CompanionOverlay.petReact];
    for (final overlay in gestures) {
      expect(overlay.pose, isNotNull);
    }
    expect(
      MochiVisualProvider.interactionSpriteSpecs().map((s) => s.actionId),
      containsAll(gestures.map((o) => o.pose!.id)),
    );
  });
}
