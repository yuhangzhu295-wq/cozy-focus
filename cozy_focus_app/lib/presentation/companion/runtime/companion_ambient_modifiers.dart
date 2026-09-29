import '../../../../domain/growth/growth_stage.dart';
import '../time_of_day.dart';
import 'companion_context.dart';

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

  const AmbientModifier({
    this.extraEligible = const {},
    this.dwellScale = 1.0,
  });

  @override
  String toString() =>
      'AmbientModifier(+${extraEligible.map((b) => b.id).join('|')} x$dwellScale)';
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

  /// The contexts whose pools may vary. Task contexts are excluded on purpose.
  static const Set<CompanionBaseContext> ambientContexts = {
    CompanionBaseContext.home,
    CompanionBaseContext.room,
    CompanionBaseContext.complete,
  };

  /// Per-stage contribution. Growth is **additive**: a later stage keeps
  /// everything an earlier one had.
  static const Map<GrowthStage, AmbientModifier> growth = {
    GrowthStage.sprout: AmbientModifier(dwellScale: 1.35),
    GrowthStage.seedling: AmbientModifier(
      dwellScale: 1.15,
      extraEligible: {CompanionMacroBehavior.glance},
    ),
    GrowthStage.growing: AmbientModifier(
      dwellScale: 1.0,
      extraEligible: {
        CompanionMacroBehavior.glance,
        CompanionMacroBehavior.microRest,
      },
    ),
    GrowthStage.blooming: AmbientModifier(
      dwellScale: 0.9,
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

  /// The combined modifier for a context.
  ///
  /// Returns the neutral modifier for a task context, so a focus session and a
  /// craft job present identically at every stage and every hour.
  static AmbientModifier resolve({
    required CompanionBaseContext baseContext,
    required GrowthStage growthStage,
    required TimeOfDayBand timeOfDayBand,
  }) {
    if (!ambientContexts.contains(baseContext)) {
      return const AmbientModifier();
    }

    final stage = growth[growthStage] ?? const AmbientModifier();
    final band = timeOfDay[timeOfDayBand] ?? const AmbientModifier();

    return AmbientModifier(
      extraEligible: {...stage.extraEligible, ...band.extraEligible},
      dwellScale: stage.dwellScale * band.dwellScale,
    );
  }
}
