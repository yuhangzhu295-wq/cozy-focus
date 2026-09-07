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
  }) async {
    _assertIdle();
    final session = FocusSession(
      id: _uuid.v4(),
      userId: userId,
      categoryId: categoryId,
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
    _assertStatus(session, FocusSessionStatus.running);
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
    _assertStatus(session, FocusSessionStatus.paused);
    // Close the open pause interval
    final intervals = session.pauseIntervals.toList();
    if (intervals.isNotEmpty && intervals.last.pauseEnd == null) {
      intervals[intervals.length - 1] =
          PauseInterval(pauseStart: intervals.last.pauseStart, pauseEnd: _clock.now());
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
        session.status != FocusSessionStatus.paused) {
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

  Future<FocusSession> save({String? note}) async {
    final session = _requireSession();
    _assertStatus(session, FocusSessionStatus.finishing);

    // Write immutable FocusRecord
    await _recordRepo.insert(
      FocusRecord(
        id: _uuid.v4(),
        sessionId: session.id,
        userId: session.userId,
        categoryId: session.categoryId,
        durationSeconds: session.elapsedSeconds,
        startAt: session.startAt,
        endAt: session.endAt!,
        recordedAt: _clock.now(),
        isCountedForReward: true,
        note: note,
      ),
    );

    // Settle reward (idempotent — safe to call multiple times)
    await _rewardService.settle(session);

    final completed = session.copyWith(status: FocusSessionStatus.completed);
    await _sessionRepo.update(completed);
    _currentSession = null;
    return completed.copyWith(status: FocusSessionStatus.saved);
  }

  // ── cancel ─────────────────────────────────────────────────────────────────

  Future<FocusSession> cancel() async {
    final session = _requireSession();
    if (session.status != FocusSessionStatus.running &&
        session.status != FocusSessionStatus.paused) {
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
  /// Called on app launch to re-hydrate the last active session from local DB.
  /// If the session timer has already expired, auto-completes it.

  Future<FocusSession?> restore(String userId) async {
    final activeSessions = await _sessionRepo.findActive(userId);
    if (activeSessions.isEmpty) return null;

    // Pick the most recent active session
    final session = activeSessions.reduce(
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

