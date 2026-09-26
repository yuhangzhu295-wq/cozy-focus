import '../../domain/growth/growth_stage.dart';
import '../animations/pet_motion_spec.dart';

/// The additive idle behaviours Mochi can perform, one per flourish cycle.
///
/// These sit *on top of* the fixed micro-motion layer (呼吸 / 轻摆 / 眨眼 / 耳朵 /
/// 尾巴), which is present at every stage and is never switched off. A flourish
/// is the extra, occasional thing — the difference between "a pet that is
/// breathing" and "a pet that is doing something".
enum PetIdleFlourishKind {
  /// Turns to look at something. Head leads, ears lead the head.
  lookAround,

  /// Ears prick up without the head moving. Reads as *listening*.
  earPerk,

  /// A quick tail swing with a small head follow. Reads as *happy to see you*.
  tailSweep,

  /// A small upward settle — body lifts a little, then lets go. Reads as a
  /// contented sigh rather than as an action.
  settle,
}

/// Stable identifiers, for diagnostics and test failure messages.
extension PetIdleFlourishKindLabel on PetIdleFlourishKind {
  String get label => switch (this) {
        PetIdleFlourishKind.lookAround => 'LOOK_AROUND',
        PetIdleFlourishKind.earPerk => 'EAR_PERK',
        PetIdleFlourishKind.tailSweep => 'TAIL_SWEEP',
        PetIdleFlourishKind.settle => 'SETTLE',
      };
}

/// One flourish, described purely as channel amplitudes.
///
/// Every value is a *peak* reached at the middle of the flourish window; the
/// window itself supplies the `0 -> 1 -> 0` envelope, so a spec only has to say
/// how far the motion goes, never when.
///
/// ## Why this is a table rather than a boolean
///
/// The idle layer used to be gated by a single boolean and, when it was on,
/// always performed the *same* behaviour: a slow look-around. A `growing` Mochi
/// and a `blooming` Mochi therefore did the identical thing — only at different
/// frequencies. Frequency is cadence, and cadence alone cannot carry "Mochi
/// grew up": two stages that differ only in how often they do the same thing
/// still read as the same animal.
///
/// Each stage now gets a **pool** of behaviours instead. Pools differ in size
/// *and* in play order, so the first thing a Mochi does when it looks up is
/// stage-specific: a seedling looks, a growing Mochi wags first, a blooming one
/// settles first.
///
/// ## Presentation-only
///
/// Nothing here can reach XP, coins, happiness, a focus session, a craft job or
/// any stored value. These are visual amplitudes and nothing else.
class PetIdleFlourishSpec {
  final PetIdleFlourishKind kind;

  /// Peak head yaw, in degrees, at the middle of the window.
  final double headYawDegrees;

  /// Peak ear lead, in degrees.
  ///
  /// The ears lead the head through a look, which is what makes it read as
  /// *noticing* something rather than as slow drift. A spec may move the ears
  /// without the head ([PetIdleFlourishKind.earPerk]) — that is a different
  /// behaviour, not a weaker version of a look.
  final double earLeadDegrees;

  /// Peak tail swing, in degrees.
  final double tailWagDegrees;

  /// Peak upward body offset, in logical pixels.
  final double bodyLiftPx;

  const PetIdleFlourishSpec({
    required this.kind,
    this.headYawDegrees = 0.0,
    this.earLeadDegrees = 0.0,
    this.tailWagDegrees = 0.0,
    this.bodyLiftPx = 0.0,
  });

  /// Whether this flourish moves anything at all.
  ///
  /// A spec that moves nothing would be indistinguishable from the layer being
  /// switched off, so the table never contains one — `pet_idle_behavior_test`
  /// asserts this for every row and every pool member.
  bool get isVisible =>
      headYawDegrees != 0.0 ||
      earLeadDegrees != 0.0 ||
      tailWagDegrees != 0.0 ||
      bodyLiftPx != 0.0;
}

/// The four behaviours, named so the pool table reads as behaviour rather than
/// as a wall of numbers.
abstract final class PetIdleFlourishes {
  const PetIdleFlourishes._();

