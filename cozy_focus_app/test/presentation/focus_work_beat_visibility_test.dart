import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/presentation/animations/pet_idle_fallback_view.dart';
import 'package:cozy_focus_app/presentation/animations/pet_motion_spec.dart';
import 'package:cozy_focus_app/presentation/companion/focus_phase.dart';
import 'package:cozy_focus_app/presentation/companion/mochi_layered_renderer.dart';
import 'package:cozy_focus_app/presentation/companion/pet_focus_activity.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ============================================================================
// Stage D — "is the focus loop more than one breathing animation?"
//
// §25's FAIL condition is 「整个计时器只有 Mochi 专注中 + 同一呼吸动画」, and its
// positive requirement is 「正常会话至少 2 种可见可区分的工作行为变体」.
//
// `focus_phase_test.dart` already proves the *schedule* declares five windows per
// phase with four distinct amplitude regimes. What it cannot prove is that those
// regimes reach the screen — a declared schedule that `_frameFor` never reads
// would pass every one of those tests.
//
// The device series in `companion_final/focus_session.json` cannot settle it
// either, and it is worth being precise about why: five frames taken 3 s apart
// land on five *unknown* cycle positions, so a small frame-to-frame difference
// is equally consistent with "the beat changed" and with "the same beat was
// sampled at a different point of its own oscillation". A screenshot pair can
// show that Mochi moves. It cannot show *which beat* was on screen.
//
// So this file runs the experiment the device run cannot: **hold the cycle
// position constant and vary only the phase.**
//
// A cycle position of 0.70 resolves to a different beat in each of the three
// mid-session phases:
//
//     working   (0.68–0.86) -> work       amplitude 1.00
//     deepFocus (0.62–0.86) -> microIdle  amplitude 0.45
//     finishing (0.58–0.76) -> glance     amplitude 1.00 + a 2.2° head lift
//
// The `work` window at 0.68–0.86 is the brief's "work variant": the working
// phase walks `prepare -> work -> microIdle -> work -> returning`, so `work`
// appears twice with different neighbours. Landing on the *second* `work` is
// what makes 0.70 a three-way split instead of a two-way one.
//
// Progress, category, growth stage and clock time are all held equal, so the
// only input that differs is the phase, and the phase's only effect on the body
// channels is `beat.amplitudeScale`. Whatever the three frames differ by is
// therefore attributable to the beat and to nothing else.
//
// The measured numbers are written to
// `outputs/ai_handoff/companion_stage_d_beat_frames.json` so the gate report can
// cite them instead of re-deriving them.
//
// Nothing here writes business state: no XP, coin, session, craft job or
// inventory value is created or changed. TEST-ONLY inputs throughout.
// ============================================================================

/// The size the focus page actually mounts Mochi at
/// (`focus_active_page.dart`, the running-session branch).
const double _focusAvatarSize = 160;

/// The density of the device the runtime evidence is captured on
/// (`emulator-5554`, 1080x2400 @ 420 dpi). Used only to express the measured
/// logical-pixel differences in the physical pixels a screenshot would show.
const double _devicePixelRatio = 2.625;

/// The category the runtime sample used, so the flavour factor is the real one.
const String _categoryId = 'study';

/// Held constant across every sample. It fixes `progressIntensity`, which is a
/// *separate* multiplier on the same channels as the beat — varying it would
/// confound the measurement.
const double _progress = 0.3;

/// The cycle position the experiment is anchored on. See the header.
const double _probePosition = 0.70;

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

PetIdleFallbackViewState _fallback(WidgetTester tester) => tester
    .state<PetIdleFallbackViewState>(find.byType(PetIdleFallbackView).first);

/// One frame's worth of the channels the focus loop owns.
///
/// `earRotation` / `tailRotation` are deliberately absent: the ear twitch is
/// scheduled by a `Timer` with a random interval, so it is not reproducible
/// across samples and asserting on it would be flaky by construction.
class _BeatFrame {
  final FocusPhase phase;
  final double cyclePosition;
  final PetFocusActivity activity;
  final double amplitude;
  final double intensity;
  final double scale;
  final double dy;
  final double rotation;
  final double headRotation;

  const _BeatFrame({
    required this.phase,
    required this.cyclePosition,
    required this.activity,
    required this.amplitude,
    required this.intensity,
    required this.scale,
    required this.dy,
    required this.rotation,
    required this.headRotation,
  });

