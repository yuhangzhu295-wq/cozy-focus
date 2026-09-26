/// Per-state interaction behaviour: what Mochi does when you touch it.
///
/// ## Status: TEMPORARY DEFAULT MAPPING (documented, not silently invented)
///
/// V4.1's motion package names a single `11J_Interact.png` channel and gives no
/// per-state interaction variants — the same gap `MOCHI_GROWTH_STAGE0_AUDIT.md`
/// §A4/§B3 records for the rest of the companion layer. The behaviours, the
/// amplitudes and the long-press ("轻抚") response below are therefore a
/// **chosen default**, centralised in [table] so retuning a state is a
/// one-row edit.
///
/// ## Why interaction stays an overlay, and never becomes a state
///
/// `PetVisualState.interact` exists in the enum but is **never assigned** — it
/// appears only in switch-exhaustiveness lists. That is deliberate, and this
/// stage keeps it that way.
///
/// The brief's critical constraint is "a short interaction must return to the
/// correct previous base state (Focus → tap → FocusInteract → Focus, not Idle)".
/// Modelling that as a real state means saving the previous state and restoring
/// it, and *every* missed restore is exactly the bug the constraint warns about.
///
/// So the base state is never touched. An interaction is a **time-bounded
/// overlay** whose amplitude comes from the current base state's spec, read
/// fresh on every frame. The base state therefore cannot be lost: there is
/// nothing to restore, and "Focus → tap → Focus" holds by construction rather
/// than by remembering.
///
/// ## The overlay takes only the channels it needs
///
/// [PetInteractionSpec.ownedChannels] is what makes "Interact outranks
/// Craft/Focus/Pause/Sleep" concrete. During a focus glance the overlay takes
/// the head, the ears and the eyes — and leaves the body to the focus sway, so a
/// glance reads as *a glance from a working Mochi* instead of replacing the work
/// pose. Idle, having no commitment to protect, hands over every channel.
library;

import '../../domain/models/enums.dart';

/// How an interaction reads, per base state.
///
/// Carried for diagnostics and tests; the amplitudes are what the renderer
/// actually consumes.
enum PetInteractionKind {
  /// Idle: a cheerful full-body response.
  friendly,

  /// Focus: a brief glance, then straight back to work.
  glance,

  /// Pause: a soft settle.
  soothe,

  /// Craft: a small reaction, then back to the job.
  react,

  /// Sleep: barely enough to show Mochi noticed.
  drowsy,
}

/// A motion channel an interaction may take over.
///
/// The set a spec owns is the whole priority mechanism: the overlay wins on the
/// channels it takes and yields the rest to the base state.
enum PetMotionChannel {
  /// Overall size pulse.
  scale,

  /// Vertical bob.
  dy,

  /// Rotation about the bottom centre.
  bodyTilt,

  /// Ear rotation.
  ear,

  /// Tail rotation.
  tail,

  /// Eye openness.
  eyes,

  /// Head rotation.
  head,
}

/// One base state's interaction amplitudes.
///
/// Every channel is expressed as a peak the unit shape is multiplied by, so the
/// renderer keeps a single set of tweens and only the numbers change per state.
/// See [PetInteractionSpec.table] for the values.
class PetInteractionSpec {
  /// How this interaction reads.
  final PetInteractionKind kind;

  /// How long the tap response runs.
  final Duration tapDuration;

  /// Peak of the size pulse. `1.0` means "no pulse".
  final double tapScalePeak;

  /// Peak of the vertical bob, in logical pixels.
  final double tapDyPeak;

  /// Peak body tilt, in degrees. `0` keeps the body still — the knob that makes
  /// a focus glance a glance instead of a wobble.
  final double tapBodyTiltDegrees;

  /// Peak ear tilt, in degrees.
  final double tapEarTiltDegrees;

  /// Peak tail swing, in degrees.
  final double tapTailTiltDegrees;

  /// The floor the eyes close to during the reaction, as an eye scale.
  /// `1.0` means "eyes stay open".
  final double tapEyeSquintMin;

  /// Peak head tilt, in degrees. The glance channel.
  final double tapHeadTiltDegrees;

  /// How long the long-press stroke runs.
  final Duration strokeDuration;

  /// How far the eyes soften during a stroke, as an eye scale. `1.0` is open,
  /// `0.0` fully closed.
  final double strokeEyeClose;

  /// Head tilt during a stroke, in degrees.
  final double strokeHeadTiltDegrees;

