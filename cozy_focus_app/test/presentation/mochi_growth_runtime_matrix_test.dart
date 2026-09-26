import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cozy_focus_app/domain/growth/growth_stage.dart';
import 'package:cozy_focus_app/domain/growth/growth_stage_spec.dart';
import 'package:cozy_focus_app/domain/growth/mochi_growth_profile.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/presentation/animations/pet_idle_fallback_view.dart';
import 'package:cozy_focus_app/presentation/animations/pet_interaction_spec.dart';
import 'package:cozy_focus_app/presentation/animations/pet_motion_spec.dart';
import 'package:cozy_focus_app/presentation/companion/focus_phase.dart';
import 'package:cozy_focus_app/presentation/companion/pet_focus_activity.dart';
import 'package:cozy_focus_app/presentation/companion/pet_idle_behavior.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ============================================================================
// Stage C — the four-stage runtime matrix
//
// §21 requires a matrix produced from TEST-ONLY data covering, per stage:
// resolved stage, visual profile, an idle sample, a focus sample, a touch
// sample, the size ratio, and how many behaviours are available.
//
// The matrix is *generated*, not hand-written: this test resolves four synthetic
// `PetProgress` rows, mounts the real avatar for each of them, reads the real
// renderer state, and writes the result to
// `outputs/ai_handoff/mochi_growth_runtime_matrix.json`. Re-running it is how
// the matrix is refreshed.
//
// Nothing here writes business state. The synthetic rows exist only inside this
// test; no XP, coin, happiness, session, craft job or inventory value is created
// or changed.
// ============================================================================

const double _radToDeg = 180 / math.pi;

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

PetIdleFallbackViewState _fallback(WidgetTester tester) => tester
    .state<PetIdleFallbackViewState>(find.byType(PetIdleFallbackView).first);

/// The lowest XP that resolves to [stage], found by search so a retune of the
/// level curve fails loudly here rather than silently sampling the wrong tier.
///
/// The XP is returned alongside the profile because the matrix has to record
/// which TEST-ONLY input produced which row.
({MochiGrowthProfile profile, int xp}) _sampleFor(GrowthStage stage) {
  for (var xp = 0; xp <= 8000; xp += 5) {
    final profile = GrowthStageResolver.resolve(
      experiencePoints: xp,
      happinessScore: 50,
    );
    if (profile.stage == stage) return (profile: profile, xp: xp);
  }
  fail('no XP in 0..8000 resolves to $stage');
}

/// Steps the flourish into its window one second at a time.
///
/// One large pump would miss the wrap that advances the behaviour pool, so the
/// cycle is stepped.
Future<void> _pumpIntoFlourishWindow(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    if (_fallback(tester).flourishController.value >
        PetMotionSpec.idleFlourishWindowStart) {
      return;
    }
    await tester.pump(const Duration(seconds: 1));
  }
  fail('the flourish window never opened within 60 s');
}

Map<String, Object?> _idleSample(PetIdleFallbackViewState state) {
  final flourish = state.currentIdleFlourish;
  return <String, Object?>{
    'behaviour': flourish?.kind.label,
    'cycle_value_at_sample': state.flourishController.value,
    'observed_head_yaw_deg': state.flourishLookValue * _radToDeg,
    'observed_ear_lead_deg': state.flourishEarValue * _radToDeg,
    'observed_tail_wag_deg': state.flourishTailValue * _radToDeg,
    'observed_body_lift_px': state.flourishLiftValue,
    'declared_peak_head_yaw_deg': flourish?.headYawDegrees ?? 0.0,
    'declared_peak_ear_lead_deg': flourish?.earLeadDegrees ?? 0.0,
    'declared_peak_tail_wag_deg': flourish?.tailWagDegrees ?? 0.0,
    'declared_peak_body_lift_px': flourish?.bodyLiftPx ?? 0.0,
    'rendered_body_scale': state.renderedBodyScale,
    'rendered_head_rotation_rad': state.renderedHeadRotation,
  };
}

Map<String, Object?> _touchSample(PetVisualState visualState) {
  final spec = PetInteractionSpec.forState(visualState);
  if (spec == null) {
    return <String, Object?>{'spec': null, 'answers': false};
  }
  return <String, Object?>{
    'spec': spec.kind.name,
    'answers': true,
    'tap_duration_ms': spec.tapDuration.inMilliseconds,
    'stroke_duration_ms': spec.strokeDuration.inMilliseconds,
    'tap_head_tilt_deg': spec.tapHeadTiltDegrees,
    'tap_ear_tilt_deg': spec.tapEarTiltDegrees,
    'tap_tail_tilt_deg': spec.tapTailTiltDegrees,
    'stroke_shows_heart': spec.strokeShowsHeart,
    'owned_channels': spec.ownedChannels.map((c) => c.name).toList()..sort(),
  };
}

