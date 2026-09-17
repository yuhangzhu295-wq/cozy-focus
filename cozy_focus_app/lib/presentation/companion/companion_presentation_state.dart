import '../../domain/models/enums.dart' show PetVisualState;

class CompanionPresentationState {
  final PetVisualState visualState;
  final int level;
  final int experiencePoints;
  final double happinessNormalized;
  final double focusProgress;
  final double craftProgress;
  final bool reducedMotion;

  const CompanionPresentationState({
    required this.visualState,
    required this.level,
    required this.experiencePoints,
    required this.happinessNormalized,
    required this.focusProgress,
    required this.craftProgress,
    required this.reducedMotion,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanionPresentationState &&
          runtimeType == other.runtimeType &&
          visualState == other.visualState &&
          level == other.level &&
          experiencePoints == other.experiencePoints &&
          happinessNormalized == other.happinessNormalized &&
          focusProgress == other.focusProgress &&
          craftProgress == other.craftProgress &&
          reducedMotion == other.reducedMotion;

  @override
  int get hashCode => Object.hash(
        visualState,
        level,
        experiencePoints,
        happinessNormalized,
        focusProgress,
        craftProgress,
        reducedMotion,
      );

  @override
  String toString() =>
      'CompanionPresentationState(visualState: $visualState, level: $level, experiencePoints: $experiencePoints, happinessNormalized: $happinessNormalized, focusProgress: $focusProgress, craftProgress: $craftProgress, reducedMotion: $reducedMotion)';
}
