import 'enums.dart';
import 'focus_review.dart';

/// Immutable record written once a session is completed and saved.
/// This is the fact source for all statistics aggregation.
class FocusRecord {
  final String id; // UUIDv4, idempotency key
  final String sessionId; // FK -> focus_sessions.id
  final String userId;
  final String? categoryId;
  final String?
      taskName; // denormalized for history reads without joining sessions

  /// The task this focus was for, when it came from one. Null for a session
  /// started without a task, which stays a first-class way to focus.
  final String? taskId;

  /// A [FocusMood] id, or a legacy emoji from before that vocabulary existed.
  final String? mood;

  /// The chosen [FocusGain] ids, comma separated. Null when none were chosen.
  final String? gains;

  /// What the user wants to try next time.
  final String? nextIntention;

  /// How the session that produced this record counted.
  ///
  /// Carried onto the record so history can say "25 minutes of 番茄钟" without
  /// joining back to a session that may since have been pruned, and so the
  /// timeline and the analytics can tell a timed block from an open one.
  final FocusTimingMode timingMode;

  /// The mood as the app knows it, or null.
  ///
  /// Null covers both "no mood was chosen" and "the stored value is from the old
  /// emoji vocabulary and was not recognised", which the screen shows the same
  /// way: nothing selected.
  FocusMood? get moodValue => FocusMood.fromId(mood);

  /// The gains chosen, ignoring anything unrecognised.
  List<FocusGain> get gainValues => FocusReview.decodeGains(gains);

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
    this.taskId,
    this.mood,
    this.gains,
    this.nextIntention,
    this.timingMode = FocusTimingMode.countdown,
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
    String? taskId,
    String? mood,
    String? gains,
    String? nextIntention,
    FocusTimingMode? timingMode,
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
      taskId: taskId ?? this.taskId,
      mood: mood ?? this.mood,
      gains: gains ?? this.gains,
      nextIntention: nextIntention ?? this.nextIntention,
      timingMode: timingMode ?? this.timingMode,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      recordedAt: recordedAt ?? this.recordedAt,
      isCountedForReward: isCountedForReward ?? this.isCountedForReward,
      note: note ?? this.note,
    );
  }
}
