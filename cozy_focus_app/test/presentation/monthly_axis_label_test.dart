import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart' hide FocusRecord;
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/monthly_report_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// The monthly trend chart's day labels were clipped on a small screen.
///
/// ## Found by walking the reports at 360dp
///
/// The chart is 31 `Expanded` columns in a `Row`. On a 411dp phone each column
/// is about 9dp and an 8px two-digit label just fits; on a 360dp phone each
/// column is about 7dp and it does not, so `14`, `21` and `28` were painted as
/// one digit followed by a sliver of the next — read at a glance the axis said
/// 1, 7, 1|, 2|, 2|. The single-digit labels were fine, which is why a suite
/// that only ever ran at one screen size never saw it.
///
/// The assertion is about the layout, not the pixels: a two-digit label must be
/// laid out wider than a one-digit one. Before the fix both were clamped to the
/// column, so both measured the same.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  const userId = 'default_user';
  final month = DateTime(2026, 10, 1);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(_FixedClock(month)),
      currentUserIdProvider.overrideWithValue(userId),
    ]);

    // One record early in the month, so the chart has a bar and the axis is
    // drawn.
    final at = DateTime(2026, 10, 3, 10);
    await db.focusRecordDao.insert(FocusRecord(
      id: 'rec_1',
      sessionId: 'sess_1',
      userId: userId,
      taskName: '写方案',
      timingMode: FocusTimingMode.countdown,
      durationSeconds: 1500,
      startAt: at,
      endAt: at.add(const Duration(minutes: 25)),
      recordedAt: at.add(const Duration(minutes: 25)),
      isCountedForReward: true,
    ));
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpAt(WidgetTester tester, double widthDp) async {
    // A phone the width of the narrowest one the design has to survive. The
    // device pixel ratio is 1 so a dp is a logical pixel and the widths below
    // read as the numbers they are.
    tester.view.physicalSize = Size(widthDp, 640);
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
          home: const MonthlyReportPage(),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('a two-digit day label gets room for both digits',
      (tester) async {
    await pumpAt(tester, 360);

    final one = tester.getSize(find.text('7'));
    final two = tester.getSize(find.text('14'));

    expect(two.width, greaterThan(one.width),
        reason: 'the label has to lay out at its own width; clamped to the '
            'column it loses its second digit');
    expect(find.text('21'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
  });

  testWidgets('and it still does on the wide phone the design was drawn for',
      (tester) async {
    // Not a guard: on a 411dp phone the column is 8.9dp and the label needs
    // about the same, so this passes with or without the fix — which is exactly
    // why the defect survived a suite that only ran at this size. It is here to
    // pin that the label still lays out at all after the change.
    await pumpAt(tester, 411);

    expect(tester.getSize(find.text('14')).width,
        greaterThan(tester.getSize(find.text('7')).width));
  });

  testWidgets('the labelled days are still the five the design marks',
      (tester) async {
    await pumpAt(tester, 360);

    for (final day in const [1, 7, 14, 21, 28]) {
      expect(find.text('$day'), findsOneWidget, reason: '$day');
    }
    // October has 31 days, and only the five above carry a label.
    expect(find.text('2'), findsNothing);
    expect(find.text('31'), findsNothing);
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