  /// Ear droop during a stroke, in degrees. Negative droops.
  final double strokeEarDroopDegrees;

  /// Whether a stroke shows the heart feedback.
  ///
  /// Deliberately false where the user is in the middle of something: a heart
  /// popping up over a running focus session or craft job is a distraction, and
  /// the whole point of the per-state split is that Mochi does not pull
  /// attention away from work it is helping with.
  final bool strokeShowsHeart;

  /// The channels the interaction takes over, leaving the rest to the base
  /// state.
  final Set<PetMotionChannel> ownedChannels;

  const PetInteractionSpec({
    required this.kind,
    required this.tapDuration,
    required this.tapScalePeak,
    required this.tapDyPeak,
    required this.tapBodyTiltDegrees,
    required this.tapEarTiltDegrees,
    required this.tapTailTiltDegrees,
    required this.tapEyeSquintMin,
    required this.tapHeadTiltDegrees,
    required this.strokeDuration,
    required this.strokeEyeClose,
    required this.strokeHeadTiltDegrees,
    required this.strokeEarDroopDegrees,
    required this.strokeShowsHeart,
    required this.ownedChannels,
  });

  /// The base states an interaction is meaningful in, and their amplitudes.
  ///
  /// [PetVisualState.celebrate] and [PetVisualState.greeting] are absent on
  /// purpose — see [PetInteractionPriority.canInteractDuring].
  /// [PetVisualState.interact] is absent because it is not a state at all.
  static const Map<PetVisualState, PetInteractionSpec> table = {
    PetVisualState.idle: PetInteractionSpec(
      kind: PetInteractionKind.friendly,
      tapDuration: Duration(milliseconds: 750),
      tapScalePeak: 1.06,
      tapDyPeak: -8.0,
      tapBodyTiltDegrees: 4.0,
      tapEarTiltDegrees: 6.0,
      tapTailTiltDegrees: 5.0,
      tapEyeSquintMin: 0.55,
      tapHeadTiltDegrees: 0.0,
      strokeDuration: Duration(milliseconds: 900),
      strokeEyeClose: 0.12,
      strokeHeadTiltDegrees: 5.0,
      strokeEarDroopDegrees: 8.0,
      strokeShowsHeart: true,
      ownedChannels: {
        PetMotionChannel.scale,
        PetMotionChannel.dy,
        PetMotionChannel.bodyTilt,
        PetMotionChannel.ear,
        PetMotionChannel.tail,
        PetMotionChannel.eyes,
      },
    ),
    // A glance: the head turns a little and the eyes narrow, the body does not
    // move. Short, because the user is working and this is not an invitation.
    PetVisualState.focus: PetInteractionSpec(
      kind: PetInteractionKind.glance,
      tapDuration: Duration(milliseconds: 420),
      tapScalePeak: 1.0,
      tapDyPeak: 0.0,
      tapBodyTiltDegrees: 0.0,
      tapEarTiltDegrees: 4.0,
      tapTailTiltDegrees: 0.0,
      tapEyeSquintMin: 0.82,
      tapHeadTiltDegrees: 3.5,
      strokeDuration: Duration(milliseconds: 700),
      strokeEyeClose: 0.45,
      strokeHeadTiltDegrees: 3.0,
      strokeEarDroopDegrees: 4.0,
      strokeShowsHeart: false,
      ownedChannels: {
        PetMotionChannel.head,
        PetMotionChannel.eyes,
        PetMotionChannel.ear,
      },
    ),
    // Soothing: the eyes soften and the ears and tail settle. No bounce — the
    // user just stopped, and being bounced at is the wrong register.
    PetVisualState.pause: PetInteractionSpec(
      kind: PetInteractionKind.soothe,
      tapDuration: Duration(milliseconds: 700),
      tapScalePeak: 1.0,
      tapDyPeak: 0.0,
      tapBodyTiltDegrees: 0.0,
      tapEarTiltDegrees: -4.0,
      tapTailTiltDegrees: 6.0,
      tapEyeSquintMin: 0.60,
      tapHeadTiltDegrees: -2.0,
      strokeDuration: Duration(milliseconds: 1000),
      strokeEyeClose: 0.20,
      strokeHeadTiltDegrees: -4.0,
      strokeEarDroopDegrees: -6.0,
      strokeShowsHeart: true,
      ownedChannels: {
        PetMotionChannel.eyes,
        PetMotionChannel.ear,
        PetMotionChannel.tail,
        PetMotionChannel.head,
      },
    ),
    // A reaction: a small bob and a flick, no tilt and no size pulse, so the
    // craft pose underneath survives untouched.
    PetVisualState.craft: PetInteractionSpec(
      kind: PetInteractionKind.react,
      tapDuration: Duration(milliseconds: 450),
      tapScalePeak: 1.0,
      tapDyPeak: -2.0,
      tapBodyTiltDegrees: 0.0,
      tapEarTiltDegrees: 5.0,
      tapTailTiltDegrees: 0.0,
      tapEyeSquintMin: 0.78,
      tapHeadTiltDegrees: 1.5,
      strokeDuration: Duration(milliseconds: 700),
      strokeEyeClose: 0.50,
      strokeHeadTiltDegrees: 2.0,
      strokeEarDroopDegrees: 3.0,
      strokeShowsHeart: false,
      ownedChannels: {
        PetMotionChannel.dy,
        PetMotionChannel.ear,
        PetMotionChannel.eyes,
        PetMotionChannel.head,
      },
    ),
    // Drowsy: an ear flick and a slower eye response. No movement, no heart —
    // the user is asleep and Mochi is not going to wake them for a poke.
    PetVisualState.sleep: PetInteractionSpec(
      kind: PetInteractionKind.drowsy,
      tapDuration: Duration(milliseconds: 500),
      tapScalePeak: 1.0,
      tapDyPeak: 0.0,
      tapBodyTiltDegrees: 0.0,
      tapEarTiltDegrees: 2.5,
      tapTailTiltDegrees: 0.0,
      tapEyeSquintMin: 0.92,
      tapHeadTiltDegrees: 0.0,
      strokeDuration: Duration(milliseconds: 800),
      strokeEyeClose: 0.08,
      strokeHeadTiltDegrees: 2.0,
      strokeEarDroopDegrees: 2.0,
      strokeShowsHeart: false,
      ownedChannels: {
        PetMotionChannel.ear,
        PetMotionChannel.eyes,
      },
    ),
  };

