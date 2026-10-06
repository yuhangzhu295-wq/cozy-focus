import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/rest_session.dart';
import '../../domain/repositories/i_rest_repository.dart';
import '../../domain/services/focus_clock.dart';
import 'providers.dart';

/// The rest screen's state.
class RestUIState {
  /// The rest in flight, or null.
  final RestSession? session;

  final int elapsedSeconds;

  /// Seconds left of the planned length, or 0 when there is no target.
  final int remainingSeconds;

  final bool isLoading;

  const RestUIState({
    this.session,
    this.elapsedSeconds = 0,
    this.remainingSeconds = 0,
    this.isLoading = false,
  });

  bool get isResting => session?.isRunning == true;

  /// The pet's state while this is on screen.
  ///
  /// Sleep rather than pause: the design has Mochi lying down with its eyes shut,
  /// and `PetVisualState.sleep` is the app's existing name for exactly that. The
  /// rest screen supplies it; the animation layer is not told anything new.
  bool get petShouldRest => isResting;

  RestUIState copyWith({
    RestSession? session,
    int? elapsedSeconds,
    int? remainingSeconds,
    bool? isLoading,
  }) =>
      RestUIState(
        session: session ?? this.session,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        isLoading: isLoading ?? this.isLoading,
      );
}

/// Starts, runs and ends a rest.
///
/// ## The ticker is a display refresh, like the focus one
///
/// Elapsed comes from the timestamps on the session; the one-second timer only
/// asks for a rebuild. Nothing about how long the rest was is decided by how many
/// times the timer fired, so a rest that spans the app being closed comes back
/// with the right length.
class RestController extends StateNotifier<RestUIState> {
  RestController(this._ref) : super(const RestUIState()) {
    restore();
  }

  final Ref _ref;
  Timer? _ticker;

  IRestRepository get _repo => _ref.read(restRepositoryProvider);

  FocusClock get _clock => _ref.read(focusClockProvider);

  String get _userId => _ref.read(currentUserIdProvider);

  /// Picks up a rest that was running when the app closed.
  ///
  /// A rest has no save step, so a rest interrupted by the app being killed is
  /// simply still running: its end time was never written, and the user comes back
  /// to the screen they left.
  Future<void> restore() async {
    final running = await _repo.findRunning(_userId);
    if (!mounted) return;
    state = state.copyWith(session: running, isLoading: false);
    _sync();
  }

  /// Begins a rest of [minutes].
  Future<RestSession> start(int minutes) async {
    // One at a time: starting a second rest while one is running would leave the
    // first without an end time and no way to reach it.
    final existing = await _repo.findRunning(_userId);
    if (existing != null) {
      state = state.copyWith(session: existing);
      _sync();
      return existing;
    }

    final now = _clock.now();
    final session = RestSession(
      id: const Uuid().v4(),
      userId: _userId,
      plannedSeconds: minutes * 60,
      startAt: now,
      createdAt: now,
    );
    await _repo.insert(session);
    if (mounted) {
      state = state.copyWith(session: session);
      _sync();
    }
    return session;
  }

  /// Ends the rest, keeping the time it actually lasted.
  ///
  /// [completed] distinguishes a rest that ran its course from one the user ended
  /// early. Both are kept; the status is what the timeline reads to say which.
  Future<RestSession?> finish({bool completed = true}) async {
    final session = state.session;
    if (session == null || !session.isRunning) return null;

    final ended = session.copyWith(
      endAt: _clock.now(),
      status: completed ? RestStatus.completed : RestStatus.cancelled,
    );
    await _repo.updateSession(ended);
    _ticker?.cancel();
    if (mounted) {
      state = state.copyWith(session: ended);
      _sync();
    }
    return ended;
  }

  /// Clears the finished rest so the screen goes back to its setup state.
  void dismiss() {
    _ticker?.cancel();
    state = const RestUIState();
  }

  void _sync() {
    final session = state.session;
    if (session == null) {
      _ticker?.cancel();
      return;
    }
    final now = _clock.now();
    final elapsed = session.elapsedSecondsAt(now);
    final remaining = session.remainingSecondsAt(now) ?? 0;
    state = state.copyWith(
      elapsedSeconds: elapsed,
      remainingSeconds: remaining,
    );

    if (!session.isRunning) {
      _ticker?.cancel();
      return;
    }
    // A rest that reached its length ends itself, the way a countdown does.
    if (remaining <= 0 && session.plannedSeconds > 0) {
      _ticker?.cancel();
      finish();
      return;
    }
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || state.session?.isRunning != true) {
        _ticker?.cancel();
        return;
      }
      _sync();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final restControllerProvider =
    StateNotifierProvider<RestController, RestUIState>(
  (ref) => RestController(ref),
);
