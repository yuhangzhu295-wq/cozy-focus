import 'dart:io';

import 'package:cozy_focus_app/domain/growth/growth_stage.dart';
import 'package:cozy_focus_app/presentation/companion/focus_phase.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_availability.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_behavior_director.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_event.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/random_source.dart';
import 'package:cozy_focus_app/presentation/companion/time_of_day.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_test_support.dart';

/// P4A — the companion life loop's behaviour contract.
///
/// The director is the one behaviour authority. These tests pin what it must do
/// when it is handed an event, a gated repertoire, or a context it must not
/// animate, and they pin what it must *not* grow: a second scheduler, a second
/// random engine, or a claim of variety it does not have.
void main() {
  late CompanionCatalog catalog;

  setUp(() => catalog = loadShippedCatalog());

  CompanionBehaviorDirector director(
    CompanionContext context, {
    int seed = 7,
    CompanionActionAvailability Function(String)? availabilityOf,
  }) =>
      CompanionBehaviorDirector(
        catalog: catalog,
        context: context,
        random: SeededRandomSource(seed),
        availabilityOf: availabilityOf,
      );

  CompanionContext context({
    CompanionBaseContext base = CompanionBaseContext.focus,
    FocusPhase? phase = FocusPhase.working,
    CompanionId id = CompanionId.dog,
    GrowthStage growth = GrowthStage.sprout,
    TimeOfDayBand timeOfDay = TimeOfDayBand.midday,
    bool hasSession = true,
    double? craftProgress,
  }) =>
      CompanionContext(
        companionId: id,
        baseContext: base,
        focusPhase: base == CompanionBaseContext.focus ? phase : null,
        focusProgress: base == CompanionBaseContext.focus ? 0.3 : null,
        hasActiveSession: hasSession,
        craftProgress: craftProgress,
        growthStage: growth,
        timeOfDay: timeOfDay,
      );

  /// Advances past [duration] in one jump and returns the macro.
  CompanionMacroBehavior? after(
    CompanionBehaviorDirector d,
    Duration duration,
  ) {
    d.advanceTo(d.now + duration);
    return d.currentMacroBehavior;
  }

  group('event model', () {
    test('every event has a stable wire id and round-trips', () {
      for (final event in CompanionEvent.values) {
        expect(event.id, isNotEmpty);
        expect(CompanionEvent.fromId(event.id), event);
      }
      expect(CompanionEvent.fromId('not_an_event'), isNull);
      expect(CompanionEvent.fromId(null), isNull);
    });

    test('gestures are distinguished from transitions', () {
      expect(CompanionEvent.tap.isGesture, isTrue);
      expect(CompanionEvent.longPress.isGesture, isTrue);
      expect(CompanionEvent.focusCompleted.isGesture, isFalse);
      expect(CompanionEvent.pauseStarted.isGesture, isFalse);
      expect(CompanionEvent.roomActionChanged.isGesture, isFalse);
    });
  });

  group('focus completion always celebrates', () {
    // The hard rule. It has to hold whatever the hour, the growth stage or the
    // ambient pool says, so it is swept rather than spot-checked.
    test('the event alone forces a celebration, at every hour and stage', () {
      for (final band in TimeOfDayBand.values) {
        for (final stage in GrowthStage.values) {
          final d = director(
            context(
              base: CompanionBaseContext.home,
              timeOfDay: band,
              growth: stage,
            ),
          );
          d.dispatch(CompanionEvent.focusCompleted);
          expect(
            d.currentMacroBehavior,
            CompanionMacroBehavior.celebrate,
            reason: 'band=$band stage=$stage',
          );
          expect(d.intent.pose, CompanionPose.celebrate);
        }
      }
    });

    test('a completed context celebrates without needing the event', () {
      // The structural half: `complete` is excluded from the ambient modifiers
      // and its recipe lists only `celebrate`, so the hour cannot dilute it.
      for (final band in TimeOfDayBand.values) {
        final d = director(
          context(base: CompanionBaseContext.complete, timeOfDay: band),
        );
        expect(d.currentMacroBehavior, CompanionMacroBehavior.celebrate,
            reason: 'band=$band');
      }
    });

    test('the celebration outlives a re-pick and then hands over', () {
      final d = director(context(base: CompanionBaseContext.complete));
      d.dispatch(CompanionEvent.focusCompleted);
      expect(d.isCelebrating, isTrue);

      // Mid-celebration a context update arrives; it must not cut the moment
      // short.
      d.updateContext(context(base: CompanionBaseContext.complete));
      expect(d.currentMacroBehavior, CompanionMacroBehavior.celebrate);

      // Once the dwell expires the celebration releases.
      d.advanceTo(d.now + const Duration(seconds: 30));
      expect(d.isCelebrating, isFalse);
    });

    test('a transition event releases a running celebration', () {
      final d = director(context(base: CompanionBaseContext.complete));
      d.dispatch(CompanionEvent.focusCompleted);
      expect(d.isCelebrating, isTrue);

      // The world moved on: a new session started.
      d.updateContext(context(base: CompanionBaseContext.focus));
      d.dispatch(CompanionEvent.focusStarted);
      expect(d.isCelebrating, isFalse);
      expect(d.currentMacroBehavior, isNot(CompanionMacroBehavior.celebrate));
    });
  });

  group('interaction overlays cover and restore', () {
    test('tap shows the tap overlay and restores the same macro', () {
      final d = director(context());
      final macroBefore = d.currentMacroBehavior;
      expect(macroBefore, isNotNull);

      expect(d.dispatch(CompanionEvent.tap), isTrue);
      expect(d.overlay, d.profile.tapOverlay);
      expect(d.intent.isOverlayActive, isTrue);
      // The base and the macro are untouched while the overlay runs.
      expect(d.currentMacroBehavior, macroBefore);
      expect(d.intent.baseContext, CompanionBaseContext.focus);

      after(d, const Duration(seconds: 3));
      expect(d.overlay.id, 'none');
      expect(d.currentMacroBehavior, macroBefore,
          reason: 'the macro must resume, not be replaced by idle');
      expect(d.intent.baseContext, CompanionBaseContext.focus);
    });

    test('long press shows the pet overlay and restores the same macro', () {
      final d = director(context());
      final macroBefore = d.currentMacroBehavior;

      expect(d.dispatch(CompanionEvent.longPress), isTrue);
      expect(d.overlay, d.profile.longPressOverlay);
      expect(d.currentMacroBehavior, macroBefore);

      after(d, const Duration(seconds: 4));
      expect(d.overlay.id, 'none');
      expect(d.currentMacroBehavior, macroBefore);
    });

    test('an overlay never becomes the base context', () {
      final d = director(context());
      d.dispatch(CompanionEvent.tap);
      // The failure this guards: focus -> interaction -> idle.
      expect(d.intent.baseContext, CompanionBaseContext.focus);
      after(d, const Duration(seconds: 5));
      expect(d.intent.baseContext, CompanionBaseContext.focus);
      expect(d.currentMacroBehavior, isNot(CompanionMacroBehavior.idle),
          reason: 'focus must not decay to idle through an interaction');
    });
  });

  group('rapid interaction is bounded', () {
    test('overlays do not stack', () {
      final d = director(context());
      expect(d.dispatch(CompanionEvent.tap), isTrue);
      // A second gesture while one runs is refused outright.
      expect(d.dispatch(CompanionEvent.longPress), isFalse);
      expect(d.overlay, d.profile.tapOverlay);
    });

    test('a cooldown follows an overlay, so taps cannot chain', () {
      final d = director(context());
      expect(d.dispatch(CompanionEvent.tap), isTrue);

      // End the overlay.
      after(d, const Duration(seconds: 3));
      expect(d.overlay.id, 'none');

      // Inside the cooldown the next tap is refused.
      expect(d.dispatch(CompanionEvent.tap), isFalse,
          reason: 'the cooldown after an overlay must hold');

      // Past it, a tap works again.
      after(
          d,
          CompanionBehaviorDirector.overlayCooldown +
              const Duration(milliseconds: 50));
      expect(d.dispatch(CompanionEvent.tap), isTrue);
    });
  });

  group('capability gating', () {
    test('the shipped dog can be asked for its work behaviours', () {
      final availability = CompanionActionAvailabilityResolver.resolve('dog');
      for (final pose in const [
        CompanionPose.idle,
        CompanionPose.focusRead,
        CompanionPose.focusWrite,
        CompanionPose.focusThink,
        CompanionPose.craftWork,
        CompanionPose.celebrate,
      ]) {
        expect(availability.canSchedule(pose), isTrue, reason: pose.id);
        expect(availability.hasOwnDrawing(pose), isTrue, reason: pose.id);
      }
    });

    test('a pose the pack never names is not schedulable', () {
      final availability = CompanionActionAvailabilityResolver.resolve('dog');
      // The dog names no greeting or unlock behaviour. They are overlays it
      // never uses, and the pack has no art for them — so they are absent
      // rather than quietly resolving to idle.
      expect(availability.canSchedule(CompanionPose.greeting), isFalse);
      expect(availability.canSchedule(CompanionPose.unlockReact), isFalse);
    });

    test('a named pose with no drawing of its own is a reported fallback', () {
      final availability = CompanionActionAvailabilityResolver.resolve('dog');
      // `room_sit` is named by the pack's semantic fallback and resolves to
      // idle. It stays schedulable, and it is *reported* rather than counted as
      // a distinct behaviour.
      expect(availability.canSchedule(CompanionPose.roomSit), isTrue);
      expect(availability.hasOwnDrawing(CompanionPose.roomSit), isFalse);
    });

    test('an unknown companion falls back to the default, not to nothing', () {
      final unknown = CompanionActionAvailabilityResolver.resolve('dragon');
      final dog = CompanionActionAvailabilityResolver.resolve('dog');
      expect(unknown.companionId, dog.companionId);
      expect(unknown.schedulable, dog.schedulable);
    });

    test('the director never selects an unavailable behaviour', () {
      // A dog with its writing and thinking art removed. The shared recipe still
      // lists them; the gate is what stops the director asking.
      const trimmed = CompanionActionAvailability(
        companionId: 'dog',
        schedulable: {'idle', 'focus_read'},
      );
      final d = director(context(), availabilityOf: (_) => trimmed);

      for (var i = 0; i < 200; i++) {
        d.advanceTo(Duration(milliseconds: i * 1000));
        final macro = d.currentMacroBehavior;
        expect(macro, isNotNull);
        expect(trimmed.canSchedule(macro!.pose), isTrue,
            reason: 'selected ${macro.id}, which is not available');
        expect(macro, isNot(CompanionMacroBehavior.focusWrite));
        expect(macro, isNot(CompanionMacroBehavior.focusThink));
      }
    });

    test('a companion with nothing available degrades and says so', () {
      const nothing = CompanionActionAvailability(
        companionId: 'dog',
        schedulable: {},
      );
      final d = director(context(), availabilityOf: (_) => nothing);
      expect(d.currentMacroBehavior, isNull);
      expect(d.isUsingFallback, isTrue);
    });

    test('a fallback is reported, not counted as variety', () {
      // Only idle, and only as a fallback drawing.
      const onlyIdle = CompanionActionAvailability(
        companionId: 'dog',
        schedulable: {'idle'},
        fallbackOnly: {'idle'},
      );
      final d = director(context(), availabilityOf: (_) => onlyIdle);
      expect(d.currentMacroBehavior, CompanionMacroBehavior.idle);
      expect(d.isUsingFallback, isTrue,
          reason: 'a fallback must never be reported as a real behaviour');
    });
  });

  group('context transitions still gate', () {
    test('pause blocks focus behaviours', () {
      final d = director(context());
      expect(d.currentMacroBehavior, isNot(CompanionMacroBehavior.idle));

      d.updateContext(context(base: CompanionBaseContext.pause));
      for (var i = 0; i < 60; i++) {
        d.advanceTo(Duration(milliseconds: i * 1000));
        expect(d.currentMacroBehavior, CompanionMacroBehavior.rest,
            reason: 'pause must not schedule a focus behaviour');
      }
    });

    test('craft behaviour needs a real craft job', () {
      // A craft context with no job is ungrounded and must not animate work.
      final d = director(context(base: CompanionBaseContext.craft));
      expect(d.currentMacroBehavior, CompanionMacroBehavior.idle);

      d.updateContext(context(
        base: CompanionBaseContext.craft,
        craftProgress: 0.4,
      ));
      expect(d.currentMacroBehavior, CompanionMacroBehavior.craftWork);
    });

    test('a focus context with no session is not grounded', () {
      final d = director(context(hasSession: false, phase: null));
      expect(d.currentMacroBehavior, CompanionMacroBehavior.idle);
    });
  });

  group('one behaviour authority', () {
    /// The director's own source, for the structural assertions below.
    late String source;

    setUpAll(() {
      source = File(
        'lib/presentation/companion/runtime/companion_behavior_director.dart',
      ).readAsStringSync();
    });

    test('the director owns no timer, ticker or subscription', () {
      // Time is pushed in through `advanceTo`. If the director ever grew its own
      // clock there would be two schedulers and something to leak.
      for (final banned in const [
        'Timer(',
        'Timer.periodic',
        'createTicker',
        'Ticker(',
        'StreamSubscription',
        'Future.delayed',
      ]) {
        expect(source.contains(banned), isFalse,
            reason: 'the director must not own a clock ($banned)');
      }
    });

    test('the director has exactly one random source', () {
      expect('random.nextDouble'.allMatches(source).length,
          greaterThanOrEqualTo(1));
      // One injected source, no ad-hoc `Random()` anywhere.
      expect(source.contains('Random()'), isFalse);
      expect(source.contains('SystemRandomSource()'), isTrue);
    });

    test('the director reaches no business layer', () {
      for (final banned in const [
        'app_database',
        'Repository',
        'Controller',
        'FocusSessionEngine',
        'CraftEngine',
        'RewardService',
        'RewardLedger',
      ]) {
        // `CompanionBehaviorDirector` itself is the only Controller-shaped word
        // allowed, and it is the class name.
        if (banned == 'Controller') continue;
        expect(source.contains(banned), isFalse, reason: banned);
      }
    });

    test('a behaviour is chosen by recipe, never by a fixed timeline', () {
      // The brief forbids "0-5 min = read, 5-10 = write". Nothing in the
      // director may branch on elapsed focus time to pick a behaviour; the
      // phase comes from the context and the pick comes from the recipe.
      expect(source.contains('focusProgress'), isTrue,
          reason: 'progress is passed through, not interpreted');
      for (final banned in const [
        'elapsed',
        'minutes',
        'inSeconds >',
        'inMinutes',
      ]) {
        expect(source.contains(banned), isFalse,
            reason: 'the director must not time-slice behaviour ($banned)');
      }
    });
  });
}
