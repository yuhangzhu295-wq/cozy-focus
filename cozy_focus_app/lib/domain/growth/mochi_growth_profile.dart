import '../models/pet_models.dart' show PetProgress;
import 'growth_level_curve.dart';
import 'growth_stage.dart';
import 'growth_stage_spec.dart';

/// The resolved, presentation-only growth profile for Mochi.
///
/// Produced by `GrowthStageResolver` from the real `PetProgress` truth. It is
/// the value the render chain consumes, and it is deliberately **immutable and
/// side-effect free**: holding or reading it cannot change XP, level, rewards,
/// happiness, sessions or craft.
///
/// Every field is a rendering instruction. The stage-derived values come from
/// the centralised [GrowthStageSpec.table]; the happiness term is a bounded
/// modulation *inside* the current stage, so no amount of happiness can move
/// Mochi to another stage — only XP can do that.
///
/// See [GrowthStageSpec] for the rule that growth is **additive**: the V4.1
/// fixed micro-motion layer is present at every stage, and a later stage adds
/// behaviours rather than a younger one losing them.
class MochiGrowthProfile {
  /// The stage earned by XP.
  final GrowthStage stage;

  /// The tier's display name, from the spec table.
  final String displayName;

  /// The level the curve derives from XP. Authoritative over any stored value.
  final int level;

  /// `happinessScore / 100`, clamped. Used only for the idle-energy nudge.
  final double happinessNormalized;

  /// Subtle body-proportion maturation, straight from the spec.
  final double maturityScale;

  /// Part-motion amplitude multiplier, spec value times the happiness nudge.
  final double partMotionFactor;

  /// Blink cadence multiplier from the spec.
  final double blinkIntervalScale;

  /// Ear-twitch cadence multiplier from the spec.
  final double earTwitchIntervalScale;

  /// Whether this stage adds the idle flourish layer.
  final bool hasIdleFlourish;

  /// Flourish cadence multiplier from the spec.
  final double flourishIntervalScale;

  /// How lively the idle layer reads.
  final GrowthIdlePersonality idlePersonality;

  const MochiGrowthProfile({
    required this.stage,
    required this.displayName,
    required this.level,
    required this.happinessNormalized,
    required this.maturityScale,
    required this.partMotionFactor,
    required this.blinkIntervalScale,
    required this.earTwitchIntervalScale,
    required this.hasIdleFlourish,
    required this.flourishIntervalScale,
    required this.idlePersonality,
  });

  /// A neutral profile for callers that have no `PetProgress` yet (a widget
  /// test, or the first frame before the database read resolves).
  ///
  /// It resolves the *same way* real data would at zero XP and zero happiness,
  /// so "no data" never invents a more grown Mochi than the user has earned.
  /// Held as a `static final` rather than a getter so the renderer can read it
  /// on every frame without allocating.
  static final MochiGrowthProfile initial = GrowthStageResolver.resolve(
    experiencePoints: 0,
    happinessScore: 0,
  );

  /// Resolve from the real `PetProgress` truth.
  ///
  /// Accepts `null` so a page that has not loaded its progress yet (or a widget
  /// test with no database) resolves to [initial] instead of forcing every call
  /// site to null-check. This is the single entry point the presentation layer
  /// uses, so "what stage is this Mochi" is decided in exactly one place.
  static MochiGrowthProfile fromProgress(PetProgress? progress) {
    if (progress == null) return initial;
    return GrowthStageResolver.resolve(
      experiencePoints: progress.experiencePoints,
      happinessScore: progress.happinessScore,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MochiGrowthProfile &&
          runtimeType == other.runtimeType &&
          stage == other.stage &&
          displayName == other.displayName &&
          level == other.level &&
          happinessNormalized == other.happinessNormalized &&
          maturityScale == other.maturityScale &&
          partMotionFactor == other.partMotionFactor &&
          blinkIntervalScale == other.blinkIntervalScale &&
          earTwitchIntervalScale == other.earTwitchIntervalScale &&
          hasIdleFlourish == other.hasIdleFlourish &&
          flourishIntervalScale == other.flourishIntervalScale &&
          idlePersonality == other.idlePersonality;

  @override
  int get hashCode => Object.hash(
        stage,
        displayName,
        level,
        happinessNormalized,
        maturityScale,
        partMotionFactor,
        blinkIntervalScale,
        earTwitchIntervalScale,
        hasIdleFlourish,
        flourishIntervalScale,
        idlePersonality,
      );

  @override
  String toString() => 'MochiGrowthProfile(stage: ${stage.name}, '
      'level: $level, maturityScale: $maturityScale, '
      'partMotionFactor: $partMotionFactor, '
      'hasIdleFlourish: $hasIdleFlourish)';
}

/// Pure mapping from real `PetProgress` truth to a [MochiGrowthProfile].
///
/// Split out from the profile so the mapping can be tested without a widget
/// tree, and so there is exactly one place that decides "what stage is this".
abstract final class GrowthStageResolver {
  const GrowthStageResolver._();

  /// How far happiness may push the idle energy, either side of neutral.
  ///
  /// Kept small on purpose: happiness is a mood, not a growth stage. A full
  /// sweep from the saddest to the happiest pet moves the amplitude by ±5% and
  /// can never change the stage.
  static const double _happinessEnergySpan = 0.05;

  /// The stage earned by [experiencePoints].
  ///
  /// The level is derived from XP rather than read from `PetProgress.level`, so
  /// a row written before level derivation existed still resolves to the right
  /// stage. `MOCHI_GROWTH_STAGE0_AUDIT.md` §A records that `level` shipped as a
  /// dead field.
  static GrowthStage resolveStage({required int experiencePoints}) =>
      specForLevel(GrowthLevelCurve.levelForXp(experiencePoints)).stage;

  /// The spec row whose level range covers [level].
  static GrowthStageSpec specForLevel(int level) {
    for (final spec in GrowthStageSpec.table) {
      if (spec.coversLevel(level)) return spec;
    }
    // Above the top of the curve: hold the final stage rather than invent one.
    return GrowthStageSpec.table.last;
  }

  /// Resolve the full presentation profile.
  ///
  /// [experiencePoints] drives the stage. [happinessScore] nudges idle energy
  /// inside that stage. Nothing is written anywhere.
  static MochiGrowthProfile resolve({
    required int experiencePoints,
    required int happinessScore,
  }) {
    final xp = experiencePoints < 0 ? 0 : experiencePoints;
    final level = GrowthLevelCurve.levelForXp(xp);
    final spec = specForLevel(level);
    final happiness = (happinessScore.clamp(0, 100)) / 100.0;

    // Neutral at 50 happiness, ±span at the extremes.
    final energyNudge = 1.0 + (happiness - 0.5) * 2 * _happinessEnergySpan;

    return MochiGrowthProfile(
      stage: spec.stage,
      displayName: spec.displayName,
      level: level,
      happinessNormalized: happiness,
      maturityScale: spec.maturityScale,
      partMotionFactor: spec.partMotionFactor * energyNudge,
      blinkIntervalScale: spec.blinkIntervalScale,
      earTwitchIntervalScale: spec.earTwitchIntervalScale,
      hasIdleFlourish: spec.hasIdleFlourish,
      flourishIntervalScale: spec.flourishIntervalScale,
      idlePersonality: spec.idlePersonality,
    );
  }
}
