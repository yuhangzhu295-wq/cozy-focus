import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/presentation/companion/companion_visual_state.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_presentation_intent.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:flutter_test/flutter_test.dart';

/// The renderer state for an intent, and the completion's one exception.
///
/// ## The defect this guards
///
/// `celebrate` is a **one-shot** rig state. A rig mounted in it never becomes
/// ambient - it logs `ambient=false timers=0 breathe=false` and stands perfectly
/// still - because the ambient layer is only started for the sustained states,
/// and the one-shot hands over to it only when its own controller completes.
///
/// The completion context lasts as long as the page is open, so mapping it to
/// `celebrate` unconditionally meant the rig was frozen from the moment the
/// celebration handed over. Measured on the device: the companion's pixels were
/// identical for 5.95 seconds after a celebration that had lasted 0.6.
///
/// ## Why this mapping is one function
///
/// It existed twice - `CompanionAvatar` pushed it into the motion controller and
/// the Mochi provider passed it to the widget - and the fix went into one of
/// them. The rig reads the *controller's* state, so it never saw the change. That
/// is the failure mode of two copies, and it is why there is now one.
void main() {
  CompanionPresentationIntent intent({
    required CompanionBaseContext base,
    CompanionMacroBehavior? macro,
    CompanionPose pose = CompanionPose.idle,
  }) =>
      CompanionPresentationIntent(
        companionId: CompanionId.dog,
        pose: pose,
        baseContext: base,
        macroBehavior: macro,
      );

  test('the completion celebrates while the moment is running', () {
    expect(
      companionVisualStateFor(intent(
        base: CompanionBaseContext.complete,
        macro: CompanionMacroBehavior.celebrate,
        pose: CompanionPose.celebrate,
      )),
      PetVisualState.celebrate,
    );
  });

  test('and settles once the director has handed over', () {
    // The one exception. Without it the rig stays in the one-shot state and the
    // companion stands still for as long as the page is open.
    expect(
      companionVisualStateFor(intent(
        base: CompanionBaseContext.complete,
        macro: CompanionMacroBehavior.idle,
      )),
      PetVisualState.idle,
      reason:
          'the completion is not a state, it is a moment - once the director '
          'moves on, the companion has to be able to breathe again',
    );
  });

  test('every other context maps to its own state', () {
    expect(companionVisualStateFor(intent(base: CompanionBaseContext.home)),
        PetVisualState.idle);
    expect(companionVisualStateFor(intent(base: CompanionBaseContext.room)),
        PetVisualState.idle);
    expect(companionVisualStateFor(intent(base: CompanionBaseContext.focus)),
        PetVisualState.focus);
    expect(companionVisualStateFor(intent(base: CompanionBaseContext.pause)),
        PetVisualState.pause);
    expect(companionVisualStateFor(intent(base: CompanionBaseContext.craft)),
        PetVisualState.craft);
    expect(companionVisualStateFor(intent(base: CompanionBaseContext.sleep)),
        PetVisualState.sleep);
  });

  test('a missing macro is treated as settled, not as celebrating', () {
    // `macroBehavior` is nullable, and the safe reading of "no behaviour" is that
    // no celebration is running. The other reading would freeze the companion on
    // a page that has not decided anything yet.
    expect(
      companionVisualStateFor(intent(base: CompanionBaseContext.complete)),
      PetVisualState.idle,
    );
  });

  test('only the completion is special - a focus session is never idle', () {
    for (final base in CompanionBaseContext.values) {
      if (base == CompanionBaseContext.complete) continue;
      final state = companionVisualStateFor(intent(
        base: base,
        macro: CompanionMacroBehavior.celebrate,
        pose: CompanionPose.celebrate,
      ));
      expect(state, isNot(PetVisualState.celebrate),
          reason: '$base must not borrow the completion rule');
    }
  });
}
