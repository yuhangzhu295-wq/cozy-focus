/// The beats Mochi performs while a craft job is running.
///
/// ## Where these come from
///
/// `designs/motion/11G_Craft.png` specifies Craft as a **3–5 秒循环** with four
/// named keyframes: **抬手 / 敲击 / 停顿 / 检查** ("raise / strike / pause /
/// inspect"), and states the binding explicitly — 「与 craftProgress 阶段绑定」.
///
/// These four values are those four keyframes, in that order. Their names, their
/// order and the cycle length are all read from 11G; nothing here was invented.
///
/// ## How four arm keyframes map onto this renderer
///
/// The reference art shows Mochi holding a tool, so two of the four beats read
/// as arm gestures. This renderer has no arm channel — the available channels
/// are `scale / dy / body tilt / ear / tail / eyes / head` — and the head is a
/// single 2-D rotation around the base of the head
/// (`mochi_layered_renderer.dart`), so a nod and a sideways tilt are the same
/// channel here. Each beat is therefore expressed as the closest thing those
/// channels can do:
///
/// | 11G beat | expressed as |
/// |---|---|
/// | 抬手 `raise` | a small upward `dy` and the head tipped back |
/// | 敲击 `strike` | a downward `dy` and the head dipped — the working beat |
/// | 停顿 `pause` | the stillest beat, lowest amplitude, no offset |
/// | 检查 `inspect` | the head turned to one side, as if turning the work over |
///
/// This is a *translation*, not an invention: only the channel mapping is a
/// choice, and it is the same choice STAGE 2 already made for 11F (see
/// `PetFocusActivitySpec`). 11G's own constraint — 「不制造持续大幅运动」's craft
/// counterpart, a 3–5 s loop rather than continuous motion — is honoured by
/// keeping every amplitude within a few percent of neutral.
///
/// ## These never touch business state
///
/// Nothing here advances a craft job, consumes an ingredient, awards an item or
/// writes a record. The whole file is a presentation schedule, and
/// `craftProgress` is only ever *read*.
enum PetCraftActivity {
  /// 抬手 — Mochi lifts the tool.
  raise,

  /// 敲击 — the working beat.
  strike,

  /// 停顿 — a beat of stillness between strikes.
  pause,

  /// 检查 — Mochi turns the work over to look at it.
  inspect,
}

/// Per-beat rendering parameters.
///
/// Deliberately tiny, for the same reason 11F's are: a craft loop that swung the
/// whole body around would fight the focus loop's calm register and read as a
/// different character.
class PetCraftActivitySpec {
  /// Multiplier on the craft state's motion *delta away from neutral*.
  ///
  /// Never `0` and never negative. Scaling the delta rather than the pose means
  /// the neutral pose is never displaced, so a beat cannot make Mochi drift.
  final double amplitudeScale;

  /// A vertical offset in logical pixels, spread across the beat.
  ///
  /// Negative is up, matching the convention the rest of the motion layer uses
  /// (`breatheDyMax` and friends are negative).
  final double dyOffset;

  /// A head rotation in degrees, signed.
  ///
  /// One channel carries both "tipped back" (negative) and "dipped" (positive)
  /// and "turned aside" (used by [PetCraftActivity.inspect]); see the file docs.
  final double headDegrees;

  const PetCraftActivitySpec({
    required this.amplitudeScale,
    this.dyOffset = 0.0,
    this.headDegrees = 0.0,
  });

  /// The centralised beat table.
  ///
  /// `pause` is the strongest signal in the loop: it drops to 0.5, so a
  /// screenshot taken during it is unmistakably calmer than one taken during
  /// `strike`. That is what makes the loop observable rather than merely
  /// asserted — the same trick `PetFocusActivitySpec` uses for `microIdle`.
  static const Map<PetCraftActivity, PetCraftActivitySpec> table = {
    PetCraftActivity.raise: PetCraftActivitySpec(
      amplitudeScale: 1.08,
      dyOffset: -1.4,
      headDegrees: -1.1,
    ),
    PetCraftActivity.strike: PetCraftActivitySpec(
      amplitudeScale: 1.12,
      dyOffset: 1.0,
      headDegrees: 1.5,
    ),
    PetCraftActivity.pause: PetCraftActivitySpec(
      amplitudeScale: 0.50,
    ),
    PetCraftActivity.inspect: PetCraftActivitySpec(
      amplitudeScale: 0.86,
      dyOffset: -0.5,
      headDegrees: 2.4,
    ),
  };

  static PetCraftActivitySpec of(PetCraftActivity activity) => table[activity]!;
}

/// The progress stage a craft job is in.
///
/// 11G requires the loop to bind to 「craftProgress 阶段」 without naming any
/// stages, so the three boundaries below are a **temporary default mapping** —
/// the same status the focus long-arc phases carry (see
/// `MOCHI_GROWTH_STAGE0_AUDIT.md` §D8). They are centralised here so a future
/// design decision changes one table rather than the renderer.
enum PetCraftStage {
  /// Just started: mostly getting set up, little actual striking.
  early,

  /// The bulk of the job: striking, broken by pauses.
  mid,

