import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/models/analytics_range.dart';
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/services/analytics_summary.dart';

/// P7 — the statistics, computed from records.
///
/// ## Why the arithmetic is tested this precisely
///
/// The screen's whole claim is that every number on it comes from the database.
/// A statistics view is the easiest place in an app to write a plausible number
/// that nothing produced, so each figure here is pinned against hand-built
/// records — including the cases that produce nothing, where an invented default
/// would be most tempting.
void main() {
  const userId = 'default_user';

  FocusRecord record({
    required String id,
    required DateTime startAt,
    int minutes = 25,
    String? taskId,
    String? taskName,
  }) =>
      FocusRecord(
        id: id,
        sessionId: 'sess_$id',
        userId: userId,
        taskId: taskId,
        taskName: taskName,
        durationSeconds: minutes * 60,
        startAt: startAt,
        endAt: startAt.add(Duration(minutes: minutes)),
        recordedAt: startAt,
        isCountedForReward: true,
      );

  /// A Monday, so the week window is unambiguous.
  final monday = DateTime(2026, 10, 5);

  AnalyticsSummary summary(
    List<FocusRecord> records, {
    AnalyticsRangeKind kind = AnalyticsRangeKind.week,
    DateTime? day,
    Map<String, String> titles = const {},
  }) =>
      buildAnalyticsSummary(
        range: AnalyticsRange.containing(kind, day ?? monday),
        records: records,
        titleForTask: (id) => titles[id],
      );

  group('the window', () {
    test('a week starts on Monday and runs seven days', () {
      final range = AnalyticsRange.containing(
        AnalyticsRangeKind.week,
        DateTime(2026, 10, 8),
      );
      expect(range.from, DateTime(2026, 10, 5));
      expect(range.to, DateTime(2026, 10, 12));
      expect(range.days, 7);
      expect(range.label, '10 月 5 日 - 10 月 11 日');
    });

    test('a week window on a Monday starts on that day', () {
      final range = AnalyticsRange.containing(AnalyticsRangeKind.week, monday);
      expect(range.from, monday);
    });

    test('a day window is one day', () {
      final range = AnalyticsRange.containing(
        AnalyticsRangeKind.day,
        DateTime(2026, 10, 8, 15),
      );
      expect(range.from, DateTime(2026, 10, 8));
      expect(range.to, DateTime(2026, 10, 9));
      expect(range.days, 1);
      expect(range.label, '10 月 8 日');
    });

    test('a month window is the calendar month', () {
      final range = AnalyticsRange.containing(
        AnalyticsRangeKind.month,
        DateTime(2026, 10, 8),
      );
      expect(range.from, DateTime(2026, 10, 1));
      expect(range.to, DateTime(2026, 11, 1));
      expect(range.days, 31);
    });

    test('stepping moves by one day, week or month', () {
      final day = AnalyticsRange.containing(AnalyticsRangeKind.day, monday);
      expect(day.step(-1).from, DateTime(2026, 10, 4));
      expect(day.step(1).from, DateTime(2026, 10, 6));

      final week = AnalyticsRange.containing(AnalyticsRangeKind.week, monday);
      expect(week.step(-1).from, DateTime(2026, 9, 28));
      expect(week.step(1).from, DateTime(2026, 10, 12));

      final month = AnalyticsRange.containing(AnalyticsRangeKind.month, monday);
      expect(month.step(-1).from, DateTime(2026, 9, 1));
      expect(month.step(1).from, DateTime(2026, 11, 1));
    });

    test('a window with nothing in it reports nothing', () {
      final s = summary(const []);
      expect(s.isEmpty, isTrue);
      expect(s.totalSeconds, 0);
      expect(s.sessionCount, 0);
      expect(s.averageSeconds, 0,
          reason: 'no sessions is not an average of zero minutes');
      expect(s.shares, isEmpty);
      expect(s.daily, hasLength(7),
          reason: 'the empty days are still days on the chart');
      expect(s.busiestDaySeconds, 0);
    });
  });

  group('the three numbers', () {
    test('total, count and mean come from the records', () {
      final s = summary([
        record(id: 'a', startAt: DateTime(2026, 10, 5, 9), minutes: 25),
        record(id: 'b', startAt: DateTime(2026, 10, 6, 9), minutes: 50),
        record(id: 'c', startAt: DateTime(2026, 10, 6, 14), minutes: 45),
      ]);

      expect(s.totalSeconds, (25 + 50 + 45) * 60);
      expect(s.sessionCount, 3);
      expect(s.averageSeconds, 40 * 60);
    });

    test('the mean is rounded, not truncated', () {
      final s = summary([
        record(id: 'a', startAt: DateTime(2026, 10, 5, 9), minutes: 25),
        record(id: 'b', startAt: DateTime(2026, 10, 5, 10), minutes: 26),
      ]);
      expect(s.averageSeconds, 1530, reason: '25.5 minutes rounds to 25:30');
    });

    test('records outside the window are left out', () {
      // The query is expected to scope the window; this is the second check, and
      // a query that silently widened would otherwise inflate every number.
      final s = summary([
        record(id: 'in', startAt: DateTime(2026, 10, 5, 9), minutes: 30),
        record(id: 'before', startAt: DateTime(2026, 10, 4, 9), minutes: 90),
        record(id: 'after', startAt: DateTime(2026, 10, 12, 9), minutes: 90),
      ]);

      expect(s.totalSeconds, 30 * 60);
      expect(s.sessionCount, 1);
    });

    test('a record at midnight on the last day is inside the window', () {
      final s = summary([
        record(id: 'edge', startAt: DateTime(2026, 10, 11), minutes: 20),
      ]);
      expect(s.sessionCount, 1);
      expect(s.totalSeconds, 20 * 60);
    });

    test('a record at midnight on the day after is outside', () {
      final s = summary([
        record(id: 'edge', startAt: DateTime(2026, 10, 12), minutes: 20),
      ]);
      expect(s.sessionCount, 0);
    });
  });

  group('the daily chart', () {
    test('has one bucket per day, in order, including the empty ones', () {
      final s = summary([
        record(id: 'a', startAt: DateTime(2026, 10, 5, 9), minutes: 25),
        record(id: 'b', startAt: DateTime(2026, 10, 7, 9), minutes: 50),
      ]);

      expect(s.daily.map((b) => b.weekdayLabel),
          ['周一', '周二', '周三', '周四', '周五', '周六', '周日']);
      expect(s.daily.map((b) => b.seconds), [25 * 60, 0, 50 * 60, 0, 0, 0, 0]);
      expect(s.daily[2].sessions, 1);
      expect(s.daily[1].sessions, 0);
    });

    test('a day with several sessions adds them up', () {
      final s = summary([
        record(id: 'a', startAt: DateTime(2026, 10, 5, 9), minutes: 25),
        record(id: 'b', startAt: DateTime(2026, 10, 5, 14), minutes: 35),
      ]);
      expect(s.daily.first.seconds, 60 * 60);
      expect(s.daily.first.sessions, 2);
    });

    test('the busiest day is what the chart scales to', () {
      final s = summary([
        record(id: 'a', startAt: DateTime(2026, 10, 5, 9), minutes: 25),
        record(id: 'b', startAt: DateTime(2026, 10, 6, 9), minutes: 95),
      ]);
      expect(s.busiestDaySeconds, 95 * 60);
    });

    test('a month window has one bucket per day of that month', () {
      final s = summary(
        const [],
        kind: AnalyticsRangeKind.month,
        day: DateTime(2026, 10, 8),
      );
      expect(s.daily, hasLength(31));
      expect(s.daily.first.day, DateTime(2026, 10, 1));
      expect(s.daily.last.day, DateTime(2026, 10, 31));
    });
  });

  group('the task distribution', () {
    test('groups by task, heaviest first, with real shares', () {
      final s = summary(
        [
          record(
            id: 'a',
            startAt: DateTime(2026, 10, 5, 9),
            minutes: 60,
            taskId: 't1',
          ),
          record(
            id: 'b',
            startAt: DateTime(2026, 10, 5, 11),
            minutes: 30,
            taskId: 't2',
          ),
          record(
            id: 'c',
            startAt: DateTime(2026, 10, 6, 9),
            minutes: 30,
            taskId: 't1',
          ),
        ],
        titles: {'t1': '写产品方案', 't2': '健身'},
      );

      expect(s.shares.map((x) => x.title), ['写产品方案', '健身']);
      expect(s.shares.first.seconds, 90 * 60);
      expect(s.shares.first.percentLabel, '75%');
      expect(s.shares.last.seconds, 30 * 60);
      expect(s.shares.last.percentLabel, '25%');
      expect(s.shares.first.sessions, 2);
    });

    test('the shares add up to the whole window', () {
      final s = summary([
        record(
            id: 'a',
            startAt: DateTime(2026, 10, 5, 9),
            minutes: 20,
            taskId: 't1'),
        record(
            id: 'b',
            startAt: DateTime(2026, 10, 5, 10),
            minutes: 30,
            taskId: 't2'),
        record(
            id: 'c',
            startAt: DateTime(2026, 10, 5, 11),
            minutes: 50,
            taskId: 't3'),
      ], titles: {
        't1': '一',
        't2': '二',
        't3': '三'
      });

      final sum = s.shares.fold<double>(0, (acc, x) => acc + x.fraction);
      expect(sum, closeTo(1.0, 1e-9));
      expect(
          s.shares.fold<int>(0, (acc, x) => acc + x.seconds), s.totalSeconds);
    });

    test('a task that no longer exists keeps its recorded name', () {
      final s = summary([
        record(
          id: 'a',
          startAt: DateTime(2026, 10, 5, 9),
          taskId: 'gone',
          taskName: '被删掉的任务',
        ),
      ], titles: {});
      expect(s.shares.single.title, '被删掉的任务');
      expect(s.shares.single.taskId, 'gone');
    });

    test('a session with no task is grouped by the name it carried', () {
      final s = summary([
        record(id: 'a', startAt: DateTime(2026, 10, 5, 9), taskName: '写作练习'),
      ]);
      expect(s.shares.single.title, '写作练习');
      expect(s.shares.single.taskId, isNull);
    });

    test('a session with neither a task nor a name still has a row', () {
      final s = summary([
        record(id: 'a', startAt: DateTime(2026, 10, 5, 9)),
      ]);
      expect(s.shares.single.title, '未命名专注');
    });

    test('two untitled sessions are one row, not two', () {
      final s = summary([
        record(id: 'a', startAt: DateTime(2026, 10, 5, 9), minutes: 20),
        record(id: 'b', startAt: DateTime(2026, 10, 5, 10), minutes: 30),
      ]);
      expect(s.shares, hasLength(1));
      expect(s.shares.single.seconds, 50 * 60);
      expect(s.shares.single.sessions, 2);
    });

    test('equal durations keep a stable order', () {
      final records = [
        record(
            id: 'a',
            startAt: DateTime(2026, 10, 5, 9),
            minutes: 30,
            taskId: 'tb'),
        record(
            id: 'b',
            startAt: DateTime(2026, 10, 5, 10),
            minutes: 30,
            taskId: 'ta'),
      ];
      final titles = {'ta': 'A 任务', 'tb': 'B 任务'};
      expect(
          summary(records, titles: titles).shares.map((x) => x.title),
          summary(records.reversed.toList(), titles: titles)
              .shares
              .map((x) => x.title));
    });
  });

  test('the range labels are the design\'s', () {
    expect(AnalyticsRangeKind.values.map((k) => k.label), ['日', '周', '月']);
  });
}