void main() {
  group('Stage C — four-stage runtime matrix', () {
    testWidgets('every stage resolves, renders and is sampled', (tester) async {
      final matrix = <Map<String, Object?>>[];

      for (final stage in GrowthStage.values) {
        final sample = _sampleFor(stage);
        final profile = sample.profile;
        final spec = GrowthStageSpec.of(stage);
        final pool = PetIdleBehaviorSpec.of(profile.idlePersonality).pool;

        // --- idle sample ---------------------------------------------------
        // Each stage is mounted under its own key so it gets a fresh renderer
        // State. Without that the four stages would share one State — the same
        // `PetIdleFallbackView` in the same tree position — and the idle
        // behaviour cursor would carry over from the previous stage, so the
        // matrix would record an arbitrary rotation offset instead of the
        // behaviour the stage actually opens with.
        await tester.pumpWidget(_app(PetAvatarWidget(
          key: ValueKey('idle-${stage.name}'),
          visualState: PetVisualState.idle,
          growthProfile: profile,
        )));
        await tester.pump(const Duration(milliseconds: 100));

        expect(_fallback(tester).growthMaturityScale, profile.maturityScale);
        if (pool.isEmpty) {
          // The youngest stage has not developed the layer, so there is no
          // window to wait for and no behaviour to sample.
          expect(_fallback(tester).flourishController.isAnimating, isFalse);
        } else {
          await _pumpIntoFlourishWindow(tester);
        }
        final idle = _idleSample(_fallback(tester));

        if (pool.isNotEmpty) {
          expect(idle['behaviour'], pool.first.kind.label,
              reason:
                  '${stage.name} did not open with its newest behaviour, so '
                  'the stage difference would be hidden behind a behaviour the '
                  'stage already had');
        }

        // --- focus sample --------------------------------------------------
        // 30 % of a session is the WORKING phase. Half of the 4.5 s work cycle
        // is a fixed, reproducible point inside the beat schedule.
        const progress = 0.3;
        final resolved = FocusPhaseResolver.resolve(progress);
        expect(resolved, FocusPhase.working,
            reason: '30 % of a session must be the WORKING phase');
        final phase = resolved!;

        await tester.pumpWidget(_app(PetAvatarWidget(
          key: ValueKey('focus-${stage.name}'),
          visualState: PetVisualState.focus,
          growthProfile: profile,
          focusProgress: progress,
          focusPhase: phase,
          focusCategoryId: 'study',
        )));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(PetMotionSpec.focusWorkCycle ~/ 2);

        final focusState = _fallback(tester);
        final workingActivities = PetFocusActivitySchedule.windowsFor(phase)
            .map((w) => w.activity)
            .toSet();
        expect(workingActivities, contains(focusState.currentFocusActivity),
            reason:
                'the focus sample fell outside the phase it was sampled at');

        matrix.add(<String, Object?>{
          'stage': stage.name,
          'display_name': spec.displayName,
          'level_range': '${spec.minLevel}-${spec.maxLevel}',
          'resolved_level': profile.level,
          'test_only_xp': sample.xp,
          'visual_profile': <String, Object?>{
            'maturity_scale': profile.maturityScale,
            'part_motion_factor': profile.partMotionFactor,
            'blink_interval_scale': profile.blinkIntervalScale,
            'ear_twitch_interval_scale': profile.earTwitchIntervalScale,
            'has_idle_flourish': profile.hasIdleFlourish,
            'flourish_interval_scale': profile.flourishIntervalScale,
            'flourish_cycle_ms':
                PetMotionSpec.idleFlourishCycle.inMilliseconds *
                    profile.flourishIntervalScale,
            'idle_personality': profile.idlePersonality.name,
          },
          'size_ratio': profile.maturityScale,
          'available_behaviour_count': pool.length,
          'idle_behaviours': pool.map((f) => f.kind.label).toList(),
          'idle_sample': idle,
          'focus_sample': <String, Object?>{
            'progress': progress,
            'phase': phase.name,
            'activity': focusState.currentFocusActivity.name,
            'amplitude_scale': focusState.focusActivityAmplitude,
            'flavour': PetWorkFlavourResolver.forCategoryId('study').name,
            'rendered_body_scale': focusState.renderedBodyScale,
          },
          'touch_sample': _touchSample(PetVisualState.idle),
        });
      }

      // --- the matrix's own invariants ------------------------------------
      expect(matrix, hasLength(4));
      expect(matrix.map((r) => r['stage']),
          GrowthStage.values.map((s) => s.name).toList());

      // Growth must be more than a scale: proportion, amplitude, cadence and
      // the behaviour count each have to move on their own.
      final scales = matrix.map((r) => r['size_ratio'] as double).toList();
      expect(scales.toSet(), hasLength(4), reason: 'two stages share a size');

      final factors = matrix
          .map((r) => (r['visual_profile']
              as Map<String, Object?>)['part_motion_factor'] as double)
          .toList();
      expect(factors.toSet(), hasLength(4),
          reason: 'two stages share an amplitude');

      final counts =
          matrix.map((r) => r['available_behaviour_count'] as int).toList();
      expect(counts, <int>[0, 2, 3, 4]);

      for (var i = 1; i < counts.length; i++) {
        expect(counts[i], greaterThan(counts[i - 1]),
            reason: 'stage $i offers no more behaviour than stage ${i - 1}');
      }

      // §25, structurally: the WORKING phase has to schedule at least two
      // distinct beats. Whether they *read* as two behaviours needs frames —
      // that is Stage D — but a single-beat phase could never pass it.
      final workingDistinct =
          PetFocusActivitySchedule.windowsFor(FocusPhase.working)
              .map((w) => w.activity.name)
              .toSet();
      expect(workingDistinct.length, greaterThanOrEqualTo(2));

      // --- write the matrix ------------------------------------------------
      final payload = <String, Object?>{
        'generated_by':
            'test/presentation/mochi_growth_runtime_matrix_test.dart',
        'note': 'TEST-ONLY data. No business value is created or changed by '
            'generating this file.',
        'stages': matrix,
        'focus_beat_schedule': <String, Object?>{
          for (final phase in FocusPhase.values)
            phase.name: PetFocusActivitySchedule.windowsFor(phase)
                .map((w) => <String, Object?>{
                      'start': w.start,
                      'end': w.end,
                      'activity': w.activity.name,
                    })
                .toList(),
        },
        'interaction_specs': <String, Object?>{
          for (final state in PetVisualState.values)
            state.name: _touchSample(state),
        },
      };

      final file = File('outputs/ai_handoff/mochi_growth_runtime_matrix.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
      );
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
    });
  });
}
