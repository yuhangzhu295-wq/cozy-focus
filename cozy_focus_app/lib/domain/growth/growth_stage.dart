/// Growth stages for Mochi.
///
/// ## Status: TEMPORARY DEFAULT MAPPING (documented, not silently invented)
///
/// Neither V4.1 (`docs/cozy_focus_v4_1/`) nor any existing product contract
/// defines growth stages. The design package names its motion art purely by
/// animation channel (`11A_Idle_Breathe.png` … `11K_Greeting.png`) and contains
/// no baby/child/adult variants; a full-package search for `stage`, `maturity`,
/// `evolve`, `tier`, `幼年`, `成年`, `阶段`, `进化` returns only development
/// workflow terms. The evidence is in `MOCHI_GROWTH_STAGE0_AUDIT.md` §A/§B.
///
/// The four stages below are therefore a **chosen default**, centralised in
/// [GrowthStageSpec.table] so replacing them is a one-file change. They are
/// ordered tiers of the *same* character — a sprout-themed puppy growing up —
/// deliberately chosen to keep Mochi recognisable rather than to redesign it
/// between tiers.
enum GrowthStage {
  /// Newly adopted. Smallest, calmest, fewest flourishes.
  sprout,

  /// Settled in. Adds tail/ear flourish variety.
  seedling,

  /// Established companion. Full micro-motion, faster expression cadence.
  growing,

  /// Fully grown. Richest idle behaviour and expression cadence.
  blooming,
}

/// How lively the idle layer reads at a stage.
///
/// This is a *presentation* descriptor only: it selects which additive idle
/// behaviours the presentation layer may play (`PetIdleBehaviorSpec` in
/// `lib/presentation/companion/pet_idle_behavior.dart`) and how the existing
/// micro-motion channels are retuned. It never touches rewards, XP, or any
/// other business value.
///
/// It is deliberately *not* a copy of [GrowthStage]: the stage says how far
/// along Mochi is, this says how that reads. They map one-to-one today, but a
/// retune that gives two stages the same personality — or gives one stage a
/// personality no other stage has — is a presentation change, not a growth
/// change, and should not require touching the level table.
enum GrowthIdlePersonality {
  /// Short, gentle, infrequent motion.
  gentle,

  /// Steady and curious.
  steady,

  /// Confident, more varied.
  lively,

  /// Settled but expressive.
  content,
}
