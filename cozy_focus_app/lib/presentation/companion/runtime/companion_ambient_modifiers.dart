import '../../../../domain/growth/growth_stage.dart';
import '../time_of_day.dart';
import 'companion_context.dart';
import 'presentation_vitals.dart';
import '../animation/companion_emotion.dart';

/// A contribution to the ambient behaviour pool.
///
/// Growth and time of day both make the companion read differently without
/// changing what it is *for*, so they are modelled as one concept: a set of extra
/// eligible behaviours plus a multiplier on how long a behaviour dwells.
class AmbientModifier {
  /// Behaviours this modifier adds to an ambient pool.
  final Set<CompanionMacroBehavior> extraEligible;

  /// Multiplier on the chosen dwell. `< 1` changes behaviour more often.
  final double dwellScale;

  /// Multiplier on how long a reaction overlay holds. `< 1` means briefer.
  final double overlayDurationScale;

  const AmbientModifier({
    this.extraEligible = const {},
    this.dwellScale = 1.0,
    this.overlayDurationScale = 1.0,
  });

  @override
  String toString() =>
      'AmbientModifier(+${extraEligible.map((b) => b.id).join('|')} '
      'x$dwellScale overlay x$overlayDurationScale)';
}

/// Growth and time-of-day variation for the ambient behaviour pool.
///
/// ## Why the pool and not a scale factor
///
/// `docs/05_多伙伴与成长规范.md` requires a growth stage to change the *visible
/// behaviour pool or expression richness*, and explicitly not to be carried by
/// scale or a level label alone. The V4.1 idle layer already grows its flourish
/// pool per stage; this does the same for the runtime's macro behaviours, so a
/// grown companion genuinely does more things rather than the same thing faster.
///
/// ## It cannot touch the economy
///
/// Growth arrives here as a [GrowthStage] — a presentation descriptor derived
/// from the shared `PetProgress`. Nothing in this file reads or writes XP,
/// coins, happiness, a session, a craft job or inventory. A stage change is
/// therefore incapable of changing what the user has earned.
///
/// ## Ambient only
///
/// Focus, craft, pause and sleep are *task* contexts: a session must present the
/// same work behaviours at every stage, or the companion would appear to work
/// differently as it grew. Only the ambient contexts take modifiers.
abstract final class CompanionAmbientModifiers {
  const CompanionAmbientModifiers._();

  /// The contexts whose pools may vary.
  ///
  /// Task contexts are excluded on purpose: a focus session and a craft job must
  /// present identically at every stage and hour.
  ///
  /// `complete` is excluded for a different reason, and it is not an oversight.
  /// Completion is a one-shot moment whose whole purpose is to celebrate. Adding
  /// the hour's restful beats to its pool would mean that late at night the
  /// companion celebrated only about a third of the time and looked sleepy the
  /// rest — which contradicts "Completion must visibly celebrate". Ambient
  /// variety belongs where the companion is idling, not where it is marking a
  /// finished session.
  static const Set<CompanionBaseContext> ambientContexts = {
    CompanionBaseContext.home,
    CompanionBaseContext.room,
  };

  /// Per-stage contribution. Growth is **additive**: a later stage keeps
  /// everything an earlier one had.
  static const Map<GrowthStage, AmbientModifier> growth = {
    GrowthStage.sprout: AmbientModifier(
      dwellScale: 1.35,
      overlayDurationScale: 0.85,
    ),
    GrowthStage.seedling: AmbientModifier(
      dwellScale: 1.15,
      overlayDurationScale: 0.95,
      extraEligible: {CompanionMacroBehavior.glance},
    ),
    GrowthStage.growing: AmbientModifier(
      dwellScale: 1.0,
      overlayDurationScale: 1.05,
      extraEligible: {
        CompanionMacroBehavior.glance,
        CompanionMacroBehavior.microRest,
      },
    ),
    GrowthStage.blooming: AmbientModifier(
      dwellScale: 0.9,
      overlayDurationScale: 1.15,
      extraEligible: {
        CompanionMacroBehavior.glance,
        CompanionMacroBehavior.microRest,
      },
    ),
  };

