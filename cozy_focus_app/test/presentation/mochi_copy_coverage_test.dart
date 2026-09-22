import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/growth/mochi_growth_profile.dart';
import 'package:cozy_focus_app/presentation/companion/pet_encouragement.dart';
import 'package:cozy_focus_app/presentation/companion/time_of_day.dart';

/// Does the encouragement channel ever actually *say* what it declares?
///
/// The rest of `pet_encouragement_test.dart` feeds `decide` hand-built inputs.
/// Those prove each branch works; they cannot prove any real session reaches it,
/// because reachability falls out of how the branches interact over a whole
/// session — the 3-message cap, the 150 s silence and the progress bands together
/// decide whether a category is ever selected. A category that can never be
/// selected is 4 lines of dead copy.
///
/// So this drives the real [PetEncouragementScheduler] (never a reimplementation
/// of `decide`) second by second across a matrix of session lengths, times of
/// day, happiness scores and pause patterns, and asserts the properties that
/// matter over all of them:
///
///  * the anti-harassment cap holds everywhere, and is actually *reached* (a cap
///    that no scenario hits would make this vacuous);
///  * every gap is either the full silence or a pause comfort line inside the
///    shorter pause allowance;
///  * every category the engine owns is reachable somewhere;
///  * every category has an entry point, so no copy line is orphaned;
///  * the opening line never lands before [PetEncouragementBudget.firstMessageDelay];
///  * and the coverage grid is exactly what `MOCHI_GROWTH_COPY_REVIEW.md` tells
///    the owner it is.
///
/// That last one is the point of the file: a cadence tweak silently changes which
/// copy a user can ever hear, and the owner's copy review has to be re-issued.
///
/// The growth stage is held fixed: it selects the *wording* (four variants per
/// category, one per stage), never the *category*, so it cannot affect this
/// matrix.
///
/// The machine-readable matrix is written to
/// `outputs/ai_handoff/mochi_copy_reachability.json` so the review doc's numbers
/// are traceable to a green run rather than transcribed by hand.
void main() {
  final scenarios = _matrix();
  final runs = {for (final s in scenarios) s.label: _sweep(s)};

  final decideKinds = <PetMessageKind>{
    PetMessageKind.startEncouragement,
    PetMessageKind.focusCompanion,
    PetMessageKind.midpointSupport,
    PetMessageKind.finishingSupport,
    PetMessageKind.pauseComfort,
    PetMessageKind.lateNightCare,
  };

  final outsideDecide = <String, PetMessageKind>{
    'greeting/midday': PetEncouragementEngine.greeting(
            growth: _growth, timeOfDay: TimeOfDayBand.midday)
        .kind,
    'greeting/lateNight': PetEncouragementEngine.greeting(
            growth: _growth, timeOfDay: TimeOfDayBand.lateNight)
        .kind,
    'touchResponse': PetEncouragementEngine.touchResponse(growth: _growth).kind,
    'completionPraise':
        PetEncouragementEngine.completionPraise(growth: _growth).kind,
  };

  /// kind -> the scenarios (band/happiness key) it appeared in.
  final reachableIn = <PetMessageKind, Set<String>>{};

  /// kind -> earliest second it was ever spoken, and where.
  final earliest = <PetMessageKind, int>{};
  final earliestWhere = <PetMessageKind, String>{};
  for (final s in scenarios) {
    for (final spoken in runs[s.label]!) {
      reachableIn.putIfAbsent(spoken.kind, () => <String>{}).add(s.gridKey);
      final best = earliest[spoken.kind];
      if (best == null || spoken.second < best) {
        earliest[spoken.kind] = spoken.second;
        earliestWhere[spoken.kind] = s.label;
      }
    }
  }

  group('Mochi copy coverage over ${scenarios.length} swept sessions', () {
    test('no session exceeds the anti-harassment cap, and the cap is reached',
        () {
      final over = runs.entries
          .where((e) =>
              e.value.length > PetEncouragementBudget.maxMessagesPerSession)
          .toList();
      expect(over, isEmpty,
          reason: 'these sessions produced more than '
              '${PetEncouragementBudget.maxMessagesPerSession} messages: '
              '${over.map((e) => '${e.key} -> ${e.value.length}').join('; ')}');

      // Otherwise the assertion above is vacuous: a cap nothing approaches is
      // not being tested.
      final most =
          runs.values.map((v) => v.length).reduce((a, b) => a > b ? a : b);
      expect(most, PetEncouragementBudget.maxMessagesPerSession,
          reason: 'no swept session ever reached the cap, so the cap assertion '
              'above proves nothing');
    });

    test(
        'every gap is the full silence, or a pause line inside the shorter one',
        () {
      final breaches = <String>[];
      runs.forEach((label, spoken) {
        for (var i = 1; i < spoken.length; i++) {
          final gap = spoken[i].second - spoken[i - 1].second;
          final isPause = spoken[i].kind == PetMessageKind.pauseComfort;
          final ok =
              gap >= PetEncouragementBudget.minGapBetweenMessages.inSeconds ||
                  (isPause &&
                      gap >= PetEncouragementBudget.minGapAfterPause.inSeconds);
          if (!ok) {
            breaches.add('$label: ${spoken[i - 1].kind.name} -> '
                '${spoken[i].kind.name} after ${gap}s');
          }
        }
      });
      expect(breaches, isEmpty, reason: breaches.join('; '));
    });

    test('nothing is said before the first-message delay', () {
      final early = earliest.entries
          .where((e) =>
              e.value < PetEncouragementBudget.firstMessageDelay.inSeconds)
          .toList();
      expect(early, isEmpty,
          reason: 'spoken too early: '
              '${early.map((e) => '${e.key.name} at ${e.value}s').join('; ')}');
    });

    test('every category the engine owns is reachable in a real session', () {
      final unreachable = decideKinds.difference(reachableIn.keys.toSet());
      expect(unreachable, isEmpty,
          reason: 'these categories can never be spoken by any swept session, '
              'so their copy is dead: '
              '${unreachable.map((k) => k.name).join(', ')}');
    });

    test('every category has an entry point', () {
      final declared = <PetMessageKind>{
        ...decideKinds,
        ...outsideDecide.values
      };
      expect(PetMessageKind.values.toSet().difference(declared), isEmpty,
          reason: 'a category exists in the copy table with nothing that can '
              'produce it');
      // `lateNightCare` is shared on purpose: `greeting` returns care rather than
      // a greeting at night, and the returned kind is how the caller finds out
      // which it got. So the outside entry points cover four values, one of
      // which also belongs to `decide`.
      expect(outsideDecide.values.toSet(), {
        PetMessageKind.returnGreeting,
        PetMessageKind.lateNightCare,
        PetMessageKind.petTouchResponse,
        PetMessageKind.completionPraise,
      });
      expect(outsideDecide['greeting/lateNight'], PetMessageKind.lateNightCare);
    });

    test(
        'the chatty line needs happiness and daylight; the finishing line is '
        'the other way round', () {
      // Measured, not assumed. `focusCompanion` is withheld below
      // `lowHappinessThreshold` on purpose, and `lateNightCare` outranks it at
      // night — so the chatty line is a daytime-and-coping line. The
      // consequence for `finishingSupport` is the surprising half: a *happy*
      // user's budget is spent by the midpoint band, so the last-stretch line is
      // only ever heard by a user below the happiness threshold. See
      // `MOCHI_GROWTH_COPY_REVIEW.md`.
      for (final band in TimeOfDayBand.values) {
        final key80 = '${band.name}/h80';
        final key20 = '${band.name}/h20';
        final atNight = band == TimeOfDayBand.lateNight;

        expect(reachableIn[PetMessageKind.focusCompanion]!.contains(key80),
            !atNight,
            reason: 'focusCompanion vs $key80');
        expect(
            reachableIn[PetMessageKind.focusCompanion]!.contains(key20), false,
            reason: 'focusCompanion must be withheld below the happiness '
                'threshold ($key20)');

        expect(reachableIn[PetMessageKind.finishingSupport]!.contains(key20),
            !atNight,
            reason: 'finishingSupport vs $key20');
        expect(reachableIn[PetMessageKind.finishingSupport]!.contains(key80),
            false,
            reason: 'finishingSupport vs $key80');

        expect(reachableIn[PetMessageKind.lateNightCare]!.contains(key80),
            atNight);
        expect(reachableIn[PetMessageKind.lateNightCare]!.contains(key20),
            atNight);

        for (final always in [
          PetMessageKind.startEncouragement,
          PetMessageKind.midpointSupport,
          PetMessageKind.pauseComfort,
        ]) {
          expect(reachableIn[always]!.contains(key80), true,
              reason: '${always.name} vs $key80');
          expect(reachableIn[always]!.contains(key20), true,
              reason: '${always.name} vs $key20');
        }
      }
    });

    test('a comfort line requires a pause', () {
      final unpaused = runs.entries.where(
          (e) => !e.key.contains('/1pause') && !e.key.contains('/2pauses'));
      for (final entry in unpaused) {
        expect(entry.value.any((s) => s.kind == PetMessageKind.pauseComfort),
            false,
            reason: '${entry.key} was never paused yet got a comfort line');
      }
      final paused = runs.entries.where((e) => e.key.contains('/1pause'));
      expect(
          paused.any(
              (e) => e.value.any((s) => s.kind == PetMessageKind.pauseComfort)),
          true,
          reason:
              'no paused session produced a comfort line, so the pause path '
              'is untested here');
    });

    test('the report the review doc cites is regenerated', () {
      final grid = <String, List<String>>{};
      for (final s in scenarios) {
        grid.putIfAbsent(s.gridKey, () => <String>[]);
        for (final spoken in runs[s.label]!) {
          if (!grid[s.gridKey]!.contains(spoken.kind.name)) {
            grid[s.gridKey]!.add(spoken.kind.name);
          }
        }
      }
      grid.updateAll((_, v) => v..sort());

      final payload = <String, Object?>{
        'scenarios': scenarios.length,
        'grid_key_format': '<timeOfDayBand>/h<happiness>',
        'reachable_by_grid_key': grid,
        'earliest_second': {
          for (final e in earliest.entries) e.key.name: e.value
        },
        'earliest_in_scenario': {
          for (final e in earliestWhere.entries) e.key.name: e.value
        },
        'entry_points_outside_decide': {
          for (final e in outsideDecide.entries) e.key: e.value.name
        },
        'messages_per_scenario': {
          for (final e in runs.entries) e.key: e.value.length
        },
        // The full timeline, so a claim about *why* a category is unreachable in
        // a given case can be checked against the run instead of reasoned about.
        'timeline': {
          for (final e in runs.entries)
            e.key: [
              for (final s in e.value) {'second': s.second, 'kind': s.kind.name}
            ],
        },
      };
      final file = File('outputs/ai_handoff/mochi_copy_reachability.json');
      file.parent.createSync(recursive: true);
      final encoded = const JsonEncoder.withIndent('  ').convert(payload);
      file.writeAsStringSync('$encoded\n');
      expect(file.existsSync(), isTrue);
    });
  });
}

