/// Time-of-day bands, and the pure resolver that maps a clock reading onto one.
///
/// ## Status: TEMPORARY DEFAULT MAPPING (documented, not silently invented)
///
/// Neither V4.1 (`docs/cozy_focus_v4_1/`) nor any product contract in
/// `outputs/ai_handoff/` defines time-of-day bands, a late-night window, or a
/// bedtime message. A full-package search for `时段`, `timeOfDay`, `morning`,
/// `lateNight`, `深夜` returns nothing; the evidence is recorded in
/// `MOCHI_GROWTH_STAGE0_AUDIT.md` §A5/§B3.
///
/// The five bands below are therefore a **chosen default**, centralised in
/// [TimeOfDaySpec] so retuning the day is a one-file change.
///
/// ## Presentation-only, by construction
///
/// This resolver is a **presentation** concern: it may colour a greeting, pick
/// a message and (later) tint a room, and it must never touch the reward
/// economy. That is not left to convention — `time_of_day_test.dart` scans
/// `lib/domain/` and `lib/data/` and fails if either layer references these
/// types. A time-of-day band therefore *cannot* reach XP, coins, happiness, a
/// settlement or a streak.
library;

/// A band of the day, used only to choose how Mochi presents itself.
enum TimeOfDayBand {
  /// Early morning. Waking up.
  morning,

  /// Around noon.
  midday,

  /// Afternoon.
  afternoon,

  /// Evening.
  evening,

  /// Late night — the band that unlocks Mochi's care copy rather than its
  /// encouragement copy.
  lateNight,
}

/// The centralised band boundaries, as hours on a 24-hour clock.
///
/// The bands tile the whole day: every hour belongs to exactly one band, with
/// no gaps and no overlaps, which `time_of_day_test.dart` asserts by sweeping
/// all 24 hours.
abstract final class TimeOfDaySpec {
  const TimeOfDaySpec._();

  /// `lateNight` runs from this hour until [morningFrom], wrapping midnight.
  static const int lateNightFrom = 23;

  /// `morning` starts here.
  static const int morningFrom = 5;

  /// `midday` starts here.
  static const int middayFrom = 11;

  /// `afternoon` starts here.
  static const int afternoonFrom = 14;

  /// `evening` starts here.
  static const int eveningFrom = 18;

  /// Every hour at which the band changes, ascending.
  ///
  /// Exposed so a test can assert that the day is tiled *only* at these hours —
  /// a change anywhere else would mean the bands overlap or leave a gap.
  static const List<int> boundaryHours = [
    morningFrom,
    middayFrom,
    afternoonFrom,
    eveningFrom,
    lateNightFrom,
  ];
}

/// Pure mapping from a clock reading to a [TimeOfDayBand].
///
/// No state, no I/O, no caching of "now" — the caller supplies the instant, so
/// the resolver is exhaustively testable and cannot drift.
abstract final class TimeOfDayResolver {
  const TimeOfDayResolver._();

  /// Resolves [now] to its band.
  ///
  /// Only `now.hour` is read, so two instants in the same hour always resolve
  /// the same way regardless of minutes, seconds or timezone object identity.
  static TimeOfDayBand resolve(DateTime now) {
    final hour = now.hour;
    if (hour >= TimeOfDaySpec.lateNightFrom ||
        hour < TimeOfDaySpec.morningFrom) {
      return TimeOfDayBand.lateNight;
    }
    if (hour < TimeOfDaySpec.middayFrom) return TimeOfDayBand.morning;
    if (hour < TimeOfDaySpec.afternoonFrom) return TimeOfDayBand.midday;
    if (hour < TimeOfDaySpec.eveningFrom) return TimeOfDayBand.afternoon;
    return TimeOfDayBand.evening;
  }

  /// Whether [now] falls in the late-night band.
  ///
  /// Convenience for the one question the encouragement engine asks most often.
  static bool isLateNight(DateTime now) =>
      resolve(now) == TimeOfDayBand.lateNight;
}

/// Human-readable labels, for diagnostics and tests.
extension TimeOfDayBandLabel on TimeOfDayBand {
  /// The band's stable identifier.
  String get label => switch (this) {
        TimeOfDayBand.morning => 'MORNING',
        TimeOfDayBand.midday => 'MIDDAY',
        TimeOfDayBand.afternoon => 'AFTERNOON',
        TimeOfDayBand.evening => 'EVENING',
        TimeOfDayBand.lateNight => 'LATE_NIGHT',
      };
}
