// Core domain enumerations for Cozy Focus.
// All enums live here so every layer can import a single file.

enum FocusSessionStatus {
  idle,
  running,
  paused,
  finishing,
  completed,
  cancelled,
  restored,
  saved,
}

enum FocusMode {
  focus,
  shortBreak,
  longBreak,
}

enum PetSpecies {
  dog,
  cat,
  rabbit,
  capybara,
}

/// High-level visual state the business layer communicates to the animation layer.
/// Pages must never set Rive inputs directly — they only set PetVisualState.
enum PetVisualState {
  idle,
  focus,
  craft,
  pause,
  celebrate,
  sleep,
  greeting,
  interact,
}

enum CraftJobStatus {
  pending,
  inProgress,
  completed,
  cancelled,
  failed,
}

enum SyncStatus {
  pending,
  synced,
  conflicted,
  failed,
}

enum AchievementType {
  sessionCount,
  totalMinutes,
  streak,
  craftUnlock,
  petLevel,
}
