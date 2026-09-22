import 'growth_stage.dart';

/// One row of the centralised growth-stage table.
///
/// Every threshold and every per-stage presentation value lives in
/// [GrowthStageSpec.table] and nowhere else, so retuning growth is a one-file
/// change. See [GrowthStage] for why these particular values are a documented
/// default rather than a recovered spec.
///
/// Nothing here can affect business state: no XP, no rewards, no session or
/// craft semantics. The class only describes how Mochi *looks and behaves*.
///
/// ## Growth is additive, never subtractive
///
/// V4.1 `designs/motion/11_宠物动效总览.png` titles its motion set
/// **固定微动 + 状态动画** — "fixed micro-motion + state animation" — and lists
/// 呼吸 / 轻摆 / 眨眼 / 耳朵 / 尾巴 as the fixed layer beneath every state. The
/// micro layer is therefore *always* present, at every stage: a stage must never
/// be able to switch off breathe, sway, blink, ear twitch, tail wag or the
/// delayed head response.
///
/// Growth expresses itself in three additive ways instead:
///
/// 1. **Proportion** — [maturityScale] nudges the rendered body size.
/// 2. **Amplitude and cadence** — [partMotionFactor], [blinkIntervalScale] and
///    [earTwitchIntervalScale] retune the fixed layer without removing it.
/// 3. **Extra flourishes** — [hasIdleFlourish] adds a *new* behaviour on top of
///    the fixed layer. The base layer is untouched.
class GrowthStageSpec {
  final GrowthStage stage;

  /// Human-readable tier name, shown on the growth page.
  final String displayName;

  /// Inclusive level range that selects this stage.
  final int minLevel;
  final int maxLevel;

  /// Subtle body-proportion maturation, multiplied into the render size.
  ///
  /// Deliberately narrow (`0.94 … 1.03`, ~9% end to end): the same character
  /// must stay obviously the same character. This is a proportion nudge, not a
  /// redesign.
  final double maturityScale;

  /// Multiplier applied on top of `PetMotionSpec`'s per-state part-motion
  /// damping. Younger stages read calmer, later stages read more animated.
  ///
  /// Never `0`: the fixed micro layer is damped, never disabled.
  final double partMotionFactor;

  /// Multiplier on the scheduled blink interval. `< 1` means blinks come more
  /// often, i.e. a more expressive face.
  final double blinkIntervalScale;

  /// Multiplier on the scheduled ear-twitch interval, same convention.
  final double earTwitchIntervalScale;

  /// Whether this stage adds the idle flourish layer.
  ///
  /// `false` at the youngest stage means "the fixed micro layer, and nothing
  /// more" — not "fewer channels". Stages that set it gain an additional,
  /// occasional behaviour that the younger stage simply does not have yet.
  final bool hasIdleFlourish;

  /// Multiplier on the scheduled flourish interval. `< 1` means flourishes come
  /// more often. Ignored when [hasIdleFlourish] is `false`.
  final double flourishIntervalScale;

  /// How lively the idle layer reads.
  final GrowthIdlePersonality idlePersonality;

  const GrowthStageSpec({
    required this.stage,
    required this.displayName,
    required this.minLevel,
    required this.maxLevel,
    required this.maturityScale,
    required this.partMotionFactor,
    required this.blinkIntervalScale,
    required this.earTwitchIntervalScale,
    required this.hasIdleFlourish,
    required this.flourishIntervalScale,
    required this.idlePersonality,
  });

  bool coversLevel(int level) => level >= minLevel && level <= maxLevel;

  /// The centralised table. Order is ascending maturity and the ranges are
  /// contiguous and non-overlapping, which `growth_stage_resolver_test.dart`
  /// asserts.
  static const List<GrowthStageSpec> table = <GrowthStageSpec>[
    GrowthStageSpec(
      stage: GrowthStage.sprout,
      displayName: '幼芽期',
      minLevel: 1,
      maxLevel: 3,
      maturityScale: 0.94,
      partMotionFactor: 0.80,
      blinkIntervalScale: 1.15,
      earTwitchIntervalScale: 1.20,
      hasIdleFlourish: false,
      flourishIntervalScale: 1.0,
      idlePersonality: GrowthIdlePersonality.gentle,
    ),
    GrowthStageSpec(
      stage: GrowthStage.seedling,
      displayName: '幼苗期',
      minLevel: 4,
      maxLevel: 9,
      maturityScale: 0.97,
      partMotionFactor: 0.90,
      blinkIntervalScale: 1.05,
      earTwitchIntervalScale: 1.08,
      hasIdleFlourish: true,
      flourishIntervalScale: 1.25,
      idlePersonality: GrowthIdlePersonality.steady,
    ),
    GrowthStageSpec(
      stage: GrowthStage.growing,
      displayName: '成长期',
      minLevel: 10,
      maxLevel: 19,
      maturityScale: 1.00,
      partMotionFactor: 1.00,
      blinkIntervalScale: 1.00,
      earTwitchIntervalScale: 1.00,
      hasIdleFlourish: true,
      flourishIntervalScale: 1.00,
      idlePersonality: GrowthIdlePersonality.lively,
    ),
    GrowthStageSpec(
      stage: GrowthStage.blooming,
      displayName: '绽放期',
      minLevel: 20,
      maxLevel: 30,
      maturityScale: 1.03,
      partMotionFactor: 1.10,
      blinkIntervalScale: 0.92,
      earTwitchIntervalScale: 0.90,
      hasIdleFlourish: true,
      flourishIntervalScale: 0.75,
      idlePersonality: GrowthIdlePersonality.content,
    ),
  ];

  /// The spec for [stage]. Total — every enum value has exactly one row.
  static GrowthStageSpec of(GrowthStage stage) =>
      table.firstWhere((spec) => spec.stage == stage);
}
