import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/presentation/animations/pet_idle_fallback_view.dart';
import 'package:cozy_focus_app/presentation/animations/pet_interaction_spec.dart';
import 'package:cozy_focus_app/presentation/animations/pet_motion_spec.dart';
import 'package:cozy_focus_app/presentation/controllers/pet_motion_controller.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';

/// What happens when the user, the system or the router does not wait politely.
///
/// The rest of the interaction suite tests one gesture at a time, on a tree that
/// is left alone. This file tests the two cases that only appear under load or
/// under interruption:
///
///  * **§40 — rapid taps.** A user who hammers Mochi gets *one* response, not a
///    queue of them, and the overlay neither stacks nor spawns schedulers.
///  * **§60 — lifecycle.** An interaction interrupted mid-flight by a Reduced
///    Motion toggle, a route push, a background/foreground cycle or a disposal
///    leaves nothing behind.
///
/// ## Why the assertions are split across two levels
///
/// `PetMotionController` is the **gate**: `triggerInteract()` decides whether a
/// gesture is allowed, and it invokes its callback on exactly the line where it
/// returns `true`. So "no duplicate callbacks" is provable at the gate, and it
/// has to be proved *there* — `PetAvatarWidget` attaches its own callbacks in
/// `initState`, overwriting anything a test attached first. An earlier version of
/// this file attached a counter and then pumped the widget, and the counter
/// stayed at zero for every burst: it was measuring a callback that the view had
/// already replaced.
///
/// Everything else — the overlay's value, its duration, the ambient scheduler
/// count — is resolved by the **view**, so those tests drive real taps through
/// `PetAvatarWidget` rather than calling the controller directly.
///
/// The leak assertions are structural. [PetMotionController.activeTimerCount]
/// must never exceed the ambient layer's two, and the final test tears the tree
/// down mid-overlay so the framework itself fails on any `Timer` still pending.
void main() {
  /// `Scaffold` + `Center`, not a bare `home:` — without a layout that gives the
  /// avatar a real box, `tester.tap` derives a point that never reaches it and
  /// every gesture assertion below passes for the wrong reason. Same shape as
  /// `companion_business_isolation_test.dart`, which is where that was learned.
  Widget app(Widget child, {bool reduceMotion = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  Widget avatar(PetMotionController controller, PetVisualState state) =>
      PetAvatarWidget(visualState: state, controller: controller);

  PetIdleFallbackViewState fallback(WidgetTester tester) =>
      tester.state(find.byType(PetIdleFallbackView));

  group('§40 the gesture gate refuses a burst', () {
    testWidgets('twenty taps in a row buy exactly one response',
        (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.idle);

      final allowed = <bool>[];
      for (var i = 0; i < 20; i++) {
        allowed.add(controller.triggerInteract());
        await tester.pump(const Duration(milliseconds: 8));
      }

      expect(allowed.where((ok) => ok).length, 1,
          reason: 'the callback fires on the same line that returns true, so '
              'more than one true is more than one response');
      expect(allowed.first, isTrue,
          reason: 'the first tap must land — a gate that refuses everything '
              'would pass the assertion above for the wrong reason');
      expect(controller.isInteractCooldownActive, isTrue);
      expect(controller.visualState, PetVisualState.idle,
          reason: 'a burst must not walk the state machine anywhere');

      controller.dispose();
    });

    testWidgets('the gate reopens once the cooldown expires', (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.idle);

      expect(controller.triggerInteract(), isTrue);
      expect(controller.triggerInteract(), isFalse);

      await tester.pump(const Duration(seconds: 2));
      expect(controller.isInteractCooldownActive, isFalse);

      expect(controller.triggerInteract(), isTrue,
          reason: 'rate-limited is not the same as one-shot; without this the '
              'burst test above could pass with a permanently closed gate');

      controller.dispose();
    });

    testWidgets('alternating taps and strokes respect both windows',
        (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.idle);

      final taps = <bool>[];
      final strokes = <bool>[];
      for (var i = 0; i < 10; i++) {
        taps.add(controller.triggerInteract());
        strokes.add(controller.triggerStroke());
        await tester.pump(const Duration(milliseconds: 8));
      }

      // Different gestures, independent windows: each lands once, and the tap
      // must not have swallowed the stroke.
      expect(taps.where((ok) => ok).length, 1);
      expect(strokes.where((ok) => ok).length, 1);

      controller.dispose();
    });
  });

  group('§40 a burst through the widget cannot stack the overlay', () {
    testWidgets('twelve real taps leave one overlay and two ambient timers',
        (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.idle);
      await tester.pumpWidget(app(avatar(controller, PetVisualState.idle)));
      await tester.pump();

      final timersBefore = controller.activeTimerCount;
      expect(timersBefore, 2,
          reason: 'the fixed micro-motion layer is exactly two ambient timers');

      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byType(PetAvatarWidget));
        await tester.pump(const Duration(milliseconds: 60));
        final value = fallback(tester).interactController.value;
        expect(value, greaterThanOrEqualTo(0.0));
        expect(value, lessThanOrEqualTo(1.0),
            reason: 'the overlay is one controller, so its value cannot stack '
                'past 1.0 however many taps land');
      }

      // The first tap must genuinely have landed, or the loop above proved
      // nothing at all — an overlay that never starts trivially never stacks.
      expect(fallback(tester).interactController.value, greaterThan(0.0),
          reason: 'the burst never started an overlay, so it cannot have '
              'stacked one');
      expect(fallback(tester).interactionSpec, isNotNull);

      expect(controller.activeTimerCount, timersBefore,
          reason: 'an interaction schedules no timer of its own');
      expect(controller.visualState, PetVisualState.idle);

      // And it still closes by itself rather than being pinned open.
      final spec = fallback(tester).interactionSpec!;
      await tester.pump(spec.tapDuration);
      await tester.pump(const Duration(milliseconds: 60));
      expect(fallback(tester).interactController.isAnimating, isFalse);
      expect(fallback(tester).interactController.value, 0.0);

      controller.dispose();
    });

    testWidgets('the overlay duration is re-read from the spec each time',
        (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.idle);
      await tester.pumpWidget(app(avatar(controller, PetVisualState.idle)));
      await tester.pump();

      await tester.tap(find.byType(PetAvatarWidget));
      await tester.pump();
      expect(fallback(tester).interactionSpec!.tapDuration,
          PetInteractionSpec.forState(PetVisualState.idle)!.tapDuration);
      expect(fallback(tester).interactController.duration,
          PetInteractionSpec.forState(PetVisualState.idle)!.tapDuration);

      // Move to a state whose glance is shorter, and tap again.
      //
      // Two things have to happen here, and both were learned the hard way.
      // `controller.updateState` is not optional: when an explicit controller is
      // supplied the view reads the *controller's* state, so passing
      // `visualState: focus` to the widget alone leaves the spec resolving to
      // idle. And the 1500 ms gesture cooldown has to be waited out, or the
      // second tap is refused and this test silently compares the first
      // overlay's duration against the focus spec.
      controller.updateState(PetVisualState.focus);
      await tester.pumpWidget(
        app(avatar(controller, PetVisualState.focus), reduceMotion: false),
      );
      await tester
          .pump(PetMotionSpec.interactCooldown + const Duration(seconds: 1));
      expect(controller.isInteractCooldownActive, isFalse,
          reason:
              'the cooldown must have expired, or the tap below is refused');

      await tester.tap(find.byType(PetAvatarWidget));
      await tester.pump();

      expect(fallback(tester).interactionSpec!.tapDuration,
          PetInteractionSpec.forState(PetVisualState.focus)!.tapDuration,
          reason: 'the focus glance is 420 ms against idle\'s 750 ms, so a '
              'duration baked in at construction would still read 750 here');
      expect(fallback(tester).interactController.duration,
          PetInteractionSpec.forState(PetVisualState.focus)!.tapDuration);

      controller.dispose();
    });
  });

  group('§60 an interrupted overlay leaves nothing behind', () {
    testWidgets(
        'Reduced Motion switched on mid-overlay stops the ambient layer',
        (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.idle);

      await tester.pumpWidget(app(avatar(controller, PetVisualState.idle)));
      await tester.pump();
      expect(controller.activeTimerCount, 2);

      await tester.tap(find.byType(PetAvatarWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(fallback(tester).interactController.isAnimating, isTrue);

      // The system setting flips while the overlay is mid-flight.
      await tester.pumpWidget(
        app(avatar(controller, PetVisualState.idle), reduceMotion: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fallback(tester).isReduceMotionActive, isTrue);
      // Not merely "not more than before": turning motion off takes the blink
      // and ear-twitch schedulers down entirely. That is the correct behaviour
      // and asserting the number keeps it from quietly regressing.
      expect(controller.activeTimerCount, 0,
          reason: 'reduced motion must stop the ambient schedulers, not leave '
              'them running invisibly');

      // §59: with motion reduced the pet must still be *present* rather than
      // frozen into nothing. The overlay that was mid-flight resolves...
      await tester.pump(const Duration(seconds: 2));
      expect(fallback(tester).interactController.isAnimating, isFalse);

      // ...and a fresh touch is still acknowledged, by a brief flash instead of
      // a motion. "Reduced" must not mean "unresponsive".
      await tester.pump(PetMotionSpec.interactCooldown);
      await tester.tap(find.byType(PetAvatarWidget));
      await tester.pump(const Duration(milliseconds: 20));
      expect(fallback(tester).isInteractFlashActive, isTrue,
          reason:
              'under reduced motion the touch acknowledgement is the flash; '
              'if it does not fire, Mochi is simply unresponsive');
      expect(fallback(tester).interactController.isAnimating, isFalse,
          reason: 'reduced motion must not animate the overlay');
      expect(controller.activeTimerCount, 0);

      controller.dispose();
    });

    testWidgets('Reduced Motion switched off mid-overlay restores exactly one',
        (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.idle);

      await tester.pumpWidget(
        app(avatar(controller, PetVisualState.idle), reduceMotion: true),
      );
      await tester.pump();
      expect(controller.activeTimerCount, 0);

      await tester.tap(find.byType(PetAvatarWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      await tester.pumpWidget(app(avatar(controller, PetVisualState.idle)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fallback(tester).isReduceMotionActive, isFalse);
      expect(controller.activeTimerCount, 2,
          reason: 'the ambient layer must come back exactly once — a duplicate '
              'would show up here as four');

      // And the animated path still works after the round trip: a fresh touch
      // animates the overlay rather than falling back to the flash.
      await tester.pump(PetMotionSpec.interactCooldown);
      await tester.tap(find.byType(PetAvatarWidget));
      await tester.pump(const Duration(milliseconds: 120));
      expect(fallback(tester).interactController.isAnimating, isTrue,
          reason: 'turning reduced motion back off must restore the real '
              'response, not leave the flash path wired in');
      expect(fallback(tester).isInteractFlashActive, isFalse);

      await tester.pump(const Duration(seconds: 2));
      expect(fallback(tester).interactController.isAnimating, isFalse);

      controller.dispose();
    });

    testWidgets('a route pushed and popped mid-overlay', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final controller = PetMotionController(visualState: PetVisualState.idle);

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: avatar(controller, PetVisualState.idle),
        ),
      );
      await tester.pump();
      final timersBefore = controller.activeTimerCount;

      await tester.tap(find.byType(PetAvatarWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      navKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: Text('other'))),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('other'), findsOneWidget);

      navKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PetIdleFallbackView), findsOneWidget);
      expect(controller.activeTimerCount, timersBefore,
          reason: 'a route round-trip must not duplicate the ambient layer');

      controller.dispose();
    });

    testWidgets('background then foreground mid-overlay', (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.idle);

      await tester.pumpWidget(app(avatar(controller, PetVisualState.idle)));
      await tester.pump();
      final timersBefore = controller.activeTimerCount;

      await tester.tap(find.byType(PetAvatarWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.activeTimerCount, timersBefore,
          reason: 'the lifecycle cycle must not add or lose schedulers');
      expect(controller.visualState, PetVisualState.idle);

      controller.dispose();
    });

    testWidgets('the tree is torn down mid-overlay', (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.idle);

      await tester.pumpWidget(app(avatar(controller, PetVisualState.idle)));
      await tester.pump();
      expect(controller.activeTimerCount, 2);

      await tester.tap(find.byType(PetAvatarWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(fallback(tester).interactController.isAnimating, isTrue);

      // Disposing mid-flight. A `Timer` or `Ticker` still pending here fails
      // this test from inside the framework, not from an assertion of mine.
      await tester.pumpWidget(app(const SizedBox.shrink()));
      await tester.pump();

      expect(controller.activeTimerCount, 0);
      controller.dispose();
    });
  });
}
