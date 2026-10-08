import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/hourly_focus_chart.dart';

/// The hourly distribution on design 01's 今天的专注 card.
///
/// ## What these are for
///
/// The bucketing is arithmetic, and arithmetic goes wrong in ways a screenshot
/// does not show: a session landing in the wrong two-hour slot still draws a bar
/// of the right height somewhere. So most of these are about *where* time goes,
/// and one is about none of it going missing.
void main() {
  const userId = 'default_user';
  final day = DateTime(2026, 10, 9);

  FocusRecord record(DateTime from, DateTime to) => FocusRecord(
        id: 'rec_${from.millisecondsSinceEpoch}',
        sessionId: 'sess',
        userId: userId,
        taskName: '专注',
        timingMode: FocusTimingMode.countdown,
        durationSeconds: to.difference(from).inSeconds,
        startAt: from,
        endAt: to,
        recordedAt: to,
        isCountedForReward: true,
      );

  group('the window', () {
    test('is the design\'s 06:00-22:00 when the day fits inside it', () {
      final focus = HourlyFocus.of(const [], day);

      expect(focus.startHour, 6);
      expect(focus.endHour, 22);
      expect(focus.bucketCount, 8);
      expect(focus.totalSeconds, 0);
    });

    test('labels the axis where the design does', () {
      expect(HourlyFocus.of(const [], day).labelHours, [6, 9, 12, 15, 18, 21]);
    });

    test('widens for a session before dawn rather than dropping it', () {
      // 05:10-05:40. Clipping to 06:00 would erase it while the card still
      // printed its minutes beside the bars.
      final focus = HourlyFocus.of(
        [record(DateTime(2026, 10, 9, 5, 10), DateTime(2026, 10, 9, 5, 40))],
        day,
      );

      expect(focus.startHour, 4, reason: 'widened in whole two-hour steps');
      expect(focus.endHour, 22);
      expect(focus.totalSeconds, 1800);
    });

    test('widens for a session after dark', () {
      final focus = HourlyFocus.of(
        [record(DateTime(2026, 10, 9, 22, 30), DateTime(2026, 10, 9, 23, 5))],
        day,
      );

      expect(focus.endHour, 24);
      expect(focus.totalSeconds, 2100);
    });
  });

  group('where the time goes', () {
    test('a session inside one bucket stays in it', () {
      // 09:00-09:30 sits wholly inside the 08:00-10:00 bucket.
      final focus = HourlyFocus.of(
        [record(DateTime(2026, 10, 9, 9), DateTime(2026, 10, 9, 9, 30))],
        day,
      );

      expect(focus.seconds[focus.bucketForHour(9)!], 1800);
      expect(focus.totalSeconds, 1800);
    });

    test('a session across a boundary is split, not banked at its start', () {
      // 09:30-10:30: thirty minutes in each of two buckets. Counting it all at
      // 09:30 would put an hour in a bucket that had half of one.
      final focus = HourlyFocus.of(
        [record(DateTime(2026, 10, 9, 9, 30), DateTime(2026, 10, 9, 10, 30))],
        day,
      );

      expect(focus.seconds[focus.bucketForHour(9)!], 1800);
      expect(focus.seconds[focus.bucketForHour(10)!], 1800);
      expect(focus.totalSeconds, 3600);
    });

    test('nothing is lost or invented across a whole day', () {
      final records = [
        record(DateTime(2026, 10, 9, 7, 15), DateTime(2026, 10, 9, 8, 5)),
        record(DateTime(2026, 10, 9, 11), DateTime(2026, 10, 9, 11, 25)),
        record(DateTime(2026, 10, 9, 13, 50), DateTime(2026, 10, 9, 15, 10)),
        record(DateTime(2026, 10, 9, 19, 30), DateTime(2026, 10, 9, 21)),
      ];
      final expected = records.fold<int>(
          0, (sum, r) => sum + r.endAt.difference(r.startAt).inSeconds);

      expect(HourlyFocus.of(records, day).totalSeconds, expected);
    });

    test('a zero-length record contributes nothing', () {
      final at = DateTime(2026, 10, 9, 10);
      expect(HourlyFocus.of([record(at, at)], day).totalSeconds, 0);
    });

    test('bucketForHour is null outside the window', () {
      final focus = HourlyFocus.of(const [], day);

      expect(focus.bucketForHour(5), isNull);
      expect(focus.bucketForHour(22), isNull);
      expect(focus.bucketForHour(6), 0);
      expect(focus.bucketForHour(21), 7);
    });
  });

  group('the chart', () {
    Future<void> pump(WidgetTester tester, HourlyFocus focus) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SizedBox(width: 150, child: HourlyFocusChart(focus: focus)),
          ),
        ),
      );
    }

    testWidgets('draws one bar per bucket', (tester) async {
      await pump(tester, HourlyFocus.of(const [], day));

      expect(find.byType(HourlyFocusChart), findsOneWidget);
      // Eight buckets, eight bars — counted by their containers.
      final bars = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(HourlyFocusChart),
          matching: find.byType(Container),
        ),
      );
      expect(bars.length, 8);
    });

    testWidgets('labels every third hour', (tester) async {
      await pump(tester, HourlyFocus.of(const [], day));

      for (final hour in const [6, 9, 12, 15, 18, 21]) {
        expect(find.text('$hour'), findsOneWidget, reason: '$hour');
      }
    });

    testWidgets('the busiest bucket is the tallest', (tester) async {
      final focus = HourlyFocus.of(
        [
          record(DateTime(2026, 10, 9, 7), DateTime(2026, 10, 9, 7, 20)),
          record(DateTime(2026, 10, 9, 13), DateTime(2026, 10, 9, 14, 30)),
        ],
        day,
      );
      await pump(tester, focus);

      final rendered = tester
          .renderObjectList<RenderBox>(
            find.descendant(
              of: find.byType(HourlyFocusChart),
              matching: find.byType(Container),
            ),
          )
          .map((box) => box.size.height)
          .toList();
      expect(rendered.length, 8);
      final tallest =
          rendered.indexOf(rendered.reduce((a, b) => a > b ? a : b));
      expect(
        tallest,
        focus.bucketForHour(13),
        reason: 'the 12:00-14:00 bucket holds 90 minutes and is the busiest',
      );
    });

    testWidgets('an empty day says so rather than drawing a lie',
        (tester) async {
      await pump(tester, HourlyFocus.of(const [], day));

      final node = tester.getSemantics(find.byType(HourlyFocusChart));
      expect(node.label, contains('还没有记录'));
    });
  });
}
