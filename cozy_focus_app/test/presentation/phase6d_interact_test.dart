import 'dart:math' as math;

import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/presentation/animations/pet_idle_fallback_view.dart';
import 'package:cozy_focus_app/presentation/animations/pet_motion_spec.dart';
import 'package:cozy_focus_app/presentation/controllers/pet_motion_controller.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 6D interact controller contract', () {
    test('AT-6D-01: idle interact fires callback without changing state', () {
      var calls = 0;
      final controller = PetMotionController();
      controller.attach(onTriggerInteract: () => calls++);

      expect(controller.triggerInteract(), isTrue);
      expect(calls, 1);
      expect(controller.visualState, PetVisualState.idle);
      controller.dispose();
    });

    for (final state in const [
      PetVisualState.focus,
      PetVisualState.pause,
      PetVisualState.sleep,
      PetVisualState.craft,
      PetVisualState.celebrate,
      PetVisualState.greeting,
      PetVisualState.interact,
    ]) {
      test('AT-6D priority blocks interact while $state', () {
        var calls = 0;
        final controller = PetMotionController(visualState: state);
        controller.attach(onTriggerInteract: () => calls++);

        expect(controller.triggerInteract(), isFalse);
        expect(calls, 0);
        controller.dispose();
      });
    }

    testWidgets('AT-6D-08/09: cooldown blocks retap then allows it',
        (tester) async {
      var calls = 0;
      final controller = PetMotionController();
      controller.attach(onTriggerInteract: () => calls++);

      expect(controller.triggerInteract(), isTrue);
      expect(controller.triggerInteract(), isFalse);
      expect(calls, 1);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(controller.triggerInteract(), isTrue);
      expect(calls, 2);
      controller.dispose();
    });

    test('AT-6D-10: disposed controller rejects interact safely', () {
      final controller = PetMotionController();
      controller.dispose();

      expect(controller.triggerInteract(), isFalse);
    });

    test('AT-6D-15: attach remains backward compatible', () {
      var blinkCalls = 0;
      final controller = PetMotionController();
      controller.attach(onTriggerBlink: () => blinkCalls++);

      expect(controller.hasBlinkCallback, isTrue);
      expect(controller.hasInteractCallback, isFalse);
      expect(controller.triggerInteract(), isTrue);
      expect(blinkCalls, 0);
      controller.dispose();
    });

    testWidgets('detach cancels an active interact cooldown', (tester) async {
      final controller = PetMotionController();
      controller.attach();
      expect(controller.triggerInteract(), isTrue);
      expect(controller.isInteractCooldownActive, isTrue);

      controller.detach();
      expect(controller.isInteractCooldownActive, isFalse);
      controller.dispose();
    });
  });

  group('Phase 6D interact fallback view', () {
    testWidgets('AT-6D-11: tap plays then resets the 750ms interact motion',
        (tester) async {
      final controller = PetMotionController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(
              visualState: PetVisualState.idle,
              controller: controller,
            ),
          ),
        ),
      );

      final state = tester.state<PetIdleFallbackViewState>(
        find.byType(PetIdleFallbackView),
      );
      expect(find.byType(GestureDetector), findsOneWidget);
      await tester.tap(find.byType(PetAvatarWidget));
      await tester.pump();
      expect(state.interactController.isAnimating, isTrue);
      expect(controller.visualState, PetVisualState.idle);

      await tester.pump(const Duration(milliseconds: 751));
      await tester.pump();
      expect(state.interactController.value, 0.0);
      expect(state.interactController.isAnimating, isFalse);
      controller.dispose();
    });

    testWidgets(
        'interact channels preserve 30/40/30 keyframes at 225ms and 525ms',
        (tester) async {
      final controller = PetMotionController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(
              visualState: PetVisualState.idle,
              controller: controller,
            ),
          ),
        ),
      );

      final state = tester.state<PetIdleFallbackViewState>(
        find.byType(PetIdleFallbackView),
      );

      await tester.tap(find.byType(PetAvatarWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 225));

      expect(
        state.interactDy,
        closeTo(PetMotionSpec.interactBounceDyMax, 0.001),
      );
      expect(
        state.interactScale,
        closeTo(PetMotionSpec.interactScaleMax, 0.001),
      );
      expect(
        state.interactBodyTilt,
        closeTo(PetMotionSpec.interactTiltDeg * math.pi / 180, 0.001),
      );
      expect(
        state.interactEarTilt,
        closeTo(PetMotionSpec.interactEarTiltDeg * math.pi / 180, 0.001),
      );
      expect(
        state.interactTailTilt,
        closeTo(PetMotionSpec.interactTailTiltDeg * math.pi / 180, 0.001),
      );
      expect(
        state.interactEyeScaleY,
        closeTo(PetMotionSpec.interactEyeSquintMin, 0.001),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(
        state.interactDy,
        closeTo(PetMotionSpec.interactBounceDyMax, 0.001),
      );
      expect(
        state.interactScale,
        closeTo(PetMotionSpec.interactScaleMax, 0.001),
      );
      expect(
        state.interactBodyTilt,
        closeTo(-PetMotionSpec.interactTiltDeg * math.pi / 180, 0.001),
      );
      expect(
        state.interactEarTilt,
        closeTo(-PetMotionSpec.interactEarTiltDeg * math.pi / 180, 0.001),
      );
      expect(
        state.interactTailTilt,
        closeTo(-PetMotionSpec.interactTailTiltDeg * math.pi / 180, 0.001),
      );
      expect(
        state.interactEyeScaleY,
        closeTo(PetMotionSpec.interactEyeSquintMin, 0.001),
      );

      controller.dispose();
    });

    testWidgets('AT-6D-12: unmount disposes the interact controller',
        (tester) async {
      final controller = PetMotionController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(
              visualState: PetVisualState.idle,
              controller: controller,
            ),
          ),
        ),
      );
      final state = tester.state<PetIdleFallbackViewState>(
        find.byType(PetIdleFallbackView),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      expect(() => state.interactController.forward(), throwsAssertionError);
      controller.dispose();
    });

    testWidgets('AT-6D-14: reduced motion uses the 80ms static flash',
        (tester) async {
      final controller = PetMotionController();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: PetAvatarWidget(
                visualState: PetVisualState.idle,
                controller: controller,
              ),
            ),
          ),
        ),
      );
      final state = tester.state<PetIdleFallbackViewState>(
        find.byType(PetIdleFallbackView),
      );

      await tester.tap(find.byType(PetAvatarWidget));
      await tester.pump();
      expect(state.interactController.isAnimating, isFalse);
      expect(state.isInteractFlashActive, isTrue);

      await tester.pump(const Duration(milliseconds: 80));
      expect(state.isInteractFlashActive, isFalse);
      controller.dispose();
    });

    testWidgets('gesture detector is absent without an injected controller',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(visualState: PetVisualState.idle),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsNothing);
    });
  });
}
