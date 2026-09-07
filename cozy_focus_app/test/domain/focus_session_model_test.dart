import 'package:test/test.dart';
import 'package:cozy_focus_app/domain/models/focus_session.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';

void main() {
  final baseStart = DateTime(2026, 9, 1, 10, 0, 0);

  FocusSession makeSession({
    List<PauseInterval> pauseIntervals = const [],
    DateTime? endAt,
    FocusSessionStatus status = FocusSessionStatus.running,
  }) {
    return FocusSession(
      id: 'test-id',
      userId: 'user-1',
      plannedSeconds: 1500,
      mode: FocusMode.focus,
      startAt: baseStart,
      pauseIntervals: pauseIntervals,
      endAt: endAt,
      status: status,
      timezoneOffsetMinutes: 480,
    );
  }

  group('FocusSession.elapsedSeconds', () {
    test('no pauses → elapsed = endAt - startAt', () {
      final session = makeSession(
        endAt: baseStart.add(const Duration(minutes: 25)),
        status: FocusSessionStatus.finishing,
      );
      expect(session.elapsedSeconds, equals(1500));
    });

    test('one closed pause → elapsed excludes pause duration', () {
      final session = makeSession(
        pauseIntervals: [
          PauseInterval(
            pauseStart: baseStart.add(const Duration(minutes: 10)),
            pauseEnd: baseStart.add(const Duration(minutes: 15)),
          ),
        ],
        endAt: baseStart.add(const Duration(minutes: 30)),
        status: FocusSessionStatus.finishing,
      );
      // raw = 30min, pause = 5min, elapsed = 25min = 1500s
      expect(session.elapsedSeconds, equals(1500));
    });

    test('open pause (currently paused) → durationSeconds is null', () {
      final pause = PauseInterval(
        pauseStart: baseStart.add(const Duration(minutes: 10)),
      );
      expect(pause.durationSeconds, isNull);
    });

    test('elapsed is never negative', () {
      // endAt == startAt → 0
      final session = makeSession(
        endAt: baseStart,
        status: FocusSessionStatus.finishing,
      );
      expect(session.elapsedSeconds, isNonNegative);
    });
  });

  group('FocusSession.copyWith', () {
    test('status can be changed independently', () {
      final session = makeSession();
      final paused = session.copyWith(status: FocusSessionStatus.paused);
      expect(paused.status, equals(FocusSessionStatus.paused));
      expect(paused.id, equals(session.id));
    });
  });
}
