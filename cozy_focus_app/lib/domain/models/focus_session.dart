import 'enums.dart';

/// Represents one in-progress or completed focus session.
///
/// Timing truth: elapsed = endAt - startAt - sum(pauseIntervals)
/// Timer.periodic is forbidden as the elapsed-time fact source.
class FocusSession {
  final String id;              // UUIDv4
  final String userId;
  final String? categoryId;
  final int plannedSeconds;     // user-chosen duration
  final FocusMode mode;

  final DateTime startAt;       // monotonic-safe local timestamp

  /// Each entry is a closed [pauseStart, pauseEnd] pair.
  /// An open pause has pauseEnd == null (session currently paused).
  final List<PauseInterval> pauseIntervals;

  final DateTime? endAt;        // null while running or paused
  final FocusSessionStatus status;

  /// Device local timezone offset in minutes at session start.
  final int timezoneOffsetMinutes;

  const FocusSession({
    required this.id,
    required this.userId,
    this.categoryId,
    required this.plannedSeconds,
    required this.mode,
    required this.startAt,
    required this.pauseIntervals,
    this.endAt,
    required this.status,
    required this.timezoneOffsetMinutes,
  });

  /// Actual elapsed seconds, safe for background / kill / restore scenarios.
  int get elapsedSeconds {
    final reference = endAt ?? DateTime.now();
    final raw = reference.difference(startAt).inSeconds;
    final paused = pauseIntervals.fold<int>(
      0,
      (acc, p) => acc + (p.durationSeconds ?? 0),
    );
    return (raw - paused).clamp(0, raw);
  }

  bool get isActive =>
      status == FocusSessionStatus.running ||
      status == FocusSessionStatus.paused;

  FocusSession copyWith({
    List<PauseInterval>? pauseIntervals,
    DateTime? endAt,
    FocusSessionStatus? status,
  }) {
    return FocusSession(
      id: id,
      userId: userId,
      categoryId: categoryId,
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
