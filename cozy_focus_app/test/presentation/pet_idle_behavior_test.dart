import 'package:cozy_focus_app/domain/growth/growth_stage.dart';
import 'package:cozy_focus_app/domain/growth/growth_stage_spec.dart';
import 'package:cozy_focus_app/domain/growth/mochi_growth_profile.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/presentation/animations/pet_idle_fallback_view.dart';
import 'package:cozy_focus_app/presentation/animations/pet_motion_spec.dart';
import 'package:cozy_focus_app/presentation/companion/pet_idle_behavior.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ============================================================================
// The idle behaviour pool
//
// Growth has to change *what* Mochi does, not only how big it is or how fast it
// repeats itself. Two stages that perform the identical behaviour at different
// frequencies are still the same animal doing the same thing, and cadence alone
// cannot carry "Mochi grew up".
//
// These tests pin three separate claims:
//   1. the table is total, and every pool is additive and playable;
//   2. the boolean gate and the pool can never disagree;
//   3. the renderer actually walks the pool, and each behaviour moves only the
//      channels it declares.
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

Widget _idle(MochiGrowthProfile profile, {bool reduceMotion = false}) => _app(
      PetAvatarWidget(
        visualState: PetVisualState.idle,
        growthProfile: profile,
      ),
      reduceMotion: reduceMotion,
    );

/// The first XP that resolves to [stage].
///
/// Derived by search rather than hard-coded: a retune of the level curve then
/// fails loudly here instead of quietly making every test below exercise the
/// wrong stage and still pass.
MochiGrowthProfile _profileFor(GrowthStage stage) {
  for (var xp = 0; xp <= 8000; xp += 5) {
    final profile = GrowthStageResolver.resolve(
      experiencePoints: xp,
      happinessScore: 50,
    );
    if (profile.stage == stage) return profile;
  }
  fail('no XP in 0..8000 resolves to $stage');
}

/// Steps the flourish forward one second at a time until its window is open.
///
/// One large `pump` would not do. The pool advances on a *wrap* — the
/// controller's value going backwards — and a single frame that jumps from the
/// start of a cycle to the end of it never shows the value decreasing, so the
/// wrap would be missed and the pool would never move.
Future<void> _pumpIntoFlourishWindow(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    final value = _fallback(tester).flourishController.value;
    if (value > PetMotionSpec.idleFlourishWindowStart) return;
    await tester.pump(const Duration(seconds: 1));
  }
  fail('the flourish window never opened within 60 s');
}

