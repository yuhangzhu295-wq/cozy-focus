import '../models/focus_session.dart';
import '../models/enums.dart';

abstract interface class IFocusSessionRepository {
  /// Persist a new session (must be idempotent on id).
  Future<void> save(FocusSession session);

  /// Overwrite an existing session record.
  Future<void> update(FocusSession session);

  /// Fetch by id; returns null if not found.
  Future<FocusSession?> findById(String id);

  /// All active (running/paused) sessions for the user.
  Future<List<FocusSession>> findActive(String userId);

  /// Latest N sessions regardless of status.
  Future<List<FocusSession>> findRecent(String userId, {int limit = 20});

  /// Delete; only permitted for cancelled sessions.
  Future<void> delete(String id);
}
