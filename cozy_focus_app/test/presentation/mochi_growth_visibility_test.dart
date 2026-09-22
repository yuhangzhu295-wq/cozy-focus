import 'package:cozy_focus_app/domain/growth/growth_level_curve.dart';
import 'package:cozy_focus_app/domain/growth/growth_stage.dart';
import 'package:cozy_focus_app/domain/growth/growth_stage_spec.dart';
import 'package:cozy_focus_app/domain/growth/mochi_growth_profile.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/pet_models.dart';
import 'package:cozy_focus_app/presentation/animations/pet_idle_fallback_view.dart';
import 'package:cozy_focus_app/presentation/animations/pet_motion_spec.dart';
import 'package:cozy_focus_app/presentation/companion/focus_phase.dart';
import 'package:cozy_focus_app/presentation/companion/pet_focus_activity.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ============================================================================
// STAGE 1 / STAGE 2 — growth is real, visible, and cannot touch business state
// ============================================================================

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: child),
      ),
    );

PetIdleFallbackViewState _fallback(WidgetTester tester) => tester
    .state<PetIdleFallbackViewState>(find.byType(PetIdleFallbackView).first);

PetProgress _progress(
    {required int level, required int xp, int happiness = 50}) {
  return PetProgress(
    id: 'progress-1',
    petId: 'pet-1',
    level: level,
    experiencePoints: xp,
    totalFocusMinutes: 0,
    happinessScore: happiness,
    updatedAt: DateTime(2026, 9, 22),
  );
}

