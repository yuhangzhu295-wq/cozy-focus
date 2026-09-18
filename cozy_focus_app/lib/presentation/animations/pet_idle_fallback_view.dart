import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/enums.dart';
import '../controllers/pet_motion_controller.dart';
import '../theme/app_theme.dart';
import 'pet_motion_spec.dart';

/// Truthful Flutter idle-motion fallback renderer for Mochi.
/// Implements:
/// - Idle Breathe (subtle scale 1.0 -> 1.018, vertical ~2px, 3.2s)
/// - Idle Sway (rotation +-2 deg, 3.0s)
/// - Blink (100-180ms, 2-6s intervals, deterministic scheduler support)
/// - Ear Twitch (4-8s intervals, +-3 deg, 220ms)
/// - Tail Idle (+-5 deg, 2.4s)
/// - Accessibility / Reduced Motion support
///
/// Strictly gated to [PetVisualState.idle]:
/// - In Phase 6B: Focus, Pause, and Sleep each have dedicated subtle motion loops.
/// - Idle loop controllers and timers only run when in [PetVisualState.idle].
/// - Outside active motion states, other states (e.g. celebrate, craft) remain static.
/// - Switching states stops inactive loops; returning resumes without leaks.
class PetIdleFallbackView extends StatefulWidget {
  final PetVisualState visualState;
  final double size;
  final PetMotionController? controller;
  final IPetMotionScheduler? scheduler;
  final Widget? accessory;
  final double? focusProgress;
  final double? craftProgress;
  final bool showStateBadge;

  const PetIdleFallbackView({
    super.key,
    required this.visualState,
    this.size = 140,
    this.controller,
    this.scheduler,
    this.accessory,
    this.focusProgress,
    this.craftProgress,
    this.showStateBadge = true,
  });

  @override
  State<PetIdleFallbackView> createState() => PetIdleFallbackViewState();
}

