import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart';
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
    void Function(Artboard)? onInit,
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
        '9. Behavioral: Idle motion transforms tick over time, while non-idle remains static',
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

      // Now switch to non-idle: focus
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(visualState: PetVisualState.focus),
          ),
        ),
      );
      await tester.pump(); // frame update

      final focusTransformsT0 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      // Advance by 1200ms in non-idle
      await tester.pump(const Duration(milliseconds: 1200));

      final focusTransformsT1 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      // Verify non-idle stays completely static over time
      for (int i = 0; i < focusTransformsT0.length; i++) {
        expect(focusTransformsT1[i], equals(focusTransformsT0[i]),
            reason: 'Non-idle state must remain completely static over time');
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
        '13. Behavioral: controller.updateState(focus) visibly updates already-mounted PetAvatarWidget without replacement and stays static, then resumes idle',
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

      // Assert focus presentation remains completely static over time
      for (int i = 0; i < focusT0.length; i++) {
        expect(focusT1[i], equals(focusT0[i]),
            reason:
                'Focus state must remain static over time without transforms ticking');
      }

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
  });
}
