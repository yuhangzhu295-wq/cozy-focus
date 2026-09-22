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
/// This is a *presentation* descriptor only: it scales amplitude and cadence of
/// the existing micro-motion channels. It never touches rewards, XP, or any
/// other business value.
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