  /// Nearly done: Mochi starts checking the work.
  late,
}

/// Resolves [PetCraftStage] from the real `craftProgress` binding.
abstract final class PetCraftStageResolver {
  const PetCraftStageResolver._();

  /// Where [PetCraftStage.mid] begins. **Temporary default mapping.**
  static const double midFrom = 0.25;

  /// Where [PetCraftStage.late] begins. **Temporary default mapping.**
  static const double lateFrom = 0.75;

  /// Resolves the stage from a normalised progress value.
  ///
  /// Total and defensive, because this runs on every frame of a live job:
  ///
  /// * `null` (no job running) and `NaN` both resolve to [PetCraftStage.early],
  ///   and the *caller* is responsible for treating "no job" as inactive rather
  ///   than as "at the very beginning" — see
  ///   [PetCraftActivityController.isActive].
  /// * Out-of-range values clamp, so a rounding error at either end of a job
  ///   cannot produce a fourth stage.
  static PetCraftStage resolve(double? progress) {
    if (progress == null || !progress.isFinite) return PetCraftStage.early;
    final clamped = progress.clamp(0.0, 1.0);
    if (clamped < midFrom) return PetCraftStage.early;
    if (clamped < lateFrom) return PetCraftStage.mid;
    return PetCraftStage.late;
  }
}

/// One beat of the craft cycle: which activity, and how far through it we are.
class PetCraftBeat {
  final PetCraftActivity activity;

  /// Progress within this beat, `0.0 … 1.0`. Used to spread a beat's
  /// out-and-back motion across its own window instead of snapping at the
  /// boundary.
  final double localProgress;

