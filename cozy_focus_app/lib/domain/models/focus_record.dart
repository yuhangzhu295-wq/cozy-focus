/// Immutable record written once a session is completed and saved.
/// This is the fact source for all statistics aggregation.
class FocusRecord {
  final String id; // UUIDv4, idempotency key
  final String sessionId; // FK -> focus_sessions.id
  final String userId;
  final String? categoryId;
  final String?
      taskName; // denormalized for history reads without joining sessions
  final String? mood; // emoji string, e.g. "😊"
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
    this.taskName,
    this.mood,
    required this.durationSeconds,
    required this.startAt,
    required this.endAt,
    required this.recordedAt,
    required this.isCountedForReward,
    this.note,
  });

  FocusRecord copyWith({
    String? id,
    String? sessionId,
    String? userId,
    String? categoryId,
    String? taskName,
    String? mood,
    int? durationSeconds,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? recordedAt,
    bool? isCountedForReward,
    String? note,
  }) {
    return FocusRecord(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      taskName: taskName ?? this.taskName,
      mood: mood ?? this.mood,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      recordedAt: recordedAt ?? this.recordedAt,
      isCountedForReward: isCountedForReward ?? this.isCountedForReward,
      note: note ?? this.note,
    );
  }
}
