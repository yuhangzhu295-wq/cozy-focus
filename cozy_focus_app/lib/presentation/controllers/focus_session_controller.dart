import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/focus_session.dart';
import '../../domain/services/focus_clock.dart';
import '../../domain/services/focus_session_engine.dart';
import 'providers.dart';

/// State for the active focus session UI
class FocusSessionUIState {
  final FocusSession? session;
  final int elapsedSeconds;
  final int remainingSeconds;
  final bool isCompleted;
  final PetVisualState petState;
  final String? taskName;
  final String? categoryName;

  const FocusSessionUIState({
    this.session,
    this.elapsedSeconds = 0,
    this.remainingSeconds = 0,
    this.isCompleted = false,
    this.petState = PetVisualState.idle,
    this.taskName,
    this.categoryName,
  });

  FocusSessionUIState copyWith({
    FocusSession? session,
    int? elapsedSeconds,
    int? remainingSeconds,
    bool? isCompleted,
    PetVisualState? petState,
    String? taskName,
    String? categoryName,
  }) {
    return FocusSessionUIState(
      session: session ?? this.session,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
      petState: petState ?? this.petState,
      taskName: taskName ?? this.taskName,
      categoryName: categoryName ?? this.categoryName,
    );
  }
}

/// StateNotifier controlling active session UI lifecycle.
/// Timers are strictly display tickers; elapsed is calculated from timestamps.
class FocusSessionController extends StateNotifier<FocusSessionUIState> {
  final FocusSessionEngine _engine;
  final FocusClock _clock;
  Timer? _ticker;

  FocusSessionController({
    required FocusSessionEngine engine,
    required FocusClock clock,
  })  : _engine = engine,
        _clock = clock,
        super(const FocusSessionUIState()) {
    _syncFromEngine();
  }

  /// Re-sync state from engine & database (called on resume, app start, etc.)
  void _syncFromEngine() {
    final session = _engine.currentSession;
    if (session == null) {
      _ticker?.cancel();
      state = const FocusSessionUIState();
      return;
    }

    final now = _clock.now();
    final elapsed = _computeElapsed(session, now);
    final planned = session.plannedSeconds;
    final remaining = (planned > 0) ? (planned - elapsed).clamp(0, planned) : 0;

    PetVisualState petState;
    switch (session.status) {
      case FocusSessionStatus.running:
        petState = PetVisualState.focus;
        break;
      case FocusSessionStatus.paused:
        petState = PetVisualState.pause;
        break;
      case FocusSessionStatus.restored:
        final wasPaused = session.pauseIntervals.isNotEmpty &&
            session.pauseIntervals.last.pauseEnd == null;
        petState = wasPaused ? PetVisualState.pause : PetVisualState.focus;
        break;
      case FocusSessionStatus.finishing:
      case FocusSessionStatus.completed:
        petState = PetVisualState.celebrate;
        break;
      default:
        petState = PetVisualState.idle;
    }

    state = state.copyWith(
      session: session,
      elapsedSeconds: elapsed,
      remainingSeconds: remaining,
      isCompleted: (session.status == FocusSessionStatus.finishing ||
          session.status == FocusSessionStatus.completed),
      petState: petState,
    );

    final isRunning = session.status == FocusSessionStatus.running ||
        (session.status == FocusSessionStatus.restored &&
            (session.pauseIntervals.isEmpty || session.pauseIntervals.last.pauseEnd != null));
    if (isRunning) {
      _startTicker();
    } else {
      _ticker?.cancel();
    }
  }

  int _computeElapsed(FocusSession session, DateTime now) {
    final effectiveEnd = session.endAt ?? now;
    final raw = effectiveEnd.difference(session.startAt).inSeconds;
    final paused = session.pauseIntervals.fold<int>(0, (acc, p) {
      if (p.pauseEnd != null) {
        return acc + p.pauseEnd!.difference(p.pauseStart).inSeconds;
      } else {
        // Open pause: interval ongoing until now
        return acc + effectiveEnd.difference(p.pauseStart).inSeconds;
      }
    });
    return (raw - paused).clamp(0, raw);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = _engine.currentSession;
      final isRunning = session != null &&
          (session.status == FocusSessionStatus.running ||
              (session.status == FocusSessionStatus.restored &&
                  (session.pauseIntervals.isEmpty || session.pauseIntervals.last.pauseEnd != null)));
      if (!isRunning) {
        _ticker?.cancel();
        return;
      }
      final now = _clock.now();
      final elapsed = _computeElapsed(session, now);
      final planned = session.plannedSeconds;
      final remaining =
          (planned > 0) ? (planned - elapsed).clamp(0, planned) : 0;

      // If countdown reached 0 in Pomodoro/Custom mode, auto complete
      if (planned > 0 && remaining <= 0) {
        _ticker?.cancel();
        completeSession();
        return;
      }

      state = state.copyWith(
        elapsedSeconds: elapsed,
        remainingSeconds: remaining,
      );
    });
  }

  /// Start a new session
  Future<FocusSession> startSession({
    required String userId,
    required int plannedSeconds,
    required FocusMode mode,
    String? categoryId,
    String? taskName,
    String? categoryName,
  }) async {
    final session = await _engine.start(
      userId: userId,
      plannedSeconds: plannedSeconds,
      mode: mode,
      categoryId: categoryId,
    );
    state = state.copyWith(
      taskName: taskName ?? '专注任务',
      categoryName: categoryName ?? '学习',
    );
    _syncFromEngine();
    return session;
  }

  /// Pause current session
  Future<void> pauseSession() async {
    await _engine.pause();
    _syncFromEngine();
  }

  /// Resume current session
  Future<void> resumeSession() async {
    await _engine.resume();
    _syncFromEngine();
  }

  /// Complete current session (enters finishing state)
  Future<FocusSession> completeSession() async {
    _ticker?.cancel();
    final session = await _engine.complete();
    _syncFromEngine();
    return session;
  }

  /// Cancel current session
  Future<void> cancelSession() async {
    _ticker?.cancel();
    await _engine.cancel();
    _syncFromEngine();
  }

  /// Save completed session with note & mood -> generates FocusRecord & settles rewards
  Future<FocusSession> saveSession({String? note}) async {
    final result = await _engine.save(note: note);
    _syncFromEngine();
    return result;
  }

  /// App lifecycle restore hook
  Future<FocusSession?> restoreSession(String userId) async {
    final restored = await _engine.restore(userId);
    if (restored != null) {
      _syncFromEngine();
    }
    return restored;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final focusSessionControllerProvider =
    StateNotifierProvider<FocusSessionController, FocusSessionUIState>((ref) {
  final engine = ref.watch(focusSessionEngineProvider);
  final clock = ref.watch(focusClockProvider);
  return FocusSessionController(engine: engine, clock: clock);
});
