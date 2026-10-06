/// A deliberate break.
library;

/// Where a rest is in its life.
enum RestStatus {
  running('running'),
  completed('completed'),
  cancelled('cancelled');

  final String id;
  const RestStatus(this.id);

  static RestStatus fromId(String? id) {
    for (final status in RestStatus.values) {
      if (status.id == id) return status;
    }
    return RestStatus.running;
  }
}

/// One rest, from the moment it started.
class RestSession {
  final String id;
  final String userId;

  /// How long the user asked for, in seconds.
  final int plannedSeconds;

  final DateTime startAt;

  /// Null while it is still running.
  final DateTime? endAt;

  final RestStatus status;
  final DateTime createdAt;

  const RestSession({
    required this.id,
    required this.userId,
    required this.plannedSeconds,
    required this.startAt,
    this.endAt,
    this.status = RestStatus.running,
    required this.createdAt,
  });

  /// The lengths the screen offers, in the order the design shows them.
  static const List<int> presets = [5, 10, 15, 30];

  static const int defaultMinutes = 10;

  bool get isRunning => status == RestStatus.running;

  /// How long the rest actually lasted, given a reference time for one still
  /// running.
  ///
  /// Timestamps rather than a ticker, the same rule the focus timer follows, and
  /// clamped at zero for a clock that has moved backwards.
  int elapsedSecondsAt(DateTime now) {
    final reference = endAt ?? now;
    final raw = reference.difference(startAt).inSeconds;
    return raw <= 0 ? 0 : raw;
  }

  /// How much of the planned length is left, or null when the rest is over.
  int? remainingSecondsAt(DateTime now) {
    if (!isRunning) return null;
    final remaining = plannedSeconds - elapsedSecondsAt(now);
    return remaining <= 0 ? 0 : remaining;
  }

  RestSession copyWith({DateTime? endAt, RestStatus? status}) => RestSession(
        id: id,
        userId: userId,
        plannedSeconds: plannedSeconds,
        startAt: startAt,
        endAt: endAt ?? this.endAt,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
