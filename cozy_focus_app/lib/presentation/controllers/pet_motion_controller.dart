import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../domain/models/enums.dart';
import '../animations/pet_motion_spec.dart';

/// Injectable interface for scheduling random triggers like blink and ear twitch,
/// making automated testing deterministic and lifecycle safe.
abstract class IPetMotionScheduler {
  Duration nextBlinkInterval();
  Duration nextEarTwitchInterval();
}

/// Default production scheduler using Random.
class DefaultPetMotionScheduler implements IPetMotionScheduler {
  final Random _random;

  DefaultPetMotionScheduler([Random? random]) : _random = random ?? Random();

  @override
  Duration nextBlinkInterval() {
    final minMs = PetMotionSpec.minBlinkInterval.inMilliseconds;
    final maxMs = PetMotionSpec.maxBlinkInterval.inMilliseconds;
    final ms = minMs + _random.nextInt(maxMs - minMs + 1);
    return Duration(milliseconds: ms);
  }

  @override
  Duration nextEarTwitchInterval() {
    final minMs = PetMotionSpec.minEarTwitchInterval.inMilliseconds;
    final maxMs = PetMotionSpec.maxEarTwitchInterval.inMilliseconds;
    final ms = minMs + _random.nextInt(maxMs - minMs + 1);
    return Duration(milliseconds: ms);
  }
}

/// Centralized controller owning visual state, motion decider contracts, and
/// trigger lifecycles for Mochi.
class PetMotionController extends ChangeNotifier {
  PetVisualState _visualState;
  final IPetMotionScheduler scheduler;
  VoidCallback? _onTriggerBlink;
  VoidCallback? _onTriggerEarTwitch;
  VoidCallback? _onStartContinuousLoops;
  VoidCallback? _onStopContinuousLoops;
  Timer? _blinkTimer;
  Timer? _earTwitchTimer;
  bool _isDisposed = false;
  bool _isMotionActive = false;
  int _listenerCount = 0;

  PetMotionController({
    PetVisualState visualState = PetVisualState.idle,
    IPetMotionScheduler? scheduler,
  })  : _visualState = visualState,
        scheduler = scheduler ?? DefaultPetMotionScheduler();

  PetVisualState get visualState => _visualState;

  bool get isIdle => _visualState == PetVisualState.idle;
  bool get isMotionActive => _isMotionActive;
  bool get isDisposed => _isDisposed;
  int get activeTimerCount =>
      (_blinkTimer != null ? 1 : 0) + (_earTwitchTimer != null ? 1 : 0);

  /// Whether presentation callbacks are currently attached.
  bool get isAttached =>
      _onTriggerBlink != null ||
      _onTriggerEarTwitch != null ||
      _onStartContinuousLoops != null ||
      _onStopContinuousLoops != null;

  /// Observable callbacks for behavioral lifecycle verification.
  bool get hasBlinkCallback => _onTriggerBlink != null;
  bool get hasEarTwitchCallback => _onTriggerEarTwitch != null;
  bool get hasStartContinuousLoopsCallback => _onStartContinuousLoops != null;
  bool get hasStopContinuousLoopsCallback => _onStopContinuousLoops != null;

  /// Total registered listeners on this controller.
  int get listenerCount => _listenerCount;

  @override
  bool get hasListeners => super.hasListeners;

  @override
  void addListener(VoidCallback listener) {
    _listenerCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_listenerCount > 0) {
      _listenerCount--;
    }
    super.removeListener(listener);
  }

  /// Attaches presentation callbacks for discrete motion triggers.
  void attach({
    VoidCallback? onTriggerBlink,
    VoidCallback? onTriggerEarTwitch,
    VoidCallback? onStartContinuousLoops,
    VoidCallback? onStopContinuousLoops,
  }) {
    if (_isDisposed) return;
    _onTriggerBlink = onTriggerBlink;
    _onTriggerEarTwitch = onTriggerEarTwitch;
    _onStartContinuousLoops = onStartContinuousLoops;
    _onStopContinuousLoops = onStopContinuousLoops;
    if (isIdle) {
      startMotion();
    } else {
      stopMotion();
    }
  }

  /// Detaches presentation callbacks and stops active timers without disposing.
  void detach() {
    stopMotion();
    _onTriggerBlink = null;
    _onTriggerEarTwitch = null;
    _onStartContinuousLoops = null;
    _onStopContinuousLoops = null;
  }

  /// Updates the pet visual state, managing motion lifecycle transitions.
  void updateState(PetVisualState state) {
    if (_isDisposed || _visualState == state) return;
    _visualState = state;
    if (isIdle) {
      startMotion();
    } else {
      stopMotion();
    }
    notifyListeners();
  }

  /// Starts idle motion scheduling. Safely cancels any existing timers
  /// to prevent duplicate schedulers.
  void startMotion() {
    if (_isDisposed || !isIdle) return;
    _isMotionActive = true;
    _cancelTimers();
    _onStartContinuousLoops?.call();
    _scheduleNextBlink();
    _scheduleNextEarTwitch();
  }

  /// Stops idle motion scheduling and cleans up all active timers.
  void stopMotion() {
    _isMotionActive = false;
    _cancelTimers();
    _onStopContinuousLoops?.call();
  }

  void _cancelTimers() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
    _earTwitchTimer?.cancel();
    _earTwitchTimer = null;
  }

  void _scheduleNextBlink() {
    if (_isDisposed || !_isMotionActive || !isIdle) return;
    _blinkTimer = Timer(scheduler.nextBlinkInterval(), () {
      if (_isDisposed || !_isMotionActive || !isIdle) return;
      _onTriggerBlink?.call();
      _scheduleNextBlink();
    });
  }

  void _scheduleNextEarTwitch() {
    if (_isDisposed || !_isMotionActive || !isIdle) return;
    _earTwitchTimer = Timer(scheduler.nextEarTwitchInterval(), () {
      if (_isDisposed || !_isMotionActive || !isIdle) return;
      _onTriggerEarTwitch?.call();
      _scheduleNextEarTwitch();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    detach();
    super.dispose();
  }
}
