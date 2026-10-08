import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide
        Task,
        TaskSubtask,
        TaskSchedule,
        FocusSession,
        FocusRecord,
        DistractionNote;
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/models/focus_session.dart';
import 'package:cozy_focus_app/domain/models/timeline_entry.dart';
import 'package:cozy_focus_app/domain/services/duration_text.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/domain/services/timeline_projection.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';

/// Five surfaces describe the same day. They must agree.
///
/// ## What this is for
///
/// The brief's Stage 2 asks whether `FocusRecord`, `RewardLedger`,
/// `StatisticsEngine`, the task totals and the timeline tell one story. The
/// duration convention was the first part of that question and the answer was no
/// — the same week read as 2 小时 36 分钟, 2h 35m and 3 小时 on three screens. This
/// file asks the rest of it against a real database rather than stubs, because
/// the disagreement lived in the queries and the formatting, not in the widgets.
///
/// The day seeded here is deliberately awkward: a session with a task, a session
/// without one, and a sub-minute session, which is where rounding rules part
/// company.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  const userId = 'default_user';
  const taskId = 'task_alpha';
  final day = DateTime(2026, 10, 9);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider
          .overrideWithValue(_FixedClock(DateTime(2026, 10, 9, 20))),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  FocusRecord record({
    required String id,
    required int startHour,
    required int seconds,
    String? task,
  }) {
    final at = DateTime(2026, 10, 9, startHour, 10);
    return FocusRecord(
      id: id,
      sessionId: 'sess_$id',
      userId: userId,
      taskId: task,
      taskName: task == null ? null : 'Alpha',
      timingMode: FocusTimingMode.countdown,
      durationSeconds: seconds,
      startAt: at,
      endAt: at.add(Duration(seconds: seconds)),
      recordedAt: at.add(Duration(seconds: seconds)),
      isCountedForReward: true,
    );
  }

  /// Three sessions: 1,500 s on a task, 900 s on nothing, and 45 s.
  Future<List<FocusRecord>> seedDay() async {
    final records = [
      record(id: 'a', startHour: 9, seconds: 1500, task: taskId),
      record(id: 'b', startHour: 11, seconds: 900),
      record(id: 'c', startHour: 14, seconds: 45),
    ];
    for (final r in records) {
      await db.focusRecordDao.insert(r);
    }
    return records;
  }

  test('the day total is the sum of its records, and the count is the count',
      () async {
    final records = await seedDay();
    final summary = await container
        .read(statisticsEngineProvider)
        .getDaySummary(userId, day);

    expect(
      summary.totalSeconds,
      records.fold<int>(0, (sum, r) => sum + r.durationSeconds),
    );
    expect(summary.sessionCount, records.length);
  });

  test('the task total is a part of the day, not a different day', () async {
    await seedDay();
    final summary = await container
        .read(statisticsEngineProvider)
        .getDaySummary(userId, day);
    final totals = await db.taskDao.focusTotalsFor(taskId);

    expect(totals.seconds, 1500);
    expect(totals.sessions, 1);
    // The 900 s and the 45 s sessions carry no task, so the task total is
    // strictly less than the day. If these two ever matched, one of them would
    // be counting the other's rows.
    expect(totals.seconds, lessThan(summary.totalSeconds));
  });

  test('the timeline draws the same durations the records hold', () async {
    final records = await seedDay();
    final entries = buildTimeline(
      facts: TimelineDayFacts(focus: records),
      now: DateTime(2026, 10, 9, 20),
    );

    final focusEntries =
        entries.where((e) => e.kind == TimelineKind.focus).toList();
    expect(focusEntries.length, records.length);
    expect(
      focusEntries.fold<int>(0, (sum, e) => sum + (e.durationSeconds ?? 0)),
      records.fold<int>(0, (sum, r) => sum + r.durationSeconds),
    );
  });

  test('and the rows say what the total says', () async {
    final records = await seedDay();
    final summary = await container
        .read(statisticsEngineProvider)
        .getDaySummary(userId, day);

    // The sub-minute session is the interesting one: 45 seconds is 0 minutes
    // floored and 1 minute rounded, and the row, the total and the report all
    // have to choose the same one.
    final row = formatDurationText(records.last.durationSeconds);
    expect(row, '1 分钟');

    // The report's hero splits by the same rule, so its parts add back up to the
    // sentence above.
    final parts = durationParts(summary.totalSeconds);
    expect(
      formatDurationText(summary.totalSeconds),
      parts.hours == 0
          ? '${parts.minutes} 分钟'
          : '${parts.hours} 小时 ${parts.minutes} 分钟',
    );
    expect(parts.hours * 60 + parts.minutes,
        durationMinutes(summary.totalSeconds));
  });

  test('one session settles once, across all five', () async {
    final records = await seedDay();
    final rewardService = container.read(rewardServiceProvider);

    FocusSession sessionFor(FocusRecord r) => FocusSession(
          id: r.sessionId,
          userId: userId,
          plannedSeconds: r.durationSeconds,
          mode: FocusMode.focus,
          startAt: r.startAt,
          pauseIntervals: const [],
          endAt: r.endAt,
          status: FocusSessionStatus.saved,
          timezoneOffsetMinutes: 480,
        );

    for (final r in records) {
      expect(await rewardService.settle(sessionFor(r)), isTrue, reason: r.id);
    }
    expect(await db.rewardLedgerDao.countForUser(userId), records.length);

    // Second pass over the same sessions: nothing new, and nothing paid twice.
    for (final r in records) {
      expect(await rewardService.settle(sessionFor(r)), isFalse, reason: r.id);
    }
    expect(await db.rewardLedgerDao.countForUser(userId), records.length);
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
