import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/models/task_schedule.dart';
import 'package:cozy_focus_app/domain/services/today_planner.dart';

/// P2 — the two decisions the today view makes, tested without a database.
///
/// ## Why these are their own tests
///
/// "What is next" and "when could this go" are the only two places the plan
/// screen reasons rather than displays. Both are pure functions, so they can be
/// pinned exactly — including the cases a screen test would have to construct a
/// whole day to reach, like the last half hour before midnight.
void main() {
  const userId = 'default_user';

  PlannedTask placed({
    required String id,
    required DateTime startAt,
    int minutes = 25,
    String title = '写产品方案',
    TaskScheduleStatus status = TaskScheduleStatus.planned,
  }) {
    return PlannedTask(
      schedule: TaskSchedule(
        id: id,
        taskId: 'task_$id',
        userId: userId,
        date: dayKeyFor(startAt),
        startAt: startAt,
        plannedSeconds: minutes * 60,
        status: status,
        createdAt: startAt,
      ),
      title: title,
    );
  }

  group('nextPlacement', () {
    test('is the earliest still-planned placement', () {
      final day = [
        placed(id: 'a', startAt: DateTime(2026, 10, 7, 9)),
        placed(id: 'b', startAt: DateTime(2026, 10, 7, 11)),
      ];
      expect(nextPlacement(day)!.schedule.id, 'a');
    });

    test('skips the ones already marked done', () {
      final day = [
        placed(
          id: 'a',
          startAt: DateTime(2026, 10, 7, 9),
          status: TaskScheduleStatus.done,
        ),
        placed(id: 'b', startAt: DateTime(2026, 10, 7, 11)),
      ];
      expect(nextPlacement(day)!.schedule.id, 'b',
          reason: 'a finished task is not the next thing to do');
    });

    test('is null when everything is done', () {
      final day = [
        placed(
          id: 'a',
          startAt: DateTime(2026, 10, 7, 9),
          status: TaskScheduleStatus.done,
        ),
      ];
      expect(nextPlacement(day), isNull);
    });

    test('does not move on because the clock passed a start time', () {
      // The card names the earliest planned task even if its start time is
      // behind us: a card that renamed itself while the user read it would be
      // worse than one that is slightly out of date, and the row below it still
      // shows the time.
      final day = [
        placed(id: 'a', startAt: DateTime(2026, 10, 7, 9)),
        placed(id: 'b', startAt: DateTime(2026, 10, 7, 11)),
      ];
      expect(nextPlacement(day)!.schedule.id, 'a');
    });

    test('is null for an empty day', () {
      expect(nextPlacement(const []), isNull);
    });
  });

  group('recommendedSlots', () {
    final now = DateTime(2026, 10, 7, 8);
    final today = DateTime(2026, 10, 7);

    test('offers half-hour starts from the working morning', () {
      final slots = recommendedSlots(
        day: today,
        existing: const [],
        now: now,
        durationSeconds: 25 * 60,
      );
      expect(slots.first, DateTime(2026, 10, 7, 8, 30),
          reason: 'the first slot is after now, not on top of it');
      expect(slots[1], DateTime(2026, 10, 7, 9));
      expect(slots, hasLength(5));
    });

    test('skips the times a placement already occupies', () {
      final slots = recommendedSlots(
        day: today,
        existing: [
          placed(id: 'a', startAt: DateTime(2026, 10, 7, 9), minutes: 60)
        ],
        now: now,
        durationSeconds: 25 * 60,
      );
      // 09:00-10:00 is taken, so 09:00 and 09:30 are out and 10:00 is free.
      expect(slots, isNot(contains(DateTime(2026, 10, 7, 9))));
      expect(slots, isNot(contains(DateTime(2026, 10, 7, 9, 30))));
      expect(slots, contains(DateTime(2026, 10, 7, 10)));
    });

    test('a long task cannot be offered a slot that runs into the next one',
        () {
      final slots = recommendedSlots(
        day: today,
        existing: [
          placed(id: 'a', startAt: DateTime(2026, 10, 7, 10), minutes: 60)
        ],
        now: now,
        durationSeconds: 90 * 60,
      );
      // A 90 minute block at 09:00 would run to 10:30 and collide.
      expect(slots, isNot(contains(DateTime(2026, 10, 7, 9))));
      expect(slots.first, DateTime(2026, 10, 7, 8, 30));
    });

    test('drops the times already past when the day is today', () {
      final slots = recommendedSlots(
        day: today,
        existing: const [],
        now: DateTime(2026, 10, 7, 14, 20),
        durationSeconds: 25 * 60,
      );
      expect(slots.first, DateTime(2026, 10, 7, 14, 30));
      expect(
        slots.every((slot) => slot.isAfter(DateTime(2026, 10, 7, 14, 20))),
        isTrue,
      );
    });

    test('does not drop past times when the day is another day', () {
      final slots = recommendedSlots(
        day: DateTime(2026, 10, 8),
        existing: const [],
        now: DateTime(2026, 10, 7, 14, 20),
        durationSeconds: 25 * 60,
      );
      expect(slots.first, DateTime(2026, 10, 8, 8));
    });

    test('gives an empty list rather than a wrong time when the day is full',
        () {
      final busy = [
        for (var hour = 8; hour <= 21; hour++)
          placed(
            id: 'busy_$hour',
            startAt: DateTime(2026, 10, 7, hour),
            minutes: 60,
          ),
      ];
      final slots = recommendedSlots(
        day: today,
        existing: busy,
        now: now,
        durationSeconds: 25 * 60,
      );
      expect(slots, isEmpty,
          reason: 'offering a time that is already taken is worse than none');
    });
  });

  group('defaultStartFor', () {
    test('rounds up to the next half hour', () {
      expect(
        defaultStartFor(
            day: DateTime(2026, 10, 7), now: DateTime(2026, 10, 7, 9, 12)),
        DateTime(2026, 10, 7, 9, 30),
      );
      expect(
        defaultStartFor(
            day: DateTime(2026, 10, 7), now: DateTime(2026, 10, 7, 9, 30)),
        DateTime(2026, 10, 7, 10),
        reason: 'a start exactly on the half hour is still in the past by the '
            'time the form is usable',
      );
    });

    test('is the start of the working day for another day', () {
      expect(
        defaultStartFor(
            day: DateTime(2026, 10, 8), now: DateTime(2026, 10, 7, 9)),
        DateTime(2026, 10, 8, 9),
      );
    });

    test('stays on the chosen day late at night', () {
      // 23:45 rounds to tomorrow, which is a day the user did not pick.
      expect(
        defaultStartFor(
            day: DateTime(2026, 10, 7), now: DateTime(2026, 10, 7, 23, 45)),
        DateTime(2026, 10, 7, 23, 30),
      );
    });
  });

  group('dayKeyFor', () {
    test('is the local calendar day, zero padded', () {
      expect(dayKeyFor(DateTime(2026, 10, 7, 23, 59)), '2026-10-07');
      expect(dayKeyFor(DateTime(2026, 1, 9, 0, 0)), '2026-01-09');
    });
  });

  group('TaskSchedule.copyWith', () {
    test('re-derives the day when the time moves to another day', () {
      final original = TaskSchedule(
        id: 's1',
        taskId: 't1',
        userId: userId,
        date: '2026-10-07',
        startAt: DateTime(2026, 10, 7, 9),
        plannedSeconds: 1500,
        createdAt: DateTime(2026, 10, 7, 8),
      );
      final moved = original.copyWith(startAt: DateTime(2026, 10, 8, 9));
      expect(moved.date, '2026-10-08',
          reason: 'the two cannot be allowed to disagree — the day is what the '
              'today view queries on');
    });
  });
}
