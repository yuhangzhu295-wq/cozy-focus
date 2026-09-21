import '../models/enums.dart';
import '../models/focus_session.dart';
import '../models/focus_record.dart';
import '../repositories/i_focus_session_repository.dart';
import '../repositories/i_focus_record_repository.dart';
import 'focus_clock.dart';
import 'reward_service.dart';
import 'package:uuid/uuid.dart';

/// FocusSessionEngine — the single authority for session lifecycle.
///
/// State machine:
///   idle ──start──▶ running
///   running ──pause──▶ paused
///   paused ──resume──▶ running
///   running ──complete──▶ finishing ──save──▶ completed ──settled──▶ saved
///   running ──cancel──▶ cancelled
///   paused ──cancel──▶ cancelled
///   any ──restore──▶ restored (then re-evaluates to running/paused/completed)
///
/// This class must NOT import any Flutter / widget code.
class FocusSessionEngine {
  final IFocusSessionRepository _sessionRepo;
  final IFocusRecordRepository _recordRepo;
  final RewardService _rewardService;
  final FocusClock _clock;
  final Uuid _uuid;

  FocusSession? _currentSession;

  FocusSessionEngine({
    required IFocusSessionRepository sessionRepo,
    required IFocusRecordRepository recordRepo,
    required RewardService rewardService,
    FocusClock? clock,
    Uuid? uuid,
  })  : _sessionRepo = sessionRepo,
        _recordRepo = recordRepo,
        _rewardService = rewardService,
        _clock = clock ?? const SystemFocusClock(),
        _uuid = uuid ?? const Uuid();

  FocusSession? get currentSession => _currentSession;

  // ── start ──────────────────────────────────────────────────────────────────

  Future<FocusSession> start({
    required String userId,
    required int plannedSeconds,
    required FocusMode mode,
    String? categoryId,
    String? taskName,
  }) async {
    _assertIdle();
    final session = FocusSession(
      id: _uuid.v4(),
      userId: userId,
      categoryId: categoryId,
      taskName: taskName,
      plannedSeconds: plannedSeconds,
      mode: mode,
      startAt: _clock.now(),
      pauseIntervals: const [],
      status: FocusSessionStatus.running,
      timezoneOffsetMinutes: _clock.now().timeZoneOffset.inMinutes,
    );
    await _sessionRepo.save(session);
    _currentSession = session;
    return session;
  }

  // ── pause ──────────────────────────────────────────────────────────────────

  Future<FocusSession> pause() async {
    final session = _requireSession();
    if (session.status != FocusSessionStatus.running &&
        session.status != FocusSessionStatus.restored) {
      throw StateError(
          'Expected session status running but got ${session.status}');
    }
    final updated = session.copyWith(
      pauseIntervals: [
        ...session.pauseIntervals,
        PauseInterval(pauseStart: _clock.now()),
      ],
      status: FocusSessionStatus.paused,
    );
    await _sessionRepo.update(updated);
    _currentSession = updated;
    return updated;
  }

  // ── resume ─────────────────────────────────────────────────────────────────

  Future<FocusSession> resume() async {
    final session = _requireSession();
    if (session.status != FocusSessionStatus.paused &&
        session.status != FocusSessionStatus.restored) {
      throw StateError(
          'Expected session status paused but got ${session.status}');
    }
    // Close the open pause interval
    final intervals = session.pauseIntervals.toList();
    if (intervals.isNotEmpty && intervals.last.pauseEnd == null) {
      intervals[intervals.length - 1] = PauseInterval(
          pauseStart: intervals.last.pauseStart, pauseEnd: _clock.now());
    }
    final updated = session.copyWith(
      pauseIntervals: intervals,
      status: FocusSessionStatus.running,
    );
    await _sessionRepo.update(updated);
    _currentSession = updated;
    return updated;
  }

  // ── complete (timer expired or user ends) ──────────────────────────────────

  Future<FocusSession> complete() async {
    final session = _requireSession();
    if (session.status != FocusSessionStatus.running &&
        session.status != FocusSessionStatus.paused &&
        session.status != FocusSessionStatus.restored) {
      throw StateError('Cannot complete session in status: ${session.status}');
    }
    // Close any open pause
    final intervals = _closeOpenPause(session.pauseIntervals);
    final updated = session.copyWith(
      pauseIntervals: intervals,
      endAt: _clock.now(),
      status: FocusSessionStatus.finishing,
    );
    await _sessionRepo.update(updated);
    _currentSession = updated;
    return updated;
  }

  // ── save (user confirms and record is written) ─────────────────────────────

  /// [categoryId] allows overriding the session's original category (user may
  /// change it on the save page).  Defaults to the session's categoryId.
  Future<FocusSession> save({
    String? note,
    String? taskName,
    String? categoryId,
    String? mood,
  }) async {
    final session = _requireSession();
    _assertStatus(session, FocusSessionStatus.finishing);

    final completed = await _persistRecord(
      session,
      note: note,
      taskName: taskName,
      categoryId: categoryId,
      mood: mood,
    );
    _currentSession = null;
    return completed.copyWith(status: FocusSessionStatus.saved);
  }

  // ── recover abandoned sessions ─────────────────────────────────────────────

