import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart' hide FocusRecord;
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/yearly_report_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// The yearly report's metric cards on a small screen.
///
/// ## Found by walking the reports at 360dp
///
/// Two things, both invisible at the 411dp the design was drawn for:
///
/// 1. Each card is `maxLines: 1` with an ellipsis, and a 360dp card is about
///    100dp wide, so the row read `年度专注时…` and `总计专注次…` — a truncated
///    word is not a shorter word — and `比去年多了 100% ↑` lost its arrow.
/// 2. The heatmap card's header is a `spaceBetween` row whose two texts together
///    are 0.75px wider than the card. A `RenderFlex` overflow: a striped band in
///    a debug build, a silently clipped caption in a release one.
///
/// The assertions are on what is drawn, not on the strings: `find.text` matches
/// the full label whether or not the renderer cut it, so only
/// `RenderParagraph.didExceedMaxLines` says what the user actually sees, and a
/// layout overflow has to be caught by the layout itself — which is why this
/// file pumps at 360dp and lets the framework throw.
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

    // Sessions on two different days this year, so the cards carry a value, a
    // year-on-year diff and a day percentage rather than their empty copy.
    for (var i = 0; i < 2; i++) {
      final at = DateTime(2026, 10, 3 + i, 10);
      await db.focusRecordDao.insert(FocusRecord(
        id: 'rec_$i',
        sessionId: 'sess_$i',
        userId: userId,
        taskName: '写方案',
        timingMode: FocusTimingMode.countdown,
        durationSeconds: 1500,
        startAt: at,
        endAt: at.add(const Duration(minutes: 25)),
        recordedAt: at.add(const Duration(minutes: 25)),
        isCountedForReward: true,
      ));
    }
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpAt(WidgetTester tester, double widthDp) async {
    tester.view.physicalSize = Size(widthDp, 900);
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
          home: const YearlyReportPage(),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  /// The texts inside the metrics row, with the paragraph that draws each one.
  (Text, RenderParagraph) at(WidgetTester tester, int index) {
    final texts = find.descendant(
      of: find.byType(IntrinsicHeight),
      matching: find.byType(Text),
    );
    return (
      tester.widgetList<Text>(texts).elementAt(index),
      tester.renderObject<RenderParagraph>(texts.at(index)),
    );
  }

  int textCountIn(WidgetTester tester) => tester
      .widgetList<Text>(find.descendant(
        of: find.byType(IntrinsicHeight),
        matching: find.byType(Text),
      ))
      .length;

  testWidgets('nothing in the metrics row is drawn with an ellipsis',
      (tester) async {
    await pumpAt(tester, 360);

    final count = textCountIn(tester);
    // Three cards, each with a title, a value, a unit and a line under the
    // value. Asserted so a refactor cannot quietly shrink the thing under test.
    expect(count, 12);

    for (var i = 0; i < count; i++) {
      final (widget, paragraph) = at(tester, i);
      expect(paragraph.didExceedMaxLines, isFalse,
          reason: '"${widget.data}" is cut off on a 360dp phone');
    }
  });

  testWidgets('no unit is written twice', (tester) async {
    // The 专注天数 card read `占全年 0%%`: `_dayPercentageLabel` already returns
    // `0%` / `<1%` / `12%`, and the call site appended another one. Found by
    // walking the yearly report on a device — nothing in the suite looked at the
    // rendered text, only at whether the cards were the same height.
    await pumpAt(tester, 412);

    final texts = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(IntrinsicHeight),
          matching: find.byType(Text),
        ))
        .map((t) => t.data ?? '')
        .toList();
    expect(texts, isNotEmpty);

    for (final text in texts) {
      expect(text.contains('%%'), isFalse,
          reason: '"$text" writes the percent sign twice');
    }
    expect(texts.any((t) => t.contains('占全年')), isTrue,
        reason: 'the card this is about is on the screen');
  });

  testWidgets('the three cards are the same height', (tester) async {
    // A label that needs a second line must not leave one card taller than the
    // others.
    await pumpAt(tester, 360);

    final heights = [
      for (final key in const [
        'yearly_metric_duration',
        'yearly_metric_sessions',
        'yearly_metric_days',
      ])
        tester.getSize(find.byKey(ValueKey(key))).height,
    ];

    expect(heights[1], heights[0]);
    expect(heights[2], heights[0]);
  });

  testWidgets('the heatmap header does not overflow its card', (tester) async {
    // A `RenderFlex` overflow throws during layout, so reaching the end of this
    // test is the assertion. The pump is what would have failed before.
    await pumpAt(tester, 360);

    expect(find.text('全年日历热力图'), findsOneWidget);
    expect(find.text('每一个专注的日子，都闪闪发光。♡'), findsOneWidget);
  });

  testWidgets('and the wide phone still lays out the way the design draws it',
      (tester) async {
    // A check that the small-screen changes did not disturb the target width,
    // not a reproduction of the device at 411dp: `flutter test` draws with a
    // font whose Latin glyphs are about twice as wide as the real one, so a line
    // that fits on the device can still be measured as too wide here.
    await pumpAt(tester, 411);

    final count = textCountIn(tester);
    expect(count, 12);
    for (var i = 0; i < count; i++) {
      final (widget, paragraph) = at(tester, i);
      expect(paragraph.didExceedMaxLines, isFalse, reason: widget.data);
    }
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
