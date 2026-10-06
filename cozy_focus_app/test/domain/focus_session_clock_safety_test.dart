import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/focus_session.dart';

/// A session's elapsed time survives a clock that moves backwards.
///
/// ## Why this is its own test
///
/// `elapsedSecondsAt` is called once a second by the display ticker. It computed
/// `(raw - paused).clamp(0, raw)`, which throws when `raw` is negative — that is,
/// whenever the reference time is *before* the session's start. That is not a
/// hypothetical: an NTP correction, a timezone change or a user setting the device
/// clock all do it, and the failure is an `ArgumentError` inside a timer callback
/// rather than anything a screen can catch. Found by a P6 test that moved the test
/// clock backwards by mistake; the mistake was worth keeping as a case.
void main() {
  FocusSession sessionAt(DateTime startAt,
          {List<PauseInterval> pauses = const []}) =>
      FocusSession(
        id: 's1',
        userId: 'default_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
        startAt: startAt,
        pauseIntervals: pauses,
        status: FocusSessionStatus.running,
        timezoneOffsetMinutes: 480,
      );

  test('a reference before the start is zero, not a crash', () {
    final session = sessionAt(DateTime(2026, 10, 8, 12));

    expect(session.elapsedSecondsAt(DateTime(2026, 10, 8, 11)), 0,
        reason: 'the clock moved backwards; the session has not run yet');
    expect(session.elapsedSecondsAt(DateTime(2026, 10, 8, 12)), 0);
  });

  test('and it recovers when the clock catches up again', () {
    final session = sessionAt(DateTime(2026, 10, 8, 12));

    expect(session.elapsedSecondsAt(DateTime(2026, 10, 8, 11)), 0);
    expect(session.elapsedSecondsAt(DateTime(2026, 10, 8, 12, 5)), 5 * 60,
        reason: 'a backwards clock must not poison the rest of the session');
  });

  test('a backwards clock during an open pause is zero too', () {
    final session = sessionAt(
      DateTime(2026, 10, 8, 12),
      pauses: [PauseInterval(pauseStart: DateTime(2026, 10, 8, 12, 5))],
    );

    expect(session.elapsedSecondsAt(DateTime(2026, 10, 8, 11)), 0);
  });

  test('the ordinary case is unchanged', () {
    final session = sessionAt(
      DateTime(2026, 10, 8, 12),
      pauses: [
        PauseInterval(
          pauseStart: DateTime(2026, 10, 8, 12, 5),
          pauseEnd: DateTime(2026, 10, 8, 12, 10),
        ),
      ],
    );

    // 30 minutes open, 5 of them paused.
    expect(session.elapsedSecondsAt(DateTime(2026, 10, 8, 12, 30)), 25 * 60);
  });

  test('a finished session ignores the reference entirely', () {
    final session = FocusSession(
      id: 's1',
      userId: 'default_user',
      plannedSeconds: 1500,
      mode: FocusMode.focus,
      startAt: DateTime(2026, 10, 8, 12),
      pauseIntervals: const [],
      endAt: DateTime(2026, 10, 8, 12, 20),
      status: FocusSessionStatus.completed,
      timezoneOffsetMinutes: 480,
    );

    expect(session.elapsedSecondsAt(DateTime(2026, 10, 8, 11)), 20 * 60,
        reason: 'a closed session reads its own end time, so a wrong clock '
            'cannot change what it recorded');
  });
}
