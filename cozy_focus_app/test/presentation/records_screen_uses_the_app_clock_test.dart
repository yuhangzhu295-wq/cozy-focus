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
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/controllers/reports_controller.dart';
import 'package:cozy_focus_app/presentation/pages/progress_overview_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// The records screen read the wall clock while the rest of the app read the
/// injected one.
///
/// ## Found by the suite going red on its own
///
/// Six assertions about the 今日记录 rows — the duration label and the mood face
/// — started failing overnight without a line of code changing. The cause was
/// not the rows: `RecordsController.loadData` drew its "today", its yesterday
/// comparison and its 365-day window from `DateTime.now()`, and the page's own
/// today filter did the same, while the tests seed their records against a
/// substituted [FocusClock]. On the day those tests were written the real date
/// happened to equal the seeded date, so they passed; the next day the rows fell
/// outside the window the page had drawn and the finders found nothing.
///
/// The same split is why one test in that file kept passing: "a record with no
/// mood shows no mood mark at all" asserts `findsNothing`, which an empty screen
/// satisfies perfectly.
///
/// This file pins the fix with a date no real clock will ever agree with, so the
/// guard cannot be defeated by the calendar rolling over again.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  const userId = 'default_user';

  // Deliberately far from any plausible "now". If any code on this screen reads
  // the wall clock, the seeded rows land outside its window and vanish.
  final seededDay = DateTime(2001, 3, 5);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider
          .overrideWithValue(_FixedClock(DateTime(2001, 3, 5, 9, 30))),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> seed({DateTime? alsoOn}) async {
    final at = DateTime(seededDay.year, seededDay.month, seededDay.day, 9, 13);
    await db.focusRecordDao.insert(FocusRecord(
      id: 'rec_clock',
      sessionId: 'sess_clock',
      userId: userId,
      taskName: 'Ancient session',
      mood: 'flow',
      timingMode: FocusTimingMode.countdown,
      durationSeconds: 600,
      startAt: at,
      endAt: at.add(const Duration(minutes: 10)),
      recordedAt: at.add(const Duration(minutes: 10)),
      isCountedForReward: true,
    ));
    if (alsoOn != null) {
      final other = DateTime(alsoOn.year, alsoOn.month, alsoOn.day, 9, 13);
      await db.focusRecordDao.insert(FocusRecord(
        id: 'rec_clock_prev',
        sessionId: 'sess_clock_prev',
        userId: userId,
        taskName: 'Ancient session the day before',
        timingMode: FocusTimingMode.countdown,
        durationSeconds: 600,
        startAt: other,
        endAt: other.add(const Duration(minutes: 10)),
        recordedAt: other.add(const Duration(minutes: 10)),
        isCountedForReward: true,
      ));
    }
  }

  Future<void> pumpRecords(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProgressOverviewPage(),
        ),
      ),
    );
    // Fixed frames rather than settling: the companion's idle animation repeats
    // forever, so `pumpAndSettle` never returns on this screen.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('a record on the clock day is shown, whatever today really is',
      (tester) async {
    await seed();
    await pumpRecords(tester);

    expect(
      find.text('Ancient session'),
      findsOneWidget,
      reason: 'the page drew its window from the wall clock instead of '
          'focusClockProvider, so a row on the injected day fell outside it',
    );
    expect(find.text('10 分钟'), findsOneWidget);
  });

  testWidgets('the streak is counted from the injected day, not the real one',
      (tester) async {
    // Two consecutive days ending on the clock's day. The injected clock gives a
    // streak of two; the wall clock gives none, because its "today" is decades
    // away from the seeded days and the backwards walk finds nothing. One seeded
    // day would not discriminate: the streak has a fallback that returns 1 when
    // today itself is empty, so both clocks would have read 1.
    await seed(alsoOn: DateTime(2001, 3, 4));
    await pumpRecords(tester);

    expect(find.text('连续专注'), findsOneWidget);
    expect(
      find.text('2'),
      findsOneWidget,
      reason: 'the streak counted days around the wall clock instead of the '
          'injected one, so the two consecutive seeded days were not seen',
    );
  });
  group('the reports open on the clock period, not the wall-clock one', () {
    test('the week, month and year all come from the injected clock', () {
      // The same four reads that used to call DateTime.now(). 2001-03-05 is a
      // Monday, so a correct implementation opens on that day and on March 2001.
      final reports = container.read(reportsControllerProvider);

      expect(reports.selectedWeekStart, DateTime(2001, 3, 5));
      expect(reports.monthlyYear, 2001);
      expect(reports.monthlyMonth, 3);
      expect(reports.yearlyYear, 2001);
    });
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