final _growth =
    GrowthStageResolver.resolve(experiencePoints: 15, happinessScore: 80);

/// A pause window, as `(firstPausedSecond, lastPausedSecond]`.
class _Pause {
  final int start;
  final int end;
  const _Pause(this.start, this.end);
}

class _Scenario {
  final String label;
  final int totalSeconds;
  final TimeOfDayBand band;
  final int happiness;
  final List<_Pause> pauses;
  const _Scenario(
      this.label, this.totalSeconds, this.band, this.happiness, this.pauses);

  String get gridKey => '${band.name}/h$happiness';
}

/// One decision, at the session second it was made.
class _Spoken {
  final int second;
  final PetMessageKind kind;
  const _Spoken(this.second, this.kind);
}

List<_Scenario> _matrix() {
  final scenarios = <_Scenario>[];
  for (final minutes in const [5, 10, 15, 25, 45, 90]) {
    final total = minutes * 60;
    for (final band in TimeOfDayBand.values) {
      for (final happiness in const [20, 80]) {
        final tag = '${minutes}m/${band.name}/h$happiness';
        scenarios.add(_Scenario('$tag/none', total, band, happiness, const []));
        scenarios.add(_Scenario('$tag/1pause', total, band, happiness,
            [_Pause(total ~/ 4, total ~/ 4 + 60)]));
        scenarios.add(_Scenario('$tag/2pauses', total, band, happiness, [
          _Pause(total ~/ 4, total ~/ 4 + 60),
          _Pause(total ~/ 2, total ~/ 2 + 60),
        ]));
      }
    }
  }
  return scenarios;
}

