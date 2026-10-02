import 'animation_state.dart';
import 'animation_state_machine.dart';

/// The shipped animation state machine, as Dart data.
///
/// ## Why this exists alongside the JSON
///
/// `assets/companion/animation_states.json` is the **authoring source**:
/// readable, diffable, and what the pipeline writes. The presentation layer
/// needs it *synchronously* — the first frame must draw the right transition
/// without an `await` between app start and first paint.
///
/// So the same data is mirrored here, and
/// `animation_state_machine_parity_test.dart` parses the shipped JSON and fails
/// if the two disagree in any field. Drift becomes a test failure rather than a
/// silently wrong animation.
///
/// ## It is still data
///
/// There is no companion id and no species switch. Adding a transition is a row
/// in the JSON plus a row here — no controller edit.
abstract final class AnimationStateMachineData {
  const AnimationStateMachineData._();

  /// The state machine the runtime uses when no other is supplied.
  static const AnimationStateMachine bundled = AnimationStateMachine(
    postureOf: {
      AnimationState.idle: AnimationPosture.standing,
      AnimationState.walk: AnimationPosture.standing,
      AnimationState.sitDown: AnimationPosture.standing,
      AnimationState.standUp: AnimationPosture.standing,
      AnimationState.wakeUp: AnimationPosture.standing,
      AnimationState.happy: AnimationPosture.standing,
      AnimationState.sad: AnimationPosture.standing,
      AnimationState.interact: AnimationPosture.standing,
      AnimationState.focusWrite: AnimationPosture.seated,
      AnimationState.focusRead: AnimationPosture.seated,
      AnimationState.focusThink: AnimationPosture.seated,
      AnimationState.craftWork: AnimationPosture.seated,
      AnimationState.rest: AnimationPosture.seated,
      AnimationState.sleep: AnimationPosture.lying,
    },
    transitionDurations: {
      AnimationState.sitDown: Duration(milliseconds: 600),
      AnimationState.standUp: Duration(milliseconds: 550),
      AnimationState.wakeUp: Duration(milliseconds: 700),
    },
    transitions: [
      AnimationTransition(
        from: AnimationPosture.standing,
        to: AnimationPosture.seated,
        state: AnimationState.sitDown,
      ),
      AnimationTransition(
        from: AnimationPosture.standing,
        to: AnimationPosture.lying,
        state: AnimationState.sitDown,
      ),
      AnimationTransition(
        from: AnimationPosture.seated,
        to: AnimationPosture.standing,
        state: AnimationState.standUp,
      ),
      AnimationTransition(
        from: AnimationPosture.seated,
        to: AnimationPosture.lying,
        state: AnimationState.sitDown,
      ),
      AnimationTransition(
        from: AnimationPosture.lying,
        to: AnimationPosture.standing,
        state: AnimationState.wakeUp,
      ),
      AnimationTransition(
        from: AnimationPosture.lying,
        to: AnimationPosture.seated,
        state: AnimationState.wakeUp,
      ),
    ],
    poseProjections: {
      'idle': AnimationState.idle,
      'prepare': AnimationState.idle,
      'glance': AnimationState.idle,
      'micro_rest': AnimationState.idle,
      'pause_rest': AnimationState.rest,
      'room_sit': AnimationState.idle,
      'room_relax': AnimationState.idle,
      'focus_write': AnimationState.focusWrite,
      'finish': AnimationState.focusWrite,
      'room_work': AnimationState.focusWrite,
      'focus_read': AnimationState.focusRead,
      'room_read': AnimationState.focusRead,
      'focus_think': AnimationState.focusThink,
      'craft_work': AnimationState.craftWork,
      'celebrate': AnimationState.happy,
      'sleep': AnimationState.sleep,
      'room_sleep': AnimationState.sleep,
      'tap_react': AnimationState.interact,
      'pet_react': AnimationState.interact,
      'greeting': AnimationState.interact,
      'unlock_react': AnimationState.interact,
    },
  );
}
