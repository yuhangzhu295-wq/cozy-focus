/// What span the statistics are about, and the window it covers.
library;

/// 日 / 周 / 月.
enum AnalyticsRangeKind {
  day('day', '日'),
  week('week', '周'),
  month('month', '月');

  final String id;
  final String label;

  const AnalyticsRangeKind(this.id, this.label);
}

/// A window: which kind, which day it is anchored on, and its exact bounds.
///
/// Computed once and carried, rather than recomputed wherever a query needs it,
/// so the header's date range and the query cannot disagree about which days are
/// being summed.
class AnalyticsRange {
  final AnalyticsRangeKind kind;

  /// The day the window is anchored on, at local midnight.
  final DateTime anchor;

  /// The window's first day, inclusive, at local midnight.
  final DateTime from;

  /// The day after the window's last day — exclusive, so a range is
  /// `[from, to)` and a record at midnight on the last day is inside it.
  final DateTime to;

  const AnalyticsRange({
    required this.kind,
    required this.anchor,
    required this.from,
    required this.to,
  });

  /// The window of [kind] containing [day].
  ///
  /// A week starts on Monday, because the design's chart is labelled 周一 to 周日
  /// and a window that started on Sunday would put the weekend at both ends.
  factory AnalyticsRange.containing(AnalyticsRangeKind kind, DateTime day) {
    final anchor = DateTime(day.year, day.month, day.day);
    switch (kind) {
      case AnalyticsRangeKind.day:
        return AnalyticsRange(
          kind: kind,
          anchor: anchor,
          from: anchor,
          to: anchor.add(const Duration(days: 1)),
        );
      case AnalyticsRangeKind.week:
        final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
        return AnalyticsRange(
          kind: kind,
          anchor: anchor,
          from: monday,
          to: monday.add(const Duration(days: 7)),
        );
      case AnalyticsRangeKind.month:
        final first = DateTime(anchor.year, anchor.month);
        return AnalyticsRange(
          kind: kind,
          anchor: anchor,
          from: first,
          to: DateTime(anchor.year, anchor.month + 1),
        );
    }
  }

  /// How many days the window covers.
  int get days => to.difference(from).inDays;

  /// `10 月 2 日 - 10 月 8 日`, or one date for a single day.
  String get label {
    if (days <= 1) return '${from.month} 月 ${from.day} 日';
    final last = to.subtract(const Duration(days: 1));
    return '${from.month} 月 ${from.day} 日 - ${last.month} 月 ${last.day} 日';
  }

  /// Value equality, because this is a provider family key.
  ///
  /// Without it every rebuild produced a *new* window as far as Riverpod was
  /// concerned, so `analyticsSummaryProvider(range)` was a different provider each
  /// time: the old one was disposed, a new one started, and the statistics view
  /// rebuilt before any of them could resolve. The screen stayed on its loading
  /// state forever while the code looked correct.
  @override
  bool operator ==(Object other) =>
      other is AnalyticsRange &&
      other.kind == kind &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(kind, from, to);

  /// The window moved one step back or forward, anchored on the same weekday or
  /// day of month as before where the calendar allows.
  AnalyticsRange step(int direction) {
    final moved = switch (kind) {
      AnalyticsRangeKind.day => anchor.add(Duration(days: direction)),
      AnalyticsRangeKind.week => anchor.add(Duration(days: 7 * direction)),
      AnalyticsRangeKind.month =>
        DateTime(anchor.year, anchor.month + direction, anchor.day),
    };
    return AnalyticsRange.containing(kind, moved);
  }
}