  /// The spec for [state], or `null` when an interaction is not allowed there.
  ///
  /// Returning `null` rather than a neutral spec is what stops a caller from
  /// silently animating a state the brief says must not react.
  static PetInteractionSpec? forState(PetVisualState state) => table[state];

  /// The states in which an interaction is meaningful.
  static Set<PetVisualState> get interactableStates => table.keys.toSet();
}

/// The presentation priority order, and the rule built on it.
///
/// The brief's order is **Celebrate > Interact > Craft/Focus/Pause/Sleep >
/// Idle**. Modelled as four *tiers* rather than a total order, because the brief
/// groups craft/focus/pause/sleep as one level and nothing in the product
/// distinguishes them from each other — claiming "craft outranks focus" would be
/// inventing a rule.
abstract final class PetInteractionPriority {
  const PetInteractionPriority._();

  /// Which tier a state belongs to.
  ///
  /// [PetVisualState.greeting] sits with celebrate: it is the same kind of thing
  /// (a one-shot trigger that has already been earned), and the brief's list
  /// simply does not mention it. Treating it as preemptible would let a poke cut
  /// a greeting short.
  static PetPresentationTier tierOf(PetVisualState state) => switch (state) {
        PetVisualState.celebrate ||
        PetVisualState.greeting =>
          PetPresentationTier.celebration,
        PetVisualState.interact => PetPresentationTier.interaction,
        PetVisualState.craft ||
        PetVisualState.focus ||
        PetVisualState.pause ||
        PetVisualState.sleep =>
          PetPresentationTier.commitment,
        PetVisualState.idle => PetPresentationTier.idle,
      };

  /// Whether an interaction may start while [base] is the active state.
  ///
  /// True everywhere except during a one-shot celebration, which outranks it.
  /// Note that this is *only* the priority rule: whether a spec exists for
  /// [base] is a separate guard, and both must pass. `interact` passes here but
  /// has no spec, so re-entrancy is refused without a special case.
  static bool canInteractDuring(PetVisualState base) =>
      tierOf(base) != PetPresentationTier.celebration;
}

/// The four priority tiers, highest first.
enum PetPresentationTier {
  /// **Celebrate** (and greeting) — a one-shot trigger that has been earned.
  /// Nothing may preempt it.
  celebration,

  /// **Interact** — a direct response to the user touching Mochi.
  interaction,

  /// **Craft / Focus / Pause / Sleep** — a running commitment the user started.
  /// Treated as one level, as the brief groups them.
  commitment,

  /// **Idle** — nothing running.
  idle,
}
