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
  /// Base states whose ambient micro-motion (breathe / blink / ear twitch /
  /// tail wag) is sustained continuously.
  ///
  /// [PetVisualState.sleep] is excluded because a sleeping pet keeps its eyes
  /// closed and stays still apart from breathing. [PetVisualState.celebrate]
  /// and [PetVisualState.greeting] are excluded because they are one-shot
  /// triggers; the presentation layer re-enables ambient motion for them once
  /// the trigger settles (see [extendAmbientMotionTo]).
  static const Set<PetVisualState> ambientMotionStates = <PetVisualState>{
    PetVisualState.idle,
    PetVisualState.focus,
    PetVisualState.pause,
    PetVisualState.craft,
  };

  PetVisualState _visualState;
  final IPetMotionScheduler scheduler;
  final Set<PetVisualState> _ambientStates = <PetVisualState>{
    ...ambientMotionStates,
  };
  VoidCallback? _onTriggerBlink;
  VoidCallback? _onTriggerEarTwitch;
  VoidCallback? _onStartContinuousLoops;
  VoidCallback? _onStopContinuousLoops;
  VoidCallback? _onTriggerInteract;
  Timer? _blinkTimer;
  Timer? _earTwitchTimer;
  Timer? _interactCooldownTimer;
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
  bool get isFocus => _visualState == PetVisualState.focus;
  bool get isPause => _visualState == PetVisualState.pause;
  bool get isSleep => _visualState == PetVisualState.sleep;
  bool get isCelebrate => _visualState == PetVisualState.celebrate;
  bool get isCraft => _visualState == PetVisualState.craft;
  bool get isGreeting => _visualState == PetVisualState.greeting;
  bool get hasActiveMotion =>
      isIdle ||
      isFocus ||
      isPause ||
      isSleep ||
      isCelebrate ||
      isCraft ||
      isGreeting;
  bool get isMotionActive => _isMotionActive;
  bool get isDisposed => _isDisposed;

  /// Whether ambient micro-motion scheduling is currently permitted for the
  /// active [visualState]. This is the gate for the blink / ear-twitch timers.
  bool get supportsAmbientMotion => _ambientStates.contains(_visualState);

  /// Extends ambient micro-motion to a state outside [ambientMotionStates].
  ///
  /// Used after a one-shot trigger (celebrate / greeting) completes so the pet
  /// returns to base aliveness without leaving its visual state. The extension
  /// is discarded on the next real state transition.
  void extendAmbientMotionTo(PetVisualState state) {
    if (_isDisposed) return;
    if (!_ambientStates.add(state)) return;
    if (supportsAmbientMotion) startMotion();
  }

  void _resetAmbientExtensions() {
    _ambientStates.removeWhere(
      (state) => !ambientMotionStates.contains(state),
    );
  }

  int get activeTimerCount =>
      (_blinkTimer != null ? 1 : 0) + (_earTwitchTimer != null ? 1 : 0);
  bool get isInteractCooldownActive => _interactCooldownTimer != null;

  /// Whether presentation callbacks are currently attached.
  bool get isAttached =>
      _onTriggerBlink != null ||
      _onTriggerEarTwitch != null ||
      _onStartContinuousLoops != null ||
      _onStopContinuousLoops != null ||
      _onTriggerInteract != null;

  /// Observable callbacks for behavioral lifecycle verification.
  bool get hasBlinkCallback => _onTriggerBlink != null;
  bool get hasEarTwitchCallback => _onTriggerEarTwitch != null;
  bool get hasStartContinuousLoopsCallback => _onStartContinuousLoops != null;
  bool get hasStopContinuousLoopsCallback => _onStopContinuousLoops != null;
  bool get hasInteractCallback => _onTriggerInteract != null;

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
    VoidCallback? onTriggerInteract,
  }) {
    if (_isDisposed) return;
    _onTriggerBlink = onTriggerBlink;
    _onTriggerEarTwitch = onTriggerEarTwitch;
    _onStartContinuousLoops = onStartContinuousLoops;
    _onStopContinuousLoops = onStopContinuousLoops;
    _onTriggerInteract = onTriggerInteract;
    if (supportsAmbientMotion) {
      startMotion();
    } else {
      stopMotion();
    }
  }

  /// Detaches presentation callbacks and stops active timers without disposing.
  void detach() {
    stopMotion();
    _cancelInteractCooldown();
    _onTriggerBlink = null;
    _onTriggerEarTwitch = null;
    _onStartContinuousLoops = null;
    _onStopContinuousLoops = null;
    _onTriggerInteract = null;
  }

  /// Triggers a one-shot interact animation only while Mochi is idle.
  ///
  /// This never changes [visualState]; interact remains a presentation-only
  /// affordance with no business side effects.
  bool triggerInteract() {
    if (_isDisposed || _interactCooldownTimer != null) return false;
    if (_visualState != PetVisualState.idle) return false;

    _startInteractCooldown();
    _onTriggerInteract?.call();
    return true;
  }

  /// Updates the pet visual state, managing motion lifecycle transitions.
  void updateState(PetVisualState state) {
    if (_isDisposed || _visualState == state) return;
    _visualState = state;
    _resetAmbientExtensions();
    if (supportsAmbientMotion) {
      startMotion();
    } else {
      stopMotion();
    }
    notifyListeners();
  }

  /// Starts ambient motion scheduling. Safely cancels any existing timers
  /// to prevent duplicate schedulers.
  void startMotion() {
    if (_isDisposed || !supportsAmbientMotion) return;
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

  void _startInteractCooldown() {
    _interactCooldownTimer?.cancel();
    _interactCooldownTimer = Timer(PetMotionSpec.interactCooldown, () {
      _interactCooldownTimer = null;
    });
  }

  void _cancelInteractCooldown() {
    _interactCooldownTimer?.cancel();
    _interactCooldownTimer = null;
  }

  void _scheduleNextBlink() {
    if (_isDisposed || !_isMotionActive || !supportsAmbientMotion) return;
    _blinkTimer = Timer(scheduler.nextBlinkInterval(), () {
      if (_isDisposed || !_isMotionActive || !supportsAmbientMotion) return;
      _onTriggerBlink?.call();
      _scheduleNextBlink();
    });
  }

  void _scheduleNextEarTwitch() {
    if (_isDisposed || !_isMotionActive || !supportsAmbientMotion) return;
    _earTwitchTimer = Timer(scheduler.nextEarTwitchInterval(), () {
      if (_isDisposed || !_isMotionActive || !supportsAmbientMotion) return;
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
