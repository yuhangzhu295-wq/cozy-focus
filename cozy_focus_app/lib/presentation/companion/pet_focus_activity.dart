import 'focus_phase.dart';

/// The beats Mochi performs during a focus session.
///
/// ## Where these come from
///
/// `designs/motion/11F_Focus_Work.png` specifies Focus Work as a **4–6 秒循环**
/// with four keyframes: **开始 / 工作 / 微动 / 循环** ("prepare / work / micro
/// motion / loop"). That is the authoritative short arc, and it is what the
/// first four values below implement. The brief's own loop —
/// `prepare → work → micro idle → work variant → glance → return to work` — is
/// the same shape, so no parallel system was invented.
///
/// [glance] is the one addition: the brief asks for a "glance" beat and V4.1 has
/// no equivalent keyframe. It is marked as such and is deliberately the smallest
/// possible motion (a brief head lift), consistent with 11F's hard constraint
/// 「不制造持续大幅运动」.
///
/// ## These never touch business state
///
/// Nothing here awards XP, writes a record, advances a craft job, or changes a
/// session. The whole file is a presentation schedule.
enum PetFocusActivity {
  /// 开始 — Mochi gets ready to work. Slightly more animated as it settles in.
  prepare,

  /// 工作 — the low-distraction work beat.
  work,

  /// 微动 — a still beat. Visibly calmer than [work], which is what makes the
  /// loop readable as *pacing* rather than as constant motion.
  microIdle,

  /// 循环 — the return beat that carries the cycle back to [work].
  returning,

  /// A brief look up. Not a V4.1 keyframe; see the enum docs.
  glance,
}

/// Per-activity rendering parameters.
///
/// Kept tiny on purpose. 11F's constraint is 「不制造持续大幅运动」, so the beats
/// differ by *how much* the existing channels move, not by introducing new
/// gestures. The single exception is [headLiftDegrees], which only [glance] uses.
class PetFocusActivitySpec {
  /// Multiplier on the focus state's motion amplitude during this beat.
  ///
  /// Never `0`: a beat that froze Mochi entirely would read as a dropped frame,
  /// not as a pause in work.
  final double amplitudeScale;

  /// A subtle vertical offset in logical pixels, spread across the beat.
  final double dyOffset;

  /// A single out-and-back head lift, in degrees, spread across the beat.
  final double headLiftDegrees;

  /// A subtle head rotation offset in degrees, signed.
  final double headDegrees;

  /// A head bob in degrees, one full oscillation per work cycle.
  final double headBobDegrees;

  const PetFocusActivitySpec({
    required this.amplitudeScale,
    this.dyOffset = 0.0,
    this.headDegrees = 0.0,
    this.headLiftDegrees = 0.0,
    this.headBobDegrees = 0.0,
  });

  /// The centralised beat table.
  ///
  /// `microIdle` is the strongest signal in the loop: it drops to 0.45, so a
  /// screenshot taken during it is unmistakably calmer than one taken during
  /// `work`. That is what makes the loop observable rather than merely asserted.
  static const Map<PetFocusActivity, PetFocusActivitySpec> table = {
    PetFocusActivity.prepare: PetFocusActivitySpec(
      amplitudeScale: 1.12,
      dyOffset: -0.6,
      headLiftDegrees: 0.6,
    ),
    PetFocusActivity.work: PetFocusActivitySpec(
      amplitudeScale: 1.0,
      dyOffset: 0.8,
      headDegrees: 0.8,
    ),
    PetFocusActivity.microIdle: PetFocusActivitySpec(
      amplitudeScale: 0.45,
      dyOffset: -0.5,
      headDegrees: -0.4,
    ),
    PetFocusActivity.returning: PetFocusActivitySpec(
      amplitudeScale: 1.04,
      dyOffset: 0.2,
    ),
    PetFocusActivity.glance: PetFocusActivitySpec(
      amplitudeScale: 1.0,
      headLiftDegrees: 2.2,
    ),
  };

  static PetFocusActivitySpec of(PetFocusActivity activity) => table[activity]!;
}

