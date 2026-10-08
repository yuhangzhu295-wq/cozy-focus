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

/// One record, two durations.
///
/// `formatDurationText` says of itself that it is the one place that decides what
/// an hour is — "a second formatter there would be a second answer to what an
/// hour is" — and the timeline and both report pages read it. The records list
/// does not: it floors the minutes for itself. For a 54-second session that is
/// `0 分钟` in the list and `1 分钟` on the timeline, and for a 1795-second one it
/// is `29 分钟` and `30 分钟`.
///
/// Found by following the same thread as the early-finish dialog, which was the
/// same shape: this screen rounding a number the rest of the app had already
/// decided. The two are not the same fix, and the difference is worth stating —
/// a *description* of a finished block rounds (the shared formatter), while a
/// number the user compares against a goal or a payment floors, because it must
/// never promise more than the app will honour.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  const userId = 'default_user';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider
          .overrideWithValue(_FixedClock(DateTime(2026, 10, 8, 9))),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> seed(int seconds) async {
    final at = DateTime(2026, 10, 8, 8);
    await db.focusRecordDao.insert(FocusRecord(
      id: 'rec_$seconds',
      sessionId: 'sess_$seconds',
      userId: userId,
      taskName: '专注任务',
      timingMode: FocusTimingMode.countdown,
      durationSeconds: seconds,
      startAt: at,
      endAt: at.add(Duration(seconds: seconds)),
      recordedAt: at.add(Duration(seconds: seconds)),
      isCountedForReward: true,
    ));
  }

  Future<void> pump(WidgetTester tester) async {
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
  }

  testWidgets(
      'the records list writes a duration the way the rest of the app '
      'writes it', (tester) async {
    await seed(54);
    await pump(tester);

    // The one authority, for the record the list is showing.
    expect(formatDurationText(54), '1 分钟');
    expect(find.text(formatDurationText(54)), findsOneWidget,
        reason: 'the list has to agree with the timeline and the reports about '
            'the same record');
    expect(find.text('0 分钟'), findsNothing,
        reason: 'a session that happened is not zero minutes long');
  });

  testWidgets('and it keeps agreeing on a longer one', (tester) async {
    await seed(1795);
    await pump(tester);

    expect(formatDurationText(1795), '30 分钟');
    expect(find.text(formatDurationText(1795)), findsOneWidget);
    expect(find.text('29 分钟'), findsNothing);
  });

  testWidgets('a duration under a minute is still a duration', (tester) async {
    await seed(20);
    await pump(tester);

    // `formatDurationText` answers 未设置 for zero or less, and 20 seconds is
    // more than nothing: it is a session the user sat through.
    expect(formatDurationText(20), '0 分钟');
    expect(find.text('0 分钟'), findsOneWidget);
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