  /// Finalize sessions that ended but were never saved.
  ///
  /// [complete] parks a session in `finishing`; only [save] makes it durable.
  /// Anything that stops the user from finishing the save page — the close
  /// button on the save screen, the app being killed, a crash — used to leave
  /// the session in `finishing` forever: `findActive` never returned it,
  /// `isActive` was false for it, and [save] needs the in-memory session. The
  /// FocusRecord and the reward were never written, so the focus time vanished
  /// with no trace and no way to get it back.
  ///
  /// This drains that backlog from persisted data, keeping whatever metadata the
  /// session already carries. Safe to call repeatedly: [_persistRecord] skips an
  /// already-written record and [RewardService.settle] is idempotent per session.
  ///
  /// The session currently held in memory is skipped — the user may be sitting
  /// on the save page editing it, and recovery must not pre-empt their input.
  Future<List<FocusSession>> recoverAbandonedSessions(String userId) async {
    final unfinished = await _sessionRepo.findUnfinished(userId);
    final abandoned = unfinished.where((s) =>
        s.status == FocusSessionStatus.finishing &&
        s.id != _currentSession?.id);
    final recovered = <FocusSession>[];
    for (final session in abandoned) {
      recovered.add(await _persistRecord(session));
    }
    return recovered;
  }

  /// Writes the FocusRecord for a session whose [FocusSession.endAt] is already
  /// set, settles its reward and marks it `completed`.
  ///
  /// The named overrides are the save page's path (the user may retitle the task,
  /// change the category, pick a mood). Recovery passes none of them and keeps
  /// whatever the session already carries.
  Future<FocusSession> _persistRecord(
    FocusSession session, {
    String? note,
    String? taskName,
    String? categoryId,
    String? mood,
  }) async {
    final endAt = session.endAt;
    if (endAt == null) {
      throw StateError(
          'Cannot persist a record for an open session: ${session.id}');
    }

    final now = _clock.now();
    // elapsed is deterministic because endAt was set when the session closed.
    final elapsed = session.elapsedSecondsAt(now);

    // Idempotent: recovery and the save page may both reach the same session.
    final existing = await _recordRepo.findBySessionId(session.id);
    if (existing == null) {
      await _recordRepo.insert(
        FocusRecord(
          id: _uuid.v4(),
          sessionId: session.id,
          userId: session.userId,
          categoryId: categoryId ?? session.categoryId,
          taskName: taskName ?? session.taskName,
          mood: mood,
          durationSeconds: elapsed,
          startAt: session.startAt,
          endAt: endAt,
          recordedAt: now,
          isCountedForReward: true,
          note: note,
        ),
      );
    }

    // Settle reward (idempotent — safe to call multiple times)
    await _rewardService.settle(session);

    final completed = session.copyWith(status: FocusSessionStatus.completed);
    await _sessionRepo.update(completed);
    return completed;
  }

  // ── cancel ─────────────────────────────────────────────────────────────────

  Future<FocusSession> cancel() async {
    final session = _requireSession();
    if (session.status != FocusSessionStatus.running &&
        session.status != FocusSessionStatus.paused &&
        session.status != FocusSessionStatus.restored) {
      throw StateError('Cannot cancel session in status: ${session.status}');
    }
    final intervals = _closeOpenPause(session.pauseIntervals);
    final updated = session.copyWith(
      pauseIntervals: intervals,
      endAt: _clock.now(),
      status: FocusSessionStatus.cancelled,
    );
    await _sessionRepo.update(updated);
    _currentSession = null;
    return updated;
  }

  // ── restore (app killed / backgrounded) ───────────────────────────────────
  /// Called on app launch to re-hydrate the last live session from the local DB.
  ///
  /// Two things happen, in order:
  ///  1. [recoverAbandonedSessions] finalizes anything left in `finishing`, so a
  ///     session abandoned on the save page is persisted instead of dropped.
  ///  2. The most recent resumable session is handed back as `restored`.
  ///
  /// This does not auto-complete an expired countdown itself — that belongs to
  /// the caller, which also owns navigation into the save flow. See
  /// `FocusSessionController.restoreSession`.

  Future<FocusSession?> restore(String userId) async {
    await recoverAbandonedSessions(userId);

    final unfinished = await _sessionRepo.findUnfinished(userId);
    final resumable = unfinished.where((s) => s.isActive).toList();
    if (resumable.isEmpty) return null;

    // Pick the most recent resumable session
    final session = resumable.reduce(
      (a, b) => a.startAt.isAfter(b.startAt) ? a : b,
    );

    final restored = session.copyWith(status: FocusSessionStatus.restored);
    _currentSession = restored;
    return restored;
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  void _assertIdle() {
    if (_currentSession != null && _currentSession!.isActive) {
      throw StateError('A session is already active: ${_currentSession!.id}');
    }
  }

  FocusSession _requireSession() {
    final s = _currentSession;
    if (s == null) throw StateError('No active session');
    return s;
  }

  void _assertStatus(FocusSession session, FocusSessionStatus expected) {
    if (session.status != expected) {
      throw StateError(
        'Expected session status $expected but got ${session.status}',
      );
    }
  }

  List<PauseInterval> _closeOpenPause(List<PauseInterval> intervals) {
    if (intervals.isNotEmpty && intervals.last.pauseEnd == null) {
      final closed = intervals.toList();
      closed[closed.length - 1] = PauseInterval(
        pauseStart: closed.last.pauseStart,
        pauseEnd: _clock.now(),
      );
      return closed;
    }
    return intervals;
  }
}