void main() {
  // ==========================================================================
  // GrowthLevelCurve
  // ==========================================================================
  group('GrowthLevelCurve is total, monotonic and clamped', () {
    test('level rises with XP and never falls', () {
      var previous = GrowthLevelCurve.levelForXp(0);
      for (var xp = 0; xp <= 5000; xp += 7) {
        final level = GrowthLevelCurve.levelForXp(xp);
        expect(level, greaterThanOrEqualTo(previous),
            reason: 'level dropped at xp=$xp');
        expect(
            level,
            inInclusiveRange(
                GrowthLevelCurve.minLevel, GrowthLevelCurve.maxLevel));
        previous = level;
      }
    });

    test('negative XP cannot produce a level below the floor', () {
      expect(GrowthLevelCurve.levelForXp(-1), GrowthLevelCurve.minLevel);
      expect(GrowthLevelCurve.levelForXp(-99999), GrowthLevelCurve.minLevel);
    });

    test('XP beyond the cap holds the cap instead of running away', () {
      final atCap = GrowthLevelCurve.xpForLevel(GrowthLevelCurve.maxLevel);
      expect(GrowthLevelCurve.levelForXp(atCap), GrowthLevelCurve.maxLevel);
      expect(
          GrowthLevelCurve.levelForXp(atCap * 10), GrowthLevelCurve.maxLevel);
      expect(GrowthLevelCurve.isMaxLevel(atCap), isTrue);
      expect(GrowthLevelCurve.isMaxLevel(atCap - 1), isFalse);
    });

    test('xpForLevel and levelForXp are inverse inside the curve', () {
      for (var level = GrowthLevelCurve.minLevel;
          level <= GrowthLevelCurve.maxLevel;
          level++) {
        expect(GrowthLevelCurve.levelForXp(GrowthLevelCurve.xpForLevel(level)),
            level);
      }
    });

    test('xpWithinLevel is bounded and reports a full bar at the cap', () {
      for (var xp = 0; xp <= 4000; xp += 13) {
        expect(GrowthLevelCurve.xpWithinLevel(xp),
            inInclusiveRange(0, GrowthLevelCurve.xpPerLevel));
      }
      expect(
        GrowthLevelCurve.xpWithinLevel(
            GrowthLevelCurve.xpForLevel(GrowthLevelCurve.maxLevel) + 5),
        GrowthLevelCurve.xpPerLevel,
      );
    });

    test('the flat 100 XP-per-level convention matches the existing UI', () {
      // Two pages already draw a within-level bar as `experiencePoints % 100`.
      // If this constant moves, those bars become wrong.
      expect(GrowthLevelCurve.xpPerLevel, 100);
    });
  });

  // ==========================================================================
  // GrowthStageSpec table
  // ==========================================================================
  group('GrowthStageSpec.table is contiguous and total', () {
    test('level ranges ascend, touch and do not overlap', () {
      const table = GrowthStageSpec.table;
      expect(table, isNotEmpty);
      expect(table.first.minLevel, GrowthLevelCurve.minLevel);
      for (var i = 0; i < table.length; i++) {
        expect(table[i].maxLevel, greaterThanOrEqualTo(table[i].minLevel));
        if (i > 0) {
          expect(table[i].minLevel, table[i - 1].maxLevel + 1,
              reason: 'gap or overlap before ${table[i].stage.name}');
        }
      }
      expect(table.last.maxLevel, GrowthLevelCurve.maxLevel);
    });

    test('every stage has exactly one row', () {
      for (final stage in GrowthStage.values) {
        final rows = GrowthStageSpec.table.where((s) => s.stage == stage);
        expect(rows.length, 1, reason: '${stage.name} has ${rows.length} rows');
      }
    });

    test('growth never removes a V4.1 fixed micro channel', () {
      // V4.1 `designs/motion/11_宠物动效总览.png` titles the micro layer 固定微动
      // — fixed. A stage may damp it but must never disable it, so no stage's
      // amplitude factor may reach zero.
      for (final spec in GrowthStageSpec.table) {
        expect(spec.partMotionFactor, greaterThan(0.0),
            reason: '${spec.stage.name} would disable the fixed micro layer');
        expect(spec.blinkIntervalScale, greaterThan(0.0));
        expect(spec.earTwitchIntervalScale, greaterThan(0.0));
      }
    });

    test('proportion maturation stays a nudge, not a redesign', () {
      for (final spec in GrowthStageSpec.table) {
        expect(spec.maturityScale, inInclusiveRange(0.90, 1.06),
            reason: '${spec.stage.name} is no longer the same character');
      }
      // The whole span is deliberately under 10%.
      final span = GrowthStageSpec.table.last.maturityScale -
          GrowthStageSpec.table.first.maturityScale;
      expect(span, lessThan(0.10));
    });

    test('growth is additive: the flourish appears and never disappears', () {
      // Once a stage has the flourish, no later stage may lose it.
      var seen = false;
      for (final spec in GrowthStageSpec.table) {
        if (spec.hasIdleFlourish) seen = true;
        if (seen) {
          expect(spec.hasIdleFlourish, isTrue,
              reason:
                  '${spec.stage.name} lost a behaviour a younger stage had');
        }
      }
      expect(GrowthStageSpec.table.first.hasIdleFlourish, isFalse,
          reason: 'the youngest stage should have only the fixed layer');
      expect(seen, isTrue);
    });
  });

  // ==========================================================================
  // GrowthStageResolver
  // ==========================================================================
  group('GrowthStageResolver maps real PetProgress onto a stage', () {
    test('each stage boundary resolves to the right stage', () {
      for (final spec in GrowthStageSpec.table) {
        for (final level in [spec.minLevel, spec.maxLevel]) {
          final xp = GrowthLevelCurve.xpForLevel(level);
          expect(GrowthStageResolver.resolveStage(experiencePoints: xp),
              spec.stage,
              reason: 'level $level should be ${spec.stage.name}');
        }
      }
    });

    test('the stage comes from XP, not from the stored level', () {
      // A row whose stored `level` is stale must still resolve correctly. This
      // is the whole reason `level` is derived rather than trusted.
      final staleLow = _progress(level: 1, xp: 2500);
      expect(MochiGrowthProfile.fromProgress(staleLow).stage,
          GrowthStage.blooming);

      final staleHigh = _progress(level: 26, xp: 0);
      expect(
          MochiGrowthProfile.fromProgress(staleHigh).stage, GrowthStage.sprout);
    });

    test('resolving cannot mutate the PetProgress it reads', () {
      final progress = _progress(level: 3, xp: 750, happiness: 80);
      final before = (
        progress.level,
        progress.experiencePoints,
        progress.totalFocusMinutes,
        progress.happinessScore,
      );

      for (var i = 0; i < 10; i++) {
        MochiGrowthProfile.fromProgress(progress);
        GrowthStageResolver.resolve(
          experiencePoints: progress.experiencePoints,
          happinessScore: progress.happinessScore,
        );
      }

      expect(
        (
          progress.level,
          progress.experiencePoints,
          progress.totalFocusMinutes,
          progress.happinessScore,
        ),
        before,
      );
    });

    test('no progress data resolves to the youngest stage, not a random one',
        () {
      final profile = MochiGrowthProfile.fromProgress(null);
      expect(profile, MochiGrowthProfile.initial);
      expect(profile.stage, GrowthStage.sprout);
      expect(profile.level, GrowthLevelCurve.minLevel);
    });

    test('happiness nudges energy but can never change the stage', () {
      const xp = 1200; // level 13 → growing
      final sad =
          GrowthStageResolver.resolve(experiencePoints: xp, happinessScore: 0);
      final happy = GrowthStageResolver.resolve(
          experiencePoints: xp, happinessScore: 100);

      expect(sad.stage, happy.stage);
      expect(sad.partMotionFactor, lessThan(happy.partMotionFactor));
      // The nudge is bounded to a few percent either side.
      final ratio = happy.partMotionFactor / sad.partMotionFactor;
      expect(ratio, lessThan(1.15));
      expect(ratio, greaterThan(1.0));
    });

    test('out-of-range happiness clamps rather than extrapolating', () {
      final low =
          GrowthStageResolver.resolve(experiencePoints: 0, happinessScore: -50);
      final zero =
          GrowthStageResolver.resolve(experiencePoints: 0, happinessScore: 0);
      expect(low.partMotionFactor, zero.partMotionFactor);

      final high =
          GrowthStageResolver.resolve(experiencePoints: 0, happinessScore: 500);
      final full =
          GrowthStageResolver.resolve(experiencePoints: 0, happinessScore: 100);
      expect(high.partMotionFactor, full.partMotionFactor);
    });

    test('a stage change really does change the allowed behaviour set', () {
      final sprout =
          GrowthStageResolver.resolve(experiencePoints: 0, happinessScore: 50);
      final growing = GrowthStageResolver.resolve(
          experiencePoints: 1200, happinessScore: 50);

      expect(sprout.hasIdleFlourish, isFalse);
      expect(growing.hasIdleFlourish, isTrue);
      expect(sprout.maturityScale, isNot(growing.maturityScale));
      expect(sprout.idlePersonality, isNot(growing.idlePersonality));
      expect(sprout.displayName, isNot(growing.displayName));
      // And the fixed micro layer is still present in both.
      expect(sprout.partMotionFactor, greaterThan(0.0));
      expect(growing.partMotionFactor, greaterThan(0.0));
    });

    test('the flourish cadence only differs between stages that have it', () {
      // `flourishIntervalScale` is documented as inert when the stage has no
      // flourish, so the comparison has to be between two stages that do.
      final seedling = GrowthStageSpec.table[1];
      final blooming = GrowthStageSpec.table.last;

      expect(seedling.hasIdleFlourish, isTrue);
      expect(blooming.hasIdleFlourish, isTrue);
      // A shorter interval means the flourish fires more often, so a later
      // stage reads as the livelier one.
      expect(blooming.flourishIntervalScale,
          lessThan(seedling.flourishIntervalScale));
      expect(GrowthStageSpec.table.first.hasIdleFlourish, isFalse,
          reason: 'the youngest stage\'s scale should be inert');
    });

    test('profiles are value-comparable', () {
      expect(
        GrowthStageResolver.resolve(experiencePoints: 400, happinessScore: 50),
        GrowthStageResolver.resolve(experiencePoints: 400, happinessScore: 50),
      );
      expect(
        GrowthStageResolver.resolve(experiencePoints: 400, happinessScore: 50)
            .hashCode,
        GrowthStageResolver.resolve(experiencePoints: 400, happinessScore: 50)
            .hashCode,
      );
    });
  });

  // ==========================================================================
  // Growth reaches the renderer
  // ==========================================================================
  group('growth reaches the render tree', () {
    testWidgets('the maturity scale is the profile\'s, not a default',
        (tester) async {
      final young =
          GrowthStageResolver.resolve(experiencePoints: 0, happinessScore: 50);
      final grown = GrowthStageResolver.resolve(
          experiencePoints: 2500, happinessScore: 50);

      await tester.pumpWidget(_app(PetAvatarWidget(
        visualState: PetVisualState.idle,
        growthProfile: young,
      )));
      await tester.pump();
      expect(_fallback(tester).growthMaturityScale, young.maturityScale);

      await tester.pumpWidget(_app(PetAvatarWidget(
        visualState: PetVisualState.idle,
        growthProfile: grown,
      )));
      await tester.pump();
      expect(_fallback(tester).growthMaturityScale, grown.maturityScale);

      expect(grown.maturityScale, greaterThan(young.maturityScale));
    });

    testWidgets('the part-motion amplitude follows the stage', (tester) async {
      final young =
          GrowthStageResolver.resolve(experiencePoints: 0, happinessScore: 50);
      final grown = GrowthStageResolver.resolve(
          experiencePoints: 2500, happinessScore: 50);

      await tester.pumpWidget(_app(PetAvatarWidget(
        visualState: PetVisualState.idle,
        growthProfile: young,
      )));
      await tester.pump();
      final youngFactor = _fallback(tester).growthPartMotionFactor;

      await tester.pumpWidget(_app(PetAvatarWidget(
        visualState: PetVisualState.idle,
        growthProfile: grown,
      )));
      await tester.pump();
      final grownFactor = _fallback(tester).growthPartMotionFactor;

      expect(grownFactor, greaterThan(youngFactor));
    });

    testWidgets('the flourish layer only exists once the stage has it',
        (tester) async {
      final sprout =
          GrowthStageResolver.resolve(experiencePoints: 0, happinessScore: 50);
      final growing = GrowthStageResolver.resolve(
          experiencePoints: 1200, happinessScore: 50);

      await tester.pumpWidget(_app(PetAvatarWidget(
        visualState: PetVisualState.idle,
        growthProfile: sprout,
      )));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_fallback(tester).growthHasIdleFlourish, isFalse);
      expect(_fallback(tester).flourishController.isAnimating, isFalse);

      await tester.pumpWidget(_app(PetAvatarWidget(
        visualState: PetVisualState.idle,
        growthProfile: growing,
      )));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_fallback(tester).growthHasIdleFlourish, isTrue);
      expect(_fallback(tester).flourishController.isAnimating, isTrue);
    });

    testWidgets('the flourish contributes nothing before its window opens',
        (tester) async {
      final growing = GrowthStageResolver.resolve(
          experiencePoints: 1200, happinessScore: 50);

      await tester.pumpWidget(_app(PetAvatarWidget(
        visualState: PetVisualState.idle,
        growthProfile: growing,
      )));
      await tester.pump(const Duration(milliseconds: 100));
      final state = _fallback(tester);
      // Freshly started, so the cycle is near 0 — outside the window.
      expect(state.flourishController.value,
          lessThan(PetMotionSpec.idleFlourishWindowStart));
      expect(state.flourishLookValue, 0.0);
    });

    testWidgets('Reduced Motion suppresses the flourish entirely',
        (tester) async {
      final growing = GrowthStageResolver.resolve(
          experiencePoints: 1200, happinessScore: 50);

      await tester.pumpWidget(_app(
        PetAvatarWidget(
          visualState: PetVisualState.idle,
          growthProfile: growing,
        ),
        reduceMotion: true,
      ));
      await tester.pump(const Duration(milliseconds: 100));
      final state = _fallback(tester);
      expect(state.isReduceMotionActive, isTrue);
      expect(state.flourishController.isAnimating, isFalse);
      expect(state.flourishLookValue, 0.0);
      // The *rendered* frame, not the raw-channel probe: `headRotationValue`
      // forces Reduced Motion off on purpose and would still show the head lag.
      expect(state.renderedHeadRotation, 0.0);
      expect(state.renderedBodyScale, 1.0);
    });

    testWidgets('growth adds no ambient timers', (tester) async {
      // The ambient timer contract is blink + ear twitch = 2, asserted
      // throughout `pet_motion_view_test.dart`. Growth is presentation-only, so
      // it must widen neither that count nor the renderer's timer surface: the
      // flourish and the work cycle are AnimationControllers, which the ticker
      // provider owns and the state disposes.
      final growing = GrowthStageResolver.resolve(
          experiencePoints: 1200, happinessScore: 50);

      await tester.pumpWidget(_app(PetAvatarWidget(
        visualState: PetVisualState.idle,
        growthProfile: growing,
      )));
      await tester.pump(const Duration(milliseconds: 100));

      final state = _fallback(tester);
      expect(state.flourishController.isAnimating, isTrue);
      expect(state.workCycleController.isAnimating, isFalse);
      expect(state.breatheController.isAnimating, isTrue);

      // Nothing here allocates a `Timer`; if it did, the test framework would
      // report a pending timer at teardown and fail this test.
    });

    testWidgets('the renderer disposes its flourish and work-cycle controllers',
        (tester) async {
      final growing = GrowthStageResolver.resolve(
          experiencePoints: 1200, happinessScore: 50);

      await tester.pumpWidget(_app(PetAvatarWidget(
        visualState: PetVisualState.focus,
        growthProfile: growing,
        focusProgress: 0.3,
      )));
      await tester.pump(const Duration(milliseconds: 100));

      final state = _fallback(tester);
      final flourish = state.flourishController;
      final workCycle = state.workCycleController;
      expect(flourish.isAnimating, isTrue);
      expect(workCycle.isAnimating, isTrue);

      // Replacing the subtree disposes the state, which disposes both
      // controllers. `AnimationController` exposes no `isDisposed` on this
      // Flutter version, so disposal is proven the way the framework makes it
      // observable: a disposed controller asserts on further use.
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      await tester.pump();

      expect(flourish.isAnimating, isFalse);
      expect(workCycle.isAnimating, isFalse);
      expect(() => flourish.forward(), throwsAssertionError);
      expect(() => workCycle.forward(), throwsAssertionError);
    });
  });

  // ==========================================================================
  // STAGE 2 reaches the render tree
  // ==========================================================================
  group('the focus work cycle reaches the render tree', () {
    testWidgets('the work cycle runs in focus and stops outside it',
        (tester) async {
      await tester.pumpWidget(_app(const PetAvatarWidget(
        visualState: PetVisualState.idle,
        focusProgress: 0.3,
      )));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_fallback(tester).workCycleController.isAnimating, isFalse);

      await tester.pumpWidget(_app(const PetAvatarWidget(
        visualState: PetVisualState.focus,
        focusProgress: 0.3,
      )));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_fallback(tester).workCycleController.isAnimating, isTrue);

      await tester.pumpWidget(_app(const PetAvatarWidget(
        visualState: PetVisualState.pause,
        focusProgress: 0.3,
      )));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_fallback(tester).workCycleController.isAnimating, isFalse);
    });

    testWidgets('Mochi alternates beats through a focus cycle', (tester) async {
      await tester.pumpWidget(_app(const PetAvatarWidget(
        visualState: PetVisualState.focus,
        focusProgress: 0.3,
        focusPhase: FocusPhase.working,
        focusCategoryId: 'work',
      )));
      await tester.pump(const Duration(milliseconds: 100));

      final seen = <PetFocusActivity>{};
      // The cycle is PetMotionSpec.focusWorkCycle long; sample it densely.
      for (var i = 0; i < 40; i++) {
        seen.add(_fallback(tester).currentFocusActivity);
        await tester.pump(Duration(
            milliseconds: PetMotionSpec.focusWorkCycle.inMilliseconds ~/ 20));
      }

      expect(seen.length, greaterThanOrEqualTo(3),
          reason: 'a focus session must show more than one work behaviour; '
              'saw $seen');
      expect(seen, contains(PetFocusActivity.work));
    });

    testWidgets('the category flavour reaches the renderer', (tester) async {
      Future<PetWorkFlavour> flavourFor(String id) async {
        await tester.pumpWidget(_app(PetAvatarWidget(
          visualState: PetVisualState.focus,
          focusProgress: 0.3,
          focusPhase: FocusPhase.working,
          focusCategoryId: id,
        )));
        await tester.pump(const Duration(milliseconds: 100));
        return _fallback(tester).focusActivity.flavour;
      }

      expect(await flavourFor('study'), PetWorkFlavour.reading);
      expect(await flavourFor('work'), PetWorkFlavour.writing);
      expect(await flavourFor('life'), PetWorkFlavour.organizing);
      expect(await flavourFor('other'), PetWorkFlavour.generic);
    });

    testWidgets('a paused session presents no work beats', (tester) async {
      // The phase is supplied by CompanionAvatar, which reports null unless the
      // visual state is focus. A bare renderer with a null phase must stay
      // neutral rather than replaying the last session's beats.
      await tester.pumpWidget(_app(const PetAvatarWidget(
        visualState: PetVisualState.pause,
        focusProgress: 0.3,
      )));
      await tester.pump(const Duration(milliseconds: 100));
      final state = _fallback(tester);
      expect(state.focusActivity.isActive, isFalse);
      expect(state.focusActivityAmplitude, 1.0);
    });

    testWidgets('Reduced Motion suppresses the work beats', (tester) async {
      await tester.pumpWidget(_app(
        const PetAvatarWidget(
          visualState: PetVisualState.focus,
          focusProgress: 0.3,
          focusPhase: FocusPhase.working,
          focusCategoryId: 'work',
        ),
        reduceMotion: true,
      ));
      await tester.pump(const Duration(milliseconds: 100));
      final state = _fallback(tester);
      expect(state.isReduceMotionActive, isTrue);
      expect(state.workCycleController.isAnimating, isFalse);
      expect(state.renderedBodyScale, 1.0);
      expect(state.renderedHeadRotation, 0.0);
    });

    testWidgets('the phase changes the beats Mochi performs', (tester) async {
      Future<Set<PetFocusActivity>> beatsFor(FocusPhase phase) async {
        await tester.pumpWidget(_app(PetAvatarWidget(
          visualState: PetVisualState.focus,
          focusProgress: 0.3,
          focusPhase: phase,
        )));
        await tester.pump(const Duration(milliseconds: 100));
        final seen = <PetFocusActivity>{};
        for (var i = 0; i < 40; i++) {
          seen.add(_fallback(tester).currentFocusActivity);
          await tester.pump(Duration(
              milliseconds: PetMotionSpec.focusWorkCycle.inMilliseconds ~/ 20));
        }
        return seen;
      }

      final deep = await beatsFor(FocusPhase.deepFocus);
      final finishing = await beatsFor(FocusPhase.finishing);

      expect(deep, isNot(contains(PetFocusActivity.glance)));
      expect(finishing, contains(PetFocusActivity.glance));
    });
  });
}
