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
import 'package:cozy_focus_app/presentation/pages/weekly_report_page.dart';
import 'package:cozy_focus_app/presentation/pages/yearly_report_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// The report pages stretched across the whole screen in landscape.
///
/// ## Found by rotating the emulator
///
/// Nothing locks the orientation — not the manifest, not `SystemChrome` — so a
/// landscape phone is a state the app really reaches. At ~1100dp wide the year
/// heatmap's `spaceBetween` row spread its 31 fixed-size days 27dp apart and
/// stopped reading as a calendar, and every card became a letterbox. The pages
/// now hold their content to [AppLayout.reportMaxWidth] and centre it.
///
/// The gutter is asserted rather than the pixels: it is the one number the three
/// pages share, and the property that matters is that the content it leaves is
/// never wider than the cap — on any screen, including ones wider than the cap
/// by a little and by a lot.
void main() {
  group('the report gutter', () {
    test('is the design 20dp on a phone the cap does not bind on', () {
      expect(AppLayout.reportGutter(360), 20.0);
      expect(AppLayout.reportGutter(411), 20.0);
      expect(AppLayout.reportGutter(AppLayout.reportMaxWidth), 20.0);
    });

    test('leaves content no wider than the cap, on any wider screen', () {
      for (final width in const [600.0, 900.0, 1100.0, 1600.0, 2400.0]) {
        final content = width - AppLayout.reportGutter(width) * 2;
        expect(content, lessThanOrEqualTo(AppLayout.reportMaxWidth),
            reason: 'at ${width}dp the content is ${content}dp wide');
      }
    });

    test('and still leaves content no wider than the cap in portrait', () {
      for (final width in const [320.0, 360.0, 411.0, 480.0, 560.0]) {
        final content = width - AppLayout.reportGutter(width) * 2;
        expect(content, lessThanOrEqualTo(AppLayout.reportMaxWidth),
            reason: 'at ${width}dp');
        expect(content, greaterThan(0));
      }
    });

    test('grows by half the excess, so the content stays centred', () {
      // The gutter on the left must equal the gutter on the right; with a
      // symmetric padding that is the same statement as this one.
      const width = 1000.0;
      final gutter = AppLayout.reportGutter(width);
      expect(width - gutter * 2, closeTo(AppLayout.reportMaxWidth, 0.001));
    });
  });

  group('the pages use it', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider
            .overrideWithValue(_FixedClock(DateTime(2026, 10, 8, 9))),
        currentUserIdProvider.overrideWithValue('default_user'),
      ]);

      final at = DateTime(2026, 10, 3, 10);
      await db.focusRecordDao.insert(FocusRecord(
        id: 'rec_1',
        sessionId: 'sess_1',
        userId: 'default_user',
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

    Future<void> pump(WidgetTester tester, Widget page, double widthDp) async {
      tester.view.physicalSize = Size(widthDp, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.lightTheme, home: page),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    /// The horizontal padding the page's own scroll view was given.
    double gutterOf(WidgetTester tester) {
      final list = tester.widget<ListView>(find.byType(ListView).first);
      final padding = list.padding;
      expect(padding, isA<EdgeInsets>(),
          reason: 'the scroll view must carry the gutter');
      return (padding as EdgeInsets).horizontal / 2;
    }

    final pages = <String, Widget>{
      'weekly': const WeeklyReportPage(),
      'monthly': const MonthlyReportPage(),
      'yearly': const YearlyReportPage(),
    };

    for (final entry in pages.entries) {
      testWidgets('${entry.key}: centred on a landscape screen',
          (tester) async {
        await pump(tester, entry.value, 1100);

        expect(gutterOf(tester), AppLayout.reportGutter(1100));
        expect(1100 - gutterOf(tester) * 2,
            lessThanOrEqualTo(AppLayout.reportMaxWidth));
      });

      testWidgets('${entry.key}: untouched on the design phone',
          (tester) async {
        await pump(tester, entry.value, 411);

        expect(gutterOf(tester), 20.0,
            reason: 'the design gutter, because the cap does not bind here');
      });
    }
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
