import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/time_of_day.dart';

/// Builds a `DateTime` at [hour] on a fixed date, so the tests never depend on
/// the day the suite happens to run.
DateTime _at(int hour, {int minute = 0, int second = 0}) =>
    DateTime(2026, 9, 21, hour, minute, second);

void main() {
  group('TimeOfDayResolver covers the whole day', () {
    test('all 24 hours resolve, and every band is reachable', () {
      final seen = <TimeOfDayBand>{};
      for (var hour = 0; hour < 24; hour++) {
        seen.add(TimeOfDayResolver.resolve(_at(hour)));
      }
      expect(seen, TimeOfDayBand.values.toSet(),
          reason: 'the bands must tile the day with no band left unreachable');
    });

    test('the bands are contiguous — no hour is ambiguous or unassigned', () {
      // Walking the clock must produce at most one transition per boundary and
      // must never jump (a jump would mean a band is skipped somewhere).
      final sequence = [
        for (var hour = 0; hour < 24; hour++)
          TimeOfDayResolver.resolve(_at(hour)),
      ];
      for (var i = 1; i < sequence.length; i++) {
        final changed = sequence[i] != sequence[i - 1];
        if (changed) {
          // A change may only happen at a declared boundary hour.
          expect(
            TimeOfDaySpec.boundaryHours.contains(i),
            isTrue,
            reason: 'band changed at hour $i, which is not a declared boundary',
          );
        }
      }
    });

    test('each boundary hour resolves to the band it opens', () {
      expect(TimeOfDayResolver.resolve(_at(TimeOfDaySpec.morningFrom)),
          TimeOfDayBand.morning);
      expect(TimeOfDayResolver.resolve(_at(TimeOfDaySpec.middayFrom)),
          TimeOfDayBand.midday);
      expect(TimeOfDayResolver.resolve(_at(TimeOfDaySpec.afternoonFrom)),
          TimeOfDayBand.afternoon);
      expect(TimeOfDayResolver.resolve(_at(TimeOfDaySpec.eveningFrom)),
          TimeOfDayBand.evening);
      expect(TimeOfDayResolver.resolve(_at(TimeOfDaySpec.lateNightFrom)),
          TimeOfDayBand.lateNight);
    });

    test('the hour before each boundary still belongs to the previous band',
        () {
      expect(TimeOfDayResolver.resolve(_at(TimeOfDaySpec.morningFrom - 1)),
          TimeOfDayBand.lateNight);
      expect(TimeOfDayResolver.resolve(_at(TimeOfDaySpec.middayFrom - 1)),
          TimeOfDayBand.morning);
      expect(TimeOfDayResolver.resolve(_at(TimeOfDaySpec.afternoonFrom - 1)),
          TimeOfDayBand.midday);
      expect(TimeOfDayResolver.resolve(_at(TimeOfDaySpec.eveningFrom - 1)),
          TimeOfDayBand.afternoon);
      expect(TimeOfDayResolver.resolve(_at(TimeOfDaySpec.lateNightFrom - 1)),
          TimeOfDayBand.evening);
    });

    test('late night wraps midnight', () {
      expect(TimeOfDayResolver.isLateNight(_at(23, minute: 59)), isTrue);
      expect(TimeOfDayResolver.isLateNight(_at(0)), isTrue);
      expect(TimeOfDayResolver.isLateNight(_at(4, minute: 59)), isTrue);
      expect(TimeOfDayResolver.isLateNight(_at(5)), isFalse);
      expect(TimeOfDayResolver.isLateNight(_at(22, minute: 59)), isFalse);
    });

    test('only the hour is read — minutes and seconds never matter', () {
      for (var hour = 0; hour < 24; hour++) {
        final atTop = TimeOfDayResolver.resolve(_at(hour));
        final atEnd =
            TimeOfDayResolver.resolve(_at(hour, minute: 59, second: 59));
        expect(atEnd, atTop, reason: 'hour $hour disagreed within itself');
      }
    });

    test('labels are stable identifiers', () {
      expect(TimeOfDayBand.morning.label, 'MORNING');
      expect(TimeOfDayBand.midday.label, 'MIDDAY');
      expect(TimeOfDayBand.afternoon.label, 'AFTERNOON');
      expect(TimeOfDayBand.evening.label, 'EVENING');
      expect(TimeOfDayBand.lateNight.label, 'LATE_NIGHT');
    });
  });

  group('the presentation-only rule is enforced, not asserted', () {
    // `TimeOfDayResolver` may colour a greeting and pick a message. It must
    // never reach the reward economy. Rather than trust convention, scan the
    // layers that own the economy and fail if either references these types.
    test('neither the domain nor the data layer references time-of-day', () {
      const tokens = [
        'TimeOfDayBand',
        'TimeOfDayResolver',
        'TimeOfDaySpec',
        'time_of_day.dart',
      ];
      final offenders = <String>[];

      for (final root in ['lib/domain', 'lib/data']) {
        final directory = Directory(root);
        expect(directory.existsSync(), isTrue,
            reason: '$root must exist for this guard to mean anything');
        for (final entity in directory.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final text = entity.readAsStringSync();
          for (final token in tokens) {
            if (text.contains(token)) offenders.add('${entity.path} -> $token');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'time-of-day is presentation-only; it must not reach '
              'XP, coins, happiness, settlements or streaks');
    });

    test(
        'neither the domain nor the data layer references the encouragement '
        'engine', () {
      const tokens = [
        'PetEncouragementEngine',
        'PetEncouragementScheduler',
        'PetEncouragementBudget',
        'pet_encouragement.dart',
      ];
      final offenders = <String>[];

      for (final root in ['lib/domain', 'lib/data']) {
        for (final entity in Directory(root).listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final text = entity.readAsStringSync();
          for (final token in tokens) {
            if (text.contains(token)) offenders.add('${entity.path} -> $token');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'encouragement is presentation-only and must stay that way');
    });
  });
}
