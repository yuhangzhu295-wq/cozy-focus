/// The two decisions the today view makes about a day's plan.
///
/// Both are pure functions over data that already exists — the day's
/// placements, the clock, and the length being planned — because "what should I
/// do next" and "when could this go" are the questions the screen asks, and
/// answering them inside a widget would make them untestable.
library;

import '../models/task_schedule.dart';

/// The placement to put in the 下一个任务 card, or null when the day has none
/// left.
///
/// The earliest placement still marked planned, **in time order rather than
/// clock order**: a card that swapped the task it names because the wall clock
/// crossed a start time would change under the user while they read it, and the
/// plan already puts the times on screen for the user to judge. A placement that
/// has been marked done stops being next, which is the signal that matters.
PlannedTask? nextPlacement(List<PlannedTask> placements) {
  for (final placement in placements) {
    if (placement.schedule.isPlanned) return placement;
  }
  return null;
}

/// Times this placement could start, best first.
///
/// Derived from the day's own plan: candidate starts every half hour through the
/// working day, minus the ones that would collide with a placement already on the
/// day, minus the ones already in the past when the day is today. There is no
/// learned habit model behind this and the UI does not claim one — what it says
/// is 推荐, and what it means is "these are the free times in what you already
/// planned".
List<DateTime> recommendedSlots({
  required DateTime day,
  required List<PlannedTask> existing,
  required DateTime now,
  required int durationSeconds,
  int count = 5,
}) {
  final startOfDay = DateTime(day.year, day.month, day.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  final isToday = !now.isBefore(startOfDay) && now.isBefore(endOfDay);

  final busy = [
    for (final placement in existing)
      (
        from: placement.schedule.startAt,
        to: placement.schedule.startAt
            .add(Duration(seconds: placement.schedule.plannedSeconds)),
      ),
  ];

  final slots = <DateTime>[];
  // 08:00 to 21:00: the hours a focus app is asked to plan for. Earlier and
  // later are still reachable through the time picker, which is not limited to
  // this window.
  for (var minutes = 8 * 60; minutes <= 21 * 60; minutes += 30) {
    final candidate = startOfDay.add(Duration(minutes: minutes));
    if (isToday && !candidate.isAfter(now)) continue;
    final candidateEnd = candidate
        .add(Duration(seconds: durationSeconds <= 0 ? 0 : durationSeconds));
    final collides = busy.any(
      (window) =>
          candidate.isBefore(window.to) && window.from.isBefore(candidateEnd),
    );
    if (collides) continue;
    slots.add(candidate);
    if (slots.length == count) break;
  }
  return slots;
}

/// The next half hour after [now] on [day], for the schedule form's initial
/// value.
///
/// Rounds up rather than down so the default start is not already in the past
/// when the form opens, and on a future day it is the start of the working day.
DateTime defaultStartFor({required DateTime day, required DateTime now}) {
  final startOfDay = DateTime(day.year, day.month, day.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  if (now.isBefore(startOfDay) || !now.isBefore(endOfDay)) {
    return startOfDay.add(const Duration(hours: 9));
  }
  final minutes = now.hour * 60 + now.minute;
  final rounded = ((minutes ~/ 30) + 1) * 30;
  // Late at night the next half hour is tomorrow. Staying on the day the screen
  // is showing beats silently planning for a date the user did not pick.
  if (rounded > 23 * 60 + 30) {
    return startOfDay.add(const Duration(hours: 23, minutes: 30));
  }
  return startOfDay.add(Duration(minutes: rounded));
}
