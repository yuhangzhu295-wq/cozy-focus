import 'package:cozy_focus_app/presentation/companion/focus_phase.dart';
import 'package:cozy_focus_app/presentation/companion/pet_focus_activity.dart';
import 'package:flutter_test/flutter_test.dart';

/// STAGE 2 — the focus companion's presentation layer.
///
/// Everything here is presentation-only. The tests below deliberately assert
/// the *shape* of the schedule (tiling, totals, purity) rather than golden
/// numbers, so retuning a window in `pet_focus_activity.dart` does not require
/// rewriting the suite — only breaking the invariants does.
void main() {
  // ==========================================================================
  // FocusPhaseResolver
  // ==========================================================================
  group('FocusPhaseResolver maps normalised progress to a phase', () {
    test('the four bands are exactly as documented', () {
      expect(FocusPhaseResolver.resolve(0.00), FocusPhase.starting);
      expect(FocusPhaseResolver.resolve(0.03), FocusPhase.starting);
      expect(FocusPhaseResolver.resolve(0.05), FocusPhase.starting);
      expect(FocusPhaseResolver.resolve(0.06), FocusPhase.working);
      expect(FocusPhaseResolver.resolve(0.30), FocusPhase.working);
      expect(FocusPhaseResolver.resolve(0.60), FocusPhase.working);
      expect(FocusPhaseResolver.resolve(0.61), FocusPhase.deepFocus);
      expect(FocusPhaseResolver.resolve(0.92), FocusPhase.deepFocus);
      expect(FocusPhaseResolver.resolve(0.93), FocusPhase.finishing);
      expect(FocusPhaseResolver.resolve(1.00), FocusPhase.finishing);
    });

    test('thresholds are contiguous and inside 0..1', () {
      // The three thresholds must be strictly ascending and inside the unit
      // interval, or a band would be empty or unreachable.
      final t = [
        FocusPhaseSpec.startingUntil,
        FocusPhaseSpec.workingUntil,
        FocusPhaseSpec.deepFocusUntil,
      ];
      expect(t[0], greaterThan(0.0));
      expect(t[1], greaterThan(t[0]));
      expect(t[2], greaterThan(t[1]));
      expect(t[2], lessThan(1.0));
    });

    test('no progress is null', () {
      expect(FocusPhaseResolver.resolve(null), isNull);
      expect(FocusPhaseResolver.isActive(null), isFalse);
    });

    test('non-finite progress is rejected rather than trusted', () {
      expect(FocusPhaseResolver.resolve(double.nan), isNull);
      expect(FocusPhaseResolver.resolve(double.infinity), isNull);
      expect(FocusPhaseResolver.resolve(double.negativeInfinity), isNull);
    });

    test('out-of-range progress clamps instead of inventing a phase', () {
      // An over-run session is still finishing; a negative one has not started.
      expect(FocusPhaseResolver.resolve(4.2), FocusPhase.finishing);
      expect(FocusPhaseResolver.resolve(-3.0), FocusPhase.starting);
    });

    test('a 5-minute and a 50-minute session pass the same phases in order',
        () {
      // The whole point of normalising: nothing is hard-coded to 25 minutes.
      List<FocusPhase?> trail(int targetSeconds) {
        return [
          for (var elapsed = 0; elapsed <= targetSeconds; elapsed += 1)
            FocusPhaseResolver.resolve(elapsed / targetSeconds),
        ];
      }

      List<FocusPhase> distinct(List<FocusPhase?> phases) {
        final out = <FocusPhase>[];
        for (final p in phases) {
          if (p != null && (out.isEmpty || out.last != p)) out.add(p);
        }
        return out;
      }

      const expected = [
        FocusPhase.starting,
        FocusPhase.working,
        FocusPhase.deepFocus,
        FocusPhase.finishing,
      ];
      expect(distinct(trail(5 * 60)), expected);
      expect(distinct(trail(50 * 60)), expected);
    });

    test('behavioural intent is exposed per phase', () {
      expect(FocusPhase.starting.isPreparing, isTrue);
      expect(FocusPhase.working.isPreparing, isFalse);
      expect(FocusPhase.deepFocus.isConcentrating, isTrue);
      expect(FocusPhase.finishing.isAnticipating, isTrue);
      expect(
        FocusPhase.values.map((p) => p.label).toList(),
        ['STARTING', 'WORKING', 'DEEP_FOCUS', 'FINISHING'],
      );
    });
  });

  // ==========================================================================
  // PetFocusActivitySchedule — the V4.1 11F loop
  // ==========================================================================
  group('the work cycle tiles [0,1] for every phase', () {
    for (final phase in FocusPhase.values) {
      test('${phase.label} windows are contiguous, ascending and cover 0..1',
          () {
        final windows = PetFocusActivitySchedule.windowsFor(phase);
        expect(windows, isNotEmpty);
        expect(windows.first.start, 0.0);
        expect(windows.last.end, 1.0);
        for (var i = 0; i < windows.length; i++) {
          final w = windows[i];
          expect(w.end, greaterThan(w.start),
              reason: 'window $i of ${phase.label} is empty');
          if (i > 0) {
            expect(w.start, windows[i - 1].end,
                reason: 'gap or overlap before window $i of ${phase.label}');
          }
        }
      });
    }

    test('the null phase falls back to the working schedule', () {
      expect(
        PetFocusActivitySchedule.windowsFor(null),
        PetFocusActivitySchedule.windowsFor(FocusPhase.working),
      );
    });

    test('the documented 4-6 s loop bound is recorded and sane', () {
      expect(PetFocusActivitySchedule.minCycleSeconds, 4.0);
      expect(PetFocusActivitySchedule.maxCycleSeconds, 6.0);
      expect(PetFocusActivitySchedule.maxCycleSeconds,
          greaterThan(PetFocusActivitySchedule.minCycleSeconds));
    });
  });

  group('beatAt is total and defensive', () {
    test('every position in a swept cycle resolves to a real beat', () {
      for (final phase in FocusPhase.values) {
        for (var i = 0; i <= 200; i++) {
          final beat = PetFocusActivitySchedule.beatAt(i / 200, phase);
          expect(beat.localProgress, inInclusiveRange(0.0, 1.0));
          expect(PetFocusActivity.values, contains(beat.activity));
        }
      }
    });

    test('out-of-range and non-finite positions clamp rather than throw', () {
      for (final bad in [-5.0, 9.0, double.nan, double.infinity]) {
        final beat = PetFocusActivitySchedule.beatAt(bad, FocusPhase.working);
        expect(beat.localProgress, inInclusiveRange(0.0, 1.0));
      }
    });

    test('position 1.0 has a home (the last window is closed at the top)', () {
      for (final phase in FocusPhase.values) {
        final beat = PetFocusActivitySchedule.beatAt(1.0, phase);
        final last = PetFocusActivitySchedule.windowsFor(phase).last;
        expect(beat.activity, last.activity);
        expect(beat.localProgress, 1.0);
      }
    });
  });

  group('each phase produces the behaviour the brief describes', () {
    List<PetFocusActivity> beatsIn(FocusPhase phase) {
      return [
        for (var i = 0; i <= 100; i++)
          PetFocusActivitySchedule.beatAt(i / 100, phase).activity,
      ];
    }

    test('STARTING is dominated by prepare — Mochi gets ready to work', () {
      final beats = beatsIn(FocusPhase.starting);
      final prepares = beats.where((b) => b == PetFocusActivity.prepare).length;
      expect(prepares / beats.length, greaterThan(0.4));
    });

    test('WORKING is dominated by work — low-distraction work loops', () {
      final beats = beatsIn(FocusPhase.working);
      final works = beats.where((b) => b == PetFocusActivity.work).length;
      expect(works / beats.length, greaterThan(0.5));
      // ...and it is broken by a still beat, so it reads as pacing.
      expect(beats, contains(PetFocusActivity.microIdle));
    });

    test('DEEP_FOCUS is calmer and more concentrated: no glance at all', () {
      expect(beatsIn(FocusPhase.deepFocus),
          isNot(contains(PetFocusActivity.glance)));
      // "Calmer" is expressed as a longer still beat, not a second amplitude
      // scalar. Compare the share of the cycle spent still.
      double stillShare(FocusPhase phase) {
        final beats = beatsIn(phase);
        final still =
            beats.where((b) => b == PetFocusActivity.microIdle).length;
        return still / beats.length;
      }

      expect(stillShare(FocusPhase.deepFocus),
          greaterThan(stillShare(FocusPhase.working)));
    });

    test('FINISHING shows subtle anticipation via a glance beat', () {
      expect(beatsIn(FocusPhase.finishing), contains(PetFocusActivity.glance));
    });

    test('the loop returns to work rather than ending on a still beat', () {
      // prepare -> work -> micro idle -> return to work
      final windows = PetFocusActivitySchedule.windowsFor(FocusPhase.working);
      expect(windows.first.activity, PetFocusActivity.prepare);
      expect(windows[1].activity, PetFocusActivity.work);
      expect(windows[2].activity, PetFocusActivity.microIdle);
      expect(windows.last.activity, PetFocusActivity.returning);
    });
  });

  // ==========================================================================
  // Activity specs — the motion stays calm
  // ==========================================================================
  group('activity specs stay inside V4.1\'s "no large continuous motion" rule',
      () {
    test('every activity has a spec', () {
      for (final activity in PetFocusActivity.values) {
        expect(PetFocusActivitySpec.table.containsKey(activity), isTrue,
            reason: '${activity.name} has no spec');
      }
    });

    test('no beat freezes Mochi and none is theatrical', () {
      for (final entry in PetFocusActivitySpec.table.entries) {
        final spec = entry.value;
        expect(spec.amplitudeScale, greaterThan(0.0),
            reason: '${entry.key.name} would freeze the renderer');
        expect(spec.amplitudeScale, lessThanOrEqualTo(1.2),
            reason: '${entry.key.name} exceeds a calm amplitude');
        expect(spec.headLiftDegrees.abs(), lessThanOrEqualTo(3.0),
            reason: '${entry.key.name} is not a subtle head move');
        expect(spec.headBobDegrees.abs(), lessThanOrEqualTo(1.5));
      }
    });

    test('microIdle is visibly calmer than work — the observable difference',
        () {
      final work = PetFocusActivitySpec.of(PetFocusActivity.work);
      final idle = PetFocusActivitySpec.of(PetFocusActivity.microIdle);
      expect(idle.amplitudeScale, lessThan(work.amplitudeScale * 0.6),
          reason: 'the still beat must be unmistakably calmer than the work '
              'beat, or the loop is not observable at runtime');
    });

    test('only glance and the settle-in beat lift the head', () {
      final lifting = PetFocusActivitySpec.table.entries
          .where((e) => e.value.headLiftDegrees != 0.0)
          .map((e) => e.key)
          .toSet();
      expect(lifting, {PetFocusActivity.glance, PetFocusActivity.prepare});
      // And the glance is the larger of the two — it is the beat that reads as
      // "noticing", so it must not be the quieter one.
      expect(
        PetFocusActivitySpec.of(PetFocusActivity.glance).headLiftDegrees,
        greaterThan(
            PetFocusActivitySpec.of(PetFocusActivity.prepare).headLiftDegrees),
      );
    });
  });

  // ==========================================================================
  // Category flavour — presentation only
  // ==========================================================================
  group('PetWorkFlavourResolver maps the app\'s real category ids', () {
    test('the ids the app actually stores are all mapped', () {
      expect(PetWorkFlavourResolver.forCategoryId('study'),
          PetWorkFlavour.reading);
      expect(PetWorkFlavourResolver.forCategoryId('reading'),
          PetWorkFlavour.reading);
      expect(
          PetWorkFlavourResolver.forCategoryId('work'), PetWorkFlavour.writing);
      expect(PetWorkFlavourResolver.forCategoryId('life'),
          PetWorkFlavour.organizing);
      expect(PetWorkFlavourResolver.forCategoryId('other'),
          PetWorkFlavour.generic);
    });

    test('null and unknown ids degrade to generic rather than throwing', () {
      expect(
          PetWorkFlavourResolver.forCategoryId(null), PetWorkFlavour.generic);
      expect(PetWorkFlavourResolver.forCategoryId(''), PetWorkFlavour.generic);
      expect(PetWorkFlavourResolver.forCategoryId('astrophysics'),
          PetWorkFlavour.generic);
    });

    test('every flavour has a spec and none changes the character', () {
      for (final flavour in PetWorkFlavour.values) {
        final spec = PetWorkFlavourSpec.of(flavour);
        expect(spec.amplitudeScale, greaterThan(0.85));
        expect(spec.amplitudeScale, lessThan(1.15));
        expect(spec.headBobDegrees.abs(), lessThanOrEqualTo(1.5));
      }
    });
  });

  // ==========================================================================
  // PetFocusActivityController
  // ==========================================================================
  group('PetFocusActivityController is presentation-only', () {
    test('with no session it reports neutral and presents no work beats', () {
      final c = PetFocusActivityController();
      addTearDown(c.dispose);

      expect(c.isActive, isFalse);
      expect(c.phase, isNull);
      // Even if the renderer pushes cycle positions, no session means no beats.
      c.updateCycle(0.3);
      expect(c.activity, PetFocusActivity.prepare);
      expect(c.visual.amplitudeScale, 1.0);
      expect(c.visual.headLiftDegrees, 0.0);
      expect(c.visual.headBobDegrees, 0.0);
    });

    test('a session makes it active and beats follow the cycle', () {
      final c = PetFocusActivityController();
      addTearDown(c.dispose);

      c.setContext(phase: FocusPhase.working, categoryId: 'work');
      expect(c.isActive, isTrue);
      expect(c.flavour, PetWorkFlavour.writing);

      final seen = <PetFocusActivity>{};
      for (var i = 0; i <= 100; i++) {
        c.updateCycle(i / 100);
        seen.add(c.activity);
      }
      expect(seen, contains(PetFocusActivity.work));
      expect(seen, contains(PetFocusActivity.microIdle));
      expect(seen.length, greaterThanOrEqualTo(3),
          reason: 'the cycle must actually alternate, not sit on one beat');
    });

    test('ending the session releases the beat instead of freezing it', () {
      final c = PetFocusActivityController();
      addTearDown(c.dispose);

      c.setContext(phase: FocusPhase.deepFocus, categoryId: 'study');
      c.updateCycle(0.5);
      expect(c.isActive, isTrue);

      c.setContext(phase: null, categoryId: null);
      expect(c.isActive, isFalse);
      expect(c.activity, PetFocusActivity.prepare);
      expect(c.localProgress, 0.0);
      expect(c.visual.amplitudeScale, 1.0);
    });

    test('the category changes the flavour without changing the beat schedule',
        () {
      final study = PetFocusActivityController();
      final work = PetFocusActivityController();
      addTearDown(study.dispose);
      addTearDown(work.dispose);

      study.setContext(phase: FocusPhase.working, categoryId: 'study');
      work.setContext(phase: FocusPhase.working, categoryId: 'work');

      final studyBeats = <PetFocusActivity>[];
      final workBeats = <PetFocusActivity>[];
      for (var i = 0; i <= 50; i++) {
        study.updateCycle(i / 50);
        work.updateCycle(i / 50);
        studyBeats.add(study.activity);
        workBeats.add(work.activity);
      }

      // Same schedule...
      expect(studyBeats, workBeats);
      // ...different flavour.
      expect(study.flavour, PetWorkFlavour.reading);
      expect(work.flavour, PetWorkFlavour.writing);
      study.updateCycle(0.2);
      work.updateCycle(0.2);
      expect(study.visual.headBobDegrees, isNot(work.visual.headBobDegrees));
    });

    test('after dispose it is inert', () {
      final c = PetFocusActivityController();
      c.setContext(phase: FocusPhase.working, categoryId: 'work');
      c.updateCycle(0.2);
      final activityBefore = c.activity;

      c.dispose();
      expect(c.isDisposed, isTrue);

      c.updateCycle(0.95);
      c.setContext(phase: FocusPhase.finishing, categoryId: 'life');
      expect(c.activity, activityBefore,
          reason: 'a disposed controller must not keep presenting beats');
      expect(c.phase, FocusPhase.working);
      expect(c.flavour, PetWorkFlavour.writing);
    });

    test('resolving is pure — repeated calls cannot drift the inputs', () {
      // The layer has no write path at all; this pins that down by asserting
      // that the same inputs keep producing identical outputs.
      for (var i = 0; i < 5; i++) {
        expect(FocusPhaseResolver.resolve(0.7), FocusPhase.deepFocus);
        expect(
          PetFocusActivitySchedule.beatAt(0.3, FocusPhase.working).activity,
          PetFocusActivity.work,
        );
        expect(PetWorkFlavourResolver.forCategoryId('life'),
            PetWorkFlavour.organizing);
      }
    });
  });
}
