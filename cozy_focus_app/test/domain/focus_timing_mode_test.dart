import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/models/enums.dart';

/// P3 — the timing mode's rules, without a database.
///
/// ## Why the mode is not [FocusMode]
///
/// [FocusMode] already has three values, and two of them are breaks. Reusing it
/// for the timer would make `shortBreak` mean both "the user is on a break" and
/// "the timer does not count down", and the two questions would start answering
/// each other: every break would become a flow session, and a flow session would
/// read as a break. These tests pin the separation so a later change cannot
/// quietly merge them.
void main() {
  test('the three modes are the design\'s three', () {
    expect(FocusTimingMode.values.map((m) => m.id),
        ['countdown', 'countUp', 'deepFocus']);
    expect(FocusTimingMode.values.map((m) => m.label), ['番茄钟', '正计时', '深度专注']);
  });

  test('the timing mode and the session mode are different sets', () {
    // The concrete failure this guards against: reading a break as "not a
    // countdown". Nothing about FocusMode should be consultable from here.
    expect(FocusMode.values.map((m) => m.name),
        ['focus', 'shortBreak', 'longBreak']);
    for (final timing in FocusTimingMode.values) {
      expect(FocusMode.values.map((m) => m.name), isNot(contains(timing.id)),
          reason: '${timing.id} must not be a FocusMode value');
    }
  });

  group('hasTarget', () {
    test('is true only for the countdown', () {
      expect(FocusTimingMode.countdown.hasTarget, isTrue);
      expect(FocusTimingMode.countUp.hasTarget, isFalse);
      expect(FocusTimingMode.deepFocus.hasTarget, isFalse);
    });

    test('agrees with autoCompletesAtTarget', () {
      for (final mode in FocusTimingMode.values) {
        expect(mode.autoCompletesAtTarget, mode.hasTarget, reason: mode.id);
      }
    });
  });

  group('allowsPause', () {
    test('is true except for deep focus', () {
      expect(FocusTimingMode.countdown.allowsPause, isTrue);
      expect(FocusTimingMode.countUp.allowsPause, isTrue);
      expect(FocusTimingMode.deepFocus.allowsPause, isFalse,
          reason: 'the promise of deep focus is that it is not interrupted');
    });
  });

  group('fromId', () {
    test('round-trips every mode', () {
      for (final mode in FocusTimingMode.values) {
        expect(FocusTimingMode.fromId(mode.id), mode);
      }
    });

    test('defaults to countdown for a missing or unknown id', () {
      // A session that cannot be read is worse than one read as the common case.
      expect(FocusTimingMode.fromId(null), FocusTimingMode.countdown);
      expect(FocusTimingMode.fromId(''), FocusTimingMode.countdown);
      expect(FocusTimingMode.fromId('pomodoro'), FocusTimingMode.countdown);
    });
  });

  group('fromLegacyPlannedSeconds', () {
    test('reads a session with no length as a flow session', () {
      expect(
          FocusTimingMode.fromLegacyPlannedSeconds(0), FocusTimingMode.countUp);
    });

    test('reads a session with a length as a countdown', () {
      expect(FocusTimingMode.fromLegacyPlannedSeconds(1500),
          FocusTimingMode.countdown);
    });
  });

  test('the default target is the length the app already offers', () {
    expect(FocusTimingMode.defaultTargetSeconds, 25 * 60);
  });
}