  /// The original, pre-pool flourish. Its amplitudes are still sourced from
  /// [PetMotionSpec] so the retuned constants and this table cannot disagree.
  static const PetIdleFlourishSpec lookAround = PetIdleFlourishSpec(
    kind: PetIdleFlourishKind.lookAround,
    headYawDegrees: PetMotionSpec.idleFlourishLookDegrees,
    earLeadDegrees: PetMotionSpec.idleFlourishEarLeadDegrees,
  );

  /// Ears only. No head term at all — the point of the behaviour is that the
  /// head stays put.
  static const PetIdleFlourishSpec earPerk = PetIdleFlourishSpec(
    kind: PetIdleFlourishKind.earPerk,
    earLeadDegrees: 2.6,
  );

  /// Tail-led, with a small head follow.
  static const PetIdleFlourishSpec tailSweep = PetIdleFlourishSpec(
    kind: PetIdleFlourishKind.tailSweep,
    headYawDegrees: 1.2,
    earLeadDegrees: 0.5,
    tailWagDegrees: 4.5,
  );

  /// The only flourish that lifts the body. Deliberately the smallest head term
  /// of the four: a settle is felt, not watched.
  static const PetIdleFlourishSpec settle = PetIdleFlourishSpec(
    kind: PetIdleFlourishKind.settle,
    headYawDegrees: 0.9,
    earLeadDegrees: 0.6,
    tailWagDegrees: 1.5,
    bodyLiftPx: 1.4,
  );
}

/// One row of the idle-behaviour table: what a given idle personality can do.
///
/// ## Growth is additive here too
///
/// [pool] only ever gains members as the stage advances — `seedling ⊂ growing ⊂
/// blooming`. A stage can never lose a behaviour it has already learned, which
/// is the same rule the fixed micro layer follows ([GrowthStageSpec] documents
/// it as "growth is additive, never subtractive").
///
/// The pools are also **ordered newest-first**, so a stage's new behaviour is
/// the one you see first rather than the one you wait longest for. That is what
/// makes the stage difference visible within a single cycle instead of only
/// across a full rotation.
///
/// [GrowthIdlePersonality.gentle] has an **empty** pool on purpose: it is the
/// stage that has not developed the layer yet, and `hasIdleFlourish: false` is
/// the same statement in boolean form. `pet_idle_behavior_test` pins the two
/// together so they can never drift apart.
class PetIdleBehaviorSpec {
  final GrowthIdlePersonality personality;

  /// The behaviours this personality can play, in play order. Never contains a
  /// duplicate kind, and every member is visible.
  final List<PetIdleFlourishSpec> pool;

  const PetIdleBehaviorSpec({required this.personality, required this.pool});

  /// The centralised table. One row per [GrowthIdlePersonality], ordered as the
  /// stages advance, so retuning idle behaviour is a one-file change.
  static const List<PetIdleBehaviorSpec> table = <PetIdleBehaviorSpec>[
    PetIdleBehaviorSpec(
      personality: GrowthIdlePersonality.gentle,
      pool: <PetIdleFlourishSpec>[],
    ),
    PetIdleBehaviorSpec(
      personality: GrowthIdlePersonality.steady,
      pool: <PetIdleFlourishSpec>[
        PetIdleFlourishes.lookAround,
        PetIdleFlourishes.earPerk,
      ],
    ),
    PetIdleBehaviorSpec(
      personality: GrowthIdlePersonality.lively,
      pool: <PetIdleFlourishSpec>[
        PetIdleFlourishes.tailSweep,
        PetIdleFlourishes.lookAround,
        PetIdleFlourishes.earPerk,
      ],
    ),
    PetIdleBehaviorSpec(
      personality: GrowthIdlePersonality.content,
      pool: <PetIdleFlourishSpec>[
        PetIdleFlourishes.settle,
        PetIdleFlourishes.lookAround,
        PetIdleFlourishes.earPerk,
        PetIdleFlourishes.tailSweep,
      ],
    ),
  ];

  /// The row for [personality]. Total — every enum value has exactly one row.
  static PetIdleBehaviorSpec of(GrowthIdlePersonality personality) =>
      table.firstWhere((spec) => spec.personality == personality);
}