class PetIdleFallbackViewState extends State<PetIdleFallbackView>
    with TickerProviderStateMixin {
  PetMotionController? _internalController;
  PetMotionController get _effectiveController =>
      widget.controller ?? _internalController!;

  // Continuous loop controllers
  late AnimationController _breatheController;
  late Animation<double> _breatheScaleAnimation;
  late Animation<double> _breatheDyAnimation;

  late AnimationController _swayController;
  late Animation<double> _swayAnimation;

  late AnimationController _tailController;
  late Animation<double> _tailAnimation;

  // One-shot controllers
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  late AnimationController _earTwitchController;
  late Animation<double> _earTwitchAnimation;

  // Phase 6B: State-specific controllers
  late AnimationController _focusController;
  late Animation<double> _focusScaleAnimation;
  late Animation<double> _focusBreatheDyAnimation;
  late Animation<double> _focusAngleAnimation;

  late AnimationController _pauseController;
  late Animation<double> _pauseBreatheDyAnimation;

  late AnimationController _sleepController;
  late Animation<double> _sleepBreatheDyAnimation;
  late Animation<double> _sleepZzzDyAnimation;
  late Animation<double> _sleepZzzOpacityAnimation;

  // Phase 6C: Celebrate, Craft, Greeting controllers
  late AnimationController _celebrateController;
  late Animation<double> _celebrateScaleAnimation;
  late Animation<double> _celebrateBounceDyAnimation;
  late Animation<double> _celebrateAngleAnimation;

  late AnimationController _craftController;
  late Animation<double> _craftScaleAnimation;
  late Animation<double> _craftBreatheDyAnimation;
  late Animation<double> _craftTiltAngleAnimation;

  late AnimationController _greetingController;
  late Animation<double> _greetingScaleAnimation;
  late Animation<double> _greetingBounceDyAnimation;
  late Animation<double> _greetingTiltAngleAnimation;

  // Phase 6D: one-shot idle interact motion.
  late AnimationController _interactController;
  late Animation<double> _interactDyAnimation;
  late Animation<double> _interactScaleAnimation;
  late Animation<double> _interactBodyTiltAnimation;
  late Animation<double> _interactEarTiltAnimation;
  late Animation<double> _interactTailTiltAnimation;
  late Animation<double> _interactEyeSquintAnimation;
  Timer? _interactFlashTimer;
  bool _interactFlash = false;
  bool _reduceMotion = false;

  /// Testing accessors to observe animation controllers and their cleanup status
  @visibleForTesting
  AnimationController get breatheController => _breatheController;
  @visibleForTesting
  AnimationController get swayController => _swayController;
  @visibleForTesting
  AnimationController get tailController => _tailController;
  @visibleForTesting
  AnimationController get blinkController => _blinkController;
  @visibleForTesting
  AnimationController get earTwitchController => _earTwitchController;
  @visibleForTesting
  AnimationController get focusController => _focusController;
  @visibleForTesting
  AnimationController get pauseController => _pauseController;
  @visibleForTesting
  AnimationController get sleepController => _sleepController;
  @visibleForTesting
  AnimationController get celebrateController => _celebrateController;
  @visibleForTesting
  AnimationController get craftController => _craftController;
  @visibleForTesting
  AnimationController get greetingController => _greetingController;
  @visibleForTesting
  AnimationController get interactController => _interactController;
  @visibleForTesting
  bool get isInteractFlashActive => _interactFlash;
  @visibleForTesting
  double get interactDy => _interactDyAnimation.value;
  @visibleForTesting
  double get interactScale => _interactScaleAnimation.value;
  @visibleForTesting
  double get interactBodyTilt => _interactBodyTiltAnimation.value;
  @visibleForTesting
  double get interactEarTilt => _interactEarTiltAnimation.value;
  @visibleForTesting
  double get interactTailTilt => _interactTailTiltAnimation.value;
  @visibleForTesting
  double get interactEyeScaleY => _interactEyeSquintAnimation.value;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = PetMotionController(
        visualState: widget.visualState,
        scheduler: widget.scheduler,
      );
    }
    _effectiveController.addListener(_onControllerStateChanged);

    // 1. Idle Breathe
    _breatheController = AnimationController(
      vsync: this,
      duration: PetMotionSpec.breatheCycle,
    );
    _breatheScaleAnimation = Tween<double>(
      begin: PetMotionSpec.breatheScaleMin,
      end: PetMotionSpec.breatheScaleMax,
    ).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOutSine),
    );
    _breatheDyAnimation = Tween<double>(
      begin: 0.0,
      end: PetMotionSpec.breatheDyMax,
    ).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOutSine),
    );

    // 2. Idle Sway
    _swayController = AnimationController(
      vsync: this,
      duration: PetMotionSpec.swayCycle,
    );
    _swayAnimation = Tween<double>(
      begin: -PetMotionSpec.swayAngleDegrees * math.pi / 180,
      end: PetMotionSpec.swayAngleDegrees * math.pi / 180,
    ).animate(
      CurvedAnimation(parent: _swayController, curve: Curves.easeInOutSine),
    );

    // 3. Tail Idle
    _tailController = AnimationController(
      vsync: this,
      duration: PetMotionSpec.tailCycle,
    );
    _tailAnimation = Tween<double>(
      begin: -PetMotionSpec.tailIdleAngleDegrees * math.pi / 180,
      end: PetMotionSpec.tailIdleAngleDegrees * math.pi / 180,
    ).animate(
      CurvedAnimation(parent: _tailController, curve: Curves.easeInOutSine),
    );

    // 4. Blink
    _blinkController = AnimationController(
      vsync: this,
      duration: PetMotionSpec.blinkDuration,
    );
    _blinkAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 0.05), weight: 50),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.05, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    // 5. Ear Twitch
    _earTwitchController = AnimationController(
      vsync: this,
      duration: PetMotionSpec.earTwitchDuration,
    );
    _earTwitchAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: PetMotionSpec.earTwitchAngleDegrees * math.pi / 180,
        ),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: PetMotionSpec.earTwitchAngleDegrees * math.pi / 180,
          end: -PetMotionSpec.earTwitchAngleDegrees * 0.5 * math.pi / 180,
        ),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -PetMotionSpec.earTwitchAngleDegrees * 0.5 * math.pi / 180,
          end: 0.0,
        ),
        weight: 30,
      ),
    ]).animate(
      CurvedAnimation(parent: _earTwitchController, curve: Curves.easeInOut),
    );

    // 6. Phase 6B: Focus Work Controller
    _focusController = AnimationController(
      vsync: this,
      duration: PetMotionSpec.focusWorkCycle,
    );
    _focusScaleAnimation = Tween<double>(
      begin: 1.0,
      end: PetMotionSpec.focusScaleMax,
    ).animate(
      CurvedAnimation(parent: _focusController, curve: Curves.easeInOutSine),
    );
    _focusBreatheDyAnimation = Tween<double>(
      begin: 0.0,
      end: PetMotionSpec.focusBreatheDyMax,
    ).animate(
      CurvedAnimation(parent: _focusController, curve: Curves.easeInOutSine),
    );
    _focusAngleAnimation = Tween<double>(
      begin: -PetMotionSpec.focusWorkMicroAngleDegrees * math.pi / 180,
      end: PetMotionSpec.focusWorkMicroAngleDegrees * math.pi / 180,
    ).animate(
      CurvedAnimation(parent: _focusController, curve: Curves.easeInOutSine),
    );

    // 7. Phase 6B: Pause Controller
    _pauseController = AnimationController(
      vsync: this,
      duration: PetMotionSpec.pauseBreatheCycle,
    );
    _pauseBreatheDyAnimation = Tween<double>(
      begin: 0.0,
      end: PetMotionSpec.pauseBreatheDyMax,
    ).animate(
      CurvedAnimation(parent: _pauseController, curve: Curves.easeInOutSine),
    );

    // 8. Phase 6B: Sleep Controller
    _sleepController = AnimationController(
      vsync: this,
      duration: PetMotionSpec.sleepBreatheCycle,
    );
    _sleepBreatheDyAnimation = Tween<double>(
      begin: 0.0,
      end: PetMotionSpec.sleepBreatheDyMax,
    ).animate(
      CurvedAnimation(parent: _sleepController, curve: Curves.easeInOutSine),
    );
    _sleepZzzDyAnimation = Tween<double>(
      begin: 0.0,
      end: PetMotionSpec.sleepZzzDyMax,
    ).animate(
      CurvedAnimation(parent: _sleepController, curve: Curves.easeInOutSine),
    );
    _sleepZzzOpacityAnimation = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _sleepController, curve: Curves.easeInOutSine),
    );

    // 9. Phase 6C: Celebrate Controller
    _celebrateController = AnimationController(
      vsync: this,
      duration: PetMotionSpec.celebrateCycle,
    );
    _celebrateBounceDyAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween:
            Tween<double>(begin: 0.0, end: PetMotionSpec.celebrateBounceDyMax),
        weight: 35,
      ),
      TweenSequenceItem(
        tween:
            Tween<double>(begin: PetMotionSpec.celebrateBounceDyMax, end: 0.0),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.0),
        weight: 30,
      ),
    ]).animate(
      CurvedAnimation(parent: _celebrateController, curve: Curves.easeInOut),
    );
    _celebrateScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: PetMotionSpec.celebrateScaleMax),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: PetMotionSpec.celebrateScaleMax, end: 1.0),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 30,
      ),
    ]).animate(
      CurvedAnimation(parent: _celebrateController, curve: Curves.easeInOut),
    );
    _celebrateAngleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: PetMotionSpec.celebrateAngleDegrees * math.pi / 180,
        ),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: PetMotionSpec.celebrateAngleDegrees * math.pi / 180,
          end: -PetMotionSpec.celebrateAngleDegrees * math.pi / 180,
        ),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -PetMotionSpec.celebrateAngleDegrees * math.pi / 180,
          end: 0.0,
        ),
        weight: 40,
      ),
    ]).animate(
      CurvedAnimation(parent: _celebrateController, curve: Curves.easeInOut),
    );

    // 10. Phase 6C: Craft Controller
    _craftController = AnimationController(
      vsync: this,
      duration: PetMotionSpec.craftCycle,
    );
    _craftBreatheDyAnimation = Tween<double>(
      begin: 0.0,
      end: PetMotionSpec.craftBreatheDyMax,
    ).animate(
      CurvedAnimation(parent: _craftController, curve: Curves.easeInOutSine),
    );
    _craftScaleAnimation = Tween<double>(
      begin: 1.0,
      end: PetMotionSpec.craftScaleMax,
    ).animate(
      CurvedAnimation(parent: _craftController, curve: Curves.easeInOutSine),
    );
    _craftTiltAngleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: PetMotionSpec.craftTiltAngleDegrees * math.pi / 180,
        ),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: PetMotionSpec.craftTiltAngleDegrees * math.pi / 180,
          end: -PetMotionSpec.craftTiltAngleDegrees * 0.5 * math.pi / 180,
        ),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -PetMotionSpec.craftTiltAngleDegrees * 0.5 * math.pi / 180,
          end: 0.0,
        ),
        weight: 30,
      ),
    ]).animate(
      CurvedAnimation(parent: _craftController, curve: Curves.easeInOut),
    );

    // 11. Phase 6C: Greeting Controller
    _greetingController = AnimationController(
      vsync: this,
      duration: PetMotionSpec.greetingCycle,
    );
    _greetingBounceDyAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween:
            Tween<double>(begin: 0.0, end: PetMotionSpec.greetingBounceDyMax),
        weight: 40,
      ),
      TweenSequenceItem(
        tween:
            Tween<double>(begin: PetMotionSpec.greetingBounceDyMax, end: 0.0),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.0),
        weight: 20,
      ),
    ]).animate(
      CurvedAnimation(parent: _greetingController, curve: Curves.easeInOut),
    );
    _greetingScaleAnimation = Tween<double>(
      begin: 1.0,
      end: PetMotionSpec.greetingScaleMax,
    ).animate(
      CurvedAnimation(parent: _greetingController, curve: Curves.easeInOutSine),
    );
    _greetingTiltAngleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: PetMotionSpec.greetingTiltAngleDegrees * math.pi / 180,
        ),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: PetMotionSpec.greetingTiltAngleDegrees * math.pi / 180,
          end: -PetMotionSpec.greetingTiltAngleDegrees * 0.5 * math.pi / 180,
        ),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -PetMotionSpec.greetingTiltAngleDegrees * 0.5 * math.pi / 180,
          end: 0.0,
        ),
        weight: 30,
      ),
    ]).animate(
      CurvedAnimation(parent: _greetingController, curve: Curves.easeInOut),
    );

    // 12. Phase 6D: Interact Controller
    _interactController = AnimationController(
      vsync: this,
      duration: PetMotionSpec.interactDuration,
    );
    _interactController.addStatusListener(_onInteractStatusChanged);
    _interactDyAnimation = _interactSequence(
      0.0,
      PetMotionSpec.interactBounceDyMax,
      PetMotionSpec.interactBounceDyMax,
      0.0,
      Curves.easeInOutSine,
    );
    _interactScaleAnimation = _interactSequence(
      1.0,
      PetMotionSpec.interactScaleMax,
      PetMotionSpec.interactScaleMax,
      1.0,
      Curves.easeInOutSine,
    );
    _interactBodyTiltAnimation = _interactSequence(
      0.0,
      PetMotionSpec.interactTiltDeg * math.pi / 180,
      -PetMotionSpec.interactTiltDeg * math.pi / 180,
      0.0,
      Curves.easeInOut,
    );
    _interactEarTiltAnimation = _interactSequence(
      0.0,
      PetMotionSpec.interactEarTiltDeg * math.pi / 180,
      -PetMotionSpec.interactEarTiltDeg * math.pi / 180,
      0.0,
      Curves.easeInOut,
    );
    _interactTailTiltAnimation = _interactSequence(
      0.0,
      PetMotionSpec.interactTailTiltDeg * math.pi / 180,
      -PetMotionSpec.interactTailTiltDeg * math.pi / 180,
      0.0,
      Curves.easeInOut,
    );
    _interactEyeSquintAnimation = _interactSequence(
      1.0,
      PetMotionSpec.interactEyeSquintMin,
      PetMotionSpec.interactEyeSquintMin,
      1.0,
      Curves.easeInOutSine,
    );

    _effectiveController.attach(
      onTriggerBlink: _onBlinkTrigger,
      onTriggerEarTwitch: _onEarTwitchTrigger,
      onStartContinuousLoops: _startContinuousLoops,
      onStopContinuousLoops: _stopAllAnimations,
      onTriggerInteract: _onInteractTrigger,
    );

    _syncStateAnimations(widget.visualState);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduceMotion == reduceMotion) return;

    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _effectiveController.stopMotion();
      return;
    }

    _syncStateAnimations(_effectiveController.visualState);
    if (_effectiveController.isIdle) {
      _effectiveController.startMotion();
    }
  }

  Animation<double> _interactSequence(
    double begin,
    double peak,
    double settle,
    double end,
    Curve curve,
  ) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: begin,
          end: peak,
        ).chain(CurveTween(curve: curve)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: peak,
          end: settle,
        ).chain(CurveTween(curve: curve)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: settle,
          end: end,
        ).chain(CurveTween(curve: curve)),
        weight: 30,
      ),
    ]).animate(_interactController);
  }

  void _onInteractStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _interactController.reset();
    }
  }

  void _startContinuousLoops() {
    if (!_breatheController.isAnimating) {
      _breatheController.repeat(reverse: true);
    }
    if (!_swayController.isAnimating) {
      _swayController.repeat(reverse: true);
    }
    if (!_tailController.isAnimating) {
      _tailController.repeat(reverse: true);
    }
  }

  void _stopAllAnimations() {
    if (_breatheController.isAnimating) _breatheController.stop();
    _breatheController.reset();

    if (_swayController.isAnimating) _swayController.stop();
    _swayController.reset();

    if (_tailController.isAnimating) _tailController.stop();
    _tailController.reset();

    if (_blinkController.isAnimating) _blinkController.stop();
    _blinkController.reset();

    if (_earTwitchController.isAnimating) _earTwitchController.stop();
    _earTwitchController.reset();

    if (_focusController.isAnimating) _focusController.stop();
    _focusController.reset();

    if (_pauseController.isAnimating) _pauseController.stop();
    _pauseController.reset();

    if (_sleepController.isAnimating) _sleepController.stop();
    _sleepController.reset();

    if (_celebrateController.isAnimating) _celebrateController.stop();
    _celebrateController.reset();

    if (_craftController.isAnimating) _craftController.stop();
    _craftController.reset();

    if (_greetingController.isAnimating) _greetingController.stop();
    _greetingController.reset();

    if (_interactController.isAnimating) _interactController.stop();
    _interactController.reset();
    _interactFlashTimer?.cancel();
    _interactFlashTimer = null;
    _interactFlash = false;
  }

  void _syncStateAnimations(PetVisualState state) {
    if (_reduceMotion) {
      _effectiveController.stopMotion();
      return;
    }

    // If not idle, stop idle continuous loops and one-shot controllers
    if (state != PetVisualState.idle) {
      if (_breatheController.isAnimating) _breatheController.stop();
      _breatheController.reset();
      if (_swayController.isAnimating) _swayController.stop();
      _swayController.reset();
      if (_tailController.isAnimating) _tailController.stop();
      _tailController.reset();
      if (_blinkController.isAnimating) _blinkController.stop();
      _blinkController.reset();
      if (_earTwitchController.isAnimating) _earTwitchController.stop();
      _earTwitchController.reset();
    } else {
      _startContinuousLoops();
    }

    // Focus
    if (state == PetVisualState.focus) {
      if (!_focusController.isAnimating) {
        _focusController.repeat(reverse: true);
      }
    } else {
      if (_focusController.isAnimating) _focusController.stop();
      _focusController.reset();
    }

    // Pause
    if (state == PetVisualState.pause) {
      if (!_pauseController.isAnimating) {
        _pauseController.repeat(reverse: true);
      }
    } else {
      if (_pauseController.isAnimating) _pauseController.stop();
      _pauseController.reset();
    }

    // Sleep
    if (state == PetVisualState.sleep) {
      if (!_sleepController.isAnimating) {
        _sleepController.repeat(reverse: true);
      }
    } else {
      if (_sleepController.isAnimating) _sleepController.stop();
      _sleepController.reset();
    }

    // Celebrate
    if (state == PetVisualState.celebrate) {
      if (!_celebrateController.isAnimating) {
        _celebrateController.repeat();
      }
    } else {
      if (_celebrateController.isAnimating) _celebrateController.stop();
      _celebrateController.reset();
    }

    // Craft
    if (state == PetVisualState.craft) {
      if (!_craftController.isAnimating) {
        _craftController.repeat(reverse: true);
      }
    } else {
      if (_craftController.isAnimating) _craftController.stop();
      _craftController.reset();
    }

    // Greeting
    if (state == PetVisualState.greeting) {
      if (!_greetingController.isAnimating) {
        _greetingController.repeat();
      }
    } else {
      if (_greetingController.isAnimating) _greetingController.stop();
      _greetingController.reset();
    }
  }

  void _onBlinkTrigger() {
    if (!mounted ||
        _reduceMotion ||
        _effectiveController.visualState != PetVisualState.idle) {
      return;
    }
    _blinkController.forward(from: 0.0);
  }

  void _onEarTwitchTrigger() {
    if (!mounted ||
        _reduceMotion ||
        _effectiveController.visualState != PetVisualState.idle) {
      return;
    }
    _earTwitchController.forward(from: 0.0);
  }

  void _onInteractTrigger() {
    if (!mounted || _effectiveController.visualState != PetVisualState.idle) {
      return;
    }

    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _interactFlashTimer?.cancel();
      setState(() => _interactFlash = true);
      _interactFlashTimer = Timer(const Duration(milliseconds: 80), () {
        if (mounted) {
          setState(() => _interactFlash = false);
        }
        _interactFlashTimer = null;
      });
      return;
    }

    _interactController.forward(from: 0.0);
  }

  void _onControllerStateChanged() {
    if (!mounted) return;
    _syncStateAnimations(_effectiveController.visualState);
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant PetIdleFallbackView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerStateChanged);
      if (oldWidget.controller == null) {
        _internalController?.dispose();
        _internalController = null;
      } else {
        oldWidget.controller?.detach();
      }

      if (widget.controller == null) {
        _internalController = PetMotionController(
          visualState: widget.visualState,
          scheduler: widget.scheduler,
        );
      }
      _effectiveController.addListener(_onControllerStateChanged);

      _effectiveController.attach(
        onTriggerBlink: _onBlinkTrigger,
        onTriggerEarTwitch: _onEarTwitchTrigger,
        onStartContinuousLoops: _startContinuousLoops,
        onStopContinuousLoops: _stopAllAnimations,
        onTriggerInteract: _onInteractTrigger,
      );
      if (_reduceMotion) {
        _effectiveController.stopMotion();
      }
    }

    if (oldWidget.visualState != widget.visualState) {
      _effectiveController.updateState(widget.visualState);
      _syncStateAnimations(widget.visualState);
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_onControllerStateChanged);
    if (_internalController != null) {
      _internalController!.dispose();
      _internalController = null;
    } else {
      widget.controller?.detach();
    }

    _breatheController.dispose();
    _swayController.dispose();
    _tailController.dispose();
    _blinkController.dispose();
    _earTwitchController.dispose();
    _focusController.dispose();
    _pauseController.dispose();
    _sleepController.dispose();
    _celebrateController.dispose();
    _craftController.dispose();
    _greetingController.dispose();
    _interactFlashTimer?.cancel();
    _interactController.removeStatusListener(_onInteractStatusChanged);
    _interactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentVisualState = _effectiveController.visualState;
    final isIdle = currentVisualState == PetVisualState.idle;
    final isFocus = currentVisualState == PetVisualState.focus;
    final isPause = currentVisualState == PetVisualState.pause;
    final isSleep = currentVisualState == PetVisualState.sleep;
    final isCelebrate = currentVisualState == PetVisualState.celebrate;
    final isCraft = currentVisualState == PetVisualState.craft;
    final isGreeting = currentVisualState == PetVisualState.greeting;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final config = _getConfig(currentVisualState);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _breatheController,
        _swayController,
        _tailController,
        _blinkController,
        _earTwitchController,
        _focusController,
        _pauseController,
        _sleepController,
        _celebrateController,
        _craftController,
        _greetingController,
        _interactController,
      ]),
      builder: (context, child) {
        // Compose transforms: state-gated and respects reduced motion
        double scale = 1.0;
        double dy = 0.0;
        double rotation = 0.0;
        double earRotation = 0.0;
        double tailRotation = 0.0;
        double eyeScaleY = 1.0;

        if (isIdle) {
          scale = reduceMotion ? 1.0 : _breatheScaleAnimation.value;
          dy = reduceMotion
              ? (PetMotionSpec.breatheReducedDyMax * 0.5)
              : _breatheDyAnimation.value;
          rotation = reduceMotion ? 0.0 : _swayAnimation.value;
          earRotation = reduceMotion ? 0.0 : _earTwitchAnimation.value;
          tailRotation = reduceMotion ? 0.0 : _tailAnimation.value;
          eyeScaleY = reduceMotion ? 1.0 : _blinkAnimation.value;
        } else if (isFocus) {
          scale = reduceMotion ? 1.0 : _focusScaleAnimation.value;
          dy = reduceMotion
              ? (PetMotionSpec.focusBreatheDyMax * 0.5)
              : _focusBreatheDyAnimation.value;
          rotation = reduceMotion ? 0.0 : _focusAngleAnimation.value;
          eyeScaleY = 1.0; // Steady focused gaze
        } else if (isPause) {
          scale = 1.0;
          dy = reduceMotion
              ? (PetMotionSpec.pauseBreatheDyMax * 0.5)
              : _pauseBreatheDyAnimation.value;
          rotation = 0.0;
          eyeScaleY = 1.0; // Restful gaze
        } else if (isSleep) {
          scale = 1.0;
          dy = reduceMotion
              ? (PetMotionSpec.sleepBreatheDyMax * 0.5)
              : _sleepBreatheDyAnimation.value;
          rotation = 0.0;
          eyeScaleY = 0.10; // Eyes closed in sleep
        } else if (isCelebrate) {
          scale = reduceMotion ? 1.0 : _celebrateScaleAnimation.value;
          dy = reduceMotion
              ? (PetMotionSpec.celebrateBounceDyMax * 0.5)
              : _celebrateBounceDyAnimation.value;
          rotation = reduceMotion ? 0.0 : _celebrateAngleAnimation.value;
          earRotation = reduceMotion ? 0.0 : _celebrateAngleAnimation.value;
          tailRotation = reduceMotion ? 0.0 : -_celebrateAngleAnimation.value;
          eyeScaleY = 1.0; // Bright joyful gaze
        } else if (isCraft) {
          scale = reduceMotion ? 1.0 : _craftScaleAnimation.value;
          dy = reduceMotion
              ? (PetMotionSpec.craftBreatheDyMax * 0.5)
              : _craftBreatheDyAnimation.value;
          rotation = reduceMotion ? 0.0 : _craftTiltAngleAnimation.value;
          earRotation = 0.0;
          tailRotation = 0.0;
          eyeScaleY = 1.0; // Attentive crafting gaze
        } else if (isGreeting) {
          scale = reduceMotion ? 1.0 : _greetingScaleAnimation.value;
          dy = reduceMotion
              ? (PetMotionSpec.greetingBounceDyMax * 0.5)
              : _greetingBounceDyAnimation.value;
          rotation = reduceMotion ? 0.0 : _greetingTiltAngleAnimation.value;
          earRotation = reduceMotion ? 0.0 : _greetingTiltAngleAnimation.value;
          tailRotation = 0.0;
          eyeScaleY = 1.0; // Welcoming cheerful gaze
        }

        if (isIdle && _interactFlash) {
          scale = 1.02;
          dy = -1.0;
        } else if (isIdle && !reduceMotion && _interactController.isAnimating) {
          scale = _interactScaleAnimation.value;
          dy = _interactDyAnimation.value;
          rotation = _interactBodyTiltAnimation.value;
          earRotation = _interactEarTiltAnimation.value;
          tailRotation = _interactTailTiltAnimation.value;
          eyeScaleY = _interactEyeSquintAnimation.value;
        }

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Transform.rotate(
              angle: rotation,
              alignment: Alignment.bottomCenter,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: config.bgTint,
                  border: Border.all(color: config.borderColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: config.borderColor.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Sleep Zzz floating animation indicator
                    if (isSleep)
                      Positioned(
                        top: widget.size * 0.14,
                        right: widget.size * 0.20,
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            reduceMotion ? 0.0 : _sleepZzzDyAnimation.value,
                          ),
                          child: Opacity(
                            opacity: reduceMotion
                                ? 1.0
                                : _sleepZzzOpacityAnimation.value,
                            child: Text(
                              'Zzz',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: config.iconColor.withValues(alpha: 0.85),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Tail
                    Positioned(
                      bottom: widget.size * 0.25,
                      right: widget.size * 0.16,
                      child: Transform.rotate(
                        angle: tailRotation,
                        alignment: Alignment.bottomLeft,
                        child: Icon(
                          Icons.pets,
                          size: widget.size * 0.20,
                          color: config.iconColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    // Ears
                    Positioned(
                      top: widget.size * 0.18,
                      child: SizedBox(
                        width: widget.size * 0.65,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left ear
                            Transform.rotate(
                              angle: -earRotation,
                              alignment: Alignment.bottomRight,
                              child: Container(
                                width: widget.size * 0.14,
                                height: widget.size * 0.18,
                                decoration: BoxDecoration(
                                  color:
                                      config.iconColor.withValues(alpha: 0.7),
                                  borderRadius:
                                      BorderRadius.circular(widget.size * 0.08),
                                ),
                              ),
                            ),
                            // Right ear (twitches)
                            Transform.rotate(
                              angle: earRotation,
                              alignment: Alignment.bottomLeft,
                              child: Container(
                                width: widget.size * 0.14,
                                height: widget.size * 0.18,
                                decoration: BoxDecoration(
                                  color:
                                      config.iconColor.withValues(alpha: 0.7),
                                  borderRadius:
                                      BorderRadius.circular(widget.size * 0.08),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Face / Eyes / Mouth (Mochi Character)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Eyes
                        SizedBox(
                          width: widget.size * 0.38,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Left Eye
                              Transform.scale(
                                scaleY: eyeScaleY,
                                alignment: Alignment.center,
                                child: Container(
                                  width: widget.size * 0.085,
                                  height: widget.size * 0.085,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: config.iconColor,
                                  ),
                                ),
                              ),
                              // Right Eye
                              Transform.scale(
                                scaleY: eyeScaleY,
                                alignment: Alignment.center,
                                child: Container(
                                  width: widget.size * 0.085,
                                  height: widget.size * 0.085,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: config.iconColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: widget.size * 0.04),
                        // Nose / Mouth
                        Icon(
                          Icons.favorite_rounded,
                          size: widget.size * 0.08,
                          color: config.iconColor.withValues(alpha: 0.65),
                        ),
                      ],
                    ),
                    // Optional accessory
                    if (widget.accessory != null) widget.accessory!,
                    if (widget.showStateBadge)
                      Positioned(
                        bottom: widget.size * 0.10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(config.stateIcon,
                                  size: 13, color: config.iconColor),
                              const SizedBox(width: 4),
                              Text(
                                config.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: config.iconColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _StateVisualConfig _getConfig(PetVisualState state) {
    switch (state) {
      case PetVisualState.focus:
        return const _StateVisualConfig(
          label: 'Mochi 专注中',
          bgTint: Color(0xFFE8F2EC),
          borderColor: AppColors.primarySage,
          iconColor: AppColors.primaryDark,
          stateIcon: Icons.menu_book_rounded,
        );
      case PetVisualState.pause:
        return const _StateVisualConfig(
          label: 'Mochi 休息中',
          bgTint: Color(0xFFFBF4E8),
          borderColor: AppColors.accentGold,
          iconColor: Color(0xFFB57D1B),
          stateIcon: Icons.coffee_rounded,
        );
      case PetVisualState.celebrate:
        return const _StateVisualConfig(
          label: '太棒啦!',
          bgTint: Color(0xFFFDF1EB),
          borderColor: AppColors.accentPeach,
          iconColor: AppColors.accentPeach,
          stateIcon: Icons.star_rounded,
        );
      case PetVisualState.sleep:
        return const _StateVisualConfig(
          label: '晚安 Mochi',
          bgTint: Color(0xFFEBF0F5),
          borderColor: Color(0xFF8CA1B3),
          iconColor: Color(0xFF5A7285),
          stateIcon: Icons.bedtime_rounded,
        );
      case PetVisualState.craft:
        return const _StateVisualConfig(
          label: 'Mochi 制作中',
          bgTint: Color(0xFFF4EBE3),
          borderColor: Color(0xFFB38260),
          iconColor: Color(0xFF8C5C3A),
          stateIcon: Icons.handyman_rounded,
        );
      case PetVisualState.greeting:
      case PetVisualState.idle:
      case PetVisualState.interact:
        return const _StateVisualConfig(
          label: 'Mochi 陪伴中',
          bgTint: Color(0xFFF7F2EA),
          borderColor: Color(0xFFC7BCAB),
          iconColor: Color(0xFF7A6E5D),
          stateIcon: Icons.favorite_rounded,
        );
    }
  }
}

class _StateVisualConfig {
  final String label;
  final Color bgTint;
  final Color borderColor;
  final Color iconColor;
  final IconData stateIcon;

  const _StateVisualConfig({
    required this.label,
    required this.bgTint,
    required this.borderColor,
    required this.iconColor,
    required this.stateIcon,
  });
}
