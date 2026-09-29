import 'dart:math' as math;

import 'runtime/companion_pose.dart';

/// The prop a pose carries.
///
/// ## Why props rather than bigger numbers
///
/// `docs/02_Pose_Asset_First_制作方案.md` requires the work poses to be different
/// *silhouettes*, and the reconstruction brief forbids passing off a 1px / 0.5°
/// difference as a new macro action. Mochi's approved art is a single sitting
/// illustration, so posture alone cannot separate "reading" from "writing" — the
/// head can only pitch so far before it stops reading as Mochi.
///
/// A prop changes the outline. An open book, a notebook, and a thought bubble are
/// three shapes a viewer tells apart instantly at avatar size, which is what the
/// spec actually asks for.
///
/// These are **fallback** props, drawn in code because no production pose pack
/// exists yet — see `docs/08_Runtime_Asset_GAP.md`. They are reported as an asset
/// gap, never as finished art.
enum MochiPosePropKind {
  none,
  openBook,
  notebook,
  thoughtBubbles,
  tools,
  sparkle,
  confetti,
  restZ,
  tapSpark,
  heart,
  wave,
}

/// The posture a pose applies to the approved layered art.
///
/// Every value is a *channel* the existing renderer already owns
/// (`headRotation`, `earRotation`, `eyeScaleY`, `sproutRotation`, `headDy`), so a
/// pose adds no new rendering machinery — it retargets channels that already
/// exist and adds a prop.
class MochiPoseSpec {
  /// Head-group pitch/roll in radians. Negative reads as looking down.
  final double headRotation;

  /// Ear swing in radians, applied mirrored by the renderer.
  final double earRotation;

  /// Eye squash, `1.0` = neutral, `< 1` reads as narrowed / focused.
  final double eyeScaleY;

  /// Sprout follow-through in radians.
  final double sproutRotation;

  /// Head-group vertical offset in logical pixels at [referenceSize].
  final double headDy;

  /// Extra body offset, applied by the pose layer rather than the state frame.
  final double bodyDy;

  /// The prop this pose carries.
  final MochiPosePropKind prop;

  const MochiPoseSpec({
    this.headRotation = 0.0,
    this.earRotation = 0.0,
    this.eyeScaleY = 1.0,
    this.sproutRotation = 0.0,
    this.headDy = 0.0,
    this.bodyDy = 0.0,
    this.prop = MochiPosePropKind.none,
  });

  /// The size the absolute pixel offsets were tuned at.
  ///
  /// Offsets are scaled by `size / referenceSize` so a 92pt room avatar and a
  /// 180pt focus avatar carry the same *proportional* pose.
  static const double referenceSize = 140;

  /// A copy with [dy] scaled for [size].
  MochiPoseSpec scaledTo(double size) {
    if (size == referenceSize) return this;
    final k = size / referenceSize;
    return MochiPoseSpec(
      headRotation: headRotation,
      earRotation: earRotation,
      eyeScaleY: eyeScaleY,
      sproutRotation: sproutRotation,
      headDy: headDy * k,
      bodyDy: bodyDy * k,
      prop: prop,
    );
  }

  @override
  String toString() => 'MochiPoseSpec(head=${headRotation.toStringAsFixed(3)} '
      'ear=${earRotation.toStringAsFixed(3)} eye=${eyeScaleY.toStringAsFixed(2)} '
      'prop=${prop.name})';
}

/// The centralised pose table.
///
/// One row per [CompanionPose]. Retuning a pose is a one-file change, and the
/// table is total — `mochi_pose_spec_test` asserts every pose has a row, so a new
/// pose cannot be added without deciding what it looks like.
abstract final class MochiPoseSpecs {
  const MochiPoseSpecs._();

