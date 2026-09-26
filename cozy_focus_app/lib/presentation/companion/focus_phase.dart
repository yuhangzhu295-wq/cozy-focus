/// The long-arc phases of a focus session.
///
/// ## Status: TEMPORARY DEFAULT MAPPING (documented, not silently invented)
///
/// V4.1 specifies the *short arc* in detail —
/// `designs/motion/11F_Focus_Work.png` gives Focus Work a **4–6 秒循环** with
/// keyframes 开始 / 工作 / 微动 / 循环 — but it defines no progression across a
/// whole session. `reference/02_动效架构.md` lists `focusProgress` only as a
/// binding name, with no thresholds. The same is true of every product contract
/// in `outputs/ai_handoff/`; the searches that establish this are recorded in
/// `MOCHI_GROWTH_STAGE0_AUDIT.md` §B3.
///
/// The thresholds below are therefore a **chosen default**, centralised here so
/// retuning them is a one-file change.
///
/// ## Why the phases are normalised
///
/// The input is `focusProgress = elapsed / targetDuration`, not a duration. A
/// 5-minute session and a 50-minute session therefore pass through the same four
/// phases in the same order — nothing here is hard-coded to 25 minutes.
///
/// ## Separation of concerns
///
/// The phase decides *which work beats happen* (the mix and dwell of 开始 / 工作 /
/// 微动 / 循环). It deliberately does **not** decide overall motion amplitude:
/// that is already the `focusProgress` binding (`PetMotionSpec.progressIntensity*`).
/// Keeping one amplitude system with one input avoids two scalars fighting over
/// the same transform.
enum FocusPhase {
  /// Getting ready to work. The brief's STARTING.
  starting,

  /// Low-distraction work loops. The brief's WORKING.
  working,

  /// Calmer and more concentrated. The brief's DEEP_FOCUS.
  deepFocus,

  /// Subtle anticipation of the end. The brief's FINISHING.
  finishing,
}

/// The centralised phase thresholds.
///
/// Bands are contiguous and cover `[0, 1]` with no gaps, which
/// `focus_phase_test.dart` asserts.
abstract final class FocusPhaseSpec {
  const FocusPhaseSpec._();

  /// Progress at or below this is still [FocusPhase.starting].
  static const double startingUntil = 0.05;

  /// Progress at or below this is [FocusPhase.working].
  static const double workingUntil = 0.60;

  /// Progress at or below this is [FocusPhase.deepFocus]. Everything above is
  /// [FocusPhase.finishing].
  static const double deepFocusUntil = 0.92;
}

/// Pure mapping from normalised focus progress to a [FocusPhase].
///
/// No state, no side effects, no I/O — so it can be tested exhaustively and
/// called on every frame.
abstract final class FocusPhaseResolver {
  const FocusPhaseResolver._();

  /// Resolves the phase for [progress], where `progress = elapsed / target`.
  ///
  /// Returns `null` when there is no active session ([progress] is `null`) or
  /// when the session carries no usable target. Values outside `[0, 1]` are
  /// clamped rather than trusted: an over-run session resolves to
  /// [FocusPhase.finishing], not to a fifth state that does not exist.
  static FocusPhase? resolve(double? progress) {
    if (progress == null) return null;
    if (progress.isNaN || progress.isInfinite) return null;
    final p = progress.clamp(0.0, 1.0);
    if (p <= FocusPhaseSpec.startingUntil) return FocusPhase.starting;
    if (p <= FocusPhaseSpec.workingUntil) return FocusPhase.working;
    if (p <= FocusPhaseSpec.deepFocusUntil) return FocusPhase.deepFocus;
    return FocusPhase.finishing;
  }

  /// Whether [progress] denotes a session that is actually under way.
  ///
  /// Used by the activity layer so a session that has not started (or one whose
  /// target is unknown) does not present work beats.
  static bool isActive(double? progress) => resolve(progress) != null;
}

/// The behavioural intent of each phase, in the brief's own words.
///
/// Exposed as an extension rather than baked into the enum so the intent is
/// readable at the call site and testable on its own.
extension FocusPhaseIntent on FocusPhase {
  /// STARTING — "Mochi gets ready to work."
  bool get isPreparing => this == FocusPhase.starting;

  /// FINISHING — "Mochi shows subtle anticipation."
  bool get isAnticipating => this == FocusPhase.finishing;

  /// DEEP_FOCUS — "Mochi becomes calmer and more concentrated."
  bool get isConcentrating => this == FocusPhase.deepFocus;

  /// Human-readable label, for tests and diagnostics.
  String get label => switch (this) {
        FocusPhase.starting => 'STARTING',
        FocusPhase.working => 'WORKING',
        FocusPhase.deepFocus => 'DEEP_FOCUS',
        FocusPhase.finishing => 'FINISHING',
      };
}
