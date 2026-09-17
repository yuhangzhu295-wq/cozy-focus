import '../../domain/models/enums.dart' show PetVisualState;
import 'companion_presentation_state.dart';

abstract final class CompanionPresentationMapper {
  static PetVisualState visualStateFor({
    PetVisualState? liveSessionState,
    bool hasActiveSession = false,
    bool hasActiveCraft = false,
  }) {
    if (liveSessionState != null) {
      return liveSessionState;
    }
    if (hasActiveSession) {
      return PetVisualState.focus;
    }
    if (hasActiveCraft) {
      return PetVisualState.craft;
    }
    return PetVisualState.idle;
  }

  static double normalizedProgress(num current, num total) {
    if (total <= 0) {
      return 0.0;
    }
    final ratio = current / total;
    return ratio.clamp(0.0, 1.0).toDouble();
  }

  static double normalizeHappiness(num score) {
    return (score / 100).clamp(0.0, 1.0).toDouble();
  }

  static CompanionPresentationState buildPresentationState({
    PetVisualState? liveSessionState,
    bool hasActiveSession = false,
    bool hasActiveCraft = false,
    int level = 1,
    int experiencePoints = 0,
    num happinessScore = 0,
    num currentFocus = 0,
    num totalFocus = 0,
    num currentCraft = 0,
    num totalCraft = 0,
    bool reducedMotion = false,
  }) {
    return CompanionPresentationState(
      visualState: visualStateFor(
        liveSessionState: liveSessionState,
        hasActiveSession: hasActiveSession,
        hasActiveCraft: hasActiveCraft,
      ),
      level: level,
      experiencePoints: experiencePoints,
      happinessNormalized: normalizeHappiness(happinessScore),
      focusProgress: normalizedProgress(currentFocus, totalFocus),
      craftProgress: normalizedProgress(currentCraft, totalCraft),
      reducedMotion: reducedMotion,
    );
  }
}
