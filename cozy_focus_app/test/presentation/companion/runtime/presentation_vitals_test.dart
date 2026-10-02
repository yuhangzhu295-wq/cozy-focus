import 'package:cozy_focus_app/domain/growth/growth_stage.dart';
import 'package:cozy_focus_app/presentation/companion/focus_phase.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_ambient_modifiers.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_behavior_director.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_event.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/presentation_vitals.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/random_source.dart';
import 'package:cozy_focus_app/presentation/companion/time_of_day.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_test_support.dart';

/// P4A — `PresentationVitals` as a behaviour input.
///
/// The brief lists the companion's condition alongside the context and the
/// events as a read-only input to the one behaviour authority. These tests pin
/// what it may change (how an *ambient* companion behaves), what it may not
/// (task contexts, and the completion celebration), and that passing nothing is
/// the same as passing nothing at all.
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

  CompanionContext context({
    CompanionBaseContext base = CompanionBaseContext.home,
    PresentationVitals vitals = PresentationVitals.neutral,
    GrowthStage growth = GrowthStage.sprout,
    TimeOfDayBand timeOfDay = TimeOfDayBand.midday,
  }) =>
      CompanionContext(
        companionId: CompanionId.dog,
        baseContext: base,
        growthStage: growth,
        timeOfDay: timeOfDay,
        vitals: vitals,
        hasActiveSession: base == CompanionBaseContext.focus,
        focusPhase:
            base == CompanionBaseContext.focus ? FocusPhase.working : null,
        craftProgress: base == CompanionBaseContext.craft ? 0.5 : null,
      );

  group('the vitals value', () {
    test('the neutral default contributes nothing', () {
      expect(PresentationVitals.neutral.isNeutral, isTrue);
      expect(PresentationVitals.neutral.isTired, isFalse);
      expect(PresentationVitals.neutral.isLowMood, isFalse);
    });

    test('the thresholds are the brief\'s own', () {
      expect(PresentationVitals.tiredEnergyThreshold, 40);
      expect(PresentationVitals.lowMoodThreshold, 40);
      expect(
        const PresentationVitals(energy: 39).isTired,
        isTrue,
        reason: 'energy < 40 is the brief\'s rest condition',
      );
      expect(const PresentationVitals(energy: 40).isTired, isFalse);
    });
  });

  group('the modifier table', () {
    test('neutral vitals are a no-op', () {
      final modifier = CompanionAmbientModifiers.vitalsModifier(
        PresentationVitals.neutral,
      );
      expect(modifier.extraEligible, isEmpty);
      expect(modifier.dwellScale, 1.0);
    });

    test('a tired companion rests more and dwells longer', () {
      final modifier = CompanionAmbientModifiers.vitalsModifier(
        const PresentationVitals(energy: 20),
      );
      expect(
          modifier.extraEligible, contains(CompanionMacroBehavior.microRest));
      expect(modifier.dwellScale, greaterThan(1.0));
    });

    test('a subdued companion is quieter', () {
      final modifier = CompanionAmbientModifiers.vitalsModifier(
        const PresentationVitals(mood: 20),
      );
      expect(modifier.dwellScale, greaterThan(1.0));
    });

    test('the two conditions compound', () {
      final tired = CompanionAmbientModifiers.vitalsModifier(
        const PresentationVitals(energy: 20),
      );
      final subdued = CompanionAmbientModifiers.vitalsModifier(
        const PresentationVitals(mood: 20),
      );
      final both = CompanionAmbientModifiers.vitalsModifier(
        const PresentationVitals(energy: 20, mood: 20),
      );
      expect(both.dwellScale,
          closeTo(tired.dwellScale * subdued.dwellScale, 1e-9));
    });

    test('a condition is additive on the stage and the hour', () {
      // Never a replacement: a tired grown companion still gets its growth
      // behaviours.
      final modifier = CompanionAmbientModifiers.resolve(
        baseContext: CompanionBaseContext.home,
        growthStage: GrowthStage.blooming,
        timeOfDayBand: TimeOfDayBand.lateNight,
        vitals: const PresentationVitals(energy: 10),
      );
      expect(
          modifier.extraEligible, contains(CompanionMacroBehavior.microRest));
      expect(modifier.extraEligible, contains(CompanionMacroBehavior.glance),
          reason: 'the growth contribution must survive');
    });

    test('task contexts ignore vitals entirely', () {
      // A focus session must present the same work behaviour however the
      // companion feels, or it would appear to work differently when tired.
      for (final base in const [
        CompanionBaseContext.focus,
        CompanionBaseContext.craft,
        CompanionBaseContext.pause,
        CompanionBaseContext.sleep,
        CompanionBaseContext.complete,
      ]) {
        final modifier = CompanionAmbientModifiers.resolve(
          baseContext: base,
          growthStage: GrowthStage.blooming,
          timeOfDayBand: TimeOfDayBand.lateNight,
          vitals: const PresentationVitals(energy: 1, mood: 1),
        );
        expect(modifier.extraEligible, isEmpty, reason: base.id);
        expect(modifier.dwellScale, 1.0, reason: base.id);
      }
    });
  });

  group('vitals reach behaviour only where they should', () {
    test('a tired companion at home really picks up resting', () {
      // The integration half: the modifier is not just computed, it changes what
      // is presented.
      final tired = director(
        context(vitals: const PresentationVitals(energy: 15)),
      );
      final seen = <CompanionMacroBehavior?>{};
      for (var i = 0; i < 900; i++) {
        tired.advanceTo(Duration(milliseconds: i * 1000));
        seen.add(tired.currentMacroBehavior);
      }
      expect(seen, contains(CompanionMacroBehavior.microRest));
    });

    test('a neutral companion at home never does', () {
      // The same sweep with no vitals, so the difference is the input and
      // nothing else. At midday and the youngest stage the home pool is idle
      // alone.
      final rested = director(context());
      final seen = <CompanionMacroBehavior?>{};
      for (var i = 0; i < 900; i++) {
        rested.advanceTo(Duration(milliseconds: i * 1000));
        seen.add(rested.currentMacroBehavior);
      }
      expect(seen, isNot(contains(CompanionMacroBehavior.microRest)));
    });

    test('a tired companion still works during a focus session', () {
      final tired = director(
        context(
          base: CompanionBaseContext.focus,
          vitals: const PresentationVitals(energy: 5, mood: 5),
        ),
      );
      final seen = <CompanionMacroBehavior?>{};
      for (var i = 0; i < 400; i++) {
        tired.advanceTo(Duration(milliseconds: i * 1000));
        seen.add(tired.currentMacroBehavior);
      }
      expect(seen, contains(CompanionMacroBehavior.focusWrite));
      expect(seen, isNot(contains(CompanionMacroBehavior.microRest)),
          reason: 'a session must not be diluted by the companion being tired');
    });

    test('the completion celebration survives the worst vitals', () {
      // The hard rule, re-checked through the newest input: no condition may
      // dilute a completed session's celebration.
      for (final energy in const [0, 5, 39]) {
        for (final mood in const [0, 5, 39]) {
          final d = director(
            context(
              base: CompanionBaseContext.complete,
              vitals: PresentationVitals(energy: energy, mood: mood),
            ),
          );
          expect(d.currentMacroBehavior, CompanionMacroBehavior.celebrate,
              reason: 'energy=$energy mood=$mood');
        }
      }
    });

    test('the completion event survives the worst vitals too', () {
      final d = director(
        context(vitals: const PresentationVitals(energy: 0, mood: 0)),
      );
      d.dispatch(CompanionEvent.focusCompleted);
      expect(d.currentMacroBehavior, CompanionMacroBehavior.celebrate);
    });
  });

  group('vitals are a read-only input', () {
    test('a context without vitals behaves exactly as before', () {
      // The compatibility guarantee: every existing caller passes nothing, so
      // the modifier it gets must be the one it got before this input existed.
      final withoutVitals = CompanionAmbientModifiers.resolve(
        baseContext: CompanionBaseContext.home,
        growthStage: GrowthStage.growing,
        timeOfDayBand: TimeOfDayBand.evening,
      );
      final withNeutral = CompanionAmbientModifiers.resolve(
        baseContext: CompanionBaseContext.home,
        growthStage: GrowthStage.growing,
        timeOfDayBand: TimeOfDayBand.evening,
        vitals: PresentationVitals.neutral,
      );
      expect(withNeutral.dwellScale, withoutVitals.dwellScale);
      expect(withNeutral.extraEligible, withoutVitals.extraEligible);
    });

    test('copying a context carries vitals through, and clears nothing else',
        () {
      final original = context(vitals: const PresentationVitals(energy: 12));
      final copy = original.copyWith(baseContext: CompanionBaseContext.room);
      expect(copy.vitals, original.vitals);
      expect(copy.vitals.energy, 12);
    });
  });
}
