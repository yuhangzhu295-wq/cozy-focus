import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/presentation/animations/pet_idle_fallback_view.dart';
import 'package:cozy_focus_app/presentation/animations/pet_motion_spec.dart';
import 'package:cozy_focus_app/presentation/companion/pet_craft_activity.dart';
import 'package:cozy_focus_app/presentation/companion/pet_focus_activity.dart';
import 'package:cozy_focus_app/presentation/controllers/pet_motion_controller.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';

/// STAGE 5 / C6 — the craft work loop.
///
/// `designs/motion/11G_Craft.png` specifies Craft as a **3–5 秒循环** with four
/// keyframes 抬手 / 敲击 / 停顿 / 检查, bound to `craftProgress`. These tests pin
/// both halves of that: the schedule itself, and the fact that it reaches the
/// render tree.
void main() {
  Future<PetIdleFallbackViewState> pumpPet(
    WidgetTester tester,
    PetMotionController controller,
    PetVisualState state, {
    double? craftProgress,
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: PetAvatarWidget(
            visualState: state,
            controller: controller,
            craftProgress: craftProgress,
          ),
        ),
      ),
    ));
    await tester.pump();
    return tester.state<PetIdleFallbackViewState>(
      find.byType(PetIdleFallbackView),
    );
  }

  /// Moves the shared beat clock to [position] and lets the frame recompose.
  ///
  /// The controller's `value` setter stops the animation and notifies its
  /// listeners, but `_frameFor` — which is what pushes the position into the
  /// beat layers — runs inside the `AnimatedBuilder` builder. So the position
  /// only takes effect on the next frame, and reading the beat layer before
  /// that frame reads the *previous* position. `pump()` with no duration does
  /// not advance time, so the value set here survives.
  Future<void> seekTo(
    WidgetTester tester,
    PetIdleFallbackViewState state,
    double position,
  ) async {
    state.workCycleController.value = position;
    await tester.pump();
  }

  /// The beats inside a stage's schedule, in order, de-duplicated.
  List<PetCraftActivity> beatsIn(PetCraftStage stage) {
    final seen = <PetCraftActivity>[];
    for (final window in PetCraftActivitySchedule.windowsFor(stage)) {
      if (!seen.contains(window.activity)) seen.add(window.activity);
    }
    return seen;
  }

  group('the four beats are 11G\'s four keyframes', () {
    test('the enum is exactly 抬手 / 敲击 / 停顿 / 检查, in that order', () {
      // 11G names the keyframes in this order and the loop follows it. If this
      // list ever changes, the design reference has to change first.
      expect(
        PetCraftActivity.values.map((e) => e.name).toList(),
        <String>['raise', 'strike', 'pause', 'inspect'],
        reason: '11G: 抬手 → 敲击 → 停顿 → 检查',
      );
    });

    test('every beat has a spec — the table is total', () {
      for (final activity in PetCraftActivity.values) {
        expect(PetCraftActivitySpec.table[activity], isNotNull,
            reason: '$activity has no spec');
        expect(() => PetCraftActivitySpec.of(activity), returnsNormally);
      }
      expect(PetCraftActivitySpec.table.length, PetCraftActivity.values.length);
    });

    test('the beat table invents no extra beats', () {
      expect(
        PetCraftActivitySpec.table.keys.toSet(),
        PetCraftActivity.values.toSet(),
      );
    });
  });

  group('the cycle length is inside 11G\'s band', () {
    test('11G says 3–5 s, and the band is recorded', () {
      expect(PetCraftActivitySchedule.minCycleSeconds, 3.0);
      expect(PetCraftActivitySchedule.maxCycleSeconds, 5.0);
    });

    test('the craft beat clock really is inside the band', () {
      // This is the regression guard. The shipped value was 1800 ms — outside
      // 11G's 3–5 s band, i.e. roughly twice as fast as the design specifies,
      // which read as a twitch rather than as work.
      final seconds = PetMotionSpec.craftCycle.inMilliseconds / 1000.0;
      expect(seconds,
          greaterThanOrEqualTo(PetCraftActivitySchedule.minCycleSeconds));
      expect(
          seconds, lessThanOrEqualTo(PetCraftActivitySchedule.maxCycleSeconds));
    });

    test('the focus band is untouched by the craft change', () {
      // The two loops share one clock, so a change to one must not silently
      // move the other out of its own band.
      final seconds = PetMotionSpec.focusWorkCycle.inMilliseconds / 1000.0;
      expect(seconds,
          greaterThanOrEqualTo(PetFocusActivitySchedule.minCycleSeconds));
      expect(
          seconds, lessThanOrEqualTo(PetFocusActivitySchedule.maxCycleSeconds));
    });
  });

  group('the schedule is total', () {
    for (final stage in PetCraftStage.values) {
      test('$stage tiles [0, 1] with no gap and no overlap', () {
        final windows = PetCraftActivitySchedule.windowsFor(stage);
        expect(windows, isNotEmpty);
        expect(windows.first.start, 0.0, reason: '$stage must start at 0.0');
        expect(windows.last.end, 1.0, reason: '$stage must reach 1.0');

        for (var i = 0; i < windows.length; i++) {
          expect(windows[i].end, greaterThan(windows[i].start),
              reason: 'window $i of $stage is empty or inverted');
          if (i > 0) {
            expect(windows[i].start, windows[i - 1].end,
                reason:
                    'gap or overlap between windows ${i - 1} and $i of $stage');
          }
        }
      });

      test('$stage can reach every beat it schedules', () {
        // A beat listed in a schedule but unreachable at any position would be
        // dead config that reads as "implemented" in review.
        final scheduled = beatsIn(stage);
        for (final activity in scheduled) {
          final reachable = List.generate(1001, (i) => i / 1000.0).any(
            (p) =>
                PetCraftActivitySchedule.beatAt(p, stage).activity == activity,
          );
          expect(reachable, isTrue,
              reason: '$activity is unreachable in $stage');
        }
      });

      test('$stage schedules no beat outside the enum', () {
        for (final window in PetCraftActivitySchedule.windowsFor(stage)) {
          expect(PetCraftActivity.values, contains(window.activity));
        }
      });
    }

    test('the final window is closed at the top so position 1.0 has a home',
        () {
      for (final stage in PetCraftStage.values) {
        final windows = PetCraftActivitySchedule.windowsFor(stage);
        final atEnd = PetCraftActivitySchedule.beatAt(1.0, stage);
        expect(atEnd.activity, windows.last.activity);
      }
    });

    test('a NaN or out-of-range position clamps instead of throwing', () {
      // This runs every frame of a live job; a thrown frame is a dropped frame.
      for (final position in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -1.0,
        2.0,
      ]) {
        for (final stage in PetCraftStage.values) {
          expect(
            () => PetCraftActivitySchedule.beatAt(position, stage),
            returnsNormally,
            reason: 'position $position threw for $stage',
          );
        }
      }
    });

    test('localProgress stays inside [0, 1] everywhere', () {
      for (final stage in PetCraftStage.values) {
        for (var i = 0; i <= 1000; i++) {
          final beat = PetCraftActivitySchedule.beatAt(i / 1000.0, stage);
          expect(beat.localProgress, inInclusiveRange(0.0, 1.0));
        }
      }
    });
  });

  group('the stage changes the mix, which is how 11G binds craftProgress', () {
    test('early never inspects — there is nothing to inspect yet', () {
      expect(beatsIn(PetCraftStage.early),
          isNot(contains(PetCraftActivity.inspect)));
    });

    test('early leans on raise rather than on striking', () {
      // Setting up: more raising than striking.
      final raise = PetCraftActivitySchedule.windowsFor(PetCraftStage.early)
          .where((w) => w.activity == PetCraftActivity.raise)
          .fold<double>(0, (a, w) => a + (w.end - w.start));
      final strike = PetCraftActivitySchedule.windowsFor(PetCraftStage.early)
          .where((w) => w.activity == PetCraftActivity.strike)
          .fold<double>(0, (a, w) => a + (w.end - w.start));
      expect(raise, greaterThan(strike));
    });

    test('mid is strike-dominant — this is the working stretch', () {
      final strike = PetCraftActivitySchedule.windowsFor(PetCraftStage.mid)
          .where((w) => w.activity == PetCraftActivity.strike)
          .fold<double>(0, (a, w) => a + (w.end - w.start));
      // More than half of the cycle is spent actually working.
      expect(strike, greaterThan(0.5));
    });

    test('late inspects — the job reads as finishing, not as stopped', () {
      expect(beatsIn(PetCraftStage.late), contains(PetCraftActivity.inspect));
    });

    test('the three stages are genuinely different schedules', () {
      final early = PetCraftActivitySchedule.windowsFor(PetCraftStage.early);
      final mid = PetCraftActivitySchedule.windowsFor(PetCraftStage.mid);
      final late = PetCraftActivitySchedule.windowsFor(PetCraftStage.late);
      expect(early, isNot(equals(mid)));
      expect(mid, isNot(equals(late)));
      expect(early, isNot(equals(late)));
    });

    test('pause appears in every stage — the loop always breathes', () {
      for (final stage in PetCraftStage.values) {
        expect(beatsIn(stage), contains(PetCraftActivity.pause),
            reason: '$stage has no pause beat');
      }
    });
  });

  group('the beats stay calm', () {
    test('every amplitude is positive — no beat freezes Mochi', () {
      // A beat at 0.0 would read as a dropped frame rather than as a pause in
      // work, which is the same rule PetFocusActivitySpec follows.
      for (final activity in PetCraftActivity.values) {
        final spec = PetCraftActivitySpec.of(activity);
        expect(spec.amplitudeScale, greaterThan(0.0),
            reason: '$activity freezes the pose');
      }
    });

    test('no beat swings the body theatrically', () {
      // 11G's loop is work, not celebration: every amplitude stays within a few
      // percent of neutral.
      for (final activity in PetCraftActivity.values) {
        final spec = PetCraftActivitySpec.of(activity);
        expect(spec.amplitudeScale, inInclusiveRange(0.4, 1.3),
            reason: '$activity is outside the calm band');
        expect(spec.dyOffset.abs(), lessThanOrEqualTo(3.0),
            reason: '$activity moves the body too far');
        expect(spec.headDegrees.abs(), lessThanOrEqualTo(4.0),
            reason: '$activity turns the head too far');
      }
    });

    test('pause is the stillest beat — that is what makes it observable', () {
      final pause = PetCraftActivitySpec.of(PetCraftActivity.pause);
      for (final activity in PetCraftActivity.values) {
        if (activity == PetCraftActivity.pause) continue;
        expect(pause.amplitudeScale,
            lessThan(PetCraftActivitySpec.of(activity).amplitudeScale),
            reason: 'pause is not stiller than $activity');
      }
      expect(pause.dyOffset, 0.0);
      expect(pause.headDegrees, 0.0);
    });

    test('strike is the most animated beat — the work is visible', () {
      final strike = PetCraftActivitySpec.of(PetCraftActivity.strike);
      for (final activity in PetCraftActivity.values) {
        if (activity == PetCraftActivity.strike) continue;
        expect(strike.amplitudeScale,
            greaterThan(PetCraftActivitySpec.of(activity).amplitudeScale));
      }
    });

    test('raise lifts and strike dips — the beats are signed, not identical',
        () {
      expect(PetCraftActivitySpec.of(PetCraftActivity.raise).dyOffset,
          lessThan(0.0));
      expect(PetCraftActivitySpec.of(PetCraftActivity.strike).dyOffset,
          greaterThan(0.0));
    });
  });

  group('the loop cannot drift', () {
    test('every beat edge is a zero crossing, so beats join without a step',
        () {
      // The renderer spreads a beat's offset across its own window with
      // `sin(pi * localProgress)`, which is exactly 0 at localProgress 0 and 1.
      // That is what makes 抬手 settling into 敲击 read as one gesture rather
      // than as a cut between two poses — and, because the contribution returns
      // to zero at every edge, it is also why the beat layer cannot accumulate
      // a displacement over a long job.
      for (final stage in PetCraftStage.values) {
        final windows = PetCraftActivitySchedule.windowsFor(stage);
        for (final window in windows) {
          for (final edge in <double>[window.start, window.end]) {
            final beat = PetCraftActivitySchedule.beatAt(edge, stage);
            final envelope = math.sin(math.pi * beat.localProgress);
            expect(envelope, closeTo(0.0, 1e-9),
                reason: '$stage at $edge: the beat offset does not vanish');
          }
        }
      }
    });

    test('the offset is bounded by the declared amplitude', () {
      // A beat can move the pose, but only ever by its own declared amount.
      for (final stage in PetCraftStage.values) {
        var maxDy = 0.0;
        var maxHead = 0.0;
        for (var i = 0; i <= 1000; i++) {
          final beat = PetCraftActivitySchedule.beatAt(i / 1000.0, stage);
          final spec = PetCraftActivitySpec.of(beat.activity);
          final envelope = math.sin(math.pi * beat.localProgress);
          maxDy = math.max(maxDy, (spec.dyOffset * envelope).abs());
          maxHead = math.max(maxHead, (spec.headDegrees * envelope).abs());
        }
        final declaredDy = PetCraftActivity.values
            .map((a) => PetCraftActivitySpec.of(a).dyOffset.abs())
            .reduce(math.max);
        final declaredHead = PetCraftActivity.values
            .map((a) => PetCraftActivitySpec.of(a).headDegrees.abs())
            .reduce(math.max);
        expect(maxDy, lessThanOrEqualTo(declaredDy + 1e-9));
        expect(maxHead, lessThanOrEqualTo(declaredHead + 1e-9));
      }
    });
  });

  group('the stage resolver is total and defensive', () {
    test('the declared boundaries are where the stage flips', () {
      expect(PetCraftStageResolver.resolve(0.0), PetCraftStage.early);
      expect(PetCraftStageResolver.resolve(PetCraftStageResolver.midFrom),
          PetCraftStage.mid);
      expect(PetCraftStageResolver.resolve(PetCraftStageResolver.lateFrom),
          PetCraftStage.late);
      expect(PetCraftStageResolver.resolve(1.0), PetCraftStage.late);
    });

    test('just below a boundary is still the earlier stage', () {
      expect(
        PetCraftStageResolver.resolve(PetCraftStageResolver.midFrom - 0.001),
        PetCraftStage.early,
      );
      expect(
        PetCraftStageResolver.resolve(PetCraftStageResolver.lateFrom - 0.001),
        PetCraftStage.mid,
      );
    });

    test('every stage is reachable', () {
      final reached = <PetCraftStage>{};
      for (var i = 0; i <= 1000; i++) {
        reached.add(PetCraftStageResolver.resolve(i / 1000.0));
      }
      expect(reached, PetCraftStage.values.toSet());
    });

    test('a rounding error at either end cannot invent a fourth stage', () {
      expect(PetCraftStageResolver.resolve(-0.5), PetCraftStage.early);
      expect(PetCraftStageResolver.resolve(1.5), PetCraftStage.late);
    });

    test('NaN resolves rather than throwing', () {
      expect(() => PetCraftStageResolver.resolve(double.nan), returnsNormally);
      expect(PetCraftStageResolver.resolve(double.nan), PetCraftStage.early);
    });

    test('null resolves, and the caller must still treat it as inactive', () {
      // The resolver cannot say "no job" — it only has three stages. That
      // distinction has to live on the controller, which is exactly what
      // `isActive` is for.
      expect(PetCraftStageResolver.resolve(null), PetCraftStage.early);
    });
  });

  group('the controller presents nothing when no job runs', () {
    test('a fresh controller is inactive', () {
      final controller = PetCraftActivityController();
      expect(controller.isActive, isFalse);
      expect(controller.stage, isNull);
      controller.dispose();
    });

    test('no job keeps the beat neutral even after the clock advances', () {
      final controller = PetCraftActivityController();
      for (var i = 0; i <= 10; i++) {
        controller.updateCycle(i / 10.0);
        expect(controller.activity, PetCraftActivity.raise);
        expect(controller.localProgress, 0.0);
      }
      // The neutral spec is amplitude 1.0 with no offsets: applying it is a
      // no-op, so a stale controller cannot displace the pose.
      expect(controller.visual.amplitudeScale, 1.0);
      expect(controller.visual.dyOffset, 0.0);
      expect(controller.visual.headDegrees, 0.0);
      controller.dispose();
    });

    test('a job makes it active and progress selects the stage', () {
      final controller = PetCraftActivityController();
      controller.setContext(progress: 0.1);
      expect(controller.isActive, isTrue);
      expect(controller.stage, PetCraftStage.early);

      controller.setContext(progress: 0.5);
      expect(controller.stage, PetCraftStage.mid);

      controller.setContext(progress: 0.9);
      expect(controller.stage, PetCraftStage.late);
      controller.dispose();
    });

    test('the job ending falls back to the neutral beat, not the last one', () {
      final controller = PetCraftActivityController();
      controller.setContext(progress: 0.5);
      controller.updateCycle(0.30); // a strike
      expect(controller.activity, PetCraftActivity.strike);

      controller.setContext(progress: null);
      expect(controller.isActive, isFalse);
      expect(controller.activity, PetCraftActivity.raise,
          reason: 'the last job beat must not stay frozen on screen');
      expect(controller.localProgress, 0.0);
      controller.dispose();
    });

    test('a disposed controller is inert', () {
      final controller = PetCraftActivityController();
      controller.setContext(progress: 0.5);
      controller.dispose();
      expect(controller.isDisposed, isTrue);

      controller.setContext(progress: 0.9);
      controller.updateCycle(0.6);
      expect(controller.stage, PetCraftStage.mid,
          reason: 'a disposed controller must not take new context');
      controller.dispose();
    });

    test('progress that does not move the stage does not reset the beat', () {
      final controller = PetCraftActivityController();
      controller.setContext(progress: 0.30);
      controller.updateCycle(0.30);
      final beat = controller.activity;

      // Still in `mid`, so the beat in progress must survive.
      controller.setContext(progress: 0.35);
      expect(controller.stage, PetCraftStage.mid);
      expect(controller.activity, beat);
      controller.dispose();
    });
  });

  group('the loop reaches the render tree', () {
    testWidgets('the craft state runs the beat clock at 11G\'s length',
        (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.craft);
      final state = await pumpPet(tester, controller, PetVisualState.craft,
          craftProgress: 0.5);

      expect(state.workCycleController.isAnimating, isTrue);
      expect(state.workCycleController.duration, PetMotionSpec.craftCycle);
      controller.dispose();
    });

    testWidgets('the focus state still runs its own length on the same clock',
        (tester) async {
      // The two loops share one controller, so this is the guard that the craft
      // change did not retarget focus.
      final controller = PetMotionController(visualState: PetVisualState.focus);
      final state = await pumpPet(tester, controller, PetVisualState.focus);

      expect(state.workCycleController.duration, PetMotionSpec.focusWorkCycle);
      controller.dispose();
    });

    testWidgets('leaving craft stops the beat clock', (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.craft);
      final state = await pumpPet(tester, controller, PetVisualState.craft,
          craftProgress: 0.5);
      expect(state.workCycleController.isAnimating, isTrue);

      controller.updateState(PetVisualState.idle);
      await tester.pump();
      expect(state.workCycleController.isAnimating, isFalse);
      controller.dispose();
    });

    testWidgets('the real craftProgress reaches the beat layer',
        (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.craft);
      final state = await pumpPet(tester, controller, PetVisualState.craft,
          craftProgress: 0.5);

      expect(state.craftActivity.isActive, isTrue);
      expect(state.craftActivity.stage, PetCraftStage.mid);
      controller.dispose();
    });

    testWidgets('a job at progress 0 is early, not absent', (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.craft);
      final state = await pumpPet(tester, controller, PetVisualState.craft,
          craftProgress: 0.0);

      expect(state.craftActivity.isActive, isTrue);
      expect(state.craftActivity.stage, PetCraftStage.early);
      controller.dispose();
    });

    testWidgets('no job means no beats, even in the craft state',
        (tester) async {
      // A craft state with no progress binding is a page that has not loaded a
      // job yet. It must not present work beats for a job that does not exist.
      final controller = PetMotionController(visualState: PetVisualState.craft);
      final state = await pumpPet(tester, controller, PetVisualState.craft);

      expect(state.craftActivity.isActive, isFalse);
      controller.dispose();
    });

    testWidgets('moving progress mid-job retargets the stage', (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.craft);
      final first = await pumpPet(tester, controller, PetVisualState.craft,
          craftProgress: 0.1);
      expect(first.craftActivity.stage, PetCraftStage.early);

      // Re-pumped with the same structure on purpose: that is what makes this a
      // `didUpdateWidget` test rather than an `initState` test. A different tree
      // shape would build a new State and the progress change would appear to
      // work for the wrong reason.
      final second = await pumpPet(tester, controller, PetVisualState.craft,
          craftProgress: 0.9);
      expect(identical(first, second), isTrue,
          reason:
              'the State must survive the re-pump for this to be meaningful');
      expect(second.craftActivity.stage, PetCraftStage.late,
          reason: 'progress is what selects the stage');
      controller.dispose();
    });

    testWidgets('the clock position selects the beat', (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.craft);
      final state = await pumpPet(tester, controller, PetVisualState.craft,
          craftProgress: 0.5);

      // Drive the shared clock directly so the samples differ only in the beat,
      // not in the other controllers that also advance with time.
      await seekTo(tester, state, 0.30); // inside 18–52 %: strike
      expect(state.currentCraftActivity, PetCraftActivity.strike);

      await seekTo(tester, state, 0.59); // inside 52–66 %: pause
      expect(state.currentCraftActivity, PetCraftActivity.pause);

      await seekTo(tester, state, 0.05); // inside 0–18 %: raise
      expect(state.currentCraftActivity, PetCraftActivity.raise);
      controller.dispose();
    });

    testWidgets('the beat actually moves the head channel', (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.craft);
      final state = await pumpPet(tester, controller, PetVisualState.craft,
          craftProgress: 0.5);

      // Same instant, two beats: every other channel is unchanged because no
      // other controller advanced, so this isolates the beat's contribution.
      await seekTo(tester, state, 0.59); // pause: head offset 0
      final atPause = state.headRotationValue;

      await seekTo(
          tester, state, 0.30); // strike: head offset +1.5° at full envelope
      final atStrike = state.headRotationValue;

      // The envelope comes from the schedule rather than from a hand-written
      // fraction, so this cannot drift when a window moves.
      final beat = PetCraftActivitySchedule.beatAt(0.30, PetCraftStage.mid);
      expect(beat.activity, PetCraftActivity.strike);
      final expectedDelta = PetCraftActivitySpec.of(beat.activity).headDegrees *
          math.sin(math.pi * beat.localProgress) *
          math.pi /
          180;
      expect(expectedDelta, greaterThan(0.0));
      expect(atStrike - atPause, closeTo(expectedDelta, 0.001));
      controller.dispose();
    });

    testWidgets('pause contributes no body offset at all', (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.craft);
      final state = await pumpPet(tester, controller, PetVisualState.craft,
          craftProgress: 0.5);

      await seekTo(tester, state, 0.59); // pause
      expect(state.craftActivityDy, 0.0);
      expect(state.craftActivityHeadDegrees, 0.0);
      expect(state.craftActivityAmplitude,
          PetCraftActivitySpec.of(PetCraftActivity.pause).amplitudeScale);
      controller.dispose();
    });

    testWidgets('reduced motion suppresses the craft beats', (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.craft);
      final state = await pumpPet(
        tester,
        controller,
        PetVisualState.craft,
        craftProgress: 0.5,
        reduceMotion: true,
      );

      await seekTo(tester, state, 0.30); // a strike, if it were applied
      expect(state.renderedHeadRotation, 0.0,
          reason: 'Reduced Motion must lower the beats to nothing');
      controller.dispose();
    });

    testWidgets('the beat layer adds no timer of its own', (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.craft);
      final state = await pumpPet(tester, controller, PetVisualState.craft,
          craftProgress: 0.5);

      // The V4.1 micro-motion layer is still exactly the two ambient timers;
      // the beat layer is a read of an existing controller, not a scheduler.
      expect(controller.activeTimerCount, 2);
      expect(state.craftActivity.isDisposed, isFalse);
      controller.dispose();
    });

    testWidgets('the beat layer is disposed with the widget', (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.craft);
      final state = await pumpPet(tester, controller, PetVisualState.craft,
          craftProgress: 0.5);
      final layer = state.craftActivity;

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();

      expect(layer.isDisposed, isTrue);
      controller.dispose();
    });
  });
}
