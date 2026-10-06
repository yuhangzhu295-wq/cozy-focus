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

/// How a focus session counts, which is a different question from [FocusMode].
///
/// [FocusMode] says what the session is *for* — work, a short break, a long
/// break — and its break values belong to the existing break flow, not to a
/// timer setting. This says how the timer behaves, and the two must not be
/// conflated: reading `shortBreak` as "not a countdown" would make every break a
/// flow session and every flow session a break.
///
/// The three modes the design offers:
///
/// * [countdown] — 番茄钟. A target length, a countdown, and the session finishes
///   itself when the target is reached.
/// * [countUp] — 正计时. No target. It counts up and the user decides when it is
///   over.
/// * [deepFocus] — 深度专注. No target, and **no pausing**: the commitment is not
///   to interrupt, so the pause control is not offered rather than being offered
///   and then ignored.
enum FocusTimingMode {
  countdown('countdown', '番茄钟'),
  countUp('countUp', '正计时'),
  deepFocus('deepFocus', '深度专注');

  /// The stored id. Stable, because it is written to the database.
  final String id;

  /// What the segmented control says.
  final String label;

  const FocusTimingMode(this.id, this.label);

  /// Whether this mode counts down to a target the user chose.
  ///
  /// The single question every other rule asks: whether a session in this mode
  /// carries a length, whether the ring fills towards one, and whether the timer
  /// may end the session by itself.
  bool get hasTarget => this == FocusTimingMode.countdown;

  /// Whether the user may pause. Deep focus is the one that says no, and the
  /// control says so rather than being shown and then ignored.
  bool get allowsPause => this != FocusTimingMode.deepFocus;

  /// Whether reaching the target ends the session.
  bool get autoCompletesAtTarget => hasTarget;

  /// The target used when a countdown has to be created for a session that has
  /// none — switching a running flow session to 番茄钟, for instance.
  static const int defaultTargetSeconds = 25 * 60;

  /// The mode for a stored id, defaulting to [countdown].
  ///
  /// Defaults rather than throwing: a session that cannot be read is worse than
  /// one read as the common case, and a row with no stored mode came from a
  /// version that only ever did countdowns.
  static FocusTimingMode fromId(String? id) {
    for (final mode in FocusTimingMode.values) {
      if (mode.id == id) return mode;
    }
    return FocusTimingMode.countdown;
  }

  /// The mode implied by a stored `plannedSeconds`, for rows written before the
  /// mode column existed: a session with no length was a flow session, and one
  /// with a length was a countdown.
  static FocusTimingMode fromLegacyPlannedSeconds(int plannedSeconds) =>
      plannedSeconds > 0 ? FocusTimingMode.countdown : FocusTimingMode.countUp;
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
