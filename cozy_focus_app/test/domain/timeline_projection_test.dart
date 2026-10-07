import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/models/focus_review.dart';
import 'package:cozy_focus_app/domain/models/task_schedule.dart';
import 'package:cozy_focus_app/domain/models/timeline_entry.dart';
import 'package:cozy_focus_app/domain/services/timeline_projection.dart';

/// P6 — the day's timeline, as a pure projection.
///
/// ## What is being pinned
///
/// That the timeline is assembled from the facts rather than from a copy of them,
/// and that it does not merge two facts into one row. A plan for 09:00 and the
/// focus that happened at 10:30 are different things, and the gap between them is
/// the reason to look at this screen at all.
void main() {
  const userId = 'default_user';

  PlannedTask placed({
    required String id,
    required String title,
    required DateTime startAt,
    int minutes = 25,
    String? categoryId,
    TaskScheduleStatus status = TaskScheduleStatus.planned,
  }) =>
      PlannedTask(
        schedule: TaskSchedule(
          id: 's_$id',
          taskId: id,
          userId: userId,
          date: dayKeyFor(startAt),
          startAt: startAt,
          plannedSeconds: minutes * 60,
          status: status,
          createdAt: startAt,
        ),
        title: title,
        categoryId: categoryId,
      );

  FocusRecord focused({
    required String id,
    required DateTime startAt,
    int minutes = 25,
    String? taskName,
    String? mood,
    String? sessionId,
  }) =>
      FocusRecord(
        id: id,
        sessionId: sessionId ?? 'sess_$id',
        userId: userId,
        taskName: taskName,
        mood: mood,
        durationSeconds: minutes * 60,
        startAt: startAt,
        endAt: startAt.add(Duration(minutes: minutes)),
        recordedAt: startAt,
        isCountedForReward: true,
      );

  List<TimelineEntry> project(
    TimelineDayFacts facts, {
    DateTime? now,
    String? runningSessionId,
    ({DateTime startAt, int plannedSeconds, String? taskName})? runningSession,
  }) =>
      buildTimeline(
        facts: facts,
        now: now ?? DateTime(2026, 10, 8, 12),
        runningSessionId: runningSessionId,
        runningSession: runningSession,
      );

  test('an empty day is an empty timeline', () {
    expect(project(const TimelineDayFacts()), isEmpty);
    expect(const TimelineDayFacts().isEmpty, isTrue);
  });

  test('plans, focus and notes come out in time order', () {
    final entries = project(TimelineDayFacts(
      plan: [
        placed(id: 't1', title: '写产品方案', startAt: DateTime(2026, 10, 8, 9)),
        placed(id: 't2', title: '健身', startAt: DateTime(2026, 10, 8, 14)),
      ],
      focus: [
        focused(
          id: 'r1',
          startAt: DateTime(2026, 10, 8, 10, 30),
          taskName: '专题阅读',
        ),
      ],
      notes: [
        (at: DateTime(2026, 10, 8, 12), text: '买充电线', id: 'n1'),
      ],
    ));

    expect(entries.map((e) => e.clock), ['09:00', '10:30', '12:00', '14:00']);
    expect(entries.map((e) => e.kind), [
      TimelineKind.plan,
      TimelineKind.focus,
      TimelineKind.note,
      TimelineKind.plan,
    ]);
  });

  test('a plan and the focus that followed it are two rows', () {
    // The whole point of the screen: the plan said 09:00 and the work happened at
    // 10:30, and both are true.
    final entries = project(TimelineDayFacts(
      plan: [
        placed(id: 't1', title: '写产品方案', startAt: DateTime(2026, 10, 8, 9)),
      ],
      focus: [
        focused(
          id: 'r1',
          startAt: DateTime(2026, 10, 8, 10, 30),
          taskName: '写产品方案',
        ),
      ],
    ));

    expect(entries, hasLength(2));
    expect(entries.first.kind, TimelineKind.plan);
    expect(entries.last.kind, TimelineKind.focus);
    expect(entries.last.durationSeconds, 25 * 60);
  });

  test('a plan row carries its category and whether it is done', () {
    final entries = project(TimelineDayFacts(
      plan: [
        placed(
          id: 't1',
          title: '写产品方案',
          startAt: DateTime(2026, 10, 8, 9),
          categoryId: 'work',
        ),
        placed(
          id: 't2',
          title: '健身',
          startAt: DateTime(2026, 10, 8, 14),
          status: TaskScheduleStatus.done,
        ),
      ],
    ));

    expect(entries.first.detail, '25 分钟 · 工作',
        reason: 'the design puts a duration on every row');
    expect(entries.first.isDone, isFalse);
    expect(entries.last.isDone, isTrue);
  });

  test('an unknown category is left blank rather than shown as 其他', () {
    final entries = project(TimelineDayFacts(
      plan: [
        placed(
          id: 't1',
          title: '写产品方案',
          startAt: DateTime(2026, 10, 8, 9),
          categoryId: 'from-the-future',
        ),
      ],
    ));

    expect(entries.single.detail, '25 分钟',
        reason: 'a plan row with no category still shows its length');
  });

  test('a focus row says how long it was, and its mood when there was one', () {
    final entries = project(TimelineDayFacts(
      focus: [
        focused(id: 'r1', startAt: DateTime(2026, 10, 8, 10), minutes: 50),
        focused(
          id: 'r2',
          startAt: DateTime(2026, 10, 8, 11, 30),
          minutes: 25,
          mood: FocusMood.flow.id,
        ),
      ],
    ));

    expect(entries.first.detail, '50 分钟');
    expect(entries.last.detail, '25 分钟 · 心流');
  });

  test('a focus row with no task name is still a row', () {
    final entries = project(TimelineDayFacts(
      focus: [focused(id: 'r1', startAt: DateTime(2026, 10, 8, 10))],
    ));
    expect(entries.single.title, '专注');
  });

  test('a note has no duration', () {
    final entries = project(TimelineDayFacts(
      notes: [(at: DateTime(2026, 10, 8, 12), text: '买充电线', id: 'n1')],
    ));
    expect(entries.single.durationSeconds, isNull);
    expect(entries.single.detail, isNull,
        reason: 'a thought has no length, so there is nothing to say');
  });

  group('the session in flight', () {
    test('is added from the live session, because it has no record yet', () {
      final entries = project(
        TimelineDayFacts(
          plan: [
            placed(id: 't1', title: '写产品方案', startAt: DateTime(2026, 10, 8, 9)),
          ],
        ),
        now: DateTime(2026, 10, 8, 10, 25),
        runningSessionId: 'live',
        runningSession: (
          startAt: DateTime(2026, 10, 8, 10),
          plannedSeconds: 50 * 60,
          taskName: '专题阅读',
        ),
      );

      expect(entries, hasLength(2));
      final running = entries.last;
      expect(running.isRunning, isTrue);
      expect(running.title, '专题阅读');
      expect(running.detail, '50 分钟 · 剩余 25 分钟',
          reason: 'the design shows what is left, not what was planned');
      expect(running.sourceId, 'live');
    });

    test('a count-up session says how long it has been going', () {
      final entries = project(
        const TimelineDayFacts(),
        now: DateTime(2026, 10, 8, 10, 42),
        runningSessionId: 'live',
        runningSession: (
          startAt: DateTime(2026, 10, 8, 10),
          plannedSeconds: 0,
          taskName: '自由专注',
        ),
      );

      expect(entries.single.detail, '未设置 · 已专注 42 分钟',
          reason: 'a session with no target shows elapsed, not a remainder');
    });

    test('nothing is running when no session is given', () {
      final entries = project(
        TimelineDayFacts(
          focus: [focused(id: 'r1', startAt: DateTime(2026, 10, 8, 10))],
        ),
      );
      expect(entries.single.isRunning, isFalse);
    });
  });

  test('rows in the same minute keep a stable order', () {
    // A plan, a focus and a note all at 09:00: without a tiebreak the list would
    // reorder itself between rebuilds.
    final facts = TimelineDayFacts(
      plan: [
        placed(id: 't1', title: '写产品方案', startAt: DateTime(2026, 10, 8, 9)),
      ],
      focus: [focused(id: 'r1', startAt: DateTime(2026, 10, 8, 9))],
      notes: [(at: DateTime(2026, 10, 8, 9), text: '想到一件事', id: 'n1')],
    );

    final first = project(facts).map((e) => e.kind).toList();
    final second = project(facts).map((e) => e.kind).toList();
    expect(first, second);
    expect(first, [
      TimelineKind.plan,
      TimelineKind.focus,
      TimelineKind.note,
    ]);
  });

  test('the facts object knows when it is empty', () {
    expect(const TimelineDayFacts().isEmpty, isTrue);
    expect(
      TimelineDayFacts(
        notes: [(at: DateTime(2026, 10, 8, 9), text: '一', id: null)],
      ).isEmpty,
      isFalse,
    );
  });

  test('the legend names are the four kinds the design lists', () {
    expect(TimelineKind.values.map((k) => k.label), ['任务', '专注', '休息', '快速记录']);
  });
}
