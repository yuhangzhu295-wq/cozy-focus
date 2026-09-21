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

/// Status classification — defined ONCE here, on purpose.
///
/// The model (`FocusSession.isActive`), the DAO (`findActive` / `findUnfinished`)
/// and the engine (`restore`) each used to spell these sets out separately. That
/// is how a session left in `finishing` became invisible to all three at once and
/// was silently dropped, taking its focus time with it. Derive from these
/// predicates instead of re-listing statuses anywhere else.
extension FocusSessionStatusSets on FocusSessionStatus {
  /// The countdown may still be advancing; the user can pause/resume it.
  bool get isTimerLive =>
      this == FocusSessionStatus.running || this == FocusSessionStatus.paused;

  /// Rehydrated in memory by `restore()` only — never written back to the DB.
  bool get isMemoryOnly => this == FocusSessionStatus.restored;

  /// A session the user can still drive forward (pause / resume / complete).
  bool get isResumable => isTimerLive || isMemoryOnly;

  /// Ended but not yet persisted as a FocusRecord — the session still owes a
  /// save, and dropping it would drop real focus time. Superset of [isResumable].
  bool get isUnfinished => isResumable || this == FocusSessionStatus.finishing;
}

/// Persisted status names matching [FocusSessionStatusSets.isTimerLive].
final List<String> kLiveSessionStatusNames = FocusSessionStatus.values
    .where((s) => s.isTimerLive)
    .map((s) => s.name)
    .toList(growable: false);

/// Persisted status names matching [FocusSessionStatusSets.isUnfinished].
final List<String> kUnfinishedSessionStatusNames = FocusSessionStatus.values
    .where((s) => s.isUnfinished)
    .map((s) => s.name)
    .toList(growable: false);

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