  /// Displacement from the neutral pose, in logical pixels. `scale` is a
  /// multiplier on the whole sprite so it is expressed as a size *change*
  /// against the real sprite height, which is what a screenshot would show.
  Map<String, Object?> toJson() => <String, Object?>{
        'phase': phase.name,
        'cycle_position': cyclePosition,
        'activity': activity.name,
        'amplitude_scale': amplitude,
        'progress_intensity': intensity,
        'body_scale': scale,
        'body_dy_pt': dy,
        'body_rotation_deg': rotation * 180 / math.pi,
        'head_rotation_deg': headRotation * 180 / math.pi,
      };
}

/// Mounts Mochi under [phase] and pumps the work cycle to exactly
/// [cyclePosition].
///
/// The work-cycle controller is created in `initState` and repeats for the whole
/// `focusWorkCycle`, so the *test clock* position is the cycle position: pumping
/// `cyclePosition * cycle` after the mount lands on the beat, and the assertion
/// below fails loudly if it does not.
Future<_BeatFrame> _frameAt(
  WidgetTester tester, {
  required FocusPhase phase,
  double cyclePosition = _probePosition,
}) async {
  // A fresh key forces a fresh `State`, so each sample gets its own controllers
  // starting at the same relative clock offset. Without it the second sample
  // would inherit the first one's cycle position.
  await tester.pumpWidget(_app(PetAvatarWidget(
    key: ValueKey('${phase.name}-$cyclePosition'),
    visualState: PetVisualState.focus,
    size: _focusAvatarSize,
    showStateBadge: false,
    focusProgress: _progress,
    focusPhase: phase,
    focusCategoryId: _categoryId,
  )));

  final cycleMs = PetMotionSpec.focusWorkCycle.inMilliseconds;
  await tester.pump(Duration(milliseconds: (cycleMs * cyclePosition).round()));

  final state = _fallback(tester);
  expect(
    state.workCycleController.value,
    closeTo(cyclePosition, 0.002),
    reason: 'the sample did not land on the cycle position it asked for, so '
        'the beat it reports is not the beat it measured',
  );

  return _BeatFrame(
    phase: phase,
    cyclePosition: state.workCycleController.value,
    activity: state.currentFocusActivity,
    amplitude: state.focusActivityAmplitude,
    intensity: state.progressIntensity,
    scale: state.bodyScaleForTesting,
    dy: state.bodyDyForTesting,
    rotation: state.bodyRotationForTesting,
    headRotation: state.headRotationValue,
  );
}