/// Steps forward until the pool has advanced by [cycles] completed cycles.
Future<void> _pumpFlourishCycles(WidgetTester tester, int cycles) async {
  final state = _fallback(tester);
  final target = state.flourishCycleIndex + cycles;
  for (var i = 0; i < 400 && state.flourishCycleIndex < target; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  expect(state.flourishCycleIndex, target,
      reason: 'the pool did not advance by $cycles cycles within 400 s');
}

void main() {
  // ==========================================================================
  // The table
  // ==========================================================================
  group('PetIdleBehaviorSpec is total, additive and playable', () {
    test('every personality has exactly one row', () {
      expect(
        PetIdleBehaviorSpec.table.length,
        GrowthIdlePersonality.values.length,
      );
      for (final personality in GrowthIdlePersonality.values) {
        expect(PetIdleBehaviorSpec.of(personality).personality, personality);
      }
    });

    test('no pool repeats a behaviour, and no behaviour moves nothing', () {
      for (final row in PetIdleBehaviorSpec.table) {
        final kinds = row.pool.map((f) => f.kind).toList();
        expect(kinds.toSet().length, kinds.length,
            reason: '${row.personality.name} lists a behaviour twice');
        for (final flourish in row.pool) {
          // A spec that moves nothing is indistinguishable from the layer being
          // switched off, which is exactly what `gentle` already means. A pool
          // member must never be a no-op.
          expect(flourish.isVisible, isTrue,
              reason: '${row.personality.name}/${flourish.kind.label} '
                  'declares no motion at all');
        }
      }
    });

    test('the pool only ever grows, and never loses a behaviour', () {
      final sizes =
          PetIdleBehaviorSpec.table.map((r) => r.pool.length).toList();
      expect(sizes, <int>[0, 2, 3, 4]);

      for (var i = 1; i < PetIdleBehaviorSpec.table.length; i++) {
        final previous =
            PetIdleBehaviorSpec.table[i - 1].pool.map((f) => f.kind).toSet();
        final current =
            PetIdleBehaviorSpec.table[i].pool.map((f) => f.kind).toSet();

        expect(previous.difference(current), isEmpty,
            reason: 'a stage lost a behaviour an earlier stage had already '
                'learned: ${previous.difference(current)}');
        expect(current.length, greaterThan(previous.length));
      }
    });

    test('each stage opens with a behaviour it has just learned', () {
      // The pools are ordered newest-first on purpose: waiting a whole rotation
      // to see the new behaviour would hide the stage difference for a full
      // minute, and the point of a stage change is that it is noticeable.
      for (var i = 1; i < PetIdleBehaviorSpec.table.length; i++) {
        final previous =
            PetIdleBehaviorSpec.table[i - 1].pool.map((f) => f.kind).toSet();
        final newlyLearned = PetIdleBehaviorSpec.table[i].pool
            .map((f) => f.kind)
            .where((kind) => !previous.contains(kind))
            .toSet();

        expect(newlyLearned, isNotEmpty,
            reason: 'stage $i learned nothing new, so it differs from stage '
                '${i - 1} only in cadence');
        expect(newlyLearned,
            contains(PetIdleBehaviorSpec.table[i].pool.first.kind),
            reason: 'stage $i hides its new behaviour behind one it already '
                'had');
      }
    });

    test('the boolean gate and the pool agree on every stage', () {
      // `hasIdleFlourish` and "the pool is non-empty" are two spellings of one
      // fact. If a retune ever breaks that, the renderer (which gates on the
      // pool) and the domain contract (which publishes the boolean) would
      // disagree — one stage would either claim a flourish it has no behaviour
      // for, or hide one it has.
      for (final spec in GrowthStageSpec.table) {
        final pool = PetIdleBehaviorSpec.of(spec.idlePersonality).pool;
        expect(pool.isNotEmpty, spec.hasIdleFlourish,
            reason: '${spec.displayName} (${spec.stage.name}) declares '
                'hasIdleFlourish=${spec.hasIdleFlourish} but its '
                '${spec.idlePersonality.name} pool holds ${pool.length} '
                'behaviour(s)');
      }
    });

    test('the look-around behaviour still uses the retuned constants', () {
      // The original flourish was the only behaviour, and its amplitudes live in
      // `PetMotionSpec`. Keeping the table sourced from those constants is what
      // stops a retune from silently splitting into two sources of truth.
      expect(PetIdleFlourishes.lookAround.headYawDegrees,
          PetMotionSpec.idleFlourishLookDegrees);
      expect(PetIdleFlourishes.lookAround.earLeadDegrees,
          PetMotionSpec.idleFlourishEarLeadDegrees);
    });
  });

  // ==========================================================================
  // The renderer walks the pool
  // ==========================================================================
  group('the renderer plays the stage pool', () {
    testWidgets('the stage decides which behaviours Mochi can perform',
        (tester) async {
      for (final stage in GrowthStage.values) {
        final profile = _profileFor(stage);
        await tester.pumpWidget(_idle(profile));
        await tester.pump(const Duration(milliseconds: 100));

        final state = _fallback(tester);
        final expected = PetIdleBehaviorSpec.of(profile.idlePersonality).pool;

        expect(state.idleFlourishPool.map((f) => f.kind),
            expected.map((f) => f.kind),
            reason: 'the renderer and the table disagree at $stage');
        expect(state.currentIdleFlourish?.kind,
            expected.isEmpty ? null : expected.first.kind);
      }
    });

    testWidgets('the pool advances one behaviour per completed cycle',
        (tester) async {
      final profile = _profileFor(GrowthStage.growing);
      await tester.pumpWidget(_idle(profile));
      await tester.pump(const Duration(milliseconds: 100));

      final state = _fallback(tester);
      expect(state.flourishCycleIndex, 0);
      expect(state.currentIdleFlourish!.kind, PetIdleFlourishKind.tailSweep);

      await _pumpFlourishCycles(tester, 1);
      expect(state.currentIdleFlourish!.kind, PetIdleFlourishKind.lookAround);

      await _pumpFlourishCycles(tester, 1);
      expect(state.currentIdleFlourish!.kind, PetIdleFlourishKind.earPerk);
    });

    testWidgets('tearing the layer down does not advance the pool',
        (tester) async {
      final profile = _profileFor(GrowthStage.growing);
      await tester.pumpWidget(_idle(profile));
      await tester.pump(const Duration(milliseconds: 100));
      final state = _fallback(tester);

      // Get off zero so the reset below is a real change of value rather than a
      // no-op the listener would never see.
      await tester.pump(const Duration(seconds: 3));
      expect(state.flourishController.value, greaterThan(0.0));
      final before = state.flourishCycleIndex;

      // Exactly what every teardown path does: stop, then reset to zero. A
      // naive wrap detector would read this as a new cycle, and then entering a
      // focus session would silently shuffle the pool.
      state.flourishController.stop();
      state.flourishController.value = 0.0;
      await tester.pump();

      expect(state.flourishCycleIndex, before);
      expect(state.currentIdleFlourish!.kind, PetIdleFlourishKind.tailSweep);
    });

    testWidgets('a behaviour moves only the channels it declares',
        (tester) async {
      // `seedling` opens with the look-around: head and ears, and nothing else.
      final seedling = _profileFor(GrowthStage.seedling);
      await tester.pumpWidget(_idle(seedling));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_fallback(tester).currentIdleFlourish!.kind,
          PetIdleFlourishKind.lookAround);

      await _pumpIntoFlourishWindow(tester);
      final state = _fallback(tester);
      expect(state.currentIdleFlourish!.kind, PetIdleFlourishKind.lookAround);
      expect(state.flourishLookValue, greaterThan(0.0));
      expect(state.flourishEarValue, greaterThan(0.0));
      expect(state.flourishTailValue, 0.0);
      expect(state.flourishLiftValue, 0.0);
    });

    testWidgets(
        'the settle lifts the body and the ear-perk leaves the head put',
        (tester) async {
      // `blooming` opens with the settle — the only behaviour that moves the
      // body — and reaches the ear-perk one cycle later.
      final blooming = _profileFor(GrowthStage.blooming);
      await tester.pumpWidget(_idle(blooming));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_fallback(tester).currentIdleFlourish!.kind,
          PetIdleFlourishKind.settle);

      await _pumpIntoFlourishWindow(tester);
      final settle = _fallback(tester);
      expect(settle.currentIdleFlourish!.kind, PetIdleFlourishKind.settle);
      expect(settle.flourishLiftValue, greaterThan(0.0));
      expect(settle.flourishTailValue, greaterThan(0.0));

      await _pumpFlourishCycles(tester, 1);
      expect(_fallback(tester).currentIdleFlourish!.kind,
          PetIdleFlourishKind.lookAround);

      await _pumpFlourishCycles(tester, 1);
      await _pumpIntoFlourishWindow(tester);
      final perk = _fallback(tester);
      expect(perk.currentIdleFlourish!.kind, PetIdleFlourishKind.earPerk);
      expect(perk.flourishEarValue, greaterThan(0.0));
      // The whole point of the behaviour: the head stays where it is.
      expect(perk.flourishLookValue, 0.0);
      expect(perk.flourishLiftValue, 0.0);
    });

    testWidgets('every stage contributes nothing before its window opens',
        (tester) async {
      for (final stage in GrowthStage.values) {
        await tester.pumpWidget(_idle(_profileFor(stage)));
        await tester.pump(const Duration(milliseconds: 100));

        final state = _fallback(tester);
        expect(state.flourishController.value,
            lessThan(PetMotionSpec.idleFlourishWindowStart));
        expect(state.flourishLookValue, 0.0, reason: 'at $stage');
        expect(state.flourishEarValue, 0.0, reason: 'at $stage');
        expect(state.flourishTailValue, 0.0, reason: 'at $stage');
        expect(state.flourishLiftValue, 0.0, reason: 'at $stage');
      }
    });

    testWidgets('Reduced Motion keeps the pool but plays none of it',
        (tester) async {
      final profile = _profileFor(GrowthStage.blooming);
      await tester.pumpWidget(_idle(profile, reduceMotion: true));
      await tester.pump(const Duration(milliseconds: 100));

      final state = _fallback(tester);
      // The pool is a capability, not a motion: Reduced Motion must not rewrite
      // what the stage can do, only stop it being performed.
      expect(state.idleFlourishPool, isNotEmpty);
      expect(state.flourishController.isAnimating, isFalse);
      expect(state.flourishLookValue, 0.0);
      expect(state.flourishEarValue, 0.0);
      expect(state.flourishTailValue, 0.0);
      expect(state.flourishLiftValue, 0.0);
    });
  });
}
