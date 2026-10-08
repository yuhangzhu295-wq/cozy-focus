import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
import 'package:cozy_focus_app/domain/services/duration_text.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/controllers/reports_controller.dart';
import 'package:cozy_focus_app/presentation/pages/weekly_report_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// One duration, one answer.
///
/// ## What this is for
///
/// The app had three ways of turning seconds into a figure and they disagreed.
/// `formatDurationText` rounds, which is what the records screen, the timeline
/// and the home card all use. The weekly and monthly report pages split the
/// seconds themselves with `~/`, which floors. The wrapped page rounded to whole
/// hours. So a week of 9,359 seconds read **2 小时 36 分钟** on one screen and
/// **2h 35m** on another, and **3 小时** on a third — one week, three answers,
/// none of them labelled as an approximation.
///
/// The rule now lives in one place, [durationMinutes], and the pages print from
/// [durationParts] rather than doing their own arithmetic. The format each screen
/// uses is unchanged: `2h 36m` is still what the weekly hero draws, because that
/// shape comes from the reference. Only the number was ever in dispute.
void main() {
  group('the rounding rule', () {
    test('rounds to the nearest minute', () {
      expect(durationMinutes(0), 0);
      expect(durationMinutes(29), 0);
      expect(durationMinutes(30), 1);
      expect(durationMinutes(89), 1);
      expect(durationMinutes(90), 2);
      expect(durationMinutes(1500), 25);
    });

    test('never reports a negative duration', () {
      expect(durationMinutes(-5), 0);
    });
  });

  group('the parts and the sentence agree', () {
    // The regression, in the numbers that produced it. 9,359 seconds is 155.98
    // minutes: rounding gives 156, flooring gives 155.
    const week = 9359;

    test('a week splits the way the sentence reads', () {
      final parts = durationParts(week);
      expect(parts.hours, 2);
      expect(
        parts.minutes,
        36,
        reason: 'flooring gave 35, which is what the weekly report printed',
      );
    });

    test('and the sentence says the same thing', () {
      expect(formatDurationText(week), '2 小时 36 分钟');
    });

    test('agreement holds across a spread of durations', () {
      for (final seconds in const [
        59,
        60,
        90,
        3599,
        3600,
        3630,
        7199,
        7200,
        9359,
        86399,
        90061,
      ]) {
        final parts = durationParts(seconds);
        final minutes = durationMinutes(seconds);
        expect(
          parts.hours * 60 + parts.minutes,
          minutes,
          reason: '$seconds: the parts must add up to the same minutes',
        );
        expect(formatDurationText(seconds), isNotEmpty, reason: '$seconds');
      }
    });
  });

  group('the weekly report prints that answer', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider
            .overrideWithValue(_FixedClock(DateTime(2026, 9, 8, 12))),
        currentUserIdProvider.overrideWithValue('default_user'),
      ]);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    testWidgets('the hero shows the same minutes the records screen does',
        (tester) async {
      // One record of 9,359 seconds in the week beginning 2026-09-07.
      final start = DateTime(2026, 9, 8, 10);
      await db.focusRecordDao.insert(FocusRecord(
        id: 'rec_week',
        sessionId: 'sess_week',
        userId: 'default_user',
        taskName: 'Weekly',
        timingMode: FocusTimingMode.countdown,
        durationSeconds: 9359,
        startAt: start,
        endAt: start.add(const Duration(seconds: 9359)),
        recordedAt: start.add(const Duration(seconds: 9359)),
        isCountedForReward: true,
      ));

      await container
          .read(reportsControllerProvider.notifier)
          .loadWeeklyReport(DateTime(2026, 9, 7));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const WeeklyReportPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('2h 36m'),
        findsOneWidget,
        reason: 'the same week read 2h 35m while the page floored its own '
            'arithmetic, against 2 小时 36 分钟 everywhere else',
      );
      expect(find.text('2h 35m'), findsNothing);
    });
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
