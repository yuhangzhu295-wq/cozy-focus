import 'enums.dart';

/// Represents one in-progress or completed focus session.
///
/// Timing truth: elapsed = endAt - startAt - sum(pauseIntervals)
/// Timer.periodic is forbidden as the elapsed-time fact source.
class FocusSession {
  final String id; // UUIDv4
  final String userId;
  final String? categoryId;
  final String?
      taskName; // persisted so history/reports can read it after restart

  /// The task this session is for, when it was started from one.
  final String? taskId;

  /// The target length for a [FocusTimingMode.countdown] session, and 0 for the
  /// modes that have no target.
  ///
  /// Kept as the target rather than as "whatever the user typed" so that the one
  /// question the timer asks — is there a length to count down from — has one
  /// answer, [timingMode].[FocusTimingMode.hasTarget].
  final int plannedSeconds;

  final FocusMode mode;

  /// How the timer counts. See [FocusTimingMode] for why this is not [mode].
  final FocusTimingMode timingMode;

  final DateTime startAt; // monotonic-safe local timestamp

  /// Each entry is a closed [pauseStart, pauseEnd] pair.
  /// An open pause has pauseEnd == null (session currently paused).
  final List<PauseInterval> pauseIntervals;

  final DateTime? endAt; // null while running or paused
  final FocusSessionStatus status;

  /// Device local timezone offset in minutes at session start.
  final int timezoneOffsetMinutes;

  const FocusSession({
    required this.id,
    required this.userId,
    this.categoryId,
    this.taskName,
    this.taskId,
    required this.plannedSeconds,
    required this.mode,
    this.timingMode = FocusTimingMode.countdown,
    required this.startAt,
    required this.pauseIntervals,
    this.endAt,
    required this.status,
    required this.timezoneOffsetMinutes,
  });

  /// Compute elapsed seconds given a reference "now" from the injected clock.
  ///
  /// For completed sessions [endAt] is non-null (set by FocusClock), so
  /// [nowForOpenSession] is ignored. For running/paused sessions pass the
  /// current clock time so the caller controls the time source.
  int elapsedSecondsAt(DateTime nowForOpenSession) {
    final reference = endAt ?? nowForOpenSession;
    final raw = reference.difference(startAt).inSeconds;
    // A reference before the start is not a session with negative focus time —
    // it is a clock that moved backwards, which happens on an NTP correction, a
    // timezone change or a user setting the device clock. Returning zero keeps
    // the timer honest; letting it through reached `clamp(0, raw)` with the
    // bounds the wrong way round, which throws and takes the display ticker with
    // it.
    if (raw <= 0) return 0;
    final paused = pauseIntervals.fold<int>(0, (acc, p) {
      if (p.pauseEnd != null) {
        return acc + p.pauseEnd!.difference(p.pauseStart).inSeconds;
      } else {
        // Open pause: accumulate up to reference
        return acc + reference.difference(p.pauseStart).inSeconds;
      }
    });
    return (raw - paused).clamp(0, raw);
  }

  /// Convenience getter using DateTime.now() — kept for existing tests that
  /// do not inject a clock. Production code must call elapsedSecondsAt(clock.now()).
  int get elapsedSeconds => elapsedSecondsAt(DateTime.now());

  /// A session the user can still drive forward (pause / resume / complete).
  ///
  /// Derived from [FocusSessionStatusSets.isResumable] so the status set is not
  /// spelled out a second time — see the note in enums.dart.
  bool get isActive => status.isResumable;

  /// Ended but not yet persisted as a FocusRecord — the session still owes a
  /// save. See [FocusSessionStatusSets.isUnfinished].
  bool get isUnfinished => status.isUnfinished;

  FocusSession copyWith({
    String? categoryId,
    String? taskName,
    String? taskId,
    int? plannedSeconds,
    FocusTimingMode? timingMode,
    List<PauseInterval>? pauseIntervals,
    DateTime? endAt,
    FocusSessionStatus? status,
  }) {
    return FocusSession(
      id: id,
      userId: userId,
      categoryId: categoryId ?? this.categoryId,
      taskName: taskName ?? this.taskName,
      taskId: taskId ?? this.taskId,
      plannedSeconds: plannedSeconds ?? this.plannedSeconds,
      mode: mode,
      timingMode: timingMode ?? this.timingMode,
      startAt: startAt,
      pauseIntervals: pauseIntervals ?? this.pauseIntervals,
      endAt: endAt ?? this.endAt,
      status: status ?? this.status,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
    );
  }
}

class PauseInterval {
  final DateTime pauseStart;
  final DateTime? pauseEnd;

  const PauseInterval({required this.pauseStart, this.pauseEnd});

  /// Returns null if the pause is still open.
  int? get durationSeconds {
    if (pauseEnd == null) return null;
    return pauseEnd!.difference(pauseStart).inSeconds.clamp(0, 86400);
  }
}
