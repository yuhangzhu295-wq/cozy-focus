import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/runtime/daily_routine.dart';
import 'package:cozy_focus_app/presentation/companion/time_of_day.dart';

/// The authored routine and the runtime table must not drift.
///
/// `assets/companion/daily_routine.json` is the authoring source, with the
/// rationale written next to each band. The runtime reads [DailyRoutine.shipped]
/// so the room never has to `await` an asset load before its first frame. That
/// is only safe if the two are provably identical, which is what this test
/// establishes — band by band and step by step, not by spot check.
void main() {
  late DailyRoutine fromJson;

  setUpAll(() {
    final file = File('assets/companion/daily_routine.json');
    expect(file.existsSync(), isTrue,
        reason: 'the authored routine must ship in the repository');
    fromJson = DailyRoutine.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
  });

  test('the same bands are scheduled', () {
    expect(
      fromJson.scheduledBands.map(wireIdFor).toSet(),
      DailyRoutine.shipped.scheduledBands.map(wireIdFor).toSet(),
    );
  });

  test('every band matches step for step', () {
    for (final band in fromJson.scheduledBands) {
      final authored = fromJson.stepsFor(band);
      final bundled = DailyRoutine.shipped.stepsFor(band);

      expect(bundled.length, authored.length,
          reason: '${wireIdFor(band)} count');
      for (var i = 0; i < authored.length; i++) {
        final label = '${wireIdFor(band)}[$i]';
        expect(bundled[i].role, authored[i].role, reason: '$label role');
        expect(bundled[i].action, authored[i].action, reason: '$label action');
        expect(bundled[i].label, authored[i].label, reason: '$label label');
      }
    }
  });

  test('lateNight is unscheduled in both, and on purpose', () {
    // The absence is the design: the night rule owns bedtime, and a second
    // answer to "when does it sleep" would be two sources of truth. Pinned so
    // it cannot be reintroduced by accident.
    expect(DailyRoutine.unscheduledBands, {TimeOfDayBand.lateNight});
    expect(fromJson.stepsFor(TimeOfDayBand.lateNight), isEmpty);
    expect(DailyRoutine.shipped.stepsFor(TimeOfDayBand.lateNight), isEmpty);
    expect(fromJson.scheduledBands, isNot(contains(TimeOfDayBand.lateNight)));
  });

  test('every band except lateNight has at least one step', () {
    for (final band in TimeOfDayBand.values) {
      if (DailyRoutine.unscheduledBands.contains(band)) continue;
      expect(DailyRoutine.shipped.stepsFor(band), isNotEmpty,
          reason:
              '${wireIdFor(band)} must have a routine, or the day has a hole');
    }
  });

  test('the round-trip is lossless', () {
    // `toJson` exists so a future exporter can rewrite the authored file. If it
    // dropped a field, that exporter would silently delete authored data.
    final roundTripped = DailyRoutine.fromJson(DailyRoutine.shipped.toJson());
    expect(roundTripped.scheduledBands, DailyRoutine.shipped.scheduledBands);
    for (final band in DailyRoutine.shipped.scheduledBands) {
      final a = DailyRoutine.shipped.stepsFor(band);
      final b = roundTripped.stepsFor(band);
      expect(b.length, a.length, reason: wireIdFor(band));
      for (var i = 0; i < a.length; i++) {
        expect(b[i].role, a[i].role);
        expect(b[i].action, a[i].action);
        expect(b[i].label, a[i].label);
      }
    }
  });

  test('an unknown band id is skipped rather than throwing', () {
    // A band renamed in the manifest must degrade to "no routine for that band",
    // not take the app down on the first frame.
    final routine = DailyRoutine.fromJson({
      'bands': {
        'not_a_band': {
          'steps': [
            {'role': 'seat', 'action': 'sit', 'label': 'x'},
          ],
        },
        'morning': {
          'steps': [
            {'role': 'front', 'action': 'read', 'label': '翻翻书'},
          ],
        },
      },
    });
    expect(routine.scheduledBands, {TimeOfDayBand.morning});
  });
}
