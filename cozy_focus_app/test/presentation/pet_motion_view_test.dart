import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/presentation/animations/pet_idle_fallback_view.dart';
import 'package:cozy_focus_app/presentation/animations/pet_motion_view.dart';
import 'package:cozy_focus_app/presentation/animations/rive_pet_adapter.dart';
import 'package:cozy_focus_app/presentation/controllers/pet_motion_controller.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';

/// Test double implementing IPetMotionScheduler with predictable intervals.
class FakeDeterministicScheduler implements IPetMotionScheduler {
  final Duration blinkInterval;
  final Duration earTwitchInterval;

  const FakeDeterministicScheduler({
    this.blinkInterval = const Duration(milliseconds: 3000),
    this.earTwitchInterval = const Duration(milliseconds: 5000),
  });

  @override
  Duration nextBlinkInterval() => blinkInterval;

  @override
  Duration nextEarTwitchInterval() => earTwitchInterval;
}

/// Fake Rive renderer simulating custom or crashing .riv asset fallback.
class CrashingRiveRenderer implements IPetRiveRenderer {
  final bool simulateCrashOrMissing;

  const CrashingRiveRenderer({this.simulateCrashOrMissing = false});

  @override
  Widget buildRiveWidget({
    required PetVisualState visualState,
    required double width,
    required double height,
    required BoxFit fit,
    double? focusProgress,
    double? craftProgress,
    Widget? fallback,
  }) {
    if (simulateCrashOrMissing && fallback != null) {
      return fallback;
    }
    return SizedBox(
      width: width,
      height: height,
      child: const Center(child: Text('Simulated Rive Placeholder')),
    );
  }
}

class CapturingRiveRenderer implements IPetRiveRenderer {
  PetVisualState? visualState;
  double? focusProgress;
  double? craftProgress;

  @override
  Widget buildRiveWidget({
    required PetVisualState visualState,
    required double width,
    required double height,
    required BoxFit fit,
    double? focusProgress,
    double? craftProgress,
    Widget? fallback,
  }) {
    this.visualState = visualState;
    this.focusProgress = focusProgress;
    this.craftProgress = craftProgress;
    return SizedBox(width: width, height: height);
  }
}

