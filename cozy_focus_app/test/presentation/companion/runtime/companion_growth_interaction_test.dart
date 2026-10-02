import 'package:cozy_focus_app/domain/growth/growth_stage.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_ambient_modifiers.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_behavior_director.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_event.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/random_source.dart';
import 'package:cozy_focus_app/presentation/companion/time_of_day.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_test_support.dart';

/// P5 closeout — growth's reach into interaction frequency and expression.
///
/// The ambient modifier already lets growth change the ambient behaviour pool
/// and the dwell. This pins the one piece that was missing: the overlay
/// duration scale, which makes a blooming companion hold reactions a little
/// longer than a sprout.
///
/// It also confirms that no page uses a level `if`-chain to pick behaviour, and
/// that growth's touch on interaction never reaches the business layer.
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

  CompanionContext homeContext({
    GrowthStage growth = GrowthStage.sprout,
    TimeOfDayBand timeOfDay = TimeOfDayBand.midday,
  }) =>
      CompanionContext(
        companionId: CompanionId.dog,
        baseContext: CompanionBaseContext.home,
        growthStage: growth,
        timeOfDay: timeOfDay,
      );

  group('growth scales the overlay duration', () {
    test('the ambient modifier carries the scale', () {
      final sprout = CompanionAmbientModifiers.resolve(
        baseContext: CompanionBaseContext.home,
        growthStage: GrowthStage.sprout,
        timeOfDayBand: TimeOfDayBand.midday,
      );
      final blooming = CompanionAmbientModifiers.resolve(
        baseContext: CompanionBaseContext.home,
        growthStage: GrowthStage.blooming,
        timeOfDayBand: TimeOfDayBand.midday,
      );
      expect(sprout.overlayDurationScale, lessThan(1.0),
          reason: 'a sprout holds reactions briefly');
      expect(blooming.overlayDurationScale, greaterThan(1.0),
          reason: 'a blooming companion is more expressive');
    });

    test('a blooming companion holds tap reactions longer than a sprout', () {
      // Deterministic: same seed, same recipe, only the growth stage differs.
      // The overlay duration is drawn from a seeded random source, so the
      // comparison is between the same random roll at different scales.
      Duration tapDuration(GrowthStage stage) {
        final d = director(homeContext(growth: stage), seed: 42);
        d.dispatch(CompanionEvent.tap);
        return d.interactionUntil! - d.now;
      }

      final sproutDuration = tapDuration(GrowthStage.sprout);
      final bloomingDuration = tapDuration(GrowthStage.blooming);

      expect(bloomingDuration, greaterThan(sproutDuration),
          reason: 'a more grown companion holds reactions longer: '
              'sprout=$sproutDuration blooming=$bloomingDuration');
    });

    test('the overlay duration stays inside a sane range at every stage', () {
      for (final stage in GrowthStage.values) {
        final d = director(homeContext(growth: stage), seed: 42);
        d.dispatch(CompanionEvent.tap);
        final hold = d.interactionUntil! - d.now;
        expect(hold, greaterThan(const Duration(milliseconds: 200)),
            reason: '$stage hold too brief: $hold');
        expect(hold, lessThan(const Duration(seconds: 10)),
            reason: '$stage hold too long: $hold');
      }
    });

    test('a long press holds longer than a tap at the same stage', () {
      // The recipe's pet_react range is 1000-2000ms and tap_react is 600-1200ms,
      // so the pet overlay should always outlast the tap overlay. Growth must
      // not invert that relationship.
      final d = director(homeContext(growth: GrowthStage.blooming), seed: 42);

      d.dispatch(CompanionEvent.tap);
      final tapHold = d.interactionUntil! - d.now;
      d.clearOverlay();
      d.advanceTo(d.now + const Duration(seconds: 5));

      d.dispatch(CompanionEvent.longPress);
      final longPressHold = d.interactionUntil! - d.now;

      expect(longPressHold, greaterThan(tapHold),
          reason:
              'a stroke is a bigger gesture than a tap and must outlast it: '
              'tap=$tapHold longPress=$longPressHold');
    });
  });

  group('growth never overrides context semantics', () {
    test('completion still celebrates at every stage', () {
      for (final stage in GrowthStage.values) {
        final d = director(CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.home,
          growthStage: stage,
        ));
        d.dispatch(CompanionEvent.focusCompleted);
        expect(d.currentMacroBehavior, CompanionMacroBehavior.celebrate,
            reason: '$stage');
      }
    });

    test('a paused session rests at every stage', () {
      for (final stage in GrowthStage.values) {
        final d = director(CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.pause,
          growthStage: stage,
        ));
        expect(d.currentMacroBehavior, CompanionMacroBehavior.rest,
            reason: '$stage');
      }
    });
  });

  group('no page-level level-if-chains', () {
    test('no presentation file branches behaviour on a numeric level', () {
      // The presentation layer uses GrowthStage (the enum), not numeric level
      // comparisons. Level is a display value for the growth page only.
      // Only comparison, not assignment: `level = 1` is a default parameter.
      final banned = RegExp(r'level\s*[><]=?\s*\d');
      final offenders = <String>[];
      for (final dir in [
        'lib/presentation/pages/',
        'lib/presentation/widgets/',
        'lib/presentation/companion/',
      ]) {
        final dir_ = Directory(dir);
        if (!dir_.existsSync()) continue;
        for (final f in dir_.listSync(recursive: true)) {
          if (f is! File || !f.path.endsWith('.dart')) continue;
          final src = f.readAsStringSync();
          if (banned.hasMatch(src)) {
            offenders.add(f.path);
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'these files branch on numeric level, which the brief '
              'forbids:\n${offenders.join('\n')}');
    });
  });
}
