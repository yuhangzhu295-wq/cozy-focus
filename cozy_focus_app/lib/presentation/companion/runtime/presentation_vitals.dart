/// The companion's own condition, as a **presentation input**.
///
/// ## What this is, and what it deliberately is not
///
/// The brief lists `PresentationVitals` alongside `CompanionContext` and
/// `CompanionEvent` as one of the three read-only inputs to the behaviour
/// director. This is that input: how the companion is doing, so that how it
/// behaves can depend on it.
///
/// It is **presentation state**. It is not XP, coins, a focus record, inventory,
/// craft progress or a settlement. Nothing here can reach a repository, and the
/// director that reads it has no repository to reach — so a change to a mood
/// cannot change what the user has earned. That is the same structural rule the
/// rest of the companion layer follows, applied to the newest input.
///
/// ## Why it is a separate type from `CompanionVitals`
///
/// `CompanionVitals` lives in the room module and is owned by the room
/// simulation: it is what the *room* tracks while the companion is in it. This
/// is the read-only projection the runtime is handed, so the runtime never
/// depends on the room module and a page that has no vitals can pass nothing at
/// all and get neutral behaviour.
class PresentationVitals {
  /// How the companion feels, `0…100`.
  final int mood;

  /// How much the companion has left to give, `0…100`.
  final int energy;

  /// How settled the companion is, `0…100`.
  final int focusLevel;

  /// How close the companion feels to the player, `0…100`.
  final int relationship;

  const PresentationVitals({
    this.mood = 72,
    this.energy = 80,
    this.focusLevel = 60,
    this.relationship = 20,
  });

  /// The state a page with no vitals to hand passes.
  ///
  /// Chosen to be the *middle* of the shipped starting values, not an extreme:
  /// a caller that knows nothing about the companion's condition must not
  /// accidentally make it look exhausted or euphoric. With this value every
  /// vitals contribution below is a no-op, so a page that passes nothing
  /// presents exactly as it did before this input existed.
  static const PresentationVitals neutral = PresentationVitals();

  /// Energy below which the companion is tired. The brief's own threshold.
  static const int tiredEnergyThreshold = 40;

  /// Mood below which the companion is subdued.
  static const int lowMoodThreshold = 40;

  /// Whether the companion is tired enough to want to rest.
  bool get isTired => energy < tiredEnergyThreshold;

  /// Whether the companion is subdued.
  bool get isLowMood => mood < lowMoodThreshold;

  /// Whether these vitals are the neutral default, and therefore contribute
  /// nothing. Lets the modifier table skip its own work and lets a test assert
  /// that "no vitals" really means "no effect".
  bool get isNeutral =>
      mood == neutral.mood &&
      energy == neutral.energy &&
      focusLevel == neutral.focusLevel &&
      relationship == neutral.relationship;

  PresentationVitals copyWith({
    int? mood,
    int? energy,
    int? focusLevel,
    int? relationship,
  }) =>
      PresentationVitals(
        mood: mood ?? this.mood,
        energy: energy ?? this.energy,
        focusLevel: focusLevel ?? this.focusLevel,
        relationship: relationship ?? this.relationship,
      );

  @override
  String toString() => 'PresentationVitals(mood $mood, energy $energy, '
      'focus $focusLevel, relationship $relationship)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PresentationVitals &&
          runtimeType == other.runtimeType &&
          mood == other.mood &&
          energy == other.energy &&
          focusLevel == other.focusLevel &&
          relationship == other.relationship;

  @override
  int get hashCode => Object.hash(mood, energy, focusLevel, relationship);
}
