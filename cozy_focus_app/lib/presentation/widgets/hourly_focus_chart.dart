import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/focus_record.dart';
import '../theme/app_theme.dart';

/// Where a day's focus time sits on the clock.
///
/// Pure and separate from the widget so the bucketing can be tested without
/// pumping anything: the arithmetic is the part that can be wrong in ways a
/// screenshot would not show.
///
/// ## The window
///
/// Design 01 draws eight bars of two hours, from 06:00 to 22:00, with the axis
/// labelled 6, 9, 12, 15, 18 and 21. That window is kept, and **widened in whole
/// two-hour steps when the day's focus falls outside it**. Widened rather than
/// clipped because a chart that silently drops an hour of work is worse than one
/// whose axis starts earlier than the design's — the card prints the day's real
/// total beside the bars, so bars that did not account for it would be a visible
/// contradiction.
class HourlyFocus {
  /// The first hour drawn. Always even.
  final int startHour;

  /// One past the last hour drawn. Always even.
  final int endHour;

  /// Seconds in each bucket, earliest first.
  final List<int> seconds;

  const HourlyFocus({
    required this.startHour,
    required this.endHour,
    required this.seconds,
  });

  /// The design's window, and the bucket size it draws.
  static const int designStartHour = 6;
  static const int designEndHour = 22;
  static const int bucketHours = 2;

  /// How many hours each axis label is apart, from the design's 6/9/12/15/18/21.
  static const int labelStepHours = 3;

  int get bucketCount => seconds.length;

  int get totalSeconds => seconds.fold(0, (sum, s) => sum + s);

  int get busiestSeconds => seconds.isEmpty ? 0 : seconds.reduce(math.max);

  /// The hours the axis labels sit at.
  ///
  /// Positions, not buckets: the design puts `9` at nine o'clock even though no
  /// bucket starts there, because the axis is a clock.
  List<int> get labelHours => [
        for (var hour = startHour; hour <= endHour; hour += labelStepHours)
          hour,
      ];

  /// The bucket containing [hour], or null when it falls outside the window.
  int? bucketForHour(int hour) {
    if (hour < startHour || hour >= endHour) return null;
    return (hour - startHour) ~/ bucketHours;
  }

  /// Buckets [records] for the day [day] begins.
  ///
  /// A record's seconds are split across the buckets its **wall-clock span**
  /// overlaps, so a session running across a bucket boundary is counted where it
  /// actually happened rather than wholly at its start. A pause inside that span
  /// is counted with it: this answers "when was I at this", and a two-hour
  /// session paused in the middle was still the thing occupying those hours.
  static HourlyFocus of(List<FocusRecord> records, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);

    var startHour = designStartHour;
    var endHour = designEndHour;
    for (final record in records) {
      final from = record.startAt;
      final to = record.endAt;
      if (from.isBefore(dayStart)) {
        startHour = 0;
      } else if (from.hour < startHour) {
        startHour = from.hour;
      }
      // Measured from the day's start rather than read off the clock, so a
      // session that runs past midnight extends the window instead of being
      // cut at 24:00. That matters because the day's total counts the whole
      // session — attribution is by its start, everywhere in the app — so
      // clipping the tail would leave the card printing a total the bars did
      // not account for, which is the same contradiction widening the window
      // already exists to avoid.
      final hoursIntoDay = to.difference(dayStart).inHours +
          (to.minute > 0 || to.second > 0 ? 1 : 0);
      if (hoursIntoDay > endHour) endHour = hoursIntoDay;
    }
    startHour -= startHour % bucketHours;
    endHour += endHour % bucketHours;

    final count = (endHour - startHour) ~/ bucketHours;
    final seconds = List<int>.filled(count, 0);

    for (final record in records) {
      final from = record.startAt;
      final to = record.endAt;
      if (!to.isAfter(from)) continue;
      for (var i = 0; i < count; i++) {
        final bucketStart = dayStart.add(
          Duration(hours: startHour + i * bucketHours),
        );
        final bucketEnd = bucketStart.add(const Duration(hours: bucketHours));
        final overlapStart = from.isAfter(bucketStart) ? from : bucketStart;
        final overlapEnd = to.isBefore(bucketEnd) ? to : bucketEnd;
        final overlap = overlapEnd.difference(overlapStart).inSeconds;
        if (overlap > 0) seconds[i] += overlap;
      }
    }

    return HourlyFocus(
      startHour: startHour,
      endHour: endHour,
      seconds: seconds,
    );
  }
}

/// The hourly bars design 01 draws on the right of the 今天的专注 card.
class HourlyFocusChart extends StatelessWidget {
  final HourlyFocus focus;

  const HourlyFocusChart({super.key, required this.focus});

  @override
  Widget build(BuildContext context) {
    final busiest = focus.busiestSeconds;

    return Semantics(
      // The bars are a picture of the same fact the card's total states, and a
      // screen reader walking eight unlabelled bars learns nothing. The window
      // and the busiest hour are the parts that carry information.
      excludeSemantics: true,
      label: busiest == 0
          ? '今天的专注分布：还没有记录'
          : '今天的专注分布：'
              '${focus.startHour % 24} 点到 ${focus.endHour % 24} 点，'
              '最集中的两小时有 ${(busiest / 60).floor()} 分钟',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < focus.bucketCount; i++)
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _Bar(
                        // A bucket with nothing in it is drawn as a flat mark
                        // rather than as no bar at all, so the axis still reads
                        // as a series with gaps instead of as missing columns.
                        fraction: busiest == 0 ? 0 : focus.seconds[i] / busiest,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 14,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final span = focus.endHour - focus.startHour;
                return Stack(
                  children: [
                    for (final hour in focus.labelHours)
                      Positioned(
                        // Positioned at its own hour, not under a bucket: the
                        // design's `9` sits at nine o'clock, between the two
                        // buckets that hour falls in. Clamped, because the first
                        // label would otherwise start at a negative offset and be
                        // cut off by the card's edge.
                        left: (constraints.maxWidth *
                                    ((hour - focus.startHour) / span) -
                                6)
                            .clamp(
                          0.0,
                          math.max(0.0, constraints.maxWidth - 14),
                        ),
                        child: Text(
                          // Past midnight the window keeps counting — 24, 25 —
                          // but the axis is a clock, so it reads 0, 1. A window
                          // that stopped at 24 would need a different label for
                          // the same instant depending on which side of it the
                          // bucket fell.
                          '${hour % 24}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double fraction;

  const _Bar({required this.fraction});

  @override
  Widget build(BuildContext context) {
    const maxHeight = 44.0;
    const minHeight = 3.0;
    final height =
        minHeight + (maxHeight - minHeight) * fraction.clamp(0.0, 1.0);

    return Container(
      width: 9,
      height: height,
      decoration: BoxDecoration(
        // The low end of the design's bars is a paler green than the high end,
        // so a barely-used hour reads as barely used.
        color: fraction < 0.34 ? AppColors.chartBarFaint : AppColors.chartBar,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
}
