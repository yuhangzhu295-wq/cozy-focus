import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../domain/models/enums.dart';
import '../animations/pet_interaction_spec.dart';
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
  VoidCallback? _onTriggerStroke;
  Timer? _blinkTimer;
  Timer? _earTwitchTimer;
  Timer? _interactCooldownTimer;
  Timer? _strokeCooldownTimer;
  bool _isDisposed = false;
  bool _isMotionActive = false;
  int _listenerCount = 0;

  // --- Growth-driven cadence (presentation only) -----------------------------
  //
  // The growth stage decides how expressive Mochi's face reads: a younger stage
  // blinks less often, a grown one more often. The scales are applied on top of
  // whatever the [scheduler] returns, so a deterministic test scheduler still
  // drives the timing and the growth term stays a pure multiplier.
  //
  // This is a rendering knob. It never touches XP, rewards, sessions or craft.
  double _blinkIntervalScale = 1.0;
  double _earTwitchIntervalScale = 1.0;

  PetMotionController({
    PetVisualState visualState = PetVisualState.idle,
    IPetMotionScheduler? scheduler,
  })  : _visualState = visualState,
        scheduler = scheduler ?? DefaultPetMotionScheduler();

  PetVisualState get visualState => _visualState;

  /// Cadence multiplier currently applied to the blink interval.
  double get blinkIntervalScale => _blinkIntervalScale;

  /// Cadence multiplier currently applied to the ear-twitch interval.
  double get earTwitchIntervalScale => _earTwitchIntervalScale;

  /// Applies a growth stage's cadence multipliers.
  ///
  /// Safe to call on every frame — equal values are a no-op. When the value
  /// actually changes, pending timers are re-armed so the new cadence lands
  /// immediately instead of after the current (stale) interval elapses.
  void updateMotionCadence({
    required double blinkIntervalScale,
    required double earTwitchIntervalScale,
  }) {
    if (_isDisposed) return;
    final blink = _sanitizeScale(blinkIntervalScale);
    final ear = _sanitizeScale(earTwitchIntervalScale);
    if (blink == _blinkIntervalScale && ear == _earTwitchIntervalScale) return;

    _blinkIntervalScale = blink;
    _earTwitchIntervalScale = ear;

    if (_isMotionActive && supportsAmbientMotion) {
      _blinkTimer?.cancel();
      _blinkTimer = null;
      _earTwitchTimer?.cancel();
      _earTwitchTimer = null;
      _scheduleNextBlink();
      _scheduleNextEarTwitch();
    }
  }

  /// Guards a cadence multiplier against `NaN`/`Infinity`/zero/negative input
  /// and against absurd values, so a bad growth config can never stop the
  /// ambient layer or spin it into a busy loop.
  static double _sanitizeScale(double value) {
    if (value.isNaN || value.isInfinite || value <= 0) return 1.0;
    return value.clamp(0.25, 4.0);
  }

  /// Applies a cadence multiplier to a scheduled interval, never returning a
  /// non-positive duration (which `Timer` would treat as an immediate fire).
  static Duration _scaleInterval(Duration base, double scale) {
    final ms = (base.inMilliseconds * scale).round();
    return Duration(milliseconds: ms < 1 ? 1 : ms);
  }

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
  bool get isStrokeCooldownActive => _strokeCooldownTimer != null;

  /// Whether presentation callbacks are currently attached.
  bool get isAttached =>
      _onTriggerBlink != null ||
      _onTriggerEarTwitch != null ||
      _onStartContinuousLoops != null ||
      _onStopContinuousLoops != null ||
      _onTriggerInteract != null ||
      _onTriggerStroke != null;

  /// Observable callbacks for behavioral lifecycle verification.
  bool get hasBlinkCallback => _onTriggerBlink != null;
  bool get hasEarTwitchCallback => _onTriggerEarTwitch != null;
  bool get hasStartContinuousLoopsCallback => _onStartContinuousLoops != null;
  bool get hasStopContinuousLoopsCallback => _onStopContinuousLoops != null;
  bool get hasInteractCallback => _onTriggerInteract != null;
  bool get hasStrokeCallback => _onTriggerStroke != null;

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
    VoidCallback? onTriggerStroke,
  }) {
    if (_isDisposed) return;
    _onTriggerBlink = onTriggerBlink;
    _onTriggerEarTwitch = onTriggerEarTwitch;
    _onStartContinuousLoops = onStartContinuousLoops;
    _onStopContinuousLoops = onStopContinuousLoops;
    _onTriggerInteract = onTriggerInteract;
    _onTriggerStroke = onTriggerStroke;
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
    _cancelStrokeCooldown();
    _onTriggerBlink = null;
    _onTriggerEarTwitch = null;
    _onStartContinuousLoops = null;
    _onStopContinuousLoops = null;
    _onTriggerInteract = null;
    _onTriggerStroke = null;
  }

  /// Triggers a one-shot interact animation in the current base state.
  ///
  /// ## What changed in STAGE 4, and why
  ///
  /// This used to refuse unless `visualState == idle`. That is the defect the
  /// brief names: a user who taps Mochi during a focus session got no response
  /// at all, which reads as broken rather than as considerate. Mochi now
  /// responds in every base state, with a behaviour from
  /// [PetInteractionSpec.table] chosen by that state.
  ///
  /// Two independent guards, both required:
  ///
  /// 1. [PetInteractionPriority.canInteractDuring] — a one-shot celebration
  ///    outranks an interaction, so a poke cannot cut a celebration short.
  /// 2. [PetInteractionSpec.forState] — a state with no spec does not react.
  ///    This is also what refuses re-entrancy, without a special case.
  ///
  /// This still never changes [visualState]. Interact remains a
  /// presentation-only overlay with no business side effects, which is why the
  /// base state cannot be lost.
  bool triggerInteract() {
    if (_isDisposed || _interactCooldownTimer != null) return false;
    if (!PetInteractionPriority.canInteractDuring(_visualState)) return false;
    if (PetInteractionSpec.forState(_visualState) == null) return false;

    _startInteractCooldown();
    _onTriggerInteract?.call();
    return true;
  }

  /// Triggers a one-shot long-press stroke ("轻抚").
  ///
  /// Shares the interact gate — the same two guards, the same base state
  /// untouched — but has its own cooldown, so holding Mochi and then tapping it
  /// are two distinct gestures rather than one being swallowed by the other.
  bool triggerStroke() {
    if (_isDisposed || _strokeCooldownTimer != null) return false;
    if (!PetInteractionPriority.canInteractDuring(_visualState)) return false;
    if (PetInteractionSpec.forState(_visualState) == null) return false;

    _startStrokeCooldown();
    _onTriggerStroke?.call();
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

  void _startStrokeCooldown() {
    _strokeCooldownTimer?.cancel();
    _strokeCooldownTimer = Timer(PetMotionSpec.strokeCooldown, () {
      _strokeCooldownTimer = null;
    });
  }

  void _cancelStrokeCooldown() {
    _strokeCooldownTimer?.cancel();
    _strokeCooldownTimer = null;
  }

  void _scheduleNextBlink() {
    if (_isDisposed || !_isMotionActive || !supportsAmbientMotion) return;
    final interval =
        _scaleInterval(scheduler.nextBlinkInterval(), _blinkIntervalScale);
    _blinkTimer = Timer(interval, () {
      if (_isDisposed || !_isMotionActive || !supportsAmbientMotion) return;
      _onTriggerBlink?.call();
      _scheduleNextBlink();
    });
  }

  void _scheduleNextEarTwitch() {
    if (_isDisposed || !_isMotionActive || !supportsAmbientMotion) return;
    final interval = _scaleInterval(
      scheduler.nextEarTwitchInterval(),
      _earTwitchIntervalScale,
    );
    _earTwitchTimer = Timer(interval, () {
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
