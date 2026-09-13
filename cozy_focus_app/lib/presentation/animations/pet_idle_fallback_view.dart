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
/// - All idle loop controllers and timers only run when in [PetVisualState.idle].
/// - Non-idle states remain completely safe and static.
/// - Transitions from idle to non-idle stop all motion; returning resumes without leaks.
class PetIdleFallbackView extends StatefulWidget {
  final PetVisualState visualState;
  final double size;
  final PetMotionController? controller;
  final IPetMotionScheduler? scheduler;
  final Widget? accessory;

  const PetIdleFallbackView({
    super.key,
    required this.visualState,
    this.size = 140,
    this.controller,
    this.scheduler,
    this.accessory,
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

    _effectiveController.attach(
      onTriggerBlink: _onBlinkTrigger,
      onTriggerEarTwitch: _onEarTwitchTrigger,
      onStartContinuousLoops: _startContinuousLoops,
      onStopContinuousLoops: _stopAllAnimations,
    );

    if (widget.visualState == PetVisualState.idle) {
      _startContinuousLoops();
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
  }

  void _onBlinkTrigger() {
    if (!mounted || _effectiveController.visualState != PetVisualState.idle) {
      return;
    }
    _blinkController.forward(from: 0.0);
  }

  void _onEarTwitchTrigger() {
    if (!mounted || _effectiveController.visualState != PetVisualState.idle) {
      return;
    }
    _earTwitchController.forward(from: 0.0);
  }

  void _onControllerStateChanged() {
    if (!mounted) return;
    if (_effectiveController.isIdle) {
      _startContinuousLoops();
    } else {
      _stopAllAnimations();
    }
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
      );
    }

    if (oldWidget.visualState != widget.visualState) {
      _effectiveController.updateState(widget.visualState);
      if (widget.visualState == PetVisualState.idle) {
        _startContinuousLoops();
      } else {
        _stopAllAnimations();
      }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentVisualState = _effectiveController.visualState;
    final isIdle = currentVisualState == PetVisualState.idle;
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
      ]),
      builder: (context, child) {
        // Compose transforms: strictly gated to idle and reduced motion
        final scale =
            (isIdle && !reduceMotion) ? _breatheScaleAnimation.value : 1.0;
        final dy = isIdle
            ? (reduceMotion
                ? (PetMotionSpec.breatheReducedDyMax * 0.5)
                : _breatheDyAnimation.value)
            : 0.0;
        final swayRotation =
            (isIdle && !reduceMotion) ? _swayAnimation.value : 0.0;
        final earRotation =
            (isIdle && !reduceMotion) ? _earTwitchAnimation.value : 0.0;
        final tailRotation =
            (isIdle && !reduceMotion) ? _tailAnimation.value : 0.0;
        final eyeScaleY =
            (isIdle && !reduceMotion) ? _blinkAnimation.value : 1.0;

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Transform.rotate(
              angle: swayRotation,
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
                    // State badge
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