/// The category-derived flavour of the work beat.
///
/// ## Status: PRESENTATION-ONLY CHOICE, no V4.1 authority
///
/// The brief maps task categories onto work animations (学习 → reading/writing,
/// 工作 → writing/typing/organizing, 阅读 → reading, other → generic) but marks
/// it optional — "**may** influence VISUAL work animation". V4.1 defines a single
/// Focus Work loop with no per-category art (`MOCHI_GROWTH_STAGE0_AUDIT.md` §B3
/// item 5), and 11F forbids large continuous motion.
///
/// The mapping below is therefore a *flavour*: it retunes the amplitude and bob
/// of the existing work beat and adds no new artwork. It is presentation-only by
/// construction — it is derived from `categoryId` and never written back, so
/// statistics, rewards and session semantics are untouched.
enum PetWorkFlavour {
  /// No category, or one with no mapping.
  generic,

  /// 学习 / 阅读 — steady and low-motion, like reading.
  reading,

  /// 工作 — a small rhythmic bob, like writing.
  writing,

  /// 生活 — a slightly wider sway, like sorting things out.
  organizing,
}

/// Centralised flavour parameters.
class PetWorkFlavourSpec {
  /// Multiplier on the work beat's amplitude.
  final double amplitudeScale;

  /// Head bob in degrees, one oscillation per work cycle.
  final double headBobDegrees;

  const PetWorkFlavourSpec({
    required this.amplitudeScale,
    required this.headBobDegrees,
  });

  /// The centralised flavour table.
  ///
  /// Every value stays within a few percent of 1.0. A category must never make
  /// Mochi read as a different character — it is the same pet, doing a slightly
  /// different kind of quiet work.
  static const Map<PetWorkFlavour, PetWorkFlavourSpec> table = {
    PetWorkFlavour.generic: PetWorkFlavourSpec(
      amplitudeScale: 1.0,
      headBobDegrees: 0.0,
    ),
    PetWorkFlavour.reading: PetWorkFlavourSpec(
      amplitudeScale: 0.92,
      headBobDegrees: 0.5,
    ),
    PetWorkFlavour.writing: PetWorkFlavourSpec(
      amplitudeScale: 1.05,
      headBobDegrees: 0.9,
    ),
    PetWorkFlavour.organizing: PetWorkFlavourSpec(
      amplitudeScale: 1.0,
      headBobDegrees: 0.7,
    ),
  };

  static PetWorkFlavourSpec of(PetWorkFlavour flavour) => table[flavour]!;
}

/// Maps the app's real `categoryId` values onto a [PetWorkFlavour].
///
/// The ids are the ones the app actually stores: `study`, `work`, `reading`,
/// `life`, `other` (`focus_save_page.dart`, `progress_overview_page.dart`,
/// `record_detail_page.dart`). Anything else — including `null` — is [generic],
/// so an unmapped or future category degrades to the neutral flavour rather
/// than throwing or inventing one.
abstract final class PetWorkFlavourResolver {
  const PetWorkFlavourResolver._();

  static PetWorkFlavour forCategoryId(String? categoryId) {
    switch (categoryId) {
      case 'study':
      case 'reading':
        return PetWorkFlavour.reading;
      case 'work':
        return PetWorkFlavour.writing;
      case 'life':
        return PetWorkFlavour.organizing;
      default:
        return PetWorkFlavour.generic;
    }
  }
}

/// One beat of the work cycle: which activity, and how far through it we are.
class PetFocusBeat {
  final PetFocusActivity activity;

  /// Progress within this beat, `0.0 … 1.0`. Used to spread a beat's
  /// out-and-back motion (a glance, a settle-in) across its own window instead
  /// of snapping at the boundary.
  final double localProgress;