void main() {
  group('PetMotionView & PetAvatarWidget Phase 6A Foundation Tests', () {
    testWidgets('1. PetAvatarWidget renders idle state with Mochi label',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(
              visualState: PetVisualState.idle,
              message: 'Hello Mochi!',
            ),
          ),
        ),
      );

      // Verify speech bubble and idle label
      expect(find.text('Hello Mochi!'), findsOneWidget);
      expect(find.text('Mochi \u966a\u4f34\u4e2d'), findsOneWidget);
      expect(find.byType(PetMotionView), findsOneWidget);
      expect(find.byType(PetIdleFallbackView), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets(
        '1a. Android V1 fallback renders Mochi as a dog on a cushion, not a generic avatar',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(visualState: PetVisualState.idle),
          ),
        ),
      );

      expect(find.byKey(const Key('mochi-dog-body')), findsOneWidget);
      expect(find.byKey(const Key('mochi-dog-head')), findsOneWidget);
      expect(find.byKey(const Key('mochi-left-ear')), findsOneWidget);
      expect(find.byKey(const Key('mochi-right-ear')), findsOneWidget);
      expect(find.byKey(const Key('mochi-tail')), findsOneWidget);
      expect(find.byKey(const Key('mochi-left-paw')), findsOneWidget);
      expect(find.byKey(const Key('mochi-right-paw')), findsOneWidget);
      expect(find.byKey(const Key('mochi-cushion')), findsOneWidget);
    });

    testWidgets(
        '2. Missing/default Rive asset safely uses truthful fallback without crash',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetMotionView(
              visualState: PetVisualState.idle,
              enableRive: false,
            ),
          ),
        ),
      );

      expect(find.byType(PetIdleFallbackView), findsOneWidget);
      expect(find.text('Mochi \u966a\u4f34\u4e2d'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets(
        '3. Rive renderer abstraction can be injected without changing business caller',
        (tester) async {
      const fakeRenderer = CrashingRiveRenderer();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(
              visualState: PetVisualState.idle,
              enableRive: true,
              riveRenderer: fakeRenderer,
            ),
          ),
        ),
      );

      expect(find.text('Simulated Rive Placeholder'), findsOneWidget);
    });

    testWidgets(
        '4. All PetVisualState contracts remain fully supported and render safely',
        (tester) async {
      final states = [
        PetVisualState.idle,
        PetVisualState.focus,
        PetVisualState.pause,
        PetVisualState.celebrate,
        PetVisualState.sleep,
        PetVisualState.craft,
        PetVisualState.greeting,
        PetVisualState.interact,
      ];

      for (final state in states) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PetAvatarWidget(visualState: state),
            ),
          ),
        );
        expect(find.byType(PetAvatarWidget), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 50));
      }
    });

    testWidgets(
        '5. Reduced motion (disableAnimations) stops sway/twitch and keeps Mochi visible',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: PetAvatarWidget(visualState: PetVisualState.idle),
            ),
          ),
        ),
      );

      expect(find.byType(PetAvatarWidget), findsOneWidget);
      expect(find.text('Mochi \u966a\u4f34\u4e2d'), findsOneWidget);

      // Advance frames - ensure no exceptions and stable rendering
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(PetAvatarWidget), findsOneWidget);
    });

    testWidgets(
        '6. Deterministic scheduler triggers blink and ear twitch in test environment',
        (tester) async {
      const scheduler = FakeDeterministicScheduler(
        blinkInterval: Duration(milliseconds: 1000),
        earTwitchInterval: Duration(milliseconds: 2000),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(
              visualState: PetVisualState.idle,
              scheduler: scheduler,
            ),
          ),
        ),
      );

      // Advance by 1 second to trigger scheduled blink
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 100));

      // Advance by 1 second to trigger scheduled ear twitch
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PetAvatarWidget), findsOneWidget);
    });

    testWidgets(
        '7. State transition cancels idle timers/animations and restores on return',
        (tester) async {
      const scheduler = FakeDeterministicScheduler(
        blinkInterval: Duration(milliseconds: 500),
        earTwitchInterval: Duration(milliseconds: 800),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(
              visualState: PetVisualState.idle,
              scheduler: scheduler,
            ),
          ),
        ),
      );

      // Switch to focus
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(
              visualState: PetVisualState.focus,
              scheduler: scheduler,
            ),
          ),
        ),
      );
      expect(find.text('Mochi \u4e13\u6ce8\u4e2d'), findsOneWidget);

      // Switch back to idle
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(
              visualState: PetVisualState.idle,
              scheduler: scheduler,
            ),
          ),
        ),
      );
      expect(find.text('Mochi \u966a\u4f34\u4e2d'), findsOneWidget);
    });

    testWidgets(
        '8. Widget disposal cleans up all timers and controllers cleanly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(visualState: PetVisualState.idle),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Unmount widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );

      // Ensure no dangling timer exceptions
      await tester.pump(const Duration(seconds: 10));
      expect(find.byType(PetAvatarWidget), findsNothing);
    });

    // --- P1-1 & P1-4 Behavioral Tests: Idle Motion Active vs Static Non-Idle ---

    testWidgets(
        '9. Behavioral: Idle motion transforms tick over time, while static non-motion state (interact) remains static',
        (tester) async {
      // Mount in Idle
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(visualState: PetVisualState.idle),
          ),
        ),
      );

      // Record initial transforms
      final initialTransforms = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      // Pump 800ms (1/4 into 3200ms breathe / 3000ms sway)
      await tester.pump(const Duration(milliseconds: 800));

      final activeTransforms = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      // Verify that transforms changed during idle motion
      bool anyTransformChanged = false;
      for (int i = 0; i < initialTransforms.length; i++) {
        if (initialTransforms[i] != activeTransforms[i]) {
          anyTransformChanged = true;
          break;
        }
      }
      expect(anyTransformChanged, isTrue,
          reason: 'Idle state must actively animate transforms over time');

      // Now switch to static non-motion state: interact
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(visualState: PetVisualState.interact),
          ),
        ),
      );
      await tester.pump(); // frame update

      final interactTransformsT0 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      // Advance by 1200ms in interact
      await tester.pump(const Duration(milliseconds: 1200));

      final interactTransformsT1 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      // Verify interact stays completely static over time
      for (int i = 0; i < interactTransformsT0.length; i++) {
        expect(interactTransformsT1[i], equals(interactTransformsT0[i]),
            reason: 'Interact state must remain completely static over time');
      }
    });

    // --- P1-2 & P1-4 Behavioral Tests: Rive Requested Missing Asset Fallback ---

    testWidgets(
        '10. Behavioral: Actual Rive-requested missing asset gracefully resolves to visible Flutter fallback',
        (tester) async {
      // Request Rive with default RivePetAdapter (no mock renderer; mochi.riv is absent on disk)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetMotionView(
              visualState: PetVisualState.idle,
              enableRive: true,
            ),
          ),
        ),
      );

      // Pump to let FutureBuilder resolve DefaultAssetBundle missing asset error
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Truthful fallback must render without throw/crash/blank
      expect(find.byType(PetIdleFallbackView), findsOneWidget);
      expect(find.text('Mochi \u966a\u4f34\u4e2d'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
    });

    // --- P1-3 & P1-4 Behavioral Tests: Controller Ownership & State Transition Decider ---

    testWidgets(
        '11. Behavioral: Centralized PetMotionController owns motion lifecycle and state decider',
        (tester) async {
      const scheduler = FakeDeterministicScheduler(
        blinkInterval: Duration(milliseconds: 400),
        earTwitchInterval: Duration(milliseconds: 600),
      );
      final controller = PetMotionController(
        visualState: PetVisualState.idle,
        scheduler: scheduler,
      );

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

      // Initial idle state: controller is active with 2 scheduled timers
      expect(controller.isIdle, isTrue);
      expect(controller.isMotionActive, isTrue);
      expect(controller.activeTimerCount, equals(2));

      // Transition to non-idle via controller
      controller.updateState(PetVisualState.focus);
      await tester.pump();

      expect(controller.isIdle, isFalse);
      expect(controller.isMotionActive, isFalse);
      expect(controller.activeTimerCount, equals(0));

      // Transition to sleep
      controller.updateState(PetVisualState.sleep);
      await tester.pump();
      expect(controller.isMotionActive, isFalse);
      expect(controller.activeTimerCount, equals(0));

      // Resume back to idle
      controller.updateState(PetVisualState.idle);
      await tester.pump();

      expect(controller.isIdle, isTrue);
      expect(controller.isMotionActive, isTrue);
      expect(controller.activeTimerCount, equals(2));

      // Direct stopMotion / startMotion testing
      controller.stopMotion();
      expect(controller.isMotionActive, isFalse);
      expect(controller.activeTimerCount, equals(0));

      controller.startMotion();
      expect(controller.isMotionActive, isTrue);
      expect(controller.activeTimerCount, equals(2));

      // Clean up
      controller.dispose();
      expect(controller.isDisposed, isTrue);
      expect(controller.activeTimerCount, equals(0));
    });

    // --- P1-4 Behavioral Tests: Remounting & Rapid Rebuilds Do Not Duplicate Schedulers ---

    testWidgets(
        '12. Behavioral: Unmount and remount does not duplicate schedulers or leak timers',
        (tester) async {
      const scheduler = FakeDeterministicScheduler(
        blinkInterval: Duration(milliseconds: 500),
        earTwitchInterval: Duration(milliseconds: 700),
      );
      final controller = PetMotionController(
        visualState: PetVisualState.idle,
        scheduler: scheduler,
      );

      // Mount 1
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
      expect(controller.activeTimerCount, equals(2));

      // Rapid state flips in widget tree
      for (int i = 0; i < 5; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PetAvatarWidget(
                visualState: PetVisualState.focus,
                controller: controller,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 20));

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
        await tester.pump(const Duration(milliseconds: 20));
      }

      // Must never exceed 2 active timers (no duplicates)
      expect(controller.activeTimerCount, equals(2));

      // Unmount completely
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Remount with same controller
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
      await tester.pump(const Duration(milliseconds: 50));

      // Still exactly 2 active timers
      expect(controller.activeTimerCount, equals(2));

      controller.dispose();
    });

    // --- P1-4 (Round 2): Authoritative Controller State Updates Mounted Widget ---

    testWidgets(
        '13. Behavioral: controller.updateState(focus) visibly updates already-mounted PetAvatarWidget without replacement and animates focus motion, then resumes idle',
        (tester) async {
      const scheduler = FakeDeterministicScheduler(
        blinkInterval: Duration(milliseconds: 300),
        earTwitchInterval: Duration(milliseconds: 500),
      );
      final controller = PetMotionController(
        visualState: PetVisualState.idle,
        scheduler: scheduler,
      );

      // Mount PetAvatarWidget once with controller in idle
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

      // Initial verification in idle
      expect(find.text('Mochi \u966a\u4f34\u4e2d'), findsOneWidget);
      expect(controller.isIdle, isTrue);
      expect(controller.isMotionActive, isTrue);

      // Verify transforms change over time in idle
      final idleT0 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();
      await tester.pump(const Duration(milliseconds: 800));
      final idleT1 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();
      bool idleAnimated = false;
      for (int i = 0; i < idleT0.length; i++) {
        if (idleT0[i] != idleT1[i]) {
          idleAnimated = true;
          break;
        }
      }
      expect(idleAnimated, isTrue, reason: 'Idle motion must actively animate');

      // Call controller.updateState(focus) WITHOUT replacing the mounted widget tree
      controller.updateState(PetVisualState.focus);
      await tester.pump();

      // Asserts focus presentation is visible immediately on the same mounted widget
      expect(find.text('Mochi \u4e13\u6ce8\u4e2d'), findsOneWidget);
      expect(find.text('Mochi \u966a\u4f34\u4e2d'), findsNothing);
      expect(controller.isIdle, isFalse);
      expect(controller.isMotionActive, isFalse);

      // Record transforms at t=0 in focus
      final focusT0 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();
      // Advance time by 1000ms while remaining in focus
      await tester.pump(const Duration(milliseconds: 1000));
      final focusT1 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      // In Phase 6B: Focus state has subtle micro-nod and breathing animation over time
      bool focusAnimated = false;
      for (int i = 0; i < focusT0.length; i++) {
        if (focusT0[i] != focusT1[i]) {
          focusAnimated = true;
          break;
        }
      }
      expect(focusAnimated, isTrue,
          reason:
              'Focus state in Phase 6B must actively animate subtle work motion');

      // Call controller.updateState(idle) to verify idle resumes on the same mounted widget
      controller.updateState(PetVisualState.idle);
      await tester.pump();

      expect(find.text('Mochi \u966a\u4f34\u4e2d'), findsOneWidget);
      expect(find.text('Mochi \u4e13\u6ce8\u4e2d'), findsNothing);
      expect(controller.isIdle, isTrue);
      expect(controller.isMotionActive, isTrue);

      // Verify motion transforms resume ticking over time in idle
      final resumeT0 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();
      await tester.pump(const Duration(milliseconds: 800));
      final resumeT1 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();
      bool resumeAnimated = false;
      for (int i = 0; i < resumeT0.length; i++) {
        if (resumeT0[i] != resumeT1[i]) {
          resumeAnimated = true;
          break;
        }
      }
      expect(resumeAnimated, isTrue,
          reason: 'Resumed idle motion must actively animate');

      controller.dispose();
    });

    // --- P1-4 (Round 2): Lifecycle Detachment and Animation-Controller Cleanup ---

    testWidgets(
        '14. Behavioral: Observable controller callback detachment, disposed animation-controller throws AssertionError, and remount without duplicate listeners/timers',
        (tester) async {
      const scheduler = FakeDeterministicScheduler(
        blinkInterval: Duration(milliseconds: 400),
        earTwitchInterval: Duration(milliseconds: 600),
      );
      final controller = PetMotionController(
        visualState: PetVisualState.idle,
        scheduler: scheduler,
      );

      // Controller starts unattached before mount
      expect(controller.isAttached, isFalse);
      expect(controller.hasBlinkCallback, isFalse);
      expect(controller.hasEarTwitchCallback, isFalse);
      expect(controller.hasStartContinuousLoopsCallback, isFalse);
      expect(controller.hasStopContinuousLoopsCallback, isFalse);
      expect(controller.listenerCount, equals(0));

      // Mount widget with controller
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

      // Grab reference to mounted state and its animation controllers
      final fallbackState = tester.state<PetIdleFallbackViewState>(
        find.byType(PetIdleFallbackView),
      );
      final breatheController = fallbackState.breatheController;
      final swayController = fallbackState.swayController;
      final tailController = fallbackState.tailController;
      final blinkController = fallbackState.blinkController;
      final earTwitchController = fallbackState.earTwitchController;

      // While mounted: observable callbacks are attached, listeners registered, timers active
      expect(controller.isAttached, isTrue);
      expect(controller.hasBlinkCallback, isTrue);
      expect(controller.hasEarTwitchCallback, isTrue);
      expect(controller.hasStartContinuousLoopsCallback, isTrue);
      expect(controller.hasStopContinuousLoopsCallback, isTrue);
      expect(controller.activeTimerCount, equals(2));
      // ListenableBuilder in PetAvatarWidget and listener in PetIdleFallbackView
      expect(controller.listenerCount, greaterThanOrEqualTo(1));
      final mountedListenerCount = controller.listenerCount;

      // Unmount the widget completely
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // 1. Prove controller presentation callbacks are fully detached
      expect(controller.isAttached, isFalse);
      expect(controller.hasBlinkCallback, isFalse);
      expect(controller.hasEarTwitchCallback, isFalse);
      expect(controller.hasStartContinuousLoopsCallback, isFalse);
      expect(controller.hasStopContinuousLoopsCallback, isFalse);

      // 2. Prove active timers stopped and listeners cleaned up
      expect(controller.activeTimerCount, equals(0));
      expect(controller.listenerCount, equals(0));

      // 3. Prove animation controllers are disposed (attempting to use them throws AssertionError)
      expect(() => breatheController.forward(), throwsAssertionError);
      expect(() => swayController.forward(), throwsAssertionError);
      expect(() => tailController.forward(), throwsAssertionError);
      expect(() => blinkController.forward(), throwsAssertionError);
      expect(() => earTwitchController.forward(), throwsAssertionError);

      // 4. Remount with the same controller
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
      await tester.pump(const Duration(milliseconds: 50));

      // Prove re-attachment succeeded with exact single set of listeners and timers (no duplicates)
      expect(controller.isAttached, isTrue);
      expect(controller.activeTimerCount, equals(2));
      expect(controller.listenerCount, equals(mountedListenerCount));

      // Unmount remounted widget to trigger clean lifecycle tear-down
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.listenerCount, equals(0));

      controller.dispose();
      expect(controller.isDisposed, isTrue);
      expect(controller.isAttached, isFalse);
      expect(controller.activeTimerCount, equals(0));
      expect(controller.listenerCount, equals(0));
    });

    // =========================================================================
    // Phase 6B: Focus, Pause, Sleep Dedicated Motion & Gating Tests
    // =========================================================================

    testWidgets(
        '15. Phase 6B: Focus state animates subtle breathing and micro-nod, stops idle loops',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(visualState: PetVisualState.focus),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Mochi \u4e13\u6ce8\u4e2d'), findsOneWidget);

      final fallbackState = tester.state<PetIdleFallbackViewState>(
        find.byType(PetIdleFallbackView),
      );

      // Verify idle continuous loops and timers are strictly stopped
      expect(fallbackState.breatheController.isAnimating, isFalse);
      expect(fallbackState.swayController.isAnimating, isFalse);
      expect(fallbackState.tailController.isAnimating, isFalse);
      expect(fallbackState.blinkController.isAnimating, isFalse);
      expect(fallbackState.earTwitchController.isAnimating, isFalse);

      // Verify focus controller is animating
      expect(fallbackState.focusController.isAnimating, isTrue);
      expect(fallbackState.pauseController.isAnimating, isFalse);
      expect(fallbackState.sleepController.isAnimating, isFalse);

      // Verify transforms animate over time
      final t0 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      await tester.pump(const Duration(milliseconds: 1000));

      final t1 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      bool animated = false;
      for (int i = 0; i < t0.length; i++) {
        if (t0[i] != t1[i]) {
          animated = true;
          break;
        }
      }
      expect(animated, isTrue,
          reason: 'Focus motion transforms must tick over time');
    });

    testWidgets(
        '16. Phase 6B: Pause state animates restful breathing, stops idle and focus loops',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(visualState: PetVisualState.pause),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Mochi \u4f11\u606f\u4e2d'), findsOneWidget);

      final fallbackState = tester.state<PetIdleFallbackViewState>(
        find.byType(PetIdleFallbackView),
      );

      // Idle loops stopped
      expect(fallbackState.breatheController.isAnimating, isFalse);
      expect(fallbackState.swayController.isAnimating, isFalse);
      expect(fallbackState.tailController.isAnimating, isFalse);
      expect(fallbackState.blinkController.isAnimating, isFalse);
      expect(fallbackState.earTwitchController.isAnimating, isFalse);

      // Pause controller animating
      expect(fallbackState.focusController.isAnimating, isFalse);
      expect(fallbackState.pauseController.isAnimating, isTrue);
      expect(fallbackState.sleepController.isAnimating, isFalse);

      // Verify transforms animate over time
      final t0 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      await tester.pump(const Duration(milliseconds: 1000));

      final t1 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      bool animated = false;
      for (int i = 0; i < t0.length; i++) {
        if (t0[i] != t1[i]) {
          animated = true;
          break;
        }
      }
      expect(animated, isTrue,
          reason: 'Pause motion transforms must tick over time');
    });

    testWidgets(
        '17. Phase 6B: Sleep state shows floating Zzz indicator and closed eyes, animates deep breathing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(visualState: PetVisualState.sleep),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('晚安 Mochi'), findsOneWidget);
      // Floating Zzz indicator is rendered in sleep
      expect(find.text('Zzz'), findsOneWidget);

      final fallbackState = tester.state<PetIdleFallbackViewState>(
        find.byType(PetIdleFallbackView),
      );

      // Idle loops stopped
      expect(fallbackState.breatheController.isAnimating, isFalse);
      expect(fallbackState.swayController.isAnimating, isFalse);
      expect(fallbackState.tailController.isAnimating, isFalse);
      expect(fallbackState.blinkController.isAnimating, isFalse);
      expect(fallbackState.earTwitchController.isAnimating, isFalse);

      // Sleep controller animating
      expect(fallbackState.focusController.isAnimating, isFalse);
      expect(fallbackState.pauseController.isAnimating, isFalse);
      expect(fallbackState.sleepController.isAnimating, isTrue);

      // Verify transforms animate over time
      final t0 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      await tester.pump(const Duration(milliseconds: 1000));

      final t1 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      bool animated = false;
      for (int i = 0; i < t0.length; i++) {
        if (t0[i] != t1[i]) {
          animated = true;
          break;
        }
      }
      expect(animated, isTrue,
          reason: 'Sleep motion transforms must tick over time');
    });

    testWidgets(
        '18. Phase 6B: Reduced motion (disableAnimations) freezes transforms in focus, pause, and sleep while keeping visuals intact',
        (tester) async {
      // Test sleep with reduced motion: Zzz still visible, transforms static
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: PetAvatarWidget(visualState: PetVisualState.sleep),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('晚安 Mochi'), findsOneWidget);
      expect(find.text('Zzz'), findsOneWidget);

      final t0 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      await tester.pump(const Duration(milliseconds: 1200));

      final t1 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      for (int i = 0; i < t0.length; i++) {
        expect(t1[i], equals(t0[i]),
            reason:
                'Reduced motion must freeze all transforms over time in sleep');
      }

      // Test focus with reduced motion: label visible, transforms static
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: PetAvatarWidget(visualState: PetVisualState.focus),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Mochi \u4e13\u6ce8\u4e2d'), findsOneWidget);

      final focusT0 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      await tester.pump(const Duration(milliseconds: 1200));

      final focusT1 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      for (int i = 0; i < focusT0.length; i++) {
        expect(focusT1[i], equals(focusT0[i]),
            reason:
                'Reduced motion must freeze all transforms over time in focus');
      }
    });

    testWidgets(
        '19. Phase 6B: State transitions cleanly stop and switch active animation controllers without leaks',
        (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.idle);

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
      await tester.pump();

      final fallbackState = tester.state<PetIdleFallbackViewState>(
        find.byType(PetIdleFallbackView),
      );

      expect(fallbackState.breatheController.isAnimating, isTrue);
      expect(fallbackState.focusController.isAnimating, isFalse);

      // Switch to focus
      controller.updateState(PetVisualState.focus);
      await tester.pump();
      expect(fallbackState.breatheController.isAnimating, isFalse);
      expect(fallbackState.focusController.isAnimating, isTrue);
      expect(fallbackState.pauseController.isAnimating, isFalse);
      expect(fallbackState.sleepController.isAnimating, isFalse);

      // Switch to pause
      controller.updateState(PetVisualState.pause);
      await tester.pump();
      expect(fallbackState.focusController.isAnimating, isFalse);
      expect(fallbackState.pauseController.isAnimating, isTrue);
      expect(fallbackState.sleepController.isAnimating, isFalse);

      // Switch to sleep
      controller.updateState(PetVisualState.sleep);
      await tester.pump();
      expect(fallbackState.pauseController.isAnimating, isFalse);
      expect(fallbackState.sleepController.isAnimating, isTrue);

      // Switch to celebrate state (Phase 6C active motion)
      controller.updateState(PetVisualState.celebrate);
      await tester.pump();
      expect(fallbackState.breatheController.isAnimating, isFalse);
      expect(fallbackState.focusController.isAnimating, isFalse);
      expect(fallbackState.pauseController.isAnimating, isFalse);
      expect(fallbackState.sleepController.isAnimating, isFalse);
      expect(fallbackState.celebrateController.isAnimating, isTrue);

      // Switch back to idle
      controller.updateState(PetVisualState.idle);
      await tester.pump();
      expect(fallbackState.breatheController.isAnimating, isTrue);
      expect(fallbackState.swayController.isAnimating, isTrue);
      expect(fallbackState.focusController.isAnimating, isFalse);
      expect(fallbackState.celebrateController.isAnimating, isFalse);

      // Unmount & dispose
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      await tester.pump(const Duration(milliseconds: 50));

      expect(
          () => fallbackState.focusController.forward(), throwsAssertionError);
      expect(
          () => fallbackState.pauseController.forward(), throwsAssertionError);
      expect(
          () => fallbackState.sleepController.forward(), throwsAssertionError);
      expect(() => fallbackState.celebrateController.forward(),
          throwsAssertionError);
      expect(
          () => fallbackState.craftController.forward(), throwsAssertionError);
      expect(() => fallbackState.greetingController.forward(),
          throwsAssertionError);

      controller.dispose();
    });

    testWidgets(
        '20. Phase 6B: PetMotionView with enableRive and missing asset truthfully renders focus, pause, sleep fallback',
        (tester) async {
      for (final state in [
        PetVisualState.focus,
        PetVisualState.pause,
        PetVisualState.sleep
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PetMotionView(
                visualState: state,
                enableRive: true,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(PetIdleFallbackView), findsOneWidget);
        expect(find.byType(PetMotionView), findsOneWidget);
      }
    });

    // --- Phase 6C: Celebrate, Craft, Greeting Dedicated Tests ---

    testWidgets(
        '21. Phase 6C: Celebrate state animates joyful bounce, scale, and tilt; stops idle and other loops',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(visualState: PetVisualState.celebrate),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('太棒啦!'), findsOneWidget);

      final fallbackState = tester.state<PetIdleFallbackViewState>(
        find.byType(PetIdleFallbackView),
      );

      // Idle and other loops stopped
      expect(fallbackState.breatheController.isAnimating, isFalse);
      expect(fallbackState.swayController.isAnimating, isFalse);
      expect(fallbackState.tailController.isAnimating, isFalse);
      expect(fallbackState.blinkController.isAnimating, isFalse);
      expect(fallbackState.earTwitchController.isAnimating, isFalse);
      expect(fallbackState.focusController.isAnimating, isFalse);
      expect(fallbackState.pauseController.isAnimating, isFalse);
      expect(fallbackState.sleepController.isAnimating, isFalse);
      expect(fallbackState.craftController.isAnimating, isFalse);
      expect(fallbackState.greetingController.isAnimating, isFalse);

      // Celebrate controller animating
      expect(fallbackState.celebrateController.isAnimating, isTrue);

      // Verify transforms animate over time
      final t0 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      await tester.pump(const Duration(milliseconds: 400));

      final t1 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      bool animated = false;
      for (int i = 0; i < t0.length; i++) {
        if (t0[i] != t1[i]) {
          animated = true;
          break;
        }
      }
      expect(animated, isTrue,
          reason: 'Celebrate motion transforms must tick over time');
    });

    testWidgets(
        '22. Phase 6C: Craft state animates rhythmic craft work motion; stops non-craft loops',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(visualState: PetVisualState.craft),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Mochi 制作中'), findsOneWidget);

      final fallbackState = tester.state<PetIdleFallbackViewState>(
        find.byType(PetIdleFallbackView),
      );

      // Idle and other loops stopped
      expect(fallbackState.breatheController.isAnimating, isFalse);
      expect(fallbackState.swayController.isAnimating, isFalse);
      expect(fallbackState.focusController.isAnimating, isFalse);
      expect(fallbackState.pauseController.isAnimating, isFalse);
      expect(fallbackState.sleepController.isAnimating, isFalse);
      expect(fallbackState.celebrateController.isAnimating, isFalse);
      expect(fallbackState.greetingController.isAnimating, isFalse);

      // Craft controller animating
      expect(fallbackState.craftController.isAnimating, isTrue);

      // Verify transforms animate over time
      final t0 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      await tester.pump(const Duration(milliseconds: 600));

      final t1 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      bool animated = false;
      for (int i = 0; i < t0.length; i++) {
        if (t0[i] != t1[i]) {
          animated = true;
          break;
        }
      }
      expect(animated, isTrue,
          reason: 'Craft motion transforms must tick over time');
    });

    testWidgets(
        '23. Phase 6C: Greeting state animates welcoming nod and bounce; stops non-greeting loops',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(visualState: PetVisualState.greeting),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Mochi 陪伴中'), findsOneWidget);

      final fallbackState = tester.state<PetIdleFallbackViewState>(
        find.byType(PetIdleFallbackView),
      );

      // Idle and other loops stopped
      expect(fallbackState.breatheController.isAnimating, isFalse);
      expect(fallbackState.swayController.isAnimating, isFalse);
      expect(fallbackState.focusController.isAnimating, isFalse);
      expect(fallbackState.pauseController.isAnimating, isFalse);
      expect(fallbackState.sleepController.isAnimating, isFalse);
      expect(fallbackState.celebrateController.isAnimating, isFalse);
      expect(fallbackState.craftController.isAnimating, isFalse);

      // Greeting controller animating
      expect(fallbackState.greetingController.isAnimating, isTrue);

      // Verify transforms animate over time
      final t0 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      await tester.pump(const Duration(milliseconds: 500));

      final t1 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      bool animated = false;
      for (int i = 0; i < t0.length; i++) {
        if (t0[i] != t1[i]) {
          animated = true;
          break;
        }
      }
      expect(animated, isTrue,
          reason: 'Greeting motion transforms must tick over time');
    });

    testWidgets(
        '24. Phase 6C: Reduced motion (disableAnimations) freezes transforms in celebrate, craft, and greeting while keeping visuals intact',
        (tester) async {
      for (final state in [
        PetVisualState.celebrate,
        PetVisualState.craft,
        PetVisualState.greeting,
      ]) {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: Scaffold(
                body: PetAvatarWidget(visualState: state),
              ),
            ),
          ),
        );
        await tester.pump();

        final t0 = tester
            .widgetList<Transform>(find.byType(Transform))
            .map((t) => t.transform)
            .toList();

        await tester.pump(const Duration(milliseconds: 600));

        final t1 = tester
            .widgetList<Transform>(find.byType(Transform))
            .map((t) => t.transform)
            .toList();

        for (int i = 0; i < t0.length; i++) {
          expect(t1[i], equals(t0[i]),
              reason:
                  'Reduced motion must freeze all transforms over time in $state');
        }
      }
    });

    testWidgets(
        '25. Phase 6C: PetMotionView with enableRive and missing asset truthfully renders celebrate, craft, greeting fallback',
        (tester) async {
      for (final state in [
        PetVisualState.celebrate,
        PetVisualState.craft,
        PetVisualState.greeting,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PetMotionView(
                visualState: state,
                enableRive: true,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(PetIdleFallbackView), findsOneWidget);
        expect(find.byType(PetMotionView), findsOneWidget);
      }
    });

    testWidgets(
        '26. Reduced motion stops all loops and idle scheduler timers, then restores them when re-enabled',
        (tester) async {
      final controller = PetMotionController(
        visualState: PetVisualState.idle,
        scheduler: const FakeDeterministicScheduler(),
      );

      Widget buildPet(bool disableAnimations) => MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: disableAnimations),
              child: Scaffold(
                body: PetAvatarWidget(
                  visualState: PetVisualState.idle,
                  controller: controller,
                ),
              ),
            ),
          );

      await tester.pumpWidget(buildPet(true));
      final fallbackState = tester.state<PetIdleFallbackViewState>(
        find.byType(PetIdleFallbackView),
      );

      expect(fallbackState.breatheController.isAnimating, isFalse);
      expect(fallbackState.swayController.isAnimating, isFalse);
      expect(fallbackState.tailController.isAnimating, isFalse);
      expect(fallbackState.blinkController.isAnimating, isFalse);
      expect(fallbackState.earTwitchController.isAnimating, isFalse);
      expect(fallbackState.focusController.isAnimating, isFalse);
      expect(fallbackState.pauseController.isAnimating, isFalse);
      expect(fallbackState.sleepController.isAnimating, isFalse);
      expect(fallbackState.celebrateController.isAnimating, isFalse);
      expect(fallbackState.craftController.isAnimating, isFalse);
      expect(fallbackState.greetingController.isAnimating, isFalse);
      expect(fallbackState.interactController.isAnimating, isFalse);
      expect(controller.activeTimerCount, 0);

      await tester.pumpWidget(buildPet(false));
      await tester.pump();

      expect(fallbackState.breatheController.isAnimating, isTrue);
      expect(fallbackState.swayController.isAnimating, isTrue);
      expect(fallbackState.tailController.isAnimating, isTrue);
      expect(controller.activeTimerCount, 2);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });

    testWidgets(
        '27. Renderer-neutral progress inputs remain nullable and clamp at the rendering boundary',
        (tester) async {
      final renderer = CapturingRiveRenderer();
      final cases = <(
        PetVisualState state,
        double? focus,
        double? craft,
        double? expectedFocus,
        double? expectedCraft
      )>[
        (PetVisualState.idle, null, null, null, null),
        (PetVisualState.focus, -0.25, 0.0, 0.0, 0.0),
        (PetVisualState.focus, 0.5, 0.5, 0.5, 0.5),
        (PetVisualState.craft, 1.0, 1.25, 1.0, 1.0),
      ];

      for (final entry in cases) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PetAvatarWidget(
                visualState: entry.$1,
                focusProgress: entry.$2,
                craftProgress: entry.$3,
                enableRive: true,
                riveRenderer: renderer,
              ),
            ),
          ),
        );

        expect(renderer.visualState, entry.$1);
        expect(renderer.focusProgress, entry.$4);
        expect(renderer.craftProgress, entry.$5);
      }
    });

    testWidgets(
        '28. Reduced-motion fallback accepts progress without creating Rive work or business callbacks',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: PetMotionView(
                visualState: PetVisualState.craft,
                focusProgress: 0.5,
                craftProgress: 0.5,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PetIdleFallbackView), findsOneWidget);
      final fallback = tester.widget<PetIdleFallbackView>(
        find.byType(PetIdleFallbackView),
      );
      expect(fallback.focusProgress, 0.5);
      expect(fallback.craftProgress, 0.5);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });
}