  const PetCraftBeat({
    required this.activity,
    required this.localProgress,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetCraftBeat &&
          runtimeType == other.runtimeType &&
          activity == other.activity &&
          localProgress == other.localProgress;

  @override
  int get hashCode => Object.hash(activity, localProgress);

  @override
  String toString() =>
      'PetCraftBeat(${activity.name} @ ${localProgress.toStringAsFixed(2)})';
}

/// A beat window inside the normalised craft cycle.
///
/// Public so tests can assert that each stage's windows tile `[0, 1]` with no
/// gaps and no overlaps — the property that makes [PetCraftActivitySchedule]
/// total.
class PetCraftBeatWindow {
  final double start;
  final double end;
  final PetCraftActivity activity;

  const PetCraftBeatWindow(this.start, this.end, this.activity);
}

/// Pure schedule: cycle position + stage → the beat Mochi is performing.
///
/// The stage changes the *mix and dwell* of the beats, which is how 11G's
/// 「与 craftProgress 阶段绑定」 is realised without introducing a second
/// amplitude system:
///
/// * **EARLY** — Mochi is setting up. `raise` dominates and `inspect` never
///   appears, because there is nothing to inspect yet.
/// * **MID** — the working stretch. `strike` dominates, broken by a short
///   `pause`. This is the busiest of the three.
/// * **LATE** — approaching completion. An `inspect` beat appears, so the job
///   reads as *finishing* rather than as having stopped.
abstract final class PetCraftActivitySchedule {
  const PetCraftActivitySchedule._();

  /// How long the cycle is, in seconds, as a range.
  ///
  /// 11G says **3–5 秒循环**. The renderer's craft beat clock is set inside this
  /// band (`PetMotionSpec.craftCycle`, 3800 ms). Recorded here so a future
  /// change to that duration has an obvious bound to stay inside — the same
  /// guard `PetFocusActivitySchedule` keeps for 11F.
  static const double minCycleSeconds = 3.0;
  static const double maxCycleSeconds = 5.0;

  static const List<PetCraftBeatWindow> _earlyBeats = <PetCraftBeatWindow>[
    PetCraftBeatWindow(0.00, 0.30, PetCraftActivity.raise),
    PetCraftBeatWindow(0.30, 0.62, PetCraftActivity.strike),
    PetCraftBeatWindow(0.62, 0.74, PetCraftActivity.pause),
    PetCraftBeatWindow(0.74, 1.00, PetCraftActivity.raise),
  ];

  static const List<PetCraftBeatWindow> _midBeats = <PetCraftBeatWindow>[
    PetCraftBeatWindow(0.00, 0.18, PetCraftActivity.raise),
    PetCraftBeatWindow(0.18, 0.52, PetCraftActivity.strike),
    PetCraftBeatWindow(0.52, 0.66, PetCraftActivity.pause),
    PetCraftBeatWindow(0.66, 0.88, PetCraftActivity.strike),
    PetCraftBeatWindow(0.88, 1.00, PetCraftActivity.raise),
  ];

  static const List<PetCraftBeatWindow> _lateBeats = <PetCraftBeatWindow>[
    PetCraftBeatWindow(0.00, 0.14, PetCraftActivity.raise),
    PetCraftBeatWindow(0.14, 0.44, PetCraftActivity.strike),
    PetCraftBeatWindow(0.44, 0.56, PetCraftActivity.pause),
    PetCraftBeatWindow(0.56, 0.80, PetCraftActivity.inspect),
    PetCraftBeatWindow(0.80, 1.00, PetCraftActivity.strike),
  ];

  /// The beat windows for [stage]. Total — every stage has a schedule, and each
  /// schedule covers `[0, 1]` with no gaps, which `pet_craft_activity_test.dart`
  /// asserts.
  static List<PetCraftBeatWindow> windowsFor(PetCraftStage stage) {
    switch (stage) {
      case PetCraftStage.early:
        return _earlyBeats;
      case PetCraftStage.mid:
        return _midBeats;
      case PetCraftStage.late:
        return _lateBeats;
    }
  }

  /// Resolves the beat at [cyclePosition] (`0.0 … 1.0`) for [stage].
  ///
  /// Total and defensive: a `null`/`NaN`/out-of-range position clamps into the
  /// cycle rather than throwing, because this runs on every frame of a live job
  /// and a thrown frame is a dropped frame.
  static PetCraftBeat beatAt(double cyclePosition, PetCraftStage stage) {
    final raw = (cyclePosition.isFinite) ? cyclePosition : 0.0;
    final position = raw.clamp(0.0, 1.0);
    final windows = windowsFor(stage);

    for (final window in windows) {
      // The final window is closed at the top so position == 1.0 has a home.
      final isLast = identical(window, windows.last);
      final inside = position >= window.start &&
          (isLast ? position <= window.end : position < window.end);
      if (inside) {
        final span = window.end - window.start;
        final local = span <= 0 ? 0.0 : (position - window.start) / span;
        return PetCraftBeat(
          activity: window.activity,
          localProgress: local.clamp(0.0, 1.0),
        );
      }
    }

    // Unreachable while the windows tile [0, 1]; kept total anyway.
    return const PetCraftBeat(
      activity: PetCraftActivity.strike,
      localProgress: 0.0,
    );
  }
}

/// Presentation-only owner of "what is Mochi doing in the workshop right now".
///
/// ## Why this is a plain class, not a `ChangeNotifier`
///
/// Identical reasoning to `PetFocusActivityController`: the renderer drives it
/// from inside its own build pass (the beat clock is already in the renderer's
/// `Listenable.merge`), so a notifier would fire `notifyListeners()` during a
/// build. This holds state and is *read* by the renderer. It owns no timers and
/// opens no streams; [dispose] exists to make a stale controller inert rather
/// than to release a resource.
///
/// ## It cannot touch business state
///
/// The only input is a read of `craftProgress`. Nothing is written back. There
/// is no path from here to a craft job, an ingredient, an item, XP or a record.
class PetCraftActivityController {
  PetCraftStage? _stage;
  PetCraftActivity _activity = PetCraftActivity.raise;
  double _localProgress = 0.0;
  bool _isDisposed = false;

  /// The stage in force, or `null` when no craft job is running.
  PetCraftStage? get stage => _stage;

  /// The beat currently being performed.
  PetCraftActivity get activity => _activity;

  /// Progress within the current beat, `0.0 … 1.0`.
  double get localProgress => _localProgress;

  /// Whether a craft job is under way, i.e. whether the beat layer applies.
  ///
  /// This is what keeps "no job" distinct from "a job at progress 0": the
  /// resolver maps both to [PetCraftStage.early], so the distinction has to live
  /// here or a stopped job would keep presenting beats.
  bool get isActive => _stage != null;

  bool get isDisposed => _isDisposed;

  /// Updates the job context from the real `craftProgress` binding.
  ///
  /// Call this when progress changes, not every frame — the renderer pushes the
  /// frame-level detail through [updateCycle]. `null` means no job is running.
  void setContext({double? progress}) {
    if (_isDisposed) return;
    final nextStage =
        progress == null ? null : PetCraftStageResolver.resolve(progress);
    final changed = _stage != nextStage;
    _stage = nextStage;
    if (changed && nextStage == null) {
      // No job: fall back to the neutral beat rather than leaving the last job's
      // beat frozen on screen.
      _activity = PetCraftActivity.raise;
      _localProgress = 0.0;
    }
  }

  /// Advances the activity from the beat clock's normalised position.
  ///
  /// Safe to call every frame. When no job is active the activity is held
  /// neutral, so a stale controller can never present work beats.
  void updateCycle(double cyclePosition) {
    if (_isDisposed) return;
    final stage = _stage;
    if (stage == null) {
      _activity = PetCraftActivity.raise;
      _localProgress = 0.0;
      return;
    }
    final beat = PetCraftActivitySchedule.beatAt(cyclePosition, stage);
    _activity = beat.activity;
    _localProgress = beat.localProgress;
  }

  /// The rendering parameters for the current beat.
  ///
  /// Returns a neutral spec when no job is active, so callers can apply it
  /// unconditionally without a null check.
  PetCraftActivitySpec get visual {
    if (_stage == null) return _neutralSpec;
    return PetCraftActivitySpec.of(_activity);
  }

  static const PetCraftActivitySpec _neutralSpec = PetCraftActivitySpec(
    amplitudeScale: 1.0,
  );

  void dispose() {
    _isDisposed = true;
  }
}
