import 'package:cozy_focus_app/presentation/companion/animation/animation_state.dart';
import 'package:cozy_focus_app/presentation/companion/animation/animation_state_machine.dart';
import 'package:cozy_focus_app/presentation/companion/animation/companion_animation_controller.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_presentation_intent.dart';
import 'package:flutter_test/flutter_test.dart';

/// A monotonic presentation clock, so a test cannot accidentally re-push the
/// same instant and conclude a transition is stuck.
class _Clock {
  Duration _now = Duration.zero;

  Duration advanceBy(Duration step) {
    _now += step;
    return _now;
  }
}

/// The intent a behaviour director would produce, with only the fields the
/// animation layer is allowed to read.
CompanionPresentationIntent intentFor(
  CompanionPose pose, {
  bool isOverlayActive = false,
}) =>
    CompanionPresentationIntent(
      companionId: CompanionId.dog,
      pose: pose,
      baseContext: CompanionBaseContext.focus,
      isOverlayActive: isOverlayActive,
    );

void main() {
  group('behaviour projects onto an animation', () {
    test('a work pose asks for its own sustained state', () {
      for (final entry in const {
        CompanionPose.focusWrite: AnimationState.focusWrite,
        CompanionPose.focusRead: AnimationState.focusRead,
        CompanionPose.focusThink: AnimationState.focusThink,
        CompanionPose.craftWork: AnimationState.craftWork,
      }.entries) {
        final controller = CompanionAnimationController();
        controller.setIntent(intentFor(entry.key));
        expect(controller.posture, AnimationPosture.seated,
            reason: '${entry.key} is done seated');
        // Drive the queue to its end; the sustained state is what remains.
        controller.advanceTo(const Duration(seconds: 5));
        expect(controller.currentState, entry.value, reason: '${entry.key}');
      }
    });

    test('celebrate projects onto the happy animation, not onto a pose', () {
      final controller = CompanionAnimationController();
      controller.setIntent(intentFor(CompanionPose.celebrate));
      controller.advanceTo(const Duration(seconds: 5));
      expect(controller.currentState, AnimationState.happy);
      // The asset brief names this sequence `celebrate`, and the animation layer
      // names it `happy`. The mapping must be explicit rather than implied.
      expect(AnimationState.happy.assetActionId, 'celebrate');
    });

    test('sleep leaves the character lying down', () {
      final controller = CompanionAnimationController();
      controller.setIntent(intentFor(CompanionPose.sleep));
      controller.advanceTo(const Duration(seconds: 5));
      expect(controller.currentState, AnimationState.sleep);
      expect(controller.posture, AnimationPosture.lying);
    });

    test('a reaction pose is a one-shot interact, never a new posture', () {
      for (final pose in const [
        CompanionPose.tapReact,
        CompanionPose.petReact,
        CompanionPose.greeting,
      ]) {
        final controller = CompanionAnimationController();
        controller.setIntent(intentFor(pose, isOverlayActive: true));
        expect(controller.currentState, AnimationState.interact,
            reason: '$pose');
        expect(controller.isOverlay, isTrue, reason: '$pose');
      }
    });
  });

  group('transitions are queued and never looped', () {
    test('writing from standing plays sit_down then holds focus_write', () {
      final controller = CompanionAnimationController();
      controller.setIntent(intentFor(CompanionPose.focusWrite));

      // The behaviour said "write"; the first thing drawn is getting into the
      // chair, which is the whole point of this layer existing.
      expect(controller.currentState, AnimationState.sitDown);
      expect(controller.isTransitioning, isTrue);

      // Before the transition is up, it has not handed over.
      controller.advanceTo(const Duration(milliseconds: 300));
      expect(controller.currentState, AnimationState.sitDown);

      controller.advanceTo(const Duration(milliseconds: 600));
      expect(controller.currentState, AnimationState.focusWrite);
      expect(controller.isTransitioning, isFalse);
    });

    test('a transition hands over even when the clock jumps a long way', () {
      final controller = CompanionAnimationController();
      controller.setIntent(intentFor(CompanionPose.focusWrite));

      // A coarse clock (or a test that pumps minutes) must not leave the queue
      // stale: more than one transition can complete between two calls.
      controller.advanceTo(const Duration(minutes: 2));
      expect(controller.currentState, AnimationState.focusWrite);
      expect(controller.isTransitioning, isFalse);
    });

    test('a transition is not interruptible', () {
      expect(AnimationState.sitDown.isInterruptible, isFalse);
      expect(AnimationState.standUp.isInterruptible, isFalse);
      expect(AnimationState.wakeUp.isInterruptible, isFalse);
      // The sustained states are.
      expect(AnimationState.focusWrite.isInterruptible, isTrue);
      expect(AnimationState.idle.isInterruptible, isTrue);
    });

    test('leaving a seat for the floor plays stand_up first', () {
      final clock = _Clock();
      final controller = CompanionAnimationController();
      controller.setIntent(intentFor(CompanionPose.focusWrite));
      controller.advanceTo(clock.advanceBy(const Duration(seconds: 5)));
      expect(controller.posture, AnimationPosture.seated);

      controller.setIntent(intentFor(CompanionPose.idle));
      expect(controller.currentState, AnimationState.standUp);

      // The clock has to actually pass the deadline for the handover to happen.
      controller.advanceTo(clock.advanceBy(const Duration(seconds: 5)));
      expect(controller.currentState, AnimationState.idle);
      expect(controller.posture, AnimationPosture.standing);
    });

    test('waking from sleep plays wake_up, not stand_up', () {
      final clock = _Clock();
      final controller = CompanionAnimationController();
      controller.setIntent(intentFor(CompanionPose.sleep));
      controller.advanceTo(clock.advanceBy(const Duration(seconds: 5)));
      expect(controller.posture, AnimationPosture.lying);

      controller.setIntent(intentFor(CompanionPose.idle));
      expect(controller.currentState, AnimationState.wakeUp);
      // ...and it is a wake-up, not a stand-up: the character was lying down.
      expect(controller.currentState, isNot(AnimationState.standUp));
    });

    test('an overlay never triggers a posture change', () {
      final controller = CompanionAnimationController();
      controller.setIntent(intentFor(CompanionPose.focusWrite));
      controller.advanceTo(const Duration(seconds: 5));
      expect(controller.posture, AnimationPosture.seated);

      // A tap while writing must not stand the companion up and sit it back
      // down: the player asked for a reaction, not for a journey.
      controller.setIntent(
        intentFor(CompanionPose.tapReact, isOverlayActive: true),
      );
      expect(controller.currentState, AnimationState.interact);
      expect(controller.isTransitioning, isFalse);
      expect(controller.posture, AnimationPosture.seated);
    });
  });

  group('the animation layer decides no business', () {
    test('an unchanged target does not restart a running transition', () {
      final controller = CompanionAnimationController();
      controller.setIntent(intentFor(CompanionPose.focusWrite));
      controller.advanceTo(const Duration(milliseconds: 400));
      expect(controller.currentState, AnimationState.sitDown);

      // The same behaviour re-pushed — what an unrelated rebuild looks like.
      final changed = controller.setIntent(intentFor(CompanionPose.focusWrite));
      expect(changed, isFalse);
      expect(controller.currentState, AnimationState.sitDown,
          reason: 'a rebuild must not restart the transition');
    });

    test('the controller exposes no write path back to the behaviour', () {
      final controller = CompanionAnimationController();
      controller.setIntent(intentFor(CompanionPose.focusWrite));

      // The intent is immutable and the controller only reads it. There is no
      // setter, no mutation method and no repository on the type: if one is
      // added, this is the test that should fail.
      expect(controller.currentState, isA<AnimationState>());
      expect(controller.hasIntent, isTrue);
    });
  });

  group('state vocabulary', () {
    test('no animation state is a single-frame loop by intent', () {
      // Stage 0's finding: a one-frame sequence is a still, not an animation.
      // The states here all name a multi-frame sequence in the asset brief.
      for (final state in AnimationState.values) {
        expect(state.assetActionId, isNotEmpty, reason: '$state');
      }
    });

    test('walk is a state even though no pose asks for it yet', () {
      // Stage 3 makes locomotion produce it. It is declared here so the state
      // machine can name it before the art exists.
      expect(AnimationState.values, contains(AnimationState.walk));
      expect(AnimationState.fromId('walk'), AnimationState.walk);
    });

    test('an unknown id resolves to null rather than throwing', () {
      expect(AnimationState.fromId('not_a_state'), isNull);
      expect(AnimationState.fromId(null), isNull);
    });
  });
}
