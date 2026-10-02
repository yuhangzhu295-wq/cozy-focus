import 'companion_emotion.dart';
import '../runtime/presentation_vitals.dart';

/// Derives the companion's emotional presentation state from its condition.
///
/// ## Why a resolver and not a state machine
///
/// The emotion is **derived, not stored**: `resolve()` takes the current vitals
/// and returns a label. There is no `isSad = true` column, no persisted mood
/// flag, no transition graph. The same inputs always produce the same output,
/// which makes it trivially testable and impossible to desynchronise from the
/// vitals it is derived from.
///
/// ## It is a pure function
///
/// No `DateTime.now()`, no random source, no repository. Every input is passed
/// in, so the caller controls determinism. A test can hold a fixed clock and a
/// fixed set of vitals and get the same emotion every time.
///
/// ## It decides nothing about business
///
/// Its vocabulary is thresholds on a 0–100 scale. There is no XP, no coin, no
/// session, no craft job, no inventory here.
abstract final class CompanionEmotionResolver {
  const CompanionEmotionResolver._();

  /// Derives the companion's emotion from its condition.
  ///
  /// ## Resolution order
  ///
  /// The first match wins, and the order encodes the spec's own precedence:
  /// completion > tired > low mood > curious > calm.
  ///
  /// [recentCompletion] — whether a real focus session has recently completed.
  /// The caller supplies this from the director's own completion latch or from
  /// the base context; the resolver does not track time itself.
  ///
  /// [recentlyInteracted] — whether the player has interacted with the
  /// companion within the current cooldown window. Supplied by the caller, not
  /// measured here.
  static CompanionEmotion resolve({
    required PresentationVitals vitals,
    bool recentCompletion = false,
    bool recentlyInteracted = false,
  }) {
    // Completion is the one event that overrides everything: the celebration
    // is the product's own positive beat, and low vitals must not mute it.
    if (recentCompletion) return CompanionEmotion.happy;

    // Tired is the next strongest: a depleted companion rests, regardless of
    // how it feels about the player.
    if (vitals.isTired) return CompanionEmotion.tired;

    // Low mood is subdued, not distressed. It is a *neutral* presentation fact.
    if (vitals.isLowMood) return CompanionEmotion.lowMood;

    // A recent interaction makes the companion alert and expressive.
    if (recentlyInteracted) return CompanionEmotion.curious;

    return CompanionEmotion.calm;
  }
}
