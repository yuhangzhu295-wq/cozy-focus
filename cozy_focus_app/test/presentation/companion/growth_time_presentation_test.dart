import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/domain/growth/growth_stage.dart';
import 'package:cozy_focus_app/presentation/companion/companion_avatar.dart';
import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_ambient_modifiers.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_behavior_director.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/random_source.dart';
import 'package:cozy_focus_app/presentation/companion/time_of_day.dart';
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

import '../companion/runtime/catalog_test_support.dart';

class _PresetHomeController extends HomeController {
  final HomeUIState _preset;
  _PresetHomeController(super.ref, this._preset);

  @override
  Future<void> loadHomeData() async {
    state = _preset;
  }
}

void main() {
  final catalog = loadShippedCatalog();

  CompanionBehaviorDirector director({
    CompanionBaseContext base = CompanionBaseContext.home,
    GrowthStage stage = GrowthStage.sprout,
    TimeOfDayBand band = TimeOfDayBand.midday,
    double? craftProgress,
    int seed = 9,
  }) =>
      CompanionBehaviorDirector(
        catalog: catalog,
        context: CompanionContext(
          companionId: CompanionId.dog,
          baseContext: base,
          growthStage: stage,
          timeOfDay: band,
          craftProgress: craftProgress,
        ),
        random: SeededRandomSource(seed),
      );

  /// The distinct behaviours a director presents over [seconds].
  Set<CompanionMacroBehavior> poolOver(
    CompanionBehaviorDirector d,
    int seconds,
  ) {
    final seen = <CompanionMacroBehavior>{};
    for (var ms = 0; ms <= seconds * 1000; ms += 1000) {
      d.advanceTo(Duration(milliseconds: ms));
      final m = d.currentMacroBehavior;
      if (m != null) seen.add(m);
    }
    return seen;
  }

  group('growth changes the visible behaviour pool', () {
    test('a grown companion does more things than a sprout', () {
      final sprout = poolOver(director(stage: GrowthStage.sprout), 900);
      final blooming = poolOver(director(stage: GrowthStage.blooming), 900);

      expect(
        blooming.difference(sprout),
        isNotEmpty,
        reason: 'growth must add visible behaviour, not just scale.\n'
            'sprout=$sprout blooming=$blooming',
      );
    });

    test('growth is additive — a later stage keeps what an earlier one had',
        () {
      for (var i = 1; i < GrowthStage.values.length; i++) {
        final earlier =
            poolOver(director(stage: GrowthStage.values[i - 1]), 900);
        final later = poolOver(director(stage: GrowthStage.values[i]), 900);
        expect(
          earlier.difference(later),
          isEmpty,
          reason: '${GrowthStage.values[i]} lost ${earlier.difference(later)}',
        );
      }
    });

    test('a grown companion also changes behaviour more often', () {
      final sprout = CompanionAmbientModifiers.growth[GrowthStage.sprout]!;
      final blooming = CompanionAmbientModifiers.growth[GrowthStage.blooming]!;
      expect(blooming.dwellScale, lessThan(sprout.dwellScale));
    });
  });

  group('growth does not change task behaviour', () {
    test('focus presents the same pool at every stage', () {
      // A focus context needs a live session to be grounded.
      CompanionBehaviorDirector focusDirector(GrowthStage stage) =>
          CompanionBehaviorDirector(
            catalog: catalog,
            context: CompanionContext(
              companionId: CompanionId.dog,
              baseContext: CompanionBaseContext.focus,
              hasActiveSession: true,
              growthStage: stage,
            ),
            random: SeededRandomSource(4),
          );

      final sprout = poolOver(focusDirector(GrowthStage.sprout), 600);
      final blooming = poolOver(focusDirector(GrowthStage.blooming), 600);
      expect(sprout, isNotEmpty);
      expect(blooming, sprout);
    });

    test('an ungrounded focus context presents nothing at all', () {
      final ungrounded = CompanionBehaviorDirector(
        catalog: catalog,
        context: const CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.focus,
        ),
        random: SeededRandomSource(4),
      );
      expect(
        poolOver(ungrounded, 120)
            .any(CompanionMacroBehavior.focusBehaviors.contains),
        isFalse,
      );
    });

    test('craft is unaffected by stage and by the hour', () {
      final a = director(
        base: CompanionBaseContext.craft,
        stage: GrowthStage.sprout,
        craftProgress: 0.5,
      );
      final b = director(
        base: CompanionBaseContext.craft,
        stage: GrowthStage.blooming,
        band: TimeOfDayBand.lateNight,
        craftProgress: 0.5,
      );
      expect(a.currentMacroBehavior, CompanionMacroBehavior.craftWork);
      expect(b.currentMacroBehavior, CompanionMacroBehavior.craftWork);
      expect(b.ambientModifier.extraEligible, isEmpty);
    });

    test('the modifiers are neutral outside ambient contexts', () {
      for (final context in [
        CompanionBaseContext.focus,
        CompanionBaseContext.craft,
        CompanionBaseContext.pause,
        CompanionBaseContext.sleep,
      ]) {
        final modifier = CompanionAmbientModifiers.resolve(
          baseContext: context,
          growthStage: GrowthStage.blooming,
          timeOfDayBand: TimeOfDayBand.lateNight,
        );
        expect(modifier.extraEligible, isEmpty, reason: context.id);
        expect(modifier.dwellScale, 1.0, reason: context.id);
      }
    });
  });

  group('time of day is presentation only', () {
    test('late night calms the ambient pool', () {
      final modifier = CompanionAmbientModifiers.resolve(
        baseContext: CompanionBaseContext.home,
        growthStage: GrowthStage.sprout,
        timeOfDayBand: TimeOfDayBand.lateNight,
      );
      expect(
          modifier.extraEligible, contains(CompanionMacroBehavior.microRest));
      expect(modifier.dwellScale, greaterThan(1.0));
    });

    test('daytime contributes nothing', () {
      for (final band in [
        TimeOfDayBand.morning,
        TimeOfDayBand.midday,
        TimeOfDayBand.afternoon,
        TimeOfDayBand.evening,
      ]) {
        // The band's own contribution is neutral; growth still applies, which is
        // why this reads the band table rather than the combined modifier.
        final bandModifier = CompanionAmbientModifiers.timeOfDay[band]!;
        expect(bandModifier.extraEligible, isEmpty, reason: band.label);
        expect(bandModifier.dwellScale, 1.0, reason: band.label);
      }
    });

    test('the band is carried into the intent for copy', () {
      final d = director(band: TimeOfDayBand.lateNight);
      expect(d.intent.timeOfDay, TimeOfDayBand.lateNight);
    });
  });

  group('reduced motion preserves the semantic pose at every stage', () {
    test('a reduced-motion companion presents the same pool', () {
      final normal = director(stage: GrowthStage.growing);
      final reduced = CompanionBehaviorDirector(
        catalog: catalog,
        context: const CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.home,
          growthStage: GrowthStage.growing,
          reducedMotion: true,
        ),
        random: SeededRandomSource(9),
      );
      expect(poolOver(reduced, 900), poolOver(normal, 900));
    });
  });

  group('business isolation', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    Future<Map<String, int>> snapshot() async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      final counts = <String, int>{};
      for (final row in rows) {
        final name = row.data['name'] as String;
        final count = await db
            .customSelect('SELECT COUNT(*) AS c FROM "$name"')
            .getSingle();
        counts[name] = count.data['c'] as int;
      }
      return counts;
    }

    testWidgets(
        'pose switching, tap, long press and a companion switch change no '
        'business row', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          companionSelectionStoreProvider
              .overrideWithValue(InMemoryCompanionSelectionStore()),
          homeControllerProvider.overrideWith(
            (ref) => _PresetHomeController(
              ref,
              const HomeUIState(hasActiveSession: true),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Center(child: CompanionAvatar(size: 140)),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final before = await snapshot();

      // Exercise every presentation-only operation the brief lists.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byType(CompanionAvatar));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.longPress(find.byType(CompanionAvatar));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await container
          .read(companionSelectionProvider.notifier)
          .select(CompanionId.cat);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(CompanionAvatar));
      await tester.pump(const Duration(milliseconds: 50));
      await container
          .read(companionSelectionProvider.notifier)
          .select(CompanionId.rabbit);
      await tester.pump(const Duration(milliseconds: 50));
      // Let the presentation clock run for a while.
      await tester.pump(const Duration(seconds: 2));

      final after = await snapshot();
      expect(after, before,
          reason: 'presentation must not write business rows');
    });
  });
}
