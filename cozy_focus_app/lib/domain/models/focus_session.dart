import 'enums.dart';

/// Represents one in-progress or completed focus session.
///
/// Timing truth: elapsed = endAt - startAt - sum(pauseIntervals)
/// Timer.periodic is forbidden as the elapsed-time fact source.
class FocusSession {
  final String id; // UUIDv4
  final String userId;
  final String? categoryId;
  final String? taskName; // persisted so history/reports can read it after restart
  final int plannedSeconds; // user-chosen duration
  final FocusMode mode;

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
    required this.plannedSeconds,
    required this.mode,
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

  bool get isActive =>
      status == FocusSessionStatus.running ||
      status == FocusSessionStatus.paused ||
      status == FocusSessionStatus.restored;

  FocusSession copyWith({
    String? categoryId,
    String? taskName,
    List<PauseInterval>? pauseIntervals,
    DateTime? endAt,
    FocusSessionStatus? status,
  }) {
    return FocusSession(
      id: id,
      userId: userId,
      categoryId: categoryId ?? this.categoryId,
      taskName: taskName ?? this.taskName,
      plannedSeconds: plannedSeconds,
      mode: mode,
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