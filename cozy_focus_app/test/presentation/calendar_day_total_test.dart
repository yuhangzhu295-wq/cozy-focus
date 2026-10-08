import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart' hide FocusRecord;
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/services/duration_text.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/progress_overview_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// The calendar's day total and the rows under it described a day two ways.
///
/// ## Found by opening the 日历 tab on a device
///
/// The header read `共 1 分钟  2 次` over two rows reading `0 分钟` and `1 分钟`.
/// The numbers happened to agree there, but the *conventions* did not: the header
/// took `DayProgressSummary.totalMinutes`, which floors, and the rows take
/// `formatDurationText`, which rounds. Two sessions of fifty seconds make it
/// visible — the header said 1 分钟 over two rows saying 1 分钟 each.
///
/// This is the same shape as the mood id, the record row and the room's status
/// sentence: one quantity, two answers. The rule the codebase settled on is that a
/// *description* of how long something was goes through the one formatter, and a
/// rounded total not matching the sum of rounded parts is not the problem — that
/// is true of any rounding, the same way the reports' percentages do not add to
/// 100. Having two conventions is the problem.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  const userId = 'default_user';

  /// Two fifty-second sessions on [day]: 100 seconds, which floors to 1 minute and
  /// rounds to 2.
  Future<void> seedTwoShortSessions(DateTime day) async {
    for (var i = 0; i < 2; i++) {
      final at = day.add(Duration(hours: 9 + i));
      await db.focusRecordDao.insert(FocusRecord(
        id: 'rec_$i',
        sessionId: 'sess_$i',
        userId: userId,
        taskName: '专注任务',
        timingMode: FocusTimingMode.countdown,
        durationSeconds: 50,
        startAt: at,
        endAt: at.add(const Duration(seconds: 50)),
        recordedAt: at.add(const Duration(seconds: 50)),
        isCountedForReward: true,
      ));
    }
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider
          .overrideWithValue(_FixedClock(DateTime(2026, 10, 8, 20))),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpCalendar(WidgetTester tester) async {
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
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    // The calendar is the third segment. Its day cells are `8` etc.
    await tester.tap(find.text('日历'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.tap(find.text('8'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('the day total is described the way the rows are',
      (tester) async {
    await seedTwoShortSessions(DateTime(2026, 10, 8));
    await pumpCalendar(tester);

    // What the rows say, through the one formatter.
    expect(formatDurationText(50), '1 分钟');
    expect(find.text('1 分钟'), findsNWidgets(2),
        reason: 'two rows, each fifty seconds');

    // And the header, for the same hundred seconds. `floor` would say 1.
    expect(find.text('共 2 分钟  2 次'), findsOneWidget);
    expect(find.text('共 1 分钟  2 次'), findsNothing,
        reason: 'the header may not floor what the rows round');
  });

  testWidgets('a day with nothing in it still says zero', (tester) async {
    // `formatDurationText` answers 未设置 for zero, which is a task's "no length
    // was set" rather than an empty day.
    await pumpCalendar(tester);

    expect(find.text('共 0 分钟  0 次'), findsOneWidget);
    expect(find.textContaining('未设置'), findsNothing);
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
