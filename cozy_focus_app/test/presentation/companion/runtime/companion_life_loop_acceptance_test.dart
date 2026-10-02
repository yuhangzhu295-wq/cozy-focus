import 'package:cozy_focus_app/domain/growth/growth_stage.dart';
import 'package:cozy_focus_app/presentation/companion/focus_phase.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_behavior_director.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_behavior_priority.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_event.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/presentation_vitals.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/random_source.dart';
import 'package:cozy_focus_app/presentation/companion/time_of_day.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_test_support.dart';

/// Phase 4's four acceptance criteria, at the level they can be settled without
/// sprite frames.
///
/// ## What this can and cannot prove
///
/// Criteria 2, 3 and 4 are logic and are settled here outright.
///
/// Criterion 1 — "the companion does not stand still through a 25-minute focus
/// session" — has two halves. The **logic** half is proved here: over a full
/// simulated session the presented behaviour changes many times, never settles
/// on one, and never leaves the focus repertoire. The **visual** half is not:
/// `idle` still ships a single frame, and no scheduling can make one frame move.
/// That half is P4B and is blocked on the asset batch.
void main() {
  late CompanionCatalog catalog;

  setUp(() => catalog = loadShippedCatalog());

  CompanionBehaviorDirector director(
    CompanionContext context, {
    int seed = 7,
  }) =>
      CompanionBehaviorDirector(
        catalog: catalog,
        context: context,
        random: SeededRandomSource(seed),
      );

  CompanionContext focusContext({
    FocusPhase phase = FocusPhase.working,
    GrowthStage growth = GrowthStage.sprout,
    TimeOfDayBand timeOfDay = TimeOfDayBand.midday,
    PresentationVitals vitals = PresentationVitals.neutral,
  }) =>
      CompanionContext(
        companionId: CompanionId.dog,
        baseContext: CompanionBaseContext.focus,
        focusPhase: phase,
        focusProgress: 0.4,
        hasActiveSession: true,
        growthStage: growth,
        timeOfDay: timeOfDay,
        vitals: vitals,
      );

  /// The phase a real 25-minute session is in at [minute].
  ///
  /// The boundaries mirror the app's own long-arc phases; the point of the test
  /// is that behaviour follows the *phase*, not a stopwatch inside the director.
  FocusPhase phaseAt(int minute) {
    if (minute < 1) return FocusPhase.starting;
    if (minute < 10) return FocusPhase.working;
    if (minute < 20) return FocusPhase.deepFocus;
    return FocusPhase.finishing;
  }

  group('acceptance 1 - a 25-minute session does not stand still', () {
    test('the behaviour keeps changing across the whole session', () {
      final d = director(focusContext());
      final seen = <CompanionMacroBehavior?>[];
      var longestHold = Duration.zero;
      var holdStart = Duration.zero;

      // 25 minutes, one-second steps, with the phase advancing as it really does.
      for (var second = 0; second <= 25 * 60; second++) {
        final minute = second ~/ 60;
        d.updateContext(focusContext(phase: phaseAt(minute)));
        d.advanceTo(Duration(seconds: second));

        final macro = d.currentMacroBehavior;
        if (seen.isEmpty || seen.last != macro) {
          final held = Duration(seconds: second) - holdStart;
          if (held > longestHold) longestHold = held;
          holdStart = Duration(seconds: second);
          seen.add(macro);
        }
      }

      // Not a freeze: the session presents many different behaviours.
      expect(seen.length, greaterThan(20),
          reason: 'the companion changed behaviour only ${seen.length} times '
              'in 25 minutes');

      // And no single behaviour is held for an implausible stretch. The longest
      // recipe dwell is 30s scaled by at most 1.35, so anything past a minute
      // means the scheduler stalled.
      expect(longestHold, lessThan(const Duration(seconds: 90)),
          reason: 'one behaviour was held for $longestHold');
    });

    test('the session never falls out of the focus repertoire', () {
      final d = director(focusContext());
      final seen = <CompanionMacroBehavior?>{};

      for (var second = 0; second <= 25 * 60; second++) {
        d.updateContext(focusContext(phase: phaseAt(second ~/ 60)));
        d.advanceTo(Duration(seconds: second));
        seen.add(d.currentMacroBehavior);
      }

      // The failure this guards: a companion that idles through the session, or
      // one that celebrates before the session is over.
      expect(seen, isNot(contains(CompanionMacroBehavior.idle)),
          reason: 'the companion idled during a live session');
      expect(seen, isNot(contains(CompanionMacroBehavior.celebrate)),
          reason: 'the companion celebrated before the session completed');
      expect(seen, isNot(contains(null)),
          reason: 'the companion had no behaviour at all');

      // Every behaviour it did present is a real work behaviour.
      for (final macro in seen) {
        expect(CompanionMacroBehavior.focusBehaviors, contains(macro),
            reason: '${macro?.id} is not a focus behaviour');
      }
    });

    test('the session presents more than one work behaviour', () {
      // "Not still" means variety, not merely change: a session that alternated
      // between two poses would pass the change count and still read as static.
      final d = director(focusContext(phase: FocusPhase.deepFocus));
      final seen = <CompanionMacroBehavior?>{};
      for (var second = 0; second <= 20 * 60; second++) {
        d.advanceTo(Duration(seconds: second));
        seen.add(d.currentMacroBehavior);
      }
      expect(seen.length, greaterThanOrEqualTo(3),
          reason: 'deep focus presented only $seen');
    });
  });

  group('acceptance 2 - completing a session celebrates', () {
    test('the completion event produces a celebration at every hour and stage',
        () {
      for (final band in TimeOfDayBand.values) {
        for (final stage in GrowthStage.values) {
          for (final energy in const [0, 40, 100]) {
            final d = director(focusContext(
              growth: stage,
              timeOfDay: band,
              vitals: PresentationVitals(energy: energy, mood: energy),
            ));
            d.dispatch(CompanionEvent.focusCompleted);
            expect(d.currentMacroBehavior, CompanionMacroBehavior.celebrate,
                reason: 'band=$band stage=$stage energy=$energy');
            expect(d.intent.pose, CompanionPose.celebrate);
            expect(d.currentPriority, CompanionBehaviorPriority.critical);
          }
        }
      }
    });

    test('the celebration outranks everything while it runs', () {
      final d = director(focusContext());
      d.dispatch(CompanionEvent.focusCompleted);
      expect(d.currentPriority, CompanionBehaviorPriority.critical);

      // Even a gesture cannot displace it, and it is not interruptible.
      d.dispatch(CompanionEvent.tap);
      expect(d.currentPriority, CompanionBehaviorPriority.critical);
      expect(d.currentMacroBehavior, CompanionMacroBehavior.celebrate);
    });
  });

  group('acceptance 3 - tapping the companion answers', () {
    test('a tap is answered and the session behaviour resumes', () {
      final d = director(focusContext());
      final macroBefore = d.currentMacroBehavior;
      expect(macroBefore, isNotNull);

      expect(d.dispatch(CompanionEvent.tap), isTrue);
      expect(d.currentPriority, CompanionBehaviorPriority.interaction);
      expect(d.intent.isOverlayActive, isTrue);
      // The task macro is still underneath, not replaced.
      expect(d.currentMacroBehavior, macroBefore);

      d.advanceTo(d.now + const Duration(seconds: 4));
      expect(d.intent.isOverlayActive, isFalse);
      expect(d.currentMacroBehavior, macroBefore);
      expect(d.currentPriority, CompanionBehaviorPriority.task);
      expect(d.intent.baseContext, CompanionBaseContext.focus);
    });

    test('a long press is answered too', () {
      final d = director(focusContext());
      final macroBefore = d.currentMacroBehavior;
      expect(d.dispatch(CompanionEvent.longPress), isTrue);
      expect(d.currentPriority, CompanionBehaviorPriority.interaction);
      d.advanceTo(d.now + const Duration(seconds: 5));
      expect(d.currentMacroBehavior, macroBefore);
    });
  });

  group('acceptance 4 - energy and mood reach behaviour', () {
    test('a tired ambient companion rests more than a rested one', () {
      int restsIn(PresentationVitals vitals) {
        final d = director(CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.home,
          vitals: vitals,
        ));
        var count = 0;
        for (var second = 0; second < 1800; second++) {
          d.advanceTo(Duration(seconds: second));
          if (d.currentMacroBehavior == CompanionMacroBehavior.microRest) {
            count++;
          }
        }
        return count;
      }

      final rested = restsIn(PresentationVitals.neutral);
      final tired = restsIn(const PresentationVitals(energy: 10));
      expect(tired, greaterThan(rested),
          reason: 'energy must change behaviour: rested=$rested tired=$tired');
    });

    test('the task contexts are immune to it', () {
      // Acceptance 4 must not be bought by making a session behave differently
      // when the companion is tired.
      final d = director(focusContext(
        vitals: const PresentationVitals(energy: 1, mood: 1),
      ));
      for (var second = 0; second <= 600; second++) {
        d.advanceTo(Duration(seconds: second));
        expect(d.currentPriority, CompanionBehaviorPriority.task);
        expect(CompanionMacroBehavior.focusBehaviors,
            contains(d.currentMacroBehavior));
      }
    });
  });

  group('the priority tiers', () {
    test('they are ordered, and the order is the documented one', () {
      expect(CompanionBehaviorPriority.critical.rank, 0);
      expect(CompanionBehaviorPriority.interaction.rank, 1);
      expect(CompanionBehaviorPriority.task.rank, 2);
      expect(CompanionBehaviorPriority.idle.rank, 3);

      expect(
          CompanionBehaviorPriority.critical
              .outranks(CompanionBehaviorPriority.interaction),
          isTrue);
      expect(
          CompanionBehaviorPriority.interaction
              .outranks(CompanionBehaviorPriority.task),
          isTrue);
      expect(
          CompanionBehaviorPriority.task
              .outranks(CompanionBehaviorPriority.idle),
          isTrue);
      // And the relation is not symmetric.
      expect(
          CompanionBehaviorPriority.idle
              .outranks(CompanionBehaviorPriority.task),
          isFalse);
    });

    test('the director reports the tier that actually won', () {
      final home = director(const CompanionContext(
        companionId: CompanionId.dog,
        baseContext: CompanionBaseContext.home,
      ));
      expect(home.currentPriority, CompanionBehaviorPriority.idle);

      final focus = director(focusContext());
      expect(focus.currentPriority, CompanionBehaviorPriority.task);

      focus.dispatch(CompanionEvent.tap);
      expect(focus.currentPriority, CompanionBehaviorPriority.interaction);

      focus.advanceTo(focus.now + const Duration(seconds: 4));
      focus.dispatch(CompanionEvent.focusCompleted);
      expect(focus.currentPriority, CompanionBehaviorPriority.critical);
    });

    test('pause and craft are task contexts, not idle', () {
      final pause = director(const CompanionContext(
        companionId: CompanionId.dog,
        baseContext: CompanionBaseContext.pause,
        hasActiveSession: true,
      ));
      expect(pause.currentPriority, CompanionBehaviorPriority.task);

      final craft = director(const CompanionContext(
        companionId: CompanionId.dog,
        baseContext: CompanionBaseContext.craft,
        craftProgress: 0.5,
      ));
      expect(craft.currentPriority, CompanionBehaviorPriority.task);
    });

    test('the completed context is critical without the event', () {
      final d = director(const CompanionContext(
        companionId: CompanionId.dog,
        baseContext: CompanionBaseContext.complete,
      ));
      expect(d.currentPriority, CompanionBehaviorPriority.critical);
      expect(d.currentMacroBehavior, CompanionMacroBehavior.celebrate);
    });
  });
}
