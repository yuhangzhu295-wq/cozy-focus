import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/presentation/animations/pet_idle_fallback_view.dart';
import 'package:cozy_focus_app/presentation/animations/pet_interaction_spec.dart';
import 'package:cozy_focus_app/presentation/animations/pet_motion_spec.dart';
import 'package:cozy_focus_app/presentation/controllers/pet_motion_controller.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';

/// STAGE 4 — per-state interaction, priority, and the base-state guarantee.
///
/// The behaviour under test is the brief's: Mochi answers a touch in every base
/// state, with a different response in each, and a short interaction must return
/// to the state it started in.
void main() {
  Future<PetIdleFallbackViewState> pumpPet(
    WidgetTester tester,
    PetMotionController controller,
    PetVisualState state,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PetAvatarWidget(visualState: state, controller: controller),
      ),
    ));
    await tester.pump();
    return tester.state<PetIdleFallbackViewState>(
      find.byType(PetIdleFallbackView),
    );
  }

  group('the priority order is the brief\'s', () {
    test('celebrate outranks interact, which outranks every commitment', () {
      expect(PetInteractionPriority.tierOf(PetVisualState.celebrate),
          PetPresentationTier.celebration);
      expect(PetInteractionPriority.tierOf(PetVisualState.interact),
          PetPresentationTier.interaction);
      for (final state in const [
        PetVisualState.craft,
        PetVisualState.focus,
        PetVisualState.pause,
        PetVisualState.sleep,
      ]) {
        expect(PetInteractionPriority.tierOf(state),
            PetPresentationTier.commitment,
            reason: '$state should sit in the commitment tier');
      }
      expect(PetInteractionPriority.tierOf(PetVisualState.idle),
          PetPresentationTier.idle);
    });

    test('every state has a tier — the mapping is total', () {
      for (final state in PetVisualState.values) {
        expect(() => PetInteractionPriority.tierOf(state), returnsNormally);
      }
    });

    test('an interaction is allowed everywhere except a celebration', () {
      for (final state in PetVisualState.values) {
        final expected = state != PetVisualState.celebrate &&
            state != PetVisualState.greeting;
        expect(
          PetInteractionPriority.canInteractDuring(state),
          expected,
          reason: 'canInteractDuring($state)',
        );
      }
    });

    test('greeting is treated as a celebration, not as a base state', () {
      // The brief's list does not mention greeting. It is the same kind of thing
      // as celebrate — a one-shot trigger already earned — so treating it as
      // preemptible would let a poke cut a greeting short.
      expect(PetInteractionPriority.tierOf(PetVisualState.greeting),
          PetPresentationTier.celebration);
    });
  });

  group('the spec table is total over the states that react', () {
    test('exactly the five base states have a spec', () {
      expect(
        PetInteractionSpec.interactableStates,
        {
          PetVisualState.idle,
          PetVisualState.focus,
          PetVisualState.pause,
          PetVisualState.sleep,
          PetVisualState.craft,
        },
      );
    });

    test('a state with no spec returns null rather than a neutral row', () {
      // Returning null is what stops a caller from silently animating a state
      // the brief says must not react.
      expect(PetInteractionSpec.forState(PetVisualState.celebrate), isNull);
      expect(PetInteractionSpec.forState(PetVisualState.greeting), isNull);
      expect(PetInteractionSpec.forState(PetVisualState.interact), isNull);
    });

    test('every state reads as a different behaviour', () {
      final kinds = PetInteractionSpec.table.values.map((s) => s.kind).toList();
      expect(kinds.toSet().length, kinds.length,
          reason:
              'two base states share a behaviour, so the split is cosmetic');
    });

    test('an owned channel always carries a real amplitude', () {
      // "Owned" is the priority mechanism: the overlay wins on the channels it
      // takes. An owned channel with a zero amplitude would be dead ownership —
      // it would block the base state's motion and put nothing in its place.
      for (final entry in PetInteractionSpec.table.entries) {
        final spec = entry.value;
        final amplitudes = {
          PetMotionChannel.scale: spec.tapScalePeak - 1.0,
          PetMotionChannel.dy: spec.tapDyPeak,
          PetMotionChannel.bodyTilt: spec.tapBodyTiltDegrees,
          PetMotionChannel.ear: spec.tapEarTiltDegrees,
          PetMotionChannel.tail: spec.tapTailTiltDegrees,
          PetMotionChannel.eyes: 1.0 - spec.tapEyeSquintMin,
          PetMotionChannel.head: spec.tapHeadTiltDegrees,
        };
        for (final channel in spec.ownedChannels) {
          expect(amplitudes[channel], isNot(0.0),
              reason: '${entry.key} owns $channel but does not move it');
        }
      }
    });

    test('a channel with a zero amplitude is never owned', () {
      for (final entry in PetInteractionSpec.table.entries) {
        final spec = entry.value;
        if (spec.tapBodyTiltDegrees == 0.0) {
          expect(
              spec.ownedChannels, isNot(contains(PetMotionChannel.bodyTilt)));
        }
        if (spec.tapDyPeak == 0.0) {
          expect(spec.ownedChannels, isNot(contains(PetMotionChannel.dy)));
        }
      }
    });

    test('every duration is positive and a poke is quicker than a stroke', () {
      for (final entry in PetInteractionSpec.table.entries) {
        final spec = entry.value;
        expect(spec.tapDuration.inMilliseconds, greaterThan(0));
        expect(spec.strokeDuration.inMilliseconds, greaterThan(0));
        expect(spec.tapDuration, lessThan(spec.strokeDuration),
            reason: '${entry.key}: a tap should be over before a hold is');
      }
    });

    test('a stroke never closes the eyes completely', () {
      // Mochi softening its eyes reads as affection; eyes fully shut reads as
      // going to sleep, which is a different state entirely.
      for (final entry in PetInteractionSpec.table.entries) {
        expect(entry.value.strokeEyeClose, greaterThan(0.0),
            reason: '${entry.key} shuts its eyes entirely on a stroke');
        expect(entry.value.strokeEyeClose, lessThan(1.0),
            reason: '${entry.key} does not soften its eyes at all on a stroke');
      }
    });
  });

  group('the per-state behaviours are actually different', () {
    test('a focus glance does not move the body', () {
      final glance = PetInteractionSpec.table[PetVisualState.focus]!;
      expect(glance.kind, PetInteractionKind.glance);
      // The whole point: a glance is head and eyes, so the work pose underneath
      // survives instead of being replaced by a wobble.
      expect(glance.ownedChannels, isNot(contains(PetMotionChannel.bodyTilt)));
      expect(glance.ownedChannels, isNot(contains(PetMotionChannel.dy)));
      expect(glance.ownedChannels, isNot(contains(PetMotionChannel.scale)));
      expect(glance.ownedChannels, contains(PetMotionChannel.head));
      expect(glance.tapHeadTiltDegrees, greaterThan(0.0));
    });

    test('idle hands over every channel', () {
      final friendly = PetInteractionSpec.table[PetVisualState.idle]!;
      expect(friendly.kind, PetInteractionKind.friendly);
      expect(friendly.ownedChannels, contains(PetMotionChannel.bodyTilt));
      expect(friendly.ownedChannels, contains(PetMotionChannel.scale));
      expect(friendly.ownedChannels, contains(PetMotionChannel.dy));
    });

    test('sleep reacts least, idle reacts most', () {
      double amplitudeOf(PetInteractionSpec spec) =>
          (spec.tapScalePeak - 1.0).abs() +
          spec.tapDyPeak.abs() +
          spec.tapBodyTiltDegrees.abs() +
          spec.tapEarTiltDegrees.abs() +
          spec.tapTailTiltDegrees.abs() +
          spec.tapHeadTiltDegrees.abs();

      final sleep =
          amplitudeOf(PetInteractionSpec.table[PetVisualState.sleep]!);
      for (final entry in PetInteractionSpec.table.entries) {
        if (entry.key == PetVisualState.sleep) continue;
        expect(amplitudeOf(entry.value), greaterThan(sleep),
            reason: '${entry.key} reacts less than a sleeping Mochi');
      }
    });

    test('the heart is offered only where the user is not mid-task', () {
      expect(PetInteractionSpec.table[PetVisualState.idle]!.strokeShowsHeart,
          isTrue);
      expect(PetInteractionSpec.table[PetVisualState.pause]!.strokeShowsHeart,
          isTrue);
      for (final state in const [
        PetVisualState.focus,
        PetVisualState.craft,
        PetVisualState.sleep,
      ]) {
        expect(PetInteractionSpec.table[state]!.strokeShowsHeart, isFalse,
            reason: 'a heart over $state pulls attention away from the work');
      }
    });

    test('idle keeps the amplitudes it had before STAGE 4', () {
      // The idle response is the one that already shipped. Moving the numbers
      // into a per-state table must not have changed what idle looks like.
      final idle = PetInteractionSpec.table[PetVisualState.idle]!;
      expect(idle.tapDuration, PetMotionSpec.interactDuration);
      expect(idle.tapDyPeak, PetMotionSpec.interactBounceDyMax);
      expect(idle.tapScalePeak, PetMotionSpec.interactScaleMax);
      expect(idle.tapBodyTiltDegrees, PetMotionSpec.interactTiltDeg);
      expect(idle.tapEarTiltDegrees, PetMotionSpec.interactEarTiltDeg);
      expect(idle.tapTailTiltDegrees, PetMotionSpec.interactTailTiltDeg);
      expect(idle.tapEyeSquintMin, PetMotionSpec.interactEyeSquintMin);
    });
  });

  group('the controller answers in every base state', () {
    for (final state in const [
      PetVisualState.idle,
      PetVisualState.focus,
      PetVisualState.pause,
      PetVisualState.sleep,
      PetVisualState.craft,
    ]) {
      test('$state accepts a tap and keeps its state', () {
        var calls = 0;
        final controller = PetMotionController(visualState: state);
        controller.attach(onTriggerInteract: () => calls++);

        expect(controller.triggerInteract(), isTrue);
        expect(calls, 1);
        // The critical constraint, at the controller level: the tap is an
        // overlay, so the base state survives it. `interact` is never assigned
        // and a focus tap never bounces to idle.
        expect(controller.visualState, state);
        // Not vacuous for the idle row either: it pins that a tap in any state
        // lands in that same state and no other.
        expect(controller.isIdle, state == PetVisualState.idle);
        controller.dispose();
      });
    }

    test('a one-shot celebration refuses the tap', () {
      var calls = 0;
      final controller =
          PetMotionController(visualState: PetVisualState.celebrate);
      controller.attach(onTriggerInteract: () => calls++);

      expect(controller.triggerInteract(), isFalse);
      expect(calls, 0);
      controller.dispose();
    });

    test('the tap and the stroke have independent cooldowns', () {
      final controller = PetMotionController();
      controller.attach(onTriggerInteract: () {}, onTriggerStroke: () {});

      expect(controller.triggerInteract(), isTrue);
      expect(controller.isInteractCooldownActive, isTrue);
      // A stroke right after a tap must still land: they are different
      // gestures, and sharing one cooldown would swallow the second.
      expect(controller.triggerStroke(), isTrue);
      expect(controller.isStrokeCooldownActive, isTrue);

      // Each is separately rate-limited.
      expect(controller.triggerInteract(), isFalse);
      expect(controller.triggerStroke(), isFalse);
      controller.dispose();
    });

    test('detach clears both cooldowns', () {
      final controller = PetMotionController();
      controller.attach(onTriggerInteract: () {}, onTriggerStroke: () {});
      controller.triggerInteract();
      controller.triggerStroke();

      controller.detach();
      expect(controller.isInteractCooldownActive, isFalse);
      expect(controller.isStrokeCooldownActive, isFalse);
      expect(controller.hasInteractCallback, isFalse);
      expect(controller.hasStrokeCallback, isFalse);
      controller.dispose();
    });
  });

  group('the behaviour reaches the render tree', () {
    testWidgets('the interaction kind follows the base state', (tester) async {
      const expected = {
        PetVisualState.idle: PetInteractionKind.friendly,
        PetVisualState.focus: PetInteractionKind.glance,
        PetVisualState.pause: PetInteractionKind.soothe,
        PetVisualState.craft: PetInteractionKind.react,
        PetVisualState.sleep: PetInteractionKind.drowsy,
      };

      for (final entry in expected.entries) {
        final controller = PetMotionController(visualState: entry.key);
        final state = await pumpPet(tester, controller, entry.key);
        expect(state.interactionKind, entry.value,
            reason: '${entry.key} resolved to the wrong behaviour');
        controller.dispose();
      }
    });

    testWidgets('a celebration has no behaviour at all', (tester) async {
      final controller =
          PetMotionController(visualState: PetVisualState.celebrate);
      final state = await pumpPet(tester, controller, PetVisualState.celebrate);
      expect(state.interactionKind, isNull);
      controller.dispose();
    });

    testWidgets('a focus glance moves the eyes but never the body',
        (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.focus);
      final state = await pumpPet(tester, controller, PetVisualState.focus);

      final glance = PetInteractionSpec.table[PetVisualState.focus]!;
      expect(controller.triggerInteract(), isTrue);
      await tester.pump();
      // Sample at 40% of the response. That is inside the 30–70% hold segment,
      // so the rise shape is pinned at its peak — but deliberately *off* the
      // segment's midpoint, where the swing shape crosses zero on its way from
      // +1 to −1 (easeInOut(0.5) == 0.5, so 1 + 0.5·(−2) == 0).
      await tester.pump(glance.tapDuration * 0.4);

      expect(state.interactEyeScaleY, closeTo(glance.tapEyeSquintMin, 0.01));
      expect(state.interactEarTilt.abs(), greaterThan(0.0));
      // The body is left entirely to the focus sway.
      expect(state.interactBodyTilt, 0.0);
      expect(state.interactDy, 0.0);
      expect(state.interactScale, 1.0);
      expect(controller.visualState, PetVisualState.focus);
      controller.dispose();
    });

    testWidgets('an idle response does move the body', (tester) async {
      final controller = PetMotionController();
      final state = await pumpPet(tester, controller, PetVisualState.idle);

      expect(controller.triggerInteract(), isTrue);
      await tester.pump();
      // 40% again: the body tilt rides the swing, which is zero at the exact
      // midpoint of the hold segment. Sampling there would read 0.0 and look
      // like the body never moves.
      await tester.pump(
        PetInteractionSpec.table[PetVisualState.idle]!.tapDuration * 0.4,
      );

      expect(state.interactBodyTilt.abs(), greaterThan(0.0));
      expect(state.interactDy, lessThan(0.0));
      expect(state.interactScale, greaterThan(1.0));
      expect(controller.visualState, PetVisualState.idle);
      controller.dispose();
    });

    testWidgets('the swing is a real swing, not a one-way nudge',
        (tester) async {
      // Pins the shape contract that made two earlier assertions read 0.0:
      // the swing channel runs +1 -> -1 across the hold segment, so it passes
      // through zero at the midpoint. Sampling only the midpoint would look
      // like a dead channel; sampling either side proves it is not, and proves
      // the ear/tail really reverse rather than just settling.
      final spec = PetInteractionSpec.table[PetVisualState.idle]!;
      final controller = PetMotionController();
      final state = await pumpPet(tester, controller, PetVisualState.idle);

      expect(controller.triggerInteract(), isTrue);
      await tester.pump();
      await tester.pump(spec.tapDuration * 0.4);
      final early = state.interactEarTilt;

      // 40% -> 60% of the same response: both sides of the midpoint, so this
      // needs no restart and no second widget tree.
      await tester.pump(spec.tapDuration * 0.2);
      final late = state.interactEarTilt;

      expect(early.abs(), greaterThan(0.0));
      expect(late.abs(), greaterThan(0.0));
      expect(early.sign, isNot(late.sign),
          reason: 'the swing must reverse direction across the hold segment');
      controller.dispose();
    });

    testWidgets('the response settles back to exactly the starting state',
        (tester) async {
      for (final visualState in const [
        PetVisualState.focus,
        PetVisualState.craft,
        PetVisualState.sleep,
      ]) {
        final controller = PetMotionController(visualState: visualState);
        final state = await pumpPet(tester, controller, visualState);
        final spec = PetInteractionSpec.table[visualState]!;

        expect(controller.triggerInteract(), isTrue);
        await tester.pump();
        await tester.pump(spec.tapDuration + const Duration(milliseconds: 50));

        // Settled: no residual channel and, above all, the same base state.
        expect(state.interactController.isAnimating, isFalse);
        expect(state.interactDy, 0.0);
        expect(state.interactScale, 1.0);
        expect(state.interactBodyTilt, 0.0);
        expect(controller.visualState, visualState);
        controller.dispose();
      }
    });
  });

  group('the long-press stroke', () {
    testWidgets('a long press drives the stroke, not the tap', (tester) async {
      final controller = PetMotionController();
      final state = await pumpPet(tester, controller, PetVisualState.idle);

      await tester.longPress(find.byType(PetAvatarWidget));
      await tester.pump();

      expect(state.strokeController.isAnimating, isTrue);
      expect(state.interactController.isAnimating, isFalse);
      expect(controller.isStrokeCooldownActive, isTrue);
      expect(controller.visualState, PetVisualState.idle);
      controller.dispose();
    });

    testWidgets('the eyes soften in every state that reacts', (tester) async {
      for (final visualState in const [
        PetVisualState.idle,
        PetVisualState.focus,
        PetVisualState.pause,
        PetVisualState.craft,
        PetVisualState.sleep,
      ]) {
        final controller = PetMotionController(visualState: visualState);
        final state = await pumpPet(tester, controller, visualState);
        final spec = PetInteractionSpec.table[visualState]!;

        expect(controller.triggerStroke(), isTrue);
        await tester.pump();
        await tester.pump(spec.strokeDuration ~/ 2);

        expect(state.strokeEyeScaleY, closeTo(spec.strokeEyeClose, 0.02),
            reason: '$visualState did not soften its eyes');
        expect(state.strokeEarDroop.abs(), greaterThan(0.0),
            reason: '$visualState did not droop its ears');
        expect(controller.visualState, visualState);
        controller.dispose();
      }
    });

    testWidgets('the heart appears in idle and never during work',
        (tester) async {
      final idle = PetMotionController();
      final idleState = await pumpPet(tester, idle, PetVisualState.idle);
      expect(idle.triggerStroke(), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(idleState.isStrokeHeartVisible, isTrue);
      idle.dispose();

      final focus = PetMotionController(visualState: PetVisualState.focus);
      final focusState = await pumpPet(tester, focus, PetVisualState.focus);
      expect(focus.triggerStroke(), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(focusState.isStrokeHeartVisible, isFalse,
          reason: 'a heart over a running focus session is a distraction');
      focus.dispose();
    });

    testWidgets('a stroke releases without changing the base state',
        (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.pause);
      final state = await pumpPet(tester, controller, PetVisualState.pause);
      final spec = PetInteractionSpec.table[PetVisualState.pause]!;

      expect(controller.triggerStroke(), isTrue);
      await tester.pump();
      await tester.pump(spec.strokeDuration + const Duration(milliseconds: 50));

      expect(state.strokeController.isAnimating, isFalse);
      expect(state.strokeEyeScaleY, 1.0);
      expect(state.isStrokeHeartVisible, isFalse);
      expect(controller.visualState, PetVisualState.pause);
      controller.dispose();
    });

    testWidgets('the ear droop is signed, so a soothe droops the other way',
        (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.pause);
      final state = await pumpPet(tester, controller, PetVisualState.pause);
      final spec = PetInteractionSpec.table[PetVisualState.pause]!;
      expect(spec.strokeEarDroopDegrees, lessThan(0.0));

      expect(controller.triggerStroke(), isTrue);
      await tester.pump();
      await tester.pump(spec.strokeDuration ~/ 2);

      expect(state.strokeEarDroop,
          closeTo(spec.strokeEarDroopDegrees * math.pi / 180, 0.005));
      controller.dispose();
    });
  });

  group('the overlay is presentation-only', () {
    testWidgets('no interaction writes a business value', (tester) async {
      // The overlay has no reference to a session, a craft job or a reward, and
      // this asserts the observable consequence: after a full interaction the
      // controller reports exactly the state it was given, and nothing else
      // about it has moved.
      final controller = PetMotionController(visualState: PetVisualState.focus);
      await pumpPet(tester, controller, PetVisualState.focus);

      // Baseline taken with the tree live. The V4.1 micro-motion layer is
      // present in *every* state, so the blink / ear-twitch timers are already
      // running here — they are not something an interaction introduces.
      final before = controller.visualState;
      final timerCountBefore = controller.activeTimerCount;
      expect(timerCountBefore, 2,
          reason: 'the fixed micro-motion layer is exactly two ambient timers');

      controller.triggerInteract();
      controller.triggerStroke();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      expect(controller.visualState, before);
      // Untouched: still exactly the two ambient timers, so an interaction adds
      // no scheduler of its own. The gesture cooldowns are rate limits on the
      // gesture rather than motion scheduling, and are asserted separately.
      expect(controller.activeTimerCount, timerCountBefore);
      controller.dispose();
    });
  });
}