  /// Per-band contribution. Late night is calmer: the companion rests more and
  /// glances less, which is the presentation half of "it is late".
  static const Map<TimeOfDayBand, AmbientModifier> timeOfDay = {
    TimeOfDayBand.morning: AmbientModifier(),
    TimeOfDayBand.midday: AmbientModifier(),
    TimeOfDayBand.afternoon: AmbientModifier(),
    TimeOfDayBand.evening: AmbientModifier(),
    TimeOfDayBand.lateNight: AmbientModifier(
      dwellScale: 1.25,
      extraEligible: {
        CompanionMacroBehavior.microRest,
        CompanionMacroBehavior.sleep,
      },
    ),
  };

  /// The contribution of the companion's own condition.
  ///
  /// ## Only depletion contributes
  ///
  /// A rested, cheerful companion behaves exactly as it did before this input
  /// existed. Making a healthy companion *livelier* would need a behaviour the
  /// product has not approved and art that does not exist, so it is not invented
  /// here — and it keeps [PresentationVitals.neutral] a true no-op, which is what
  /// lets a page with no vitals to hand pass nothing and change nothing.
  ///
  /// A tired companion rests more and changes what it is doing less often; a
  /// subdued one is quieter. Both are *additive* on the stage and the hour, so a
  /// condition can never take a behaviour away.
  static AmbientModifier vitalsModifier(PresentationVitals vitals) {
    if (vitals.isNeutral) return const AmbientModifier();

    final extra = <CompanionMacroBehavior>{};
    var dwellScale = 1.0;

    if (vitals.isTired) {
      extra.add(CompanionMacroBehavior.microRest);
      dwellScale *= 1.35;
    }
    if (vitals.isLowMood) {
      dwellScale *= 1.2;
    }

    return AmbientModifier(extraEligible: extra, dwellScale: dwellScale);
  }

  /// The contribution of the companion's emotional presentation state.
  ///
  /// ## Only happy and curious contribute
  ///
  /// A calm companion adds nothing (the existing pool is already calm). Tired
  /// and low-mood are handled by [vitalsModifier] from the raw vitals — adding
  /// them here too would double-count.
  ///
  /// Happy and curious are the *semantic enrichment* that raw vitals cannot
  /// express: they require context (a recent completion or interaction) that
  /// vitals alone cannot provide. Both make the companion more expressive by
  /// adding `glance` to the ambient pool.
  static AmbientModifier emotionModifier(CompanionEmotion emotion) {
    switch (emotion) {
      case CompanionEmotion.happy:
      case CompanionEmotion.curious:
        return const AmbientModifier(
          extraEligible: {CompanionMacroBehavior.glance},
        );
      case CompanionEmotion.calm:
      case CompanionEmotion.tired:
      case CompanionEmotion.lowMood:
        return const AmbientModifier();
    }
  }

  /// The combined modifier for a context.
  ///
  /// Returns the neutral modifier for a task context, so a focus session and a
  /// craft job present identically at every stage and every hour.
  static AmbientModifier resolve({
    required CompanionBaseContext baseContext,
    required GrowthStage growthStage,
    required TimeOfDayBand timeOfDayBand,
    PresentationVitals vitals = PresentationVitals.neutral,
    CompanionEmotion emotion = CompanionEmotion.calm,
  }) {
    if (!ambientContexts.contains(baseContext)) {
      return const AmbientModifier();
    }

    final stage = growth[growthStage] ?? const AmbientModifier();
    final band = timeOfDay[timeOfDayBand] ?? const AmbientModifier();
    final condition = vitalsModifier(vitals);
    final mood = emotionModifier(emotion);

    return AmbientModifier(
      extraEligible: {
        ...stage.extraEligible,
        ...band.extraEligible,
        ...condition.extraEligible,
        ...mood.extraEligible,
      },
      dwellScale: stage.dwellScale * band.dwellScale * condition.dwellScale,
      overlayDurationScale: stage.overlayDurationScale *
          band.overlayDurationScale *
          condition.overlayDurationScale,
    );
  }
}
