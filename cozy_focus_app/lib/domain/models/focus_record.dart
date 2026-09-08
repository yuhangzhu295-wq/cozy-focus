/// Immutable record written once a session is completed and saved.
/// This is the fact source for all statistics aggregation.
class FocusRecord {
  final String id; // UUIDv4, idempotency key
  final String sessionId; // FK → focus_sessions.id
  final String userId;
  final String? categoryId;
  final int durationSeconds; // actual elapsed, never planned
  final DateTime startAt;
  final DateTime endAt;
  final DateTime recordedAt; // wall clock when record was written
  final bool isCountedForReward;
  final String? note;

  const FocusRecord({
    required this.id,
    required this.sessionId,
    required this.userId,
    this.categoryId,
    required this.durationSeconds,
    required this.startAt,
    required this.endAt,
    required this.recordedAt,
    required this.isCountedForReward,
    this.note,
  });
}
