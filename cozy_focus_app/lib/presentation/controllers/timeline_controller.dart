import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/task_schedule.dart';
import '../../domain/models/timeline_entry.dart';
import '../../domain/services/timeline_projection.dart';
import 'focus_session_controller.dart';
import 'providers.dart';

/// One day's timeline, assembled from the tables that already hold the facts.
///
/// ## Why a provider and not a controller
///
/// There is nothing to mutate: the timeline is a projection, and every action
/// taken from it goes through the controller that owns the underlying fact — the
/// focus controller to stop a session, the plan controller to change a placement.
/// A controller here would be a second place that writes, which is the thing the
/// read-model rule exists to prevent.
///
/// Keyed by the day, so switching days does not re-query the ones already loaded
/// and two screens looking at the same day share one answer.
final dayTimelineProvider =
    FutureProvider.family<List<TimelineEntry>, DateTime>((ref, day) async {
  final userId = ref.watch(currentUserIdProvider);
  final clock = ref.watch(focusClockProvider);
  final midnight = DateTime(day.year, day.month, day.day);
  final nextMidnight = midnight.add(const Duration(days: 1));

  final plan = await ref
      .watch(taskRepositoryProvider)
      .schedulesForDay(userId, dayKeyFor(midnight));
  final focus = await ref
      .watch(focusRecordRepositoryProvider)
      .findByDateRange(userId, from: midnight, to: nextMidnight);
  final notes = await ref
      .watch(distractionRepositoryProvider)
      .notesBetween(userId, midnight, nextMidnight);

  // The session in flight, if there is one and it started on this day. Read from
  // the controller's current session rather than from the database, because a
  // running session has no record yet.
  final live = ref.watch(focusSessionControllerProvider).session;
  final runningOnThisDay = live != null &&
      !live.startAt.isBefore(midnight) &&
      live.startAt.isBefore(nextMidnight);

  return buildTimeline(
    facts: TimelineDayFacts(
      plan: plan,
      focus: focus,
      notes: [
        for (final note in notes)
          (at: note.createdAt, text: note.text, id: note.id),
      ],
    ),
    now: clock.now(),
    runningSessionId: runningOnThisDay ? live.id : null,
    runningSession: runningOnThisDay
        ? (
            startAt: live.startAt,
            plannedSeconds: live.plannedSeconds,
            taskName: live.taskName,
          )
        : null,
  );
});
