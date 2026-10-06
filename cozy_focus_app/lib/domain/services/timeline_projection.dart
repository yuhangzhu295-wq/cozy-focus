/// Assembles one day's timeline out of the facts that already exist.
///
/// ## The one rule that matters
///
/// Nothing is invented and nothing is merged away. A plan for 09:00 and the focus
/// session that actually happened at 10:30 are two different true things, so both
/// appear; the plan does not become the focus and the focus does not replace the
/// plan. That is what makes the timeline worth reading next to the plan view: it
/// shows where the day agreed with the plan and where it did not.
library;

import '../models/focus_record.dart';
import '../models/rest_session.dart';
import '../models/task.dart';
import '../models/task_schedule.dart';
import '../models/timeline_entry.dart';
import 'duration_text.dart';

/// Everything the projection needs about one day, gathered by the caller.
///
/// Passed as one object rather than five arguments so a new source — rest
/// sessions in P8 — is one field and one loop, and so a test can describe a day
/// without constructing a database.
class TimelineDayFacts {
  /// The day's placements, in time order.
  final List<PlannedTask> plan;

  /// The day's focus records, in start order.
  final List<FocusRecord> focus;

  /// The day's captured thoughts, in arrival order.
  final List<({DateTime at, String text, String? id})> notes;

  /// The day's rests.
  final List<RestSession> rest;

  const TimelineDayFacts({
    this.plan = const [],
    this.focus = const [],
    this.notes = const [],
    this.rest = const [],
  });

  bool get isEmpty =>
      plan.isEmpty && focus.isEmpty && notes.isEmpty && rest.isEmpty;
}

/// The day's rows, earliest first.
///
/// [now] and [runningSessionId] are what let the projection mark the session that
/// is happening right now: without them a session that has not finished yet would
/// be missing from the timeline entirely, because a focus record is only written
/// when the session is saved.
List<TimelineEntry> buildTimeline({
  required TimelineDayFacts facts,
  required DateTime now,
  String? runningSessionId,
  ({DateTime startAt, int plannedSeconds, String? taskName})? runningSession,
}) {
  final entries = <TimelineEntry>[];

  for (final placement in facts.plan) {
    final category = taskCategoryFor(placement.categoryId)?.label;
    entries.add(TimelineEntry(
      at: placement.schedule.startAt,
      kind: TimelineKind.plan,
      title: placement.title,
      durationSeconds: placement.schedule.plannedSeconds,
      detail: category,
      sourceId: placement.schedule.taskId,
      isDone: !placement.schedule.isPlanned,
    ));
  }

  for (final record in facts.focus) {
    entries.add(TimelineEntry(
      at: record.startAt,
      kind: TimelineKind.focus,
      title: record.taskName?.isNotEmpty == true ? record.taskName! : '专注',
      durationSeconds: record.durationSeconds,
      detail: _focusDetail(record),
      sourceId: record.id,
      isRunning: record.sessionId == runningSessionId,
    ));
  }

  // The session in flight. It has no record yet, so it is added from the live
  // session rather than waited for — a running focus is the row the design
  // highlights, and a timeline that omitted it would be missing the present.
  if (runningSession != null && runningSessionId != null) {
    entries.add(TimelineEntry(
      at: runningSession.startAt,
      kind: TimelineKind.focus,
      title: runningSession.taskName?.isNotEmpty == true
          ? runningSession.taskName!
          : '专注',
      durationSeconds: runningSession.plannedSeconds,
      detail: _runningDetail(runningSession, now),
      sourceId: runningSessionId,
      isRunning: true,
    ));
  }

  for (final rest in facts.rest) {
    // A running rest has no end yet, so its row shows how long it has been going
    // rather than a length it has not reached.
    final ended = rest.endAt;
    entries.add(TimelineEntry(
      at: rest.startAt,
      kind: TimelineKind.rest,
      title: ended == null ? '休息中' : '休息一下',
      durationSeconds: ended == null
          ? rest.elapsedSecondsAt(now)
          : ended.difference(rest.startAt).inSeconds,
      detail: ended == null
          ? '已休息 ${formatDurationText(rest.elapsedSecondsAt(now))}'
          : rest.status == RestStatus.cancelled
              ? '${formatDurationText(ended.difference(rest.startAt).inSeconds)} · 提前结束'
              : null,
      sourceId: rest.id,
      isRunning: ended == null,
    ));
  }

  for (final note in facts.notes) {
    entries.add(TimelineEntry(
      at: note.at,
      kind: TimelineKind.note,
      title: note.text,
      sourceId: note.id,
    ));
  }

  entries.sort((a, b) {
    final byTime = a.at.compareTo(b.at);
    if (byTime != 0) return byTime;
    // A stable order for rows in the same minute: plans first, then what actually
    // happened, then what was written down. Without this, two rows at 09:00 would
    // swap places between rebuilds.
    return a.kind.index.compareTo(b.kind.index);
  });
  return entries;
}

/// `25 分钟` or `25 分钟 · 心流`.
String _focusDetail(FocusRecord record) {
  final parts = <String>[formatDurationText(record.durationSeconds)];
  final mood = record.moodValue;
  if (mood != null) parts.add(mood.label);
  return parts.join(' · ');
}

/// `50 分钟 · 剩余 25 分钟`, for the session still running.
String _runningDetail(
  ({DateTime startAt, int plannedSeconds, String? taskName}) session,
  DateTime now,
) {
  final elapsed = now.difference(session.startAt).inSeconds.clamp(0, 1 << 31);
  final parts = <String>[formatDurationText(session.plannedSeconds)];
  if (session.plannedSeconds > 0) {
    final remaining =
        (session.plannedSeconds - elapsed).clamp(0, session.plannedSeconds);
    parts.add('剩余 ${formatDurationText(remaining)}');
  } else {
    parts.add('已专注 ${formatDurationText(elapsed)}');
  }
  return parts.join(' · ');
}