void main() {
  group('Stage D — the work beats reach the screen, not just the schedule', () {
    testWidgets('one cycle position resolves to a different beat per phase',
        (tester) async {
      final working = await _frameAt(tester, phase: FocusPhase.working);
      final deep = await _frameAt(tester, phase: FocusPhase.deepFocus);
      final finishing = await _frameAt(tester, phase: FocusPhase.finishing);

      // The same instant of the same 4.5 s loop, three different behaviours.
      expect(working.activity, PetFocusActivity.work);
      expect(deep.activity, PetFocusActivity.microIdle);
      expect(finishing.activity, PetFocusActivity.glance);

      // And the beat the renderer reports is the beat the schedule declares for
      // that position, so the two can never drift apart.
      for (final frame in <_BeatFrame>[working, deep, finishing]) {
        final declared = PetFocusActivitySchedule.beatAt(
          frame.cyclePosition,
          frame.phase,
        );
        expect(frame.activity, declared.activity,
            reason: '${frame.phase.name} renders a beat its own schedule does '
                'not put at ${frame.cyclePosition}');
        expect(
            frame.amplitude,
            PetFocusActivitySpec.of(declared.activity).amplitudeScale *
                PetWorkFlavourSpec.of(
                        PetWorkFlavourResolver.forCategoryId(_categoryId))
                    .amplitudeScale);
      }
    });

    testWidgets('the calm beat renders measurably calmer than the busy one',
        (tester) async {
      final busy = await _frameAt(tester, phase: FocusPhase.working);
      final calm = await _frameAt(tester, phase: FocusPhase.deepFocus);

      expect(busy.activity, PetFocusActivity.work);
      expect(calm.activity, PetFocusActivity.microIdle);

      // Every other input is held equal, so `progressIntensity` must be too —
      // otherwise the ratio below would be measuring the progress ramp rather
      // than the beat.
      expect(calm.intensity, closeTo(busy.intensity, 1e-12));
      expect(calm.intensity, lessThan(1.0),
          reason: 'the progress binding is supposed to be active here, so this '
              'sample is exercising both multipliers at once');

      // `_frameFor` scales the delta away from neutral by `intensity` and then
      // by `beat.amplitudeScale`, so the ratio of the two frames *is* the ratio
      // of the two beats.
      final beatRatio = busy.amplitude / calm.amplitude;
      expect(beatRatio, closeTo(1.0 / 0.45, 1e-9));

      // Scale delta and body rotation strictly follow amplitude scaling.
      expect((busy.scale - 1) / (calm.scale - 1), closeTo(beatRatio, 1e-9));
      expect(busy.rotation / calm.rotation, closeTo(beatRatio, 1e-9));

      // Body dy and head rotation now have *dedicated* per-beat channels as well:
      // work leans forward and looks down slightly, microIdle settles back and
      // tilts the other way. The gap therefore no longer follows the amplitude
      // ratio; it is the sum of the scaled base rhythm and those offsets.
      expect(busy.dy, isNot(closeTo(calm.dy, 1e-12)));
      expect(busy.headRotation, isNot(closeTo(calm.headRotation, 1e-12)));

      // What that is worth on a real screen. The avatar is a square box with the
      // 482:328 character centred in it, so the sprite is only
      // `size / aspect` tall, and `scale` multiplies that.
      const spriteHeight = _focusAvatarSize / MochiLayerAssets.aspect;
      final dyGapPx = (busy.dy - calm.dy).abs() * _devicePixelRatio;
      final heightGapPx =
          (busy.scale - calm.scale).abs() * spriteHeight * _devicePixelRatio;
      final headGapDeg =
          (busy.headRotation - calm.headRotation).abs() * 180 / math.pi;

      // 11F's own constraint is 「不制造持续大幅运动」, and the four keyframes in
      // `designs/motion/11F_Focus_Work.png` are near-identical thumbnails. So
      // this is *supposed* to be small — small enough that a single screenshot
      // pair cannot be used to tell the beats apart, which is exactly why this
      // test exists. Both bounds are pinned so that changing the amplitude is a
      // deliberate design act rather than a drift.
      expect(dyGapPx, greaterThan(0.5),
          reason: 'the beats no longer separate by a measurable amount');
      expect(heightGapPx, greaterThan(0.5));
      expect(dyGapPx, lessThan(6.0),
          reason: 'the beat separation grew past what 11F allows; this needs a '
              'design decision, not a test update');
      expect(heightGapPx, lessThan(4.0));
      expect(headGapDeg, greaterThan(0.2),
          reason:
              'independent head rotation channel difference must be measurable');
      expect(headGapDeg, lessThan(3.0),
          reason: 'head rotation remains subtle and within 11F constraints');

      // The glance is the one beat with a channel of its own: a head lift no
      // other working-phase beat has. That is what makes it a *behaviour*
      // difference rather than only an amplitude difference.
      final glance = await _frameAt(tester, phase: FocusPhase.finishing);
      expect(glance.activity, PetFocusActivity.glance);
      expect(PetFocusActivitySpec.of(PetFocusActivity.glance).headLiftDegrees,
          greaterThan(0.0));
      for (final other in PetFocusActivity.values) {
        if (other == PetFocusActivity.glance) continue;
        expect(
          PetFocusActivitySpec.of(other).headLiftDegrees,
          anyOf(
              0.0,
              equals(PetFocusActivitySpec.of(PetFocusActivity.prepare)
                  .headLiftDegrees)),
          reason: '${other.name} grew a head lift; the glance is no longer the '
              'beat that owns that channel',
        );
      }

      // --- the artifact ----------------------------------------------------
      final payload = <String, Object?>{
        'generated_by':
            'test/presentation/focus_work_beat_visibility_test.dart',
        'note': 'TEST-ONLY data. No business value is created or changed by '
            'generating this file.',
        'method': 'One cycle position, three phases, everything else equal. '
            'The phase is the only differing input, and its only effect on the '
            'body channels is the beat amplitude.',
        'design_ref': 'designs/motion/11F_Focus_Work.png',
        'probe': <String, Object?>{
          'cycle_position': _probePosition,
          'avatar_size_pt': _focusAvatarSize,
          'sprite_height_pt': spriteHeight,
          'device_pixel_ratio': _devicePixelRatio,
          'category_id': _categoryId,
          'focus_progress': _progress,
        },
        'frames': <Object?>[
          busy.toJson(),
          calm.toJson(),
          glance.toJson(),
        ],
        'measured': <String, Object?>{
          'beat_amplitude_ratio': beatRatio,
          'body_dy_gap_pt': (busy.dy - calm.dy).abs(),
          'body_dy_gap_physical_px': dyGapPx,
          'sprite_height_gap_physical_px': heightGapPx,
          'head_rotation_gap_deg': headGapDeg,
          // The glance is the one beat that is a *channel* difference rather
          // than an amplitude difference, and it is an order of magnitude
          // bigger than the amplitude gap above. The crown displacement is
          // quoted as a range because it depends on the head pivot, which sits
          // somewhere between the sprite's centre and its feet; both ends are
          // given rather than picking the flattering one.
          'glance_head_lift_vs_work_deg':
              (glance.headRotation - busy.headRotation).abs() * 180 / math.pi,
          'glance_crown_displacement_pt_min': spriteHeight /
              2 *
              (glance.headRotation - busy.headRotation).abs(),
          'glance_crown_displacement_pt_max':
              spriteHeight * (glance.headRotation - busy.headRotation).abs(),
          'glance_crown_displacement_physical_px_min': spriteHeight /
              2 *
              (glance.headRotation - busy.headRotation).abs() *
              _devicePixelRatio,
          'glance_crown_displacement_physical_px_max': spriteHeight *
              (glance.headRotation - busy.headRotation).abs() *
              _devicePixelRatio,
        },
      };

      final file =
          File('outputs/ai_handoff/companion_stage_d_beat_frames.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
      );
      expect(file.existsSync(), isTrue);
    });

    testWidgets('a full working cycle walks all four of 11F\'s keyframes',
        (tester) async {
      // 11F names four keyframes — 开始 / 工作 / 微动 / 循环 — and the brief's own
      // loop is `prepare -> work -> microIdle -> work variant -> glance ->
      // return`. §25 asks for at least two of them to be distinguishable; this
      // pins which ones the WORKING phase actually reaches, so a schedule edit
      // that quietly dropped the calm beat would fail here.
      final seen = <PetFocusActivity, double>{};

      for (var i = 0; i < 40; i++) {
        final position = i / 40;
        final frame = await _frameAt(
          tester,
          phase: FocusPhase.working,
          cyclePosition: position,
        );
        seen[frame.activity] = frame.amplitude;
      }

      expect(
        seen.keys.toSet(),
        <PetFocusActivity>{
          PetFocusActivity.prepare,
          PetFocusActivity.work,
          PetFocusActivity.microIdle,
          PetFocusActivity.returning,
        },
        reason: 'the working phase no longer walks 11F\'s four keyframes',
      );
      expect(seen.keys.length, greaterThanOrEqualTo(2));

      // The calm beat really is a different regime, not a rounding difference:
      // `microIdle` is less than half the busiest beat.
      final busiest = seen.values.reduce((a, b) => a > b ? a : b);
      final calmest = seen.values.reduce((a, b) => a < b ? a : b);
      expect(busiest / calmest, greaterThan(2.4));
      expect(seen[PetFocusActivity.microIdle], lessThan(busiest * 0.5));
    });
    testWidgets(
        'Reduced Motion disables work cycle beats while keeping Mochi visible',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: PetAvatarWidget(
              key: ValueKey('reduced-motion-focus'),
              visualState: PetVisualState.focus,
              size: _focusAvatarSize,
              showStateBadge: false,
              focusProgress: _progress,
              focusPhase: FocusPhase.working,
              focusCategoryId: _categoryId,
            ),
          ),
        ),
      ));

      final cycleMs = PetMotionSpec.focusWorkCycle.inMilliseconds;
      await tester
          .pump(Duration(milliseconds: (cycleMs * _probePosition).round()));

      final state = _fallback(tester);
      expect(state.isReduceMotionActive, isTrue);
      // In reduced motion, rendered body scale, offset & head rotation stay
      // neutral, so the new work-beat channels cannot escape the setting.
      expect(state.renderedBodyScale, closeTo(1.0, 0.05));
      // Focus keeps its static half-height offset under Reduced Motion; the
      // *animated* channels must not move while that pose stays visible.
      expect(state.renderedBodyDy.abs(), lessThan(0.6));
      expect(state.renderedHeadRotation, closeTo(0.0, 0.05));
    });
  });
}
