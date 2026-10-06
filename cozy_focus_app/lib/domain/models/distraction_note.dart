/// A thought captured during focus.
library;

import 'task.dart';

/// Where a note is in its life.
///
/// Two states, not three: a note is either still waiting for a decision or it has
/// had one. The decision itself is recorded by [DistractionNote.convertedTaskId]
/// — "it became a task" — rather than by a third status, because a status can say
/// only that something happened while the id says what.
enum DistractionNoteStatus {
  open('open'),
  handled('handled');

  final String id;
  const DistractionNoteStatus(this.id);

  static DistractionNoteStatus fromId(String? id) {
    for (final status in DistractionNoteStatus.values) {
      if (status.id == id) return status;
    }
    return DistractionNoteStatus.open;
  }
}

/// One captured thought.
class DistractionNote {
  final String id;
  final String userId;

  /// What the user typed. The sheet's limit is [maxTextLength].
  final String text;

  /// The optional tag, one of the shipped category ids, or null.
  final String? categoryId;

  final DistractionNoteStatus status;
  final DateTime createdAt;
  final DateTime? handledAt;

  /// The task this note became, when it was converted.
  final String? convertedTaskId;

  /// The focus session it arrived during, when there was one.
  final String? sessionId;

  /// The length the sheet's counter enforces. Shorter than a task's note limit
  /// because this is meant to be typed in seconds, mid-focus, and a long field
  /// invites writing the whole thing down instead of getting back to work.
  static const int maxTextLength = 100;

  /// The length a note is given when it is placed on a day.
  ///
  /// A note carries no estimate, and the app's own first preset is the honest
  /// default: a converted note is scheduled the same way a task typed on the
  /// create screen is, rather than by a number invented for this path.
  static const int defaultPlacementSeconds = 25 * 60;

  const DistractionNote({
    required this.id,
    required this.userId,
    required this.text,
    this.categoryId,
    this.status = DistractionNoteStatus.open,
    required this.createdAt,
    this.handledAt,
    this.convertedTaskId,
    this.sessionId,
  });

  bool get isOpen => status == DistractionNoteStatus.open;

  /// Whether this note was turned into something.
  bool get wasConverted => convertedTaskId != null;

  /// The tag as the app knows it, or null for an untagged note.
  ///
  /// Goes through [taskCategoryFor] so an unknown stored id stays unknown rather
  /// than being shown as 其他, the same rule the task list follows.
  TaskCategory? get category => taskCategoryFor(categoryId);

  DistractionNote copyWith({
    String? text,
    String? categoryId,
    DistractionNoteStatus? status,
    DateTime? handledAt,
    String? convertedTaskId,
  }) =>
      DistractionNote(
        id: id,
        userId: userId,
        text: text ?? this.text,
        categoryId: categoryId ?? this.categoryId,
        status: status ?? this.status,
        createdAt: createdAt,
        handledAt: handledAt ?? this.handledAt,
        convertedTaskId: convertedTaskId ?? this.convertedTaskId,
        sessionId: sessionId,
      );
}

/// Which notes the inbox is showing.
enum DistractionFilter {
  open('open', '待处理'),
  all('all', '全部'),
  handled('handled', '已处理');

  final String id;
  final String label;

  const DistractionFilter(this.id, this.label);
}