  const PetFocusBeat({
    required this.activity,
    required this.localProgress,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetFocusBeat &&
          runtimeType == other.runtimeType &&
          activity == other.activity &&
          localProgress == other.localProgress;

  @override
  int get hashCode => Object.hash(activity, localProgress);

  @override
  String toString() =>
      'PetFocusBeat(${activity.name} @ ${localProgress.toStringAsFixed(2)})';
}

/// A beat window inside the normalised work cycle.
///
/// Public so tests can assert that each phase's windows tile `[0, 1]` with no
/// gaps and no overlaps — the property that makes [PetFocusActivitySchedule]
/// total.
class PetFocusBeatWindow {
  final double start;
  final double end;
  final PetFocusActivity activity;

  const PetFocusBeatWindow(this.start, this.end, this.activity);
}

/// Pure schedule: cycle position + phase → the beat Mochi is performing.
///
/// The phase changes the *mix and dwell* of the beats, which is how the brief's
/// behavioural intent is realised:
///
/// * **STARTING** — "Mochi gets ready to work": `prepare` dominates the cycle.
/// * **WORKING** — "low-distraction work loops": `work` dominates, broken by a
///   short `microIdle`.
/// * **DEEP_FOCUS** — "calmer and more concentrated": a longer `work` beat, a
///   longer `microIdle`, and **no** `glance` at all. Calm is expressed as a
///   schedule, not as a second amplitude scalar, so there is only ever one
///   amplitude system.
/// * **FINISHING** — "subtle anticipation": a `glance` beat appears.
abstract final class PetFocusActivitySchedule {
  const PetFocusActivitySchedule._();

  /// How long the cycle is, in seconds, as a range.
  ///
  /// 11F says **4–6 秒循环**. The renderer's controller is set inside this band
  /// (`PetMotionSpec.focusWorkCycle`, 4500 ms). Recorded here so a future change
  /// to the controller duration has an obvious bound to stay inside.
  static const double minCycleSeconds = 4.0;
  static const double maxCycleSeconds = 6.0;

  static const List<PetFocusBeatWindow> _startingBeats = <PetFocusBeatWindow>[
    PetFocusBeatWindow(0.00, 0.45, PetFocusActivity.prepare),
    PetFocusBeatWindow(0.45, 0.80, PetFocusActivity.work),
    PetFocusBeatWindow(0.80, 1.00, PetFocusActivity.microIdle),
  ];

  static const List<PetFocusBeatWindow> _workingBeats = <PetFocusBeatWindow>[
    PetFocusBeatWindow(0.00, 0.12, PetFocusActivity.prepare),
    PetFocusBeatWindow(0.12, 0.55, PetFocusActivity.work),
    PetFocusBeatWindow(0.55, 0.68, PetFocusActivity.microIdle),
    PetFocusBeatWindow(0.68, 0.86, PetFocusActivity.work),
    PetFocusBeatWindow(0.86, 1.00, PetFocusActivity.returning),
  ];

  static const List<PetFocusBeatWindow> _deepFocusBeats = <PetFocusBeatWindow>[
    PetFocusBeatWindow(0.00, 0.06, PetFocusActivity.prepare),
    PetFocusBeatWindow(0.06, 0.62, PetFocusActivity.work),
    PetFocusBeatWindow(0.62, 0.86, PetFocusActivity.microIdle),
    PetFocusBeatWindow(0.86, 1.00, PetFocusActivity.work),
  ];

  static const List<PetFocusBeatWindow> _finishingBeats = <PetFocusBeatWindow>[
    PetFocusBeatWindow(0.00, 0.08, PetFocusActivity.prepare),
    PetFocusBeatWindow(0.08, 0.46, PetFocusActivity.work),
    PetFocusBeatWindow(0.46, 0.58, PetFocusActivity.microIdle),
    PetFocusBeatWindow(0.58, 0.76, PetFocusActivity.glance),
    PetFocusBeatWindow(0.76, 1.00, PetFocusActivity.work),
  ];

  /// The beat windows for [phase]. Total — every phase has a schedule, and each
  /// schedule covers `[0, 1]` with no gaps, which `focus_phase_test.dart`
  /// asserts.
  static List<PetFocusBeatWindow> windowsFor(FocusPhase? phase) {
    switch (phase) {
      case FocusPhase.starting:
        return _startingBeats;
      case FocusPhase.working:
        return _workingBeats;
      case FocusPhase.deepFocus:
        return _deepFocusBeats;
      case FocusPhase.finishing:
        return _finishingBeats;
      case null:
        return _workingBeats;
    }
  }

  /// Resolves the beat at [cyclePosition] (`0.0 … 1.0`) for [phase].
  ///
  /// Total and defensive: a `null`/`NaN`/out-of-range position clamps into the
  /// cycle rather than throwing, because this runs on every frame of a live
  /// session and a thrown frame is a dropped frame.
  static PetFocusBeat beatAt(double cyclePosition, FocusPhase? phase) {
    final raw = (cyclePosition.isFinite) ? cyclePosition : 0.0;
    final position = raw.clamp(0.0, 1.0);
    final windows = windowsFor(phase);

    for (final window in windows) {
      // The final window is closed at the top so position == 1.0 has a home.
      final isLast = identical(window, windows.last);
      final inside = position >= window.start &&
          (isLast ? position <= window.end : position < window.end);
      if (inside) {
        final span = window.end - window.start;
        final local = span <= 0 ? 0.0 : (position - window.start) / span;
        return PetFocusBeat(
          activity: window.activity,
          localProgress: local.clamp(0.0, 1.0),
        );
      }
    }

    // Unreachable while the windows tile [0, 1]; kept total anyway.
    return const PetFocusBeat(
      activity: PetFocusActivity.work,
      localProgress: 0.0,
    );
  }
}

/// Presentation-only owner of "what is Mochi doing right now".
///
/// ## Why this is a plain class, not a `ChangeNotifier`
///
/// The renderer drives it from inside its own build pass (the work-cycle
/// controller is already in the renderer's `Listenable.merge`, so the tree
/// rebuilds every frame). A notifier would therefore be firing
/// `notifyListeners()` during a build, which is exactly the rebuild-during-build
/// error the rest of the companion layer is careful to avoid.
///
/// So this holds state and is *read* by the renderer. It owns no timers, opens
/// no streams, and its [dispose] exists to make a stale controller inert rather
/// than to release a resource — the renderer disposes it with itself, which
/// `focus_activity_test.dart` asserts.
///
/// ## It cannot touch business state
///
/// Every input is a read of business state (progress, category). Nothing is
/// written back. There is no path from here to XP, a record, a session status or
/// a craft job.
class PetFocusActivityController {
  FocusPhase? _phase;
  String? _categoryId;
  PetWorkFlavour _flavour = PetWorkFlavour.generic;
  PetFocusActivity _activity = PetFocusActivity.prepare;
  double _localProgress = 0.0;
  bool _isDisposed = false;

  /// The phase in force, or `null` when no session is running.
  FocusPhase? get phase => _phase;

  /// The raw category id the flavour was derived from, for diagnostics.
  String? get categoryId => _categoryId;

  /// The resolved category flavour.
  PetWorkFlavour get flavour => _flavour;

  /// The beat currently being performed.
  PetFocusActivity get activity => _activity;

  /// Progress within the current beat, `0.0 … 1.0`.
  double get localProgress => _localProgress;

  /// Whether a session is under way, i.e. whether the activity layer applies.
  bool get isActive => _phase != null;

  bool get isDisposed => _isDisposed;

  /// Updates the session context from real business state.
  ///
  /// Call this when the session's progress or category changes, not every frame
  /// — the renderer pushes the frame-level detail through [updateCycle].
  void setContext({FocusPhase? phase, String? categoryId}) {
    if (_isDisposed) return;
    final nextFlavour = PetWorkFlavourResolver.forCategoryId(categoryId);
    final changed =
        _phase != phase || _categoryId != categoryId || _flavour != nextFlavour;
    _phase = phase;
    _categoryId = categoryId;
    _flavour = nextFlavour;
    if (changed && phase == null) {
      // No session: fall back to the neutral beat rather than leaving the last
      // session's beat frozen on screen.
      _activity = PetFocusActivity.prepare;
      _localProgress = 0.0;
    }
  }

  /// Advances the activity from the work cycle's normalised position.
  ///
  /// Safe to call every frame. When no session is active the activity is held
  /// neutral, so a stale controller can never present work beats.
  void updateCycle(double cyclePosition) {
    if (_isDisposed) return;
    if (_phase == null) {
      _activity = PetFocusActivity.prepare;
      _localProgress = 0.0;
      return;
    }
    final beat = PetFocusActivitySchedule.beatAt(cyclePosition, _phase);
    _activity = beat.activity;
    _localProgress = beat.localProgress;
  }

  /// The rendering parameters for the current beat, combining the beat's own
  /// spec with the category flavour.
  ///
  /// Returns a neutral spec when no session is active, so callers can apply it
  /// unconditionally without a null check.
  PetFocusActivitySpec get visual {
    if (_phase == null) return _neutralSpec;
    final beat = PetFocusActivitySpec.of(_activity);
    final flavour = PetWorkFlavourSpec.of(_flavour);
    return PetFocusActivitySpec(
      amplitudeScale: beat.amplitudeScale * flavour.amplitudeScale,
      dyOffset: beat.dyOffset,
      headLiftDegrees: beat.headLiftDegrees,
      headDegrees: beat.headDegrees,
      headBobDegrees: flavour.headBobDegrees,
    );
  }

  static const PetFocusActivitySpec _neutralSpec = PetFocusActivitySpec(
    amplitudeScale: 1.0,
  );

  void dispose() {
    _isDisposed = true;
  }
}