/// Drives one scenario second by second, the way `focus_active_page.dart` does.
///
/// Two clocks, deliberately kept apart:
///
///  * `elapsed` is the **monotonic** session-open time (`now - session.startAt`),
///    which is what the cadence runs on. It must keep advancing while the user is
///    paused, or a bubble could never expire and a comfort line could never
///    follow an opening line.
///  * `progress` is `elapsedSeconds / plannedSeconds` from the page's state,
///    whose elapsed time **freezes** during a pause.
///
/// A new decision is detected from [PetEncouragementScheduler.messagesThisSession]
/// rather than from the returned value: while a bubble is on screen the scheduler
/// returns the same object every tick, and two consecutive identical categories
/// would otherwise be indistinguishable from one.
List<_Spoken> _sweep(_Scenario s) {
  final scheduler = PetEncouragementScheduler();
  final spoken = <_Spoken>[];
  var pausedSoFar = 0;
  var seen = 0;
  for (var t = 1; t <= s.totalSeconds; t++) {
    final isPaused = s.pauses.any((p) => t > p.start && t <= p.end);
    final message = scheduler.advance(
      elapsed: Duration(seconds: t),
      isPaused: isPaused,
      timeOfDay: s.band,
      growth: _growth,
      happinessScore: s.happiness,
      progress: (t - pausedSoFar) / s.totalSeconds,
    );
    if (scheduler.messagesThisSession > seen) {
      seen = scheduler.messagesThisSession;
      spoken.add(_Spoken(t, message!.kind));
    }
    if (isPaused) pausedSoFar++;
  }
  return spoken;
}
