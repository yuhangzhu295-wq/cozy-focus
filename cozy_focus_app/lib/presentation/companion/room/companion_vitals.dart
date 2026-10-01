/// The companion's own simulation state.
///
/// ## What this is, and what it deliberately is not
///
/// The brief asks for the companion to be an *entity* with mood, energy, focus
/// level and relationship, so that its actions can be caused by state rather
/// than by a picture swap.
///
/// This is **presentation state**. It is not XP, not coins, not a focus record,
/// not inventory and not craft progress. Nothing in this file can reach a
/// repository, and the simulation that owns it is never handed one. That is what
/// keeps the existing rule — *animation may never write business state* — true
/// while still letting the room feel alive.
///
/// ## Why it is bounded
///
/// Every field is `0…100`. Energy draining to a negative number would make
/// "energy < 40" meaningless over time, and an unbounded relationship would
/// eventually make every response identical. Clamping happens on write, once,
/// in [copyWithEffect], so no caller has to remember.
library;

import 'furniture_entity.dart';

/// The companion's simulation state, as one immutable value.
class CompanionVitals {
  /// How the companion feels. Rises with affection and play, falls with neglect.
  final int mood;

  /// How much the companion has left to give. Falls while it acts, restored by
  /// rest and sleep.
  final int energy;

  /// How settled the companion is. Rises while it works, falls when interrupted.
  final int focusLevel;

  /// How close the companion feels to the player. Only ever rises, and only
  /// from the player's own actions — never from the passage of time, which would
  /// make affection something a player could farm by waiting.
  final int relationship;

  const CompanionVitals({
    this.mood = 72,
    this.energy = 80,
    this.focusLevel = 60,
    this.relationship = 20,
  });

  /// The state a brand-new companion starts in.
  ///
  /// Chosen so that the *first* thing the player sees is a companion that wants
  /// something: energy 80 is above the rest threshold, so it will work; mood 72
  /// is high, so it is happy. Nothing here is at an extreme, because an extreme
  /// start would make the companion look broken rather than alive.
  static const CompanionVitals initial = CompanionVitals();

  /// Whether the companion is tired enough to prefer resting over working.
  ///
  /// The threshold is the brief's own: `energy < 40`.
  bool get isTired => energy < thresholdEnergyLow;

  /// The energy below which resting becomes the preferred action.
  static const int thresholdEnergyLow = 40;

  /// The energy above which the companion is willing to work again.
  ///
  /// Deliberately above [thresholdEnergyLow]: with a single threshold the
  /// companion would oscillate between resting and working on every tick at the
  /// boundary, which reads as a glitch rather than as a decision.
  static const int thresholdEnergyHigh = 55;

  bool get isRested => energy >= thresholdEnergyHigh;

  /// Applies an [FurnitureEffect], clamping every field to `0…100`.
  CompanionVitals copyWithEffect(FurnitureEffect effect) => CompanionVitals(
        mood: _clamp(mood + effect.mood),
        energy: _clamp(energy + effect.energy),
        focusLevel: _clamp(focusLevel + effect.focus),
        relationship: _clamp(relationship + effect.relationship),
      );

  /// The state after [seconds] of simply existing.
  ///
  /// Energy drains slowly and mood drifts toward neutral, so a companion left
  /// alone is visibly a little different when the player comes back — the
  /// brief's *"when the user returns after hours"*. Relationship never changes
  /// here: it is the player's to give.
  CompanionVitals afterElapsed(Duration seconds) {
    final minutes = seconds.inSeconds / 60.0;
    if (minutes <= 0) return this;
    return CompanionVitals(
      mood: _clamp(mood - (minutes * moodDriftPerMinute).round()),
      energy: _clamp(energy - (minutes * energyDrainPerMinute).round()),
      focusLevel: _clamp(focusLevel - (minutes * focusDecayPerMinute).round()),
      relationship: relationship,
    );
  }

  /// Per-minute drift constants. Small enough that an hour away is a change the
  /// player notices, not one that resets the companion.
  static const double moodDriftPerMinute = 0.35;
  static const double energyDrainPerMinute = 0.5;
  static const double focusDecayPerMinute = 0.4;

  CompanionVitals copyWith({
    int? mood,
    int? energy,
    int? focusLevel,
    int? relationship,
  }) =>
      CompanionVitals(
        mood: _clamp(mood ?? this.mood),
        energy: _clamp(energy ?? this.energy),
        focusLevel: _clamp(focusLevel ?? this.focusLevel),
        relationship: _clamp(relationship ?? this.relationship),
      );

  static int _clamp(int value) => value < 0 ? 0 : (value > 100 ? 100 : value);

  @override
  String toString() =>
      'CompanionVitals(mood $mood, energy $energy, focus $focusLevel, '
      'relationship $relationship)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanionVitals &&
          runtimeType == other.runtimeType &&
          mood == other.mood &&
          energy == other.energy &&
          focusLevel == other.focusLevel &&
          relationship == other.relationship;

  @override
  int get hashCode => Object.hash(mood, energy, focusLevel, relationship);
}

/// Where the companion is and what it is doing, as one value.
///
/// The brief's `CompanionState` also lists `location` and
/// `currentActivity`, which are not vitals — they are the *outcome* of the
/// simulation, not its inputs. Keeping them in one object with the vitals would
/// mean every mood tick also rewrites the location, so they are separated here
/// and joined only where something has to present them together.
class CompanionActivity {
  /// The anchor the companion is at, or the floor anchor when it is wandering.
  final String anchorId;

  /// The furniture action being performed, or `null` when idle in the room.
  final String? actionId;

  /// The semantic companion action the sprite player should present.
  final String? companionAction;

  /// When the current commitment ends. The simulation re-evaluates then, not
  /// before, so the companion visibly commits to what it is doing.
  final Duration endsAt;

  const CompanionActivity({
    required this.anchorId,
    required this.endsAt,
    this.actionId,
    this.companionAction,
  });

  /// Idle at the floor anchor.
  static const CompanionActivity idle = CompanionActivity(
    anchorId: 'floor_anchor',
    endsAt: Duration.zero,
  );

  bool get isBusy => actionId != null;

  CompanionActivity copyWith({
    String? anchorId,
    String? actionId,
    bool clearAction = false,
    String? companionAction,
    Duration? endsAt,
  }) =>
      CompanionActivity(
        anchorId: anchorId ?? this.anchorId,
        actionId: clearAction ? null : (actionId ?? this.actionId),
        companionAction:
            clearAction ? null : (companionAction ?? this.companionAction),
        endsAt: endsAt ?? this.endsAt,
      );

  @override
  String toString() => 'CompanionActivity($actionId @ $anchorId '
      'until ${endsAt.inSeconds}s)';
}
