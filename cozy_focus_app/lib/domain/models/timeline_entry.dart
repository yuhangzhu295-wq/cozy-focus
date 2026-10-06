/// One row on the day's timeline.
///
/// ## Why this is a read model and not a table
///
/// A timeline is a *view* of what already happened: plans live in
/// `task_schedules`, focus lives in `focus_records`, rest will live in its own
/// table, and captured thoughts live in `distraction_notes`. A `timeline_events`
/// table would be a fourth copy of the same facts, and the moment one of the four
/// writes went missing — a focus that ended while the app was closed, a plan
/// edited on another screen — the timeline would be the screen that lied. So
/// nothing here is stored; it is assembled per day from the tables that are.
library;

/// What kind of thing a row is, which decides its icon and its colour.
enum TimelineKind {
  /// Something planned for a time — a placement in `task_schedules`.
  plan('plan'),

  /// A finished or in-flight focus session — a row in `focus_records`.
  focus('focus'),

  /// A deliberate break — a rest session. Arrives with P8.
  rest('rest'),

  /// A thought captured during focus — a row in `distraction_notes`.
  note('note');

  final String id;

  const TimelineKind(this.id);

  /// What the legend calls it.
  String get label => switch (this) {
        TimelineKind.plan => '任务',
        TimelineKind.focus => '专注',
        TimelineKind.rest => '休息',
        TimelineKind.note => '快速记录',
      };
}

/// One row: when it started, what it was, and how long it took.
class TimelineEntry {
  /// When the row sits on the axis.
  ///
  /// For a plan that is its start time; for a focus session its start; for a
  /// captured thought the moment it was made. Rows are ordered by this and by
  /// nothing else, so two rows from the same minute keep a stable order.
  final DateTime at;

  final TimelineKind kind;

  /// The main line — a task title, or the text of a captured thought.
  final String title;

  /// How long it lasted, when that is known. Null for a thought, which has no
  /// duration, and for a plan whose length is not shown.
  final int? durationSeconds;

  /// A second line, when there is something to say: the category, the remaining
  /// time, the session's mood.
  final String? detail;

  /// The id of the row this came from, for tapping through to it.
  final String? sourceId;

  /// Whether this row is the focus session running right now.
  ///
  /// Only ever true for a [TimelineKind.focus] row, and only when the projection
  /// was given a running session. The design highlights this row and gives it a
  /// stop control, which is the only interactive part of the timeline.
  final bool isRunning;

  /// Whether a plan row has been marked finished on the day's plan.
  final bool isDone;

  const TimelineEntry({
    required this.at,
    required this.kind,
    required this.title,
    this.durationSeconds,
    this.detail,
    this.sourceId,
    this.isRunning = false,
    this.isDone = false,
  });

  /// The time as `HH:mm`.
  String get clock =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}
