/// The companion's daily routine: what it prefers to do at each time of day.
///
/// ## What this adds
///
/// `time_of_day.dart` already tiles the day into five bands, and
/// `furniture_action_resolver.dart` already reads one of them — but only to
/// decide bedtime. Between 05:00 and 22:59 the companion's behaviour was
/// **identical**: it had a night mode, not a daily life.
///
/// A routine gives those eighteen hours a shape. It is a per-band, ordered
/// preference list over behaviours the furniture catalog **already declares**.
/// It does not invent behaviour and it does not name a frame: it selects, and
/// it says why.
///
/// ## Where it sits in the priority order
///
/// The routine is the second-to-last branch. A player request, a running focus
/// session, a break, being tired and the night rule all outrank it, so the
/// routine only ever changes what the companion does when **nothing more
/// important is happening** — which is exactly the window that used to be
/// undifferentiated.
///
/// ## `lateNight` is deliberately absent
///
/// The night rule already owns bedtime. Two answers to "when does it sleep"
/// would be two sources of truth, and the second one would eventually win by
/// accident. [unscheduledBands] names the omission so a parity test can assert
/// it is a decision rather than an oversight.
///
/// ## Presentation-only, by construction
///
/// There is no I/O here, no `DateTime.now()`, and no state. Like the
/// time-of-day bands, this type is **forbidden from reaching the business
/// layer**, and that is enforced rather than promised: `daily_routine_test.dart`
/// scans `lib/domain/` and `lib/data/` and fails if either references these
/// types. A routine therefore *cannot* express an XP change, a coin change or a
/// settlement — it has no vocabulary for them.
///
/// ## Why a Dart table as well as JSON
///
/// `assets/companion/daily_routine.json` is the authoring source, with the
/// rationale written next to each band. This is the runtime mirror, and it is
/// **synchronous on purpose**: the room must know what the companion is doing on
/// the first frame, without an `await` between app start and first paint and
/// without every widget test having to pump an async load. The two are held
/// together by `daily_routine_parity_test.dart`, field for field.
library;

import '../time_of_day.dart';

/// One preference in a band's routine.
///
/// [role] is an interaction-point role (`front`, `seat`, `work`, `lie`), not a
/// furniture id — the resolver already keys on roles, and a role lets the step
/// be satisfied by whichever furniture the player actually owns. A player with a
/// rug and no sofa still gets an evening; they just get it on the rug.
///
/// [action] is the specific catalog action to prefer, so the routine reads as a
/// decision ("in the morning it reads") rather than as a slot to be filled with
/// whatever happens to be first.
class DailyRoutineStep {
  /// The interaction-point role this step needs, e.g. `front`.
  final String role;

  /// The furniture action id this step prefers, e.g. `read`.
  final String action;

  /// A short phrase for diagnostics, e.g. `翻翻书`.
  final String label;

  const DailyRoutineStep({
    required this.role,
    required this.action,
    required this.label,
  });

  /// Reads a step from the authored JSON.
  factory DailyRoutineStep.fromJson(Map<String, dynamic> json) =>
      DailyRoutineStep(
        role: json['role'] as String,
        action: json['action'] as String,
        label: json['label'] as String,
      );

  /// The authored form, so a test can round-trip this back to JSON.
  Map<String, dynamic> toJson() => {
        'role': role,
        'action': action,
        'label': label,
      };

  @override
  String toString() => 'DailyRoutineStep($role→$action "$label")';
}

/// The shipped routine, and the reader for the authored form.
class DailyRoutine {
  /// The steps for each scheduled band, in preference order.
  final Map<TimeOfDayBand, List<DailyRoutineStep>> byBand;

  const DailyRoutine(this.byBand);

  /// The bands the routine intentionally does **not** schedule.
  ///
  /// Named rather than left implicit so the parity test can assert the absence
  /// is deliberate. See the library note above.
  static const Set<TimeOfDayBand> unscheduledBands = {TimeOfDayBand.lateNight};

  /// The shipped routine, mirroring `assets/companion/daily_routine.json`.
  static const DailyRoutine shipped = DailyRoutine({
    TimeOfDayBand.morning: [
      DailyRoutineStep(role: 'front', action: 'read', label: '翻翻书'),
      DailyRoutineStep(role: 'seat', action: 'sit', label: '晒晒太阳'),
    ],
    TimeOfDayBand.midday: [
      DailyRoutineStep(role: 'work', action: 'craft', label: '做点小东西'),
      DailyRoutineStep(role: 'front', action: 'search', label: '找本书'),
    ],
    TimeOfDayBand.afternoon: [
      DailyRoutineStep(role: 'front', action: 'search', label: '找本书'),
      DailyRoutineStep(role: 'work', action: 'craft', label: '做点小东西'),
    ],
    TimeOfDayBand.evening: [
      DailyRoutineStep(role: 'seat', action: 'sit', label: '窝一会儿'),
      DailyRoutineStep(role: 'seat', action: 'rest', label: '歇一歇'),
    ],
  });

  /// The steps for [band], or an empty list when the band is unscheduled.
  ///
  /// Empty rather than a default: an unscheduled band means "no routine
  /// preference", and returning a made-up step would give the resolver a
  /// preference nobody authored.
  List<DailyRoutineStep> stepsFor(TimeOfDayBand band) =>
      byBand[band] ?? const [];

  /// The bands this routine schedules.
  Set<TimeOfDayBand> get scheduledBands => byBand.keys.toSet();

  /// Reads the authored form.
  ///
  /// The JSON keys bands by wire id (`morning`, `midday`, …). An unknown key is
  /// skipped rather than throwing, so a band renamed in the manifest degrades to
  /// "no routine for that band" instead of taking the app down — the same
  /// tolerance `CompanionMacroBehavior.fromId` applies to recipe entries.
  factory DailyRoutine.fromJson(Map<String, dynamic> json) {
    final bands = json['bands'] as Map<String, dynamic>;
    final byBand = <TimeOfDayBand, List<DailyRoutineStep>>{};
    for (final entry in bands.entries) {
      final band = bandForWireId(entry.key);
      if (band == null) continue;
      final steps = (entry.value as Map<String, dynamic>)['steps'] as List;
      byBand[band] = [
        for (final step in steps)
          DailyRoutineStep.fromJson(step as Map<String, dynamic>),
      ];
    }
    return DailyRoutine(byBand);
  }

  /// The authored form, so a test can round-trip this back to JSON.
  Map<String, dynamic> toJson() => {
        'bands': {
          for (final entry in byBand.entries)
            wireIdFor(entry.key): {
              'steps': [for (final step in entry.value) step.toJson()],
            },
        },
      };
}

/// The JSON wire id for a band.
///
/// Kept here rather than on [TimeOfDayBand] because the wire id is this
/// manifest's spelling, not the band's identity — the bands predate this file
/// and their `label` extension is an upper-case diagnostic string.
String wireIdFor(TimeOfDayBand band) => switch (band) {
      TimeOfDayBand.morning => 'morning',
      TimeOfDayBand.midday => 'midday',
      TimeOfDayBand.afternoon => 'afternoon',
      TimeOfDayBand.evening => 'evening',
      TimeOfDayBand.lateNight => 'lateNight',
    };

/// The band for a JSON wire id, or `null` when the id is unknown.
TimeOfDayBand? bandForWireId(String id) {
  for (final band in TimeOfDayBand.values) {
    if (wireIdFor(band) == id) return band;
  }
  return null;
}