  static const Map<CompanionPose, MochiPoseSpec> table = {
    // --- Home / idle -------------------------------------------------------
    CompanionPose.idle: MochiPoseSpec(),

    // --- Focus: three visibly different work silhouettes --------------------
    //
    // Each of these reads differently at a glance: the head pitches in opposite
    // directions between think and write, the ears move independently of the
    // head, and the prop changes the outline entirely.
    CompanionPose.prepare: MochiPoseSpec(
      headRotation: -0.045,
      earRotation: 0.085,
      eyeScaleY: 1.04,
      sproutRotation: 0.05,
      bodyDy: -1.0,
    ),
    CompanionPose.focusRead: MochiPoseSpec(
      headRotation: -0.135,
      earRotation: 0.135,
      eyeScaleY: 0.68,
      sproutRotation: -0.06,
      headDy: 1.6,
      prop: MochiPosePropKind.openBook,
    ),
    CompanionPose.focusWrite: MochiPoseSpec(
      headRotation: -0.185,
      earRotation: -0.075,
      eyeScaleY: 0.80,
      sproutRotation: -0.11,
      headDy: 2.6,
      bodyDy: 0.8,
      prop: MochiPosePropKind.notebook,
    ),
    CompanionPose.focusThink: MochiPoseSpec(
      headRotation: 0.095,
      earRotation: 0.215,
      eyeScaleY: 1.14,
      sproutRotation: 0.09,
      headDy: -1.2,
      prop: MochiPosePropKind.thoughtBubbles,
    ),
    CompanionPose.microRest: MochiPoseSpec(
      headRotation: -0.055,
      earRotation: -0.055,
      eyeScaleY: 0.40,
      sproutRotation: -0.03,
      headDy: 1.0,
    ),
    CompanionPose.glance: MochiPoseSpec(
      headRotation: 0.055,
      earRotation: 0.175,
      eyeScaleY: 1.06,
      headDy: -0.8,
    ),
    CompanionPose.finish: MochiPoseSpec(
      headRotation: 0.035,
      earRotation: 0.12,
      eyeScaleY: 1.0,
      sproutRotation: 0.07,
      prop: MochiPosePropKind.sparkle,
    ),

    // --- Craft -------------------------------------------------------------
    CompanionPose.craftWork: MochiPoseSpec(
      headRotation: -0.15,
      earRotation: 0.10,
      eyeScaleY: 0.74,
      sproutRotation: -0.09,
      headDy: 2.0,
      prop: MochiPosePropKind.tools,
    ),

    // --- Room --------------------------------------------------------------
    CompanionPose.roomSit: MochiPoseSpec(earRotation: 0.06),
    CompanionPose.roomRelax: MochiPoseSpec(
      headRotation: -0.03,
      earRotation: -0.04,
      eyeScaleY: 0.55,
    ),
    CompanionPose.roomRead: MochiPoseSpec(
      headRotation: -0.13,
      earRotation: 0.125,
      eyeScaleY: 0.70,
      headDy: 1.5,
      prop: MochiPosePropKind.openBook,
    ),
    CompanionPose.roomSleep: MochiPoseSpec(
      headRotation: -0.09,
      earRotation: -0.16,
      eyeScaleY: 0.16,
      headDy: 2.2,
      bodyDy: 1.4,
      prop: MochiPosePropKind.restZ,
    ),
    CompanionPose.roomWork: MochiPoseSpec(
      headRotation: -0.17,
      earRotation: -0.05,
      eyeScaleY: 0.78,
      headDy: 2.4,
      prop: MochiPosePropKind.notebook,
    ),

    // --- Completion --------------------------------------------------------
    CompanionPose.celebrate: MochiPoseSpec(
      headRotation: 0.075,
      earRotation: 0.26,
      eyeScaleY: 1.10,
      sproutRotation: 0.13,
      headDy: -1.8,
      prop: MochiPosePropKind.confetti,
    ),

    // --- Pause / sleep: both visibly at rest, and differently so ------------
    CompanionPose.rest: MochiPoseSpec(
      headRotation: -0.075,
      earRotation: -0.135,
      eyeScaleY: 0.20,
      sproutRotation: -0.05,
      headDy: 1.8,
      bodyDy: 1.0,
      prop: MochiPosePropKind.restZ,
    ),
    CompanionPose.sleep: MochiPoseSpec(
      headRotation: -0.10,
      earRotation: -0.19,
      eyeScaleY: 0.10,
      sproutRotation: -0.07,
      headDy: 2.4,
      bodyDy: 1.6,
      prop: MochiPosePropKind.restZ,
    ),

    // --- Overlays ----------------------------------------------------------
    CompanionPose.tapReact: MochiPoseSpec(
      headRotation: 0.045,
      earRotation: 0.20,
      eyeScaleY: 1.12,
      headDy: -1.0,
      prop: MochiPosePropKind.tapSpark,
    ),
    CompanionPose.petReact: MochiPoseSpec(
      headRotation: -0.02,
      earRotation: -0.08,
      eyeScaleY: 0.62,
      headDy: 0.8,
      prop: MochiPosePropKind.heart,
    ),
    CompanionPose.greeting: MochiPoseSpec(
      headRotation: 0.06,
      earRotation: 0.22,
      eyeScaleY: 1.08,
      sproutRotation: 0.10,
      headDy: -1.4,
      prop: MochiPosePropKind.wave,
    ),
    CompanionPose.unlockReact: MochiPoseSpec(
      headRotation: 0.07,
      earRotation: 0.24,
      eyeScaleY: 1.12,
      sproutRotation: 0.12,
      headDy: -1.6,
      prop: MochiPosePropKind.sparkle,
    ),
  };

  /// The row for [pose]. Total — every pose has a spec.
  static MochiPoseSpec of(CompanionPose pose) =>
      table[pose] ?? const MochiPoseSpec();

  /// How much of the reduced-motion budget a pose keeps.
  ///
  /// Reduced motion must preserve the semantic pose
  /// (`docs/04_Behavior_Graph_SPEC.md`), so this only damps the *movement*
  /// channels — head pitch, ear swing, sprout sway and the body offset. The eye
  /// squash and the prop are semantic and are kept at full strength, which is why
  /// a reading Mochi still looks like it is reading with motion off.
  static MochiPoseSpec damped(MochiPoseSpec spec) => MochiPoseSpec(
        headRotation: spec.headRotation * 0.35,
        earRotation: spec.earRotation * 0.30,
        eyeScaleY: spec.eyeScaleY,
        sproutRotation: spec.sproutRotation * 0.30,
        headDy: spec.headDy * 0.25,
        bodyDy: spec.bodyDy * 0.25,
        prop: spec.prop,
      );

  /// A tiny helper for the prop painter: degrees to radians.
  static double degrees(double d) => d * math.pi / 180.0;
}
