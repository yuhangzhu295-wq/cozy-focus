import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/growth/mochi_growth_profile.dart';
import '../../domain/models/enums.dart';
import '../companion/focus_phase.dart';
import '../companion/pet_craft_activity.dart';
import '../companion/pet_focus_activity.dart';
import '../controllers/pet_motion_controller.dart';
import '../companion/mochi_layered_renderer.dart';
import '../theme/app_theme.dart';
import 'pet_interaction_spec.dart';
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

  /// The resolved, presentation-only growth profile.
  ///
  /// `null` means "no growth data" and resolves to
  /// [MochiGrowthProfile.initial] — the youngest stage — so a page that has not
  /// loaded `PetProgress` yet never renders a more grown Mochi than the user
  /// has actually earned.
  ///
  /// The profile modulates the *existing* channels (part-motion amplitude, blink
  /// and ear-twitch cadence, and a narrow body-scale maturation), plus the
  /// additive idle flourish. It cannot add business state and cannot be written
  /// back.
  final MochiGrowthProfile? growthProfile;

  /// The long-arc focus phase, or `null` when no session is running.
  ///
  /// Derived by the caller from the real `focusProgress`; see
  /// [FocusPhaseResolver]. It selects *which work beats happen* during a focus
  /// session and nothing else.
  final FocusPhase? focusPhase;

  /// The real `categoryId` of the focus task.
  ///
  /// Used only to pick a work flavour (see [PetWorkFlavourResolver]). It is read,
  /// never written: statistics, rewards and session semantics are untouched.
  final String? focusCategoryId;

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
    this.growthProfile,
    this.focusPhase,
    this.focusCategoryId,
  });

  @override
  State<PetIdleFallbackView> createState() => PetIdleFallbackViewState();
}

class PetIdleFallbackViewState extends State<PetIdleFallbackView>
    with TickerProviderStateMixin {
  PetMotionController? _internalController;
  PetMotionController get _effectiveController =>
      widget.controller ?? _internalController!;

  /// The growth profile in force for this frame. Never `null`.
  MochiGrowthProfile get _growth =>
      widget.growthProfile ?? MochiGrowthProfile.initial;

  /// The body-proportion maturation factor, exposed so tests can prove the
  /// rendered size actually follows the growth stage.
  @visibleForTesting
  double get growthMaturityScale => _growth.maturityScale;

  /// Whether the growth stage adds the idle flourish layer.
  @visibleForTesting
  bool get growthHasIdleFlourish => _growth.hasIdleFlourish;

  /// The part-motion amplitude multiplier contributed by growth alone.
  @visibleForTesting
  double get growthPartMotionFactor => _growth.partMotionFactor;

  /// The growth-scaled flourish cycle length.
  Duration get _flourishCycleDuration {
    final base = PetMotionSpec.idleFlourishCycle.inMilliseconds;
    final scaled = (base * _growth.flourishIntervalScale).round();
    return Duration(
      milliseconds: scaled.clamp(
        PetMotionSpec.idleFlourishMinCycle.inMilliseconds,
        PetMotionSpec.idleFlourishMaxCycle.inMilliseconds,
      ),
    );
  }

  @visibleForTesting
  AnimationController get flourishController => _flourishController;

  @visibleForTesting
  AnimationController get workCycleController => _workCycleController;

  /// The focus activity layer, for tests that assert beat transitions.
  @visibleForTesting
  PetFocusActivityController get focusActivity => _focusActivity;

  /// The beat Mochi is performing right now.
  @visibleForTesting
  PetFocusActivity get currentFocusActivity => _focusActivity.activity;

  /// The amplitude multiplier the current beat contributes.
  @visibleForTesting
  double get focusActivityAmplitude => _focusActivity.visual.amplitudeScale;

  /// The craft activity layer, for tests that assert beat transitions.
  @visibleForTesting
  PetCraftActivityController get craftActivity => _craftActivity;

  /// The craft beat Mochi is performing right now.
  @visibleForTesting
  PetCraftActivity get currentCraftActivity => _craftActivity.activity;

  /// The amplitude multiplier the current craft beat contributes.
  @visibleForTesting
  double get craftActivityAmplitude => _craftActivity.visual.amplitudeScale;

  /// The vertical offset the current craft beat contributes, in logical pixels.
  @visibleForTesting
  double get craftActivityDy => _craftActivity.visual.dyOffset;

  /// The head contribution the current craft beat makes, in degrees.
  @visibleForTesting
  double get craftActivityHeadDegrees => _craftActivity.visual.headDegrees;

  /// The flourish's current look-around contribution to the head channel, in
  /// radians. Zero outside the flourish window and at stages without it.
  @visibleForTesting
  double get flourishLookValue => _flourishLookRadians;

  /// The current look-around offset in radians, derived from the flourish
  /// controller's position within its cycle.
  ///
  /// A single out-and-back per cycle: `0 -> peak -> 0`. Computed rather than
  /// tweened so the whole flourish is a pure function of the cycle position and
  /// can be tested without pumping a widget tree.
  double get _flourishLookRadians {
    if (!_growth.hasIdleFlourish) return 0.0;
    final value = _flourishController.value;
    const start = PetMotionSpec.idleFlourishWindowStart;
    if (value <= start) return 0.0;
    final t = (value - start) / (1.0 - start);
    if (t <= 0.0 || t >= 1.0) return 0.0;
    // sin gives a smooth 0 -> 1 -> 0 out-and-back with no velocity discontinuity
    // at either end, so the look never snaps.
    final eased = math.sin(math.pi * t);
    return eased * PetMotionSpec.idleFlourishLookDegrees * math.pi / 180;
  }

  // Continuous loop controllers
  late AnimationController _breatheController;
  late Animation<double> _breatheScaleAnimation;
  late Animation<double> _breatheDyAnimation;

  late AnimationController _swayController;
  late Animation<double> _swayAnimation;

  late AnimationController _tailController;
  late Animation<double> _tailAnimation;

  // Delayed head response channel: the head counter-rotates against the body
  // sway and carries its own longer oscillation, so it drifts in and out of
  // phase with the body instead of moving rigidly with it.
  late AnimationController _headController;
  late Animation<double> _headAnimation;

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

  // Phase 6D / STAGE 4: the one-shot interaction overlay.
  //
  // Built from two *unit* shapes rather than six amplitude-baked tweens: a rise
  // (`0 → 1 → 1 → 0`) and a swing (`0 → 1 → −1 → 0`). The amplitudes are per base
  // state (see [PetInteractionSpec.table]) and are applied per channel in
  // [_frameFor], so a state change mid-response retargets the motion on the next
  // frame instead of needing any controller rebuilt.
  late AnimationController _interactController;
  late Animation<double> _interactRise;
  late Animation<double> _interactSwing;

  // STAGE 4: the long-press stroke ("轻抚") — a slower, softer shape than the tap
  // response. The eyes soften, the ears droop, the head tilts, then it releases.
  late AnimationController _strokeController;
  late Animation<double> _strokeEase;

  Timer? _interactFlashTimer;
  bool _interactFlash = false;
  bool _reduceMotion = false;

  // Growth-gated idle flourish. A slow, repeating cycle whose final window
  // carries a look-around. Driven by an AnimationController rather than a timer
  // so the ambient timer contract is untouched and nothing can leak.
  late AnimationController _flourishController;

  // Focus work cycle. V4.1 `designs/motion/11F_Focus_Work.png` gives Focus Work
  // a 4–6 s loop with keyframes 开始 / 工作 / 微动 / 循环; this controller's
  // position inside that loop is what selects the beat. It repeats (no
  // `reverse:`) so one controller period is exactly one loop, matching 11F.
  late AnimationController _workCycleController;

  /// Owns "what is Mochi doing right now" during a focus session.
  ///
  /// Disposed with the State. It holds no timers and no streams — the frame
  /// detail is pushed in from [_workCycleController].
  late PetFocusActivityController _focusActivity;

  /// Owns "what is Mochi doing in the workshop right now" during a craft job.
  ///
  /// The exact mirror of [_focusActivity]: 11G's four keyframes are a separate
  /// schedule from 11F's, but the mechanism is the same one — a presentation
  /// layer read by [_frameFor] and driven by the shared work-beat clock. It
  /// holds no timers and no streams.
  late PetCraftActivityController _craftActivity;

  // One-shot trigger settle flags. V4.1 lists `triggerCelebrate` as a *trigger*,
  // so celebrate/greeting play once and then hand the pet back to the ambient
  // micro-motion layer instead of looping the big bounce forever.
  bool _celebrateSettled = false;
  bool _greetingSettled = false;

  /// Testing accessors to observe animation controllers and their cleanup status
  @visibleForTesting
  AnimationController get breatheController => _breatheController;
  @visibleForTesting
  AnimationController get swayController => _swayController;
  @visibleForTesting
  AnimationController get tailController => _tailController;
  @visibleForTesting
  AnimationController get headController => _headController;
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
  AnimationController get strokeController => _strokeController;
  @visibleForTesting
  bool get isInteractFlashActive => _interactFlash;

  /// The interaction spec for the active base state, or `null` when Mochi does
  /// not react in that state.
  @visibleForTesting
  PetInteractionSpec? get interactionSpec => _interactionSpec;

  /// The interaction kind the active base state resolves to, for tests that want
  /// to name the behaviour rather than a number.
  @visibleForTesting
  PetInteractionKind? get interactionKind => _interactionSpec?.kind;

  /// Whether the heart feedback is currently on screen.
  @visibleForTesting
  bool get isStrokeHeartVisible => _showStrokeHeart;

  // The per-channel readings below are the *effective* values for the active
  // base state — the unit shape multiplied by that state's amplitude — so a test
  // can compare a focus glance against an idle greeting on the same scale.

  @visibleForTesting
  double get interactDy =>
      _interactRise.value * (_interactionSpec?.tapDyPeak ?? 0.0);
  @visibleForTesting
  double get interactScale =>
      1.0 +
      _interactRise.value * ((_interactionSpec?.tapScalePeak ?? 1.0) - 1.0);
  @visibleForTesting
  double get interactBodyTilt =>
      _interactSwing.value *
      (_interactionSpec?.tapBodyTiltDegrees ?? 0.0) *
      math.pi /
      180;
  @visibleForTesting
  double get interactEarTilt =>
      _interactSwing.value *
      (_interactionSpec?.tapEarTiltDegrees ?? 0.0) *
      math.pi /
      180;
  @visibleForTesting
  double get interactTailTilt =>
      _interactSwing.value *
      (_interactionSpec?.tapTailTiltDegrees ?? 0.0) *
      math.pi /
      180;
  @visibleForTesting
  double get interactEyeScaleY =>
      1.0 -
      _interactRise.value * (1.0 - (_interactionSpec?.tapEyeSquintMin ?? 1.0));
  @visibleForTesting
  double get strokeEyeScaleY =>
      1.0 -
      _strokeEase.value * (1.0 - (_interactionSpec?.strokeEyeClose ?? 1.0));
  @visibleForTesting
  double get strokeEarDroop =>
      _strokeEase.value *
      (_interactionSpec?.strokeEarDroopDegrees ?? 0.0) *
      math.pi /
      180;
  @visibleForTesting
  bool get isCelebrateSettled => _celebrateSettled;
  @visibleForTesting
  bool get isGreetingSettled => _greetingSettled;

  /// Effective `focusProgress` / `craftProgress` binding, expressed as motion
  /// intensity. `1.0` when the active state carries no progress binding.
  @visibleForTesting
  double get progressIntensity => _progressIntensityFor(
        _effectiveController.visualState,
      );

  /// Effective head counter-rotation in radians, including the delayed head
  /// oscillation. Exposed so tests can prove the head channel moves
  /// independently of the body.
  @visibleForTesting
  double get headRotationValue => _testFrame.headRotation;

  @visibleForTesting
  double get bodyScaleForTesting => _testFrame.scale;

  @visibleForTesting
  double get bodyDyForTesting => _testFrame.dy;

  @visibleForTesting
  double get bodyRotationForTesting => _testFrame.rotation;

  @visibleForTesting
  double get earRotationForTesting => _testFrame.earRotation;

  @visibleForTesting
  double get tailRotationForTesting => _testFrame.tailRotation;

  @visibleForTesting
  double get eyeScaleYForTesting => _testFrame.eyeScaleY;

  /// The frame the widget tree is composing right now, with reduced motion
  /// disabled so the raw motion channels are observable.
  _MotionFrame get _testFrame => _frameFor(
        _effectiveController.visualState,
        reduceMotion: false,
      );

  /// The frame the widget tree is composing right now, **honouring the live
  /// Reduced Motion setting**.
  ///
  /// [_testFrame] and its accessors deliberately force `reduceMotion: false` so
  /// the raw channels stay observable regardless of the ambient setting. That
  /// makes them the wrong tool for asserting what Reduced Motion actually
  /// renders, which is what these two accessors are for.
  _MotionFrame get _renderedFrame => _frameFor(
        _effectiveController.visualState,
        reduceMotion: _reduceMotion,
      );

  /// Body scale actually rendered, Reduced Motion included.
  @visibleForTesting
  double get renderedBodyScale => _renderedFrame.scale;

  /// Head rotation actually rendered, Reduced Motion included.
  @visibleForTesting
  double get renderedHeadRotation => _renderedFrame.headRotation;

  /// Whether Reduced Motion is currently in force.
  @visibleForTesting
  bool get isReduceMotionActive => _reduceMotion;

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

    // 3b. Delayed head response
    _headController = AnimationController(
      vsync: this,
      duration: PetMotionSpec.headLagCycle,
    );
    _headAnimation = Tween<double>(
      begin: -PetMotionSpec.headLagAngleDegrees * math.pi / 180,
      end: PetMotionSpec.headLagAngleDegrees * math.pi / 180,
    ).animate(
      CurvedAnimation(parent: _headController, curve: Curves.easeInOutSine),
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

    // 12. Phase 6D / STAGE 4: the interaction overlay.
    //
    // The duration is retargeted from the state's spec on every trigger, so the
    // value here is only the idle default.
    _interactController = AnimationController(
      vsync: this,
      duration: PetInteractionSpec.table[PetVisualState.idle]!.tapDuration,
    );
    _interactController.addStatusListener(_onInteractStatusChanged);
    _interactRise = _unitSequence(
      _interactController,
      0.0,
      1.0,
      1.0,
      0.0,
      Curves.easeInOutSine,
    );
    _interactSwing = _unitSequence(
      _interactController,
      0.0,
      1.0,
      -1.0,
      0.0,
      Curves.easeInOut,
    );

    // 13. STAGE 4: the long-press stroke.
    _strokeController = AnimationController(
      vsync: this,
      duration: PetInteractionSpec.table[PetVisualState.idle]!.strokeDuration,
    );
    _strokeController.addStatusListener(_onStrokeStatusChanged);
    _strokeEase = _unitSequence(
      _strokeController,
      0.0,
      1.0,
      1.0,
      0.0,
      Curves.easeInOutSine,
    );

    _celebrateController.addStatusListener(_onCelebrateStatusChanged);
    _greetingController.addStatusListener(_onGreetingStatusChanged);

    _flourishController = AnimationController(
      vsync: this,
      duration: _flourishCycleDuration,
    );

    _workCycleController = AnimationController(
      vsync: this,
      duration: PetMotionSpec.focusWorkCycle,
    );
    _focusActivity = PetFocusActivityController();
    _focusActivity.setContext(
      phase: widget.focusPhase,
      categoryId: widget.focusCategoryId,
    );
    _craftActivity = PetCraftActivityController();
    _craftActivity.setContext(progress: widget.craftProgress);

    _effectiveController.attach(
      onTriggerBlink: _onBlinkTrigger,
      onTriggerEarTwitch: _onEarTwitchTrigger,
      onStartContinuousLoops: _startContinuousLoops,
      onStopContinuousLoops: _stopAllAnimations,
      onTriggerInteract: _onInteractTrigger,
      onTriggerStroke: _onStrokeTrigger,
    );

    _syncGrowthToController();
    _syncStateAnimations(widget.visualState);
  }

  /// Pushes the growth stage's cadence into the motion controller.
  ///
  /// The controller owns the blink / ear-twitch timers, so growth can only
  /// reach them through here. Idempotent — the controller ignores equal values —
  /// so it is safe to call from `initState`, `didUpdateWidget` and the build
  /// path alike.
  void _syncGrowthToController() {
    _effectiveController.updateMotionCadence(
      blinkIntervalScale: _growth.blinkIntervalScale,
      earTwitchIntervalScale: _growth.earTwitchIntervalScale,
    );
    _syncFlourishCycle();
  }

  /// Re-applies the growth-scaled flourish cycle length.
  ///
  /// The duration is fixed at controller creation, so a stage change has to
  /// update it. A running flourish is restarted from zero rather than left to
  /// finish at the old length, which would stretch or clip the look.
  void _syncFlourishCycle() {
    final target = _flourishCycleDuration;
    if (_flourishController.duration == target) return;
    final wasAnimating = _flourishController.isAnimating;
    _flourishController.duration = target;
    if (wasAnimating) {
      _flourishController.repeat();
    } else {
      _flourishController.value = 0.0;
    }
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

  /// A three-segment unit shape over [controller]: rise, hold, release.
  ///
  /// Segment weights are 30 / 40 / 30, so a shape reads as "get there, stay a
  /// moment, come back" — which is what every interaction here wants. The
  /// amplitudes are deliberately *not* baked in; they come from the base state's
  /// [PetInteractionSpec] at frame time.
  Animation<double> _unitSequence(
    AnimationController controller,
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
    ]).animate(controller);
  }

  void _onStrokeStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _strokeController.reset();
    }
  }

  void _onInteractStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _interactController.reset();
    }
  }

  void _onCelebrateStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _celebrateSettled = true);
    _effectiveController.extendAmbientMotionTo(PetVisualState.celebrate);
    _syncStateAnimations(_effectiveController.visualState);
  }

  void _onGreetingStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _greetingSettled = true);
    _effectiveController.extendAmbientMotionTo(PetVisualState.greeting);
    _syncStateAnimations(_effectiveController.visualState);
  }

  /// True when the active state is a one-shot trigger that has already played
  /// and handed control back to the ambient micro-motion layer.
  bool _isSettledOneShot(PetVisualState state) =>
      (state == PetVisualState.celebrate && _celebrateSettled) ||
      (state == PetVisualState.greeting && _greetingSettled);

  /// Part-level micro-motion amplitude for a base state.
  ///
  /// The state's damping from [PetMotionSpec] is multiplied by the growth
  /// stage's own factor, so the *same* state reads calmer on a young Mochi and
  /// livelier on a grown one without any state needing a second code path.
  double _partMotionFactor(PetVisualState state) {
    double stateFactor;
    switch (state) {
      case PetVisualState.focus:
        stateFactor = PetMotionSpec.focusPartMotionFactor;
        break;
      case PetVisualState.pause:
        stateFactor = PetMotionSpec.pausePartMotionFactor;
        break;
      case PetVisualState.craft:
        stateFactor = PetMotionSpec.craftPartMotionFactor;
        break;
      case PetVisualState.idle:
      case PetVisualState.celebrate:
      case PetVisualState.sleep:
      case PetVisualState.greeting:
      case PetVisualState.interact:
        stateFactor = PetMotionSpec.idlePartMotionFactor;
        break;
    }
    return stateFactor * _growth.partMotionFactor;
  }

  void _startContinuousLoops() {
    _syncStateAnimations(_effectiveController.visualState);
  }

  void _stopAllAnimations() {
    if (_breatheController.isAnimating) _breatheController.stop();
    _breatheController.reset();

    if (_swayController.isAnimating) _swayController.stop();
    _swayController.reset();

    if (_tailController.isAnimating) _tailController.stop();
    _tailController.reset();

    if (_headController.isAnimating) _headController.stop();
    _headController.reset();

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

    if (_flourishController.isAnimating) _flourishController.stop();
    _flourishController.reset();

    if (_workCycleController.isAnimating) _workCycleController.stop();
    _workCycleController.reset();

    _celebrateSettled = false;
    _greetingSettled = false;
  }

  void _syncStateAnimations(PetVisualState state) {
    if (_reduceMotion) {
      _effectiveController.stopMotion();
      return;
    }

    final settledOneShot = _isSettledOneShot(state);
    final ambient = _effectiveController.supportsAmbientMotion;

    // --- Part-level micro-motion layer -------------------------------------
    //
    // V4.1 `reference/02_动效架构.md` puts Breathe / Sway / Blink / Ear Twitch /
    // Tail Wag *beneath* the base states. They stay engaged in every ambient
    // base state (idle / focus / pause / craft) so ears, tail and eyes never
    // freeze for the length of a long focus session or craft job; only their
    // amplitude is damped per state (see [_partMotionFactor]).
    //
    // V4.1 `designs/motion/11_宠物动效总览.png` titles this layer 固定微动 —
    // *fixed* micro-motion — so growth may retune its amplitude and cadence but
    // must never switch a channel off. The growth-gated behaviour is the
    // separate, additive flourish channel handled below.
    if (ambient) {
      if (!_tailController.isAnimating) {
        _tailController.repeat(reverse: true);
      }
      if (!_headController.isAnimating) {
        _headController.repeat(reverse: true);
      }
    } else {
      _stopPartMotion();
    }

    // --- Growth-gated flourish layer --------------------------------------
    // Strictly additive: it only ever runs *on top of* the fixed micro layer,
    // and only at stages that have developed it. A stage without it is not
    // missing a channel — it simply has the fixed layer and nothing more.
    if (ambient && _growth.hasIdleFlourish) {
      if (!_flourishController.isAnimating) {
        _flourishController.repeat();
      }
    } else if (_flourishController.isAnimating) {
      _flourishController.stop();
      _flourishController.reset();
    }

    // --- Body ambience ----------------------------------------------------
    // Full body breathing/sway belongs to idle, and to a one-shot trigger that
    // has settled back into base aliveness.
    final bodyAmbience = state == PetVisualState.idle || settledOneShot;
    if (bodyAmbience) {
      if (!_breatheController.isAnimating) {
        _breatheController.repeat(reverse: true);
      }
      if (!_swayController.isAnimating) {
        _swayController.repeat(reverse: true);
      }
    } else {
      if (_breatheController.isAnimating) _breatheController.stop();
      _breatheController.reset();
      if (_swayController.isAnimating) _swayController.stop();
      _swayController.reset();
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

    // --- Work-beat clock, shared by the two work loops ---------------------
    //
    // One controller serves both 11F (focus) and 11G (craft). Only one of the
    // two states can be active at a time and leaving either state stops and
    // resets it, so retargeting the duration can never land mid-cycle. It
    // repeats without `reverse:` so one controller period is exactly one loop —
    // 开始 → 工作 → 微动 → 循环 for 11F, 抬手 → 敲击 → 停顿 → 检查 for 11G.
    //
    // 11F wants 4–6 s and 11G wants 3–5 s, so the length belongs to the state
    // rather than to the controller. The per-state body ambience stays on its
    // own controller (`_focusController` / `_craftController`); the two are
    // independent, which is what lets a beat change without moving the pose.
    final beatCycle = switch (state) {
      PetVisualState.focus => PetMotionSpec.focusWorkCycle,
      PetVisualState.craft => PetMotionSpec.craftCycle,
      _ => null,
    };
    if (beatCycle != null) {
      if (_workCycleController.duration != beatCycle) {
        _workCycleController.duration = beatCycle;
      }
      if (!_workCycleController.isAnimating) {
        _workCycleController.repeat();
      }
    } else {
      if (_workCycleController.isAnimating) _workCycleController.stop();
      _workCycleController.reset();
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

    // Celebrate — a one-shot trigger, never a loop.
    if (state == PetVisualState.celebrate) {
      if (!_celebrateSettled && !_celebrateController.isAnimating) {
        _celebrateController.forward(from: 0.0);
      }
    } else {
      if (_celebrateController.isAnimating) _celebrateController.stop();
      _celebrateController.reset();
      _celebrateSettled = false;
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

    // Greeting — a one-shot trigger, never a loop.
    if (state == PetVisualState.greeting) {
      if (!_greetingSettled && !_greetingController.isAnimating) {
        _greetingController.forward(from: 0.0);
      }
    } else {
      if (_greetingController.isAnimating) _greetingController.stop();
      _greetingController.reset();
      _greetingSettled = false;
    }
  }

  void _stopPartMotion() {
    if (_tailController.isAnimating) _tailController.stop();
    _tailController.reset();
    if (_headController.isAnimating) _headController.stop();
    _headController.reset();
    if (_blinkController.isAnimating) _blinkController.stop();
    _blinkController.reset();
    if (_earTwitchController.isAnimating) _earTwitchController.stop();
    _earTwitchController.reset();
  }

  void _onBlinkTrigger() {
    if (!mounted ||
        _reduceMotion ||
        !_effectiveController.supportsAmbientMotion) {
      return;
    }
    _blinkController.forward(from: 0.0);
  }

  void _onEarTwitchTrigger() {
    if (!mounted ||
        _reduceMotion ||
        !_effectiveController.supportsAmbientMotion) {
      return;
    }
    _earTwitchController.forward(from: 0.0);
  }

  /// The interaction spec for the active base state.
  ///
  /// `null` means Mochi does not react in this state — either a one-shot
  /// celebration is running, or the state has no spec at all. Read fresh on
  /// every frame and on every trigger, which is why a state change mid-response
  /// simply retargets the remaining motion.
  PetInteractionSpec? get _interactionSpec =>
      PetInteractionSpec.forState(_effectiveController.visualState);

  /// Whether the long-press heart feedback is on screen.
  ///
  /// Gated by the spec, so a heart never appears over a running focus session or
  /// craft job: the per-state split exists precisely so Mochi does not pull
  /// attention away from the work it is helping with.
  bool get _showStrokeHeart =>
      _strokeController.isAnimating &&
      (_interactionSpec?.strokeShowsHeart ?? false);

  /// The reduced-motion acknowledgement: a brief flash instead of a motion.
  void _flashInteractAcknowledgement() {
    _interactFlashTimer?.cancel();
    setState(() => _interactFlash = true);
    _interactFlashTimer = Timer(const Duration(milliseconds: 80), () {
      if (mounted) {
        setState(() => _interactFlash = false);
      }
      _interactFlashTimer = null;
    });
  }

  void _onInteractTrigger() {
    if (!mounted) return;
    final spec = _interactionSpec;
    if (spec == null) return;

    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _flashInteractAcknowledgement();
      return;
    }

    // The response length belongs to the state, not to a global constant: a
    // focus glance is 420 ms, an idle response 750 ms.
    _interactController.duration = spec.tapDuration;
    _interactController.forward(from: 0.0);
  }

  void _onStrokeTrigger() {
    if (!mounted) return;
    final spec = _interactionSpec;
    if (spec == null) return;

    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _flashInteractAcknowledgement();
      return;
    }

    _strokeController.duration = spec.strokeDuration;
    _strokeController.forward(from: 0.0);
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
        onTriggerStroke: _onStrokeTrigger,
      );
      if (_reduceMotion) {
        _effectiveController.stopMotion();
      }
      _syncGrowthToController();
    }

    // A growth change is a real change to what is rendered: amplitude, cadence
    // and whether the delayed head channel exists at all. Re-run the state sync
    // so the head controller is started or retired immediately, and rebuild so
    // the maturity scale lands on this frame.
    if (oldWidget.growthProfile != widget.growthProfile) {
      _syncGrowthToController();
      _syncStateAnimations(_effectiveController.visualState);
    }

    if (oldWidget.visualState != widget.visualState) {
      _effectiveController.updateState(widget.visualState);
      _syncStateAnimations(widget.visualState);
    }

    // The phase and the category both change which beats are allowed, so a
    // change to either has to reach the activity layer before the next frame.
    if (oldWidget.focusPhase != widget.focusPhase ||
        oldWidget.focusCategoryId != widget.focusCategoryId) {
      _focusActivity.setContext(
        phase: widget.focusPhase,
        categoryId: widget.focusCategoryId,
      );
    }

    // Progress moving is what selects a different craft stage, so it has to
    // reach the activity layer before the next frame.
    if (oldWidget.craftProgress != widget.craftProgress) {
      _craftActivity.setContext(progress: widget.craftProgress);
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
    _headController.dispose();
    _blinkController.dispose();
    _earTwitchController.dispose();
    _focusController.dispose();
    _pauseController.dispose();
    _sleepController.dispose();
    _celebrateController.removeStatusListener(_onCelebrateStatusChanged);
    _celebrateController.dispose();
    _craftController.dispose();
    _greetingController.removeStatusListener(_onGreetingStatusChanged);
    _greetingController.dispose();
    _flourishController.dispose();
    _workCycleController.dispose();
    _focusActivity.dispose();
    _craftActivity.dispose();
    _interactFlashTimer?.cancel();
    _interactController.removeStatusListener(_onInteractStatusChanged);
    _interactController.dispose();
    _strokeController.removeStatusListener(_onStrokeStatusChanged);
    _strokeController.dispose();
    super.dispose();
  }

  /// V4.1 binds `focusProgress` / `craftProgress` into the engine. They are
  /// expressed here as *motion intensity*: the delta of every transform away
  /// from the neutral pose is scaled, so the pet starts a session calm and
  /// grows more animated as it approaches completion. The neutral pose itself
  /// never moves, which keeps the binding free of visual drift.
  ///
  /// Returns `1.0` when the active state carries no progress binding.
  double _progressIntensityFor(PetVisualState state) {
    double? progress;
    if (state == PetVisualState.focus) {
      progress = widget.focusProgress;
    } else if (state == PetVisualState.craft) {
      progress = widget.craftProgress;
    }
    if (progress == null) return 1.0;
    final clamped = progress.clamp(0.0, 1.0);
    return PetMotionSpec.progressIntensityMin +
        (PetMotionSpec.progressIntensityMax -
                PetMotionSpec.progressIntensityMin) *
            clamped;
  }

  /// Delayed head response: the head counter-rotates against the body sway and
  /// carries its own longer oscillation, so it drifts in and out of phase with
  /// the body instead of moving rigidly with it.
  double _headRotationFor(
    double bodyRotation, {
    required bool reduceMotion,
    double extraHeadTerm = 0.0,
  }) {
    if (reduceMotion) return 0.0;
    return -bodyRotation * PetMotionSpec.headLagFactor +
        _headAnimation.value +
        _flourishLookRadians +
        extraHeadTerm;
  }

  /// The flourish's ear lead, in radians.
  ///
  /// The ears lead the head through the look, which is what makes it read as
  /// *noticing* something rather than as slow drift.
  double get _flourishEarLeadRadians {
    final look = _flourishLookRadians;
    if (look == 0.0) return 0.0;
    return look *
        (PetMotionSpec.idleFlourishEarLeadDegrees /
            PetMotionSpec.idleFlourishLookDegrees);
  }

  /// Single authoritative composition of the current motion frame.
  ///
  /// Kept in one place so the rendered tree and the `@visibleForTesting`
  /// accessors can never drift apart.
  _MotionFrame _frameFor(
    PetVisualState state, {
    required bool reduceMotion,
  }) {
    // Keep the activity layer in step with the cycle this frame is composed
    // from. Done here (rather than from a listener) so the rendered tree and the
    // `@visibleForTesting` accessors can never read different beats.
    _focusActivity.updateCycle(_workCycleController.value);
    _craftActivity.updateCycle(_workCycleController.value);

    final settledOneShot = _isSettledOneShot(state);
    final partFactor = reduceMotion ? 0.0 : _partMotionFactor(state);

    double scale = 1.0;
    double dy = 0.0;
    double rotation = 0.0;
    double earRotation = 0.0;
    double tailRotation = 0.0;
    double eyeScaleY = 1.0;
    double extraHeadTerm = 0.0;

    switch (state) {
      case PetVisualState.idle:
        scale = reduceMotion ? 1.0 : _breatheScaleAnimation.value;
        dy = reduceMotion
            ? (PetMotionSpec.breatheReducedDyMax * 0.5)
            : _breatheDyAnimation.value;
        rotation = reduceMotion ? 0.0 : _swayAnimation.value;
        earRotation = _earTwitchAnimation.value * partFactor;
        tailRotation = _tailAnimation.value * partFactor;
        eyeScaleY = reduceMotion ? 1.0 : _blinkAnimation.value;
      case PetVisualState.focus:
        scale = reduceMotion ? 1.0 : _focusScaleAnimation.value;
        dy = reduceMotion
            ? (PetMotionSpec.focusBreatheDyMax * 0.5)
            : _focusBreatheDyAnimation.value;
        rotation = reduceMotion ? 0.0 : _focusAngleAnimation.value;
        // The ambient micro layer stays engaged: a companion that never blinks
        // or moves its tail through an entire focus session is not alive.
        earRotation = _earTwitchAnimation.value * partFactor;
        tailRotation = _tailAnimation.value * partFactor;
        eyeScaleY = reduceMotion ? 1.0 : _blinkAnimation.value;
      case PetVisualState.pause:
        scale = 1.0;
        dy = reduceMotion
            ? (PetMotionSpec.pauseBreatheDyMax * 0.5)
            : _pauseBreatheDyAnimation.value;
        rotation = 0.0;
        earRotation = _earTwitchAnimation.value * partFactor;
        tailRotation = _tailAnimation.value * partFactor;
        eyeScaleY = reduceMotion ? 1.0 : _blinkAnimation.value;
      case PetVisualState.sleep:
        scale = 1.0;
        dy = reduceMotion
            ? (PetMotionSpec.sleepBreatheDyMax * 0.5)
            : _sleepBreatheDyAnimation.value;
        rotation = 0.0;
        eyeScaleY = 0.10; // Eyes closed in sleep
      case PetVisualState.celebrate:
        if (settledOneShot) {
          // The trigger has played once; hand the pet back to base aliveness.
          scale = reduceMotion ? 1.0 : _breatheScaleAnimation.value;
          dy = reduceMotion
              ? (PetMotionSpec.breatheReducedDyMax * 0.5)
              : _breatheDyAnimation.value;
          rotation = reduceMotion ? 0.0 : _swayAnimation.value;
          earRotation = _earTwitchAnimation.value * partFactor;
          tailRotation = _tailAnimation.value * partFactor;
          eyeScaleY = reduceMotion ? 1.0 : _blinkAnimation.value;
        } else {
          scale = reduceMotion ? 1.0 : _celebrateScaleAnimation.value;
          dy = reduceMotion
              ? (PetMotionSpec.celebrateBounceDyMax * 0.5)
              : _celebrateBounceDyAnimation.value;
          rotation = reduceMotion ? 0.0 : _celebrateAngleAnimation.value;
          earRotation = reduceMotion ? 0.0 : _celebrateAngleAnimation.value;
          tailRotation = reduceMotion ? 0.0 : -_celebrateAngleAnimation.value;
          eyeScaleY = 1.0; // Bright joyful gaze
        }
      case PetVisualState.craft:
        scale = reduceMotion ? 1.0 : _craftScaleAnimation.value;
        dy = reduceMotion
            ? (PetMotionSpec.craftBreatheDyMax * 0.5)
            : _craftBreatheDyAnimation.value;
        rotation = reduceMotion ? 0.0 : _craftTiltAngleAnimation.value;
        // Craft used to pin ears and tail at 0.0, freezing them for the whole
        // job. The ambient micro layer keeps them moving independently of the
        // body tilt.
        earRotation = _earTwitchAnimation.value * partFactor;
        tailRotation = _tailAnimation.value * partFactor;
        eyeScaleY = reduceMotion ? 1.0 : _blinkAnimation.value;
      case PetVisualState.greeting:
        if (settledOneShot) {
          scale = reduceMotion ? 1.0 : _breatheScaleAnimation.value;
          dy = reduceMotion
              ? (PetMotionSpec.breatheReducedDyMax * 0.5)
              : _breatheDyAnimation.value;
          rotation = reduceMotion ? 0.0 : _swayAnimation.value;
          earRotation = _earTwitchAnimation.value * partFactor;
          tailRotation = _tailAnimation.value * partFactor;
          eyeScaleY = reduceMotion ? 1.0 : _blinkAnimation.value;
        } else {
          scale = reduceMotion ? 1.0 : _greetingScaleAnimation.value;
          dy = reduceMotion
              ? (PetMotionSpec.greetingBounceDyMax * 0.5)
              : _greetingBounceDyAnimation.value;
          rotation = reduceMotion ? 0.0 : _greetingTiltAngleAnimation.value;
          earRotation = reduceMotion ? 0.0 : _greetingTiltAngleAnimation.value;
          tailRotation =
              reduceMotion ? 0.0 : _greetingTiltAngleAnimation.value * 0.8;
          eyeScaleY = 1.0; // Welcoming cheerful gaze
        }
      case PetVisualState.interact:
        // `interact` is a trigger, never a settled visual state; the override
        // below is the only thing that drives it.
        break;
    }

    // --- V4.1 binding: focusProgress / craftProgress -> motion intensity ---
    final intensity = _progressIntensityFor(state);
    if (intensity != 1.0) {
      scale = 1.0 + (scale - 1.0) * intensity;
      dy *= intensity;
      rotation *= intensity;
      earRotation *= intensity;
      tailRotation *= intensity;
    }

    // --- Growth-gated flourish -------------------------------------------
    // Applied after the per-state switch so it is purely additive: it offsets
    // the ears and (via [_headRotationFor]) the head on top of whatever the
    // state already does, and never rewrites a state's own channel. A stage
    // without the flourish leaves every channel exactly as it was.
    if (!reduceMotion) {
      earRotation += _flourishEarLeadRadians;
    }

    // --- Focus work beats (V4.1 `designs/motion/11F_Focus_Work.png`) ------
    //
    // 11F gives Focus Work a 4–6 s loop with keyframes 开始 / 工作 / 微动 / 循环.
    // The current beat scales the focus motion's *delta away from neutral* (so
    // the neutral pose is never moved — the same discipline the progress binding
    // uses) and contributes two additive head terms:
    //
    // * a bob, one oscillation per loop, from the category flavour;
    // * a single out-and-back lift, spread across the beat, for `glance` and
    //   `prepare`.
    //
    // Only the focus state has a work cycle, and Reduced Motion suppresses it
    // entirely — 11F requires Reduced Motion to lower amplitude automatically.
    if (state == PetVisualState.focus && !reduceMotion) {
      final beat = _focusActivity.visual;

      final beatScale = beat.amplitudeScale;
      if (beatScale != 1.0) {
        scale = 1.0 + (scale - 1.0) * beatScale;
        dy *= beatScale;
        rotation *= beatScale;
        earRotation *= beatScale;
        tailRotation *= beatScale;
      }

      if (beat.headBobDegrees != 0.0) {
        extraHeadTerm += math.sin(2 * math.pi * _workCycleController.value) *
            beat.headBobDegrees *
            math.pi /
            180;
      }
      if (beat.headLiftDegrees != 0.0) {
        extraHeadTerm += math.sin(math.pi * _focusActivity.localProgress) *
            beat.headLiftDegrees *
            math.pi /
            180;
      }
    }

    // --- Craft work beats (V4.1 `designs/motion/11G_Craft.png`) ------------
    //
    // 11G gives Craft a 3–5 s loop with keyframes 抬手 / 敲击 / 停顿 / 检查 and
    // binds it to `craftProgress`. Same discipline as the focus beats above: the
    // beat scales the craft motion's delta away from neutral, so the neutral
    // pose is never displaced, and it contributes an additive `dy` and head term
    // spread across its own beat.
    //
    // The beat's own envelope is `sin(pi * localProgress)`: zero at the beat's
    // edges and full at its middle. That is what lets two adjacent beats join
    // without a step — 抬手 settling into 敲击 reads as one gesture rather than
    // as a cut between two poses.
    if (state == PetVisualState.craft && !reduceMotion) {
      final beat = _craftActivity.visual;

      final beatScale = beat.amplitudeScale;
      if (beatScale != 1.0) {
        scale = 1.0 + (scale - 1.0) * beatScale;
        dy *= beatScale;
        rotation *= beatScale;
        earRotation *= beatScale;
        tailRotation *= beatScale;
      }

      final beatEnvelope = math.sin(math.pi * _craftActivity.localProgress);
      if (beat.dyOffset != 0.0) {
        dy += beat.dyOffset * beatEnvelope;
      }
      if (beat.headDegrees != 0.0) {
        extraHeadTerm += beat.headDegrees * beatEnvelope * math.pi / 180;
      }
    }

    // --- Interaction overlay ------------------------------------------------
    //
    // Applied *after* the per-state switch and only to the channels the state's
    // spec owns. That is what makes "Interact outranks Craft/Focus/Pause/Sleep"
    // concrete rather than decorative: a focus glance takes the head, the ears
    // and the eyes and leaves the body to the focus sway, so it reads as a
    // glance *from a working Mochi* instead of replacing the work pose. Idle,
    // having no commitment to protect, hands over every channel.
    //
    // The base state itself is never written here. The overlay is time-bounded
    // and the state underneath is untouched, so a short interaction returns to
    // exactly the state it started in — there is nothing to restore and nothing
    // that can be restored wrongly.
    final interaction = _interactionSpec;
    if (interaction != null && !reduceMotion) {
      final owned = interaction.ownedChannels;

      if (_interactController.isAnimating) {
        final rise = _interactRise.value;
        final swing = _interactSwing.value;

        if (owned.contains(PetMotionChannel.scale)) {
          scale = 1.0 + rise * (interaction.tapScalePeak - 1.0);
        }
        if (owned.contains(PetMotionChannel.dy)) {
          dy = rise * interaction.tapDyPeak;
        }
        if (owned.contains(PetMotionChannel.bodyTilt)) {
          rotation = swing * interaction.tapBodyTiltDegrees * math.pi / 180;
        }
        if (owned.contains(PetMotionChannel.ear)) {
          earRotation = swing * interaction.tapEarTiltDegrees * math.pi / 180;
        }
        if (owned.contains(PetMotionChannel.tail)) {
          tailRotation = swing * interaction.tapTailTiltDegrees * math.pi / 180;
        }
        if (owned.contains(PetMotionChannel.eyes)) {
          eyeScaleY = 1.0 - rise * (1.0 - interaction.tapEyeSquintMin);
        }
        if (owned.contains(PetMotionChannel.head)) {
          extraHeadTerm +=
              rise * interaction.tapHeadTiltDegrees * math.pi / 180;
        }
      }

      // The stroke runs after the tap so that on the channels they share — eyes,
      // head, ears — a long press wins over a tap that is still settling. The
      // two cannot fire from one touch (Flutter dispatches either a tap or a
      // long press, never both), so this only matters for a tap followed
      // immediately by a long press.
      if (_strokeController.isAnimating) {
        final stroke = _strokeEase.value;
        eyeScaleY = 1.0 - stroke * (1.0 - interaction.strokeEyeClose);
        earRotation =
            stroke * interaction.strokeEarDroopDegrees * math.pi / 180;
        extraHeadTerm +=
            stroke * interaction.strokeHeadTiltDegrees * math.pi / 180;
      }
    }

    // Reduced-motion acknowledgement. Applies wherever an interaction is
    // allowed — the flash can only be set from a state that has a spec.
    if (_interactFlash) {
      scale = 1.02;
      dy = -1.0;
    }

    return _MotionFrame(
      scale: scale,
      dy: dy,
      rotation: rotation,
      earRotation: earRotation,
      tailRotation: tailRotation,
      eyeScaleY: eyeScaleY,
      headRotation: _headRotationFor(
        rotation,
        reduceMotion: reduceMotion,
        extraHeadTerm: extraHeadTerm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentVisualState = _effectiveController.visualState;
    final isSleep = currentVisualState == PetVisualState.sleep;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final config = _getConfig(currentVisualState);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _breatheController,
        _swayController,
        _tailController,
        _headController,
        _blinkController,
        _earTwitchController,
        _focusController,
        _pauseController,
        _sleepController,
        _celebrateController,
        _craftController,
        _greetingController,
        _interactController,
        _strokeController,
        _flourishController,
        _workCycleController,
      ]),
      builder: (context, child) {
        final frame = _frameFor(currentVisualState, reduceMotion: reduceMotion);

        // Growth's proportion maturation is folded into the same scale about the
        // same centre as the motion scale. It is deliberately narrow (see
        // [GrowthStageSpec.maturityScale]) so the character stays obviously the
        // same character — this is a nudge, not a redesign.
        final scale = frame.scale * _growth.maturityScale;

        return Transform.translate(
          offset: Offset(0, frame.dy),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Transform.rotate(
              angle: frame.rotation,
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    MochiLayeredRenderer(
                      size: widget.size,
                      eyeScaleY: frame.eyeScaleY,
                      earRotation: frame.earRotation,
                      sproutRotation: frame.tailRotation * 0.6,
                      headRotation: frame.headRotation,
                      headDy: frame.dy * 0.28,
                    ),
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
                    // Long-press feedback. Only where the spec allows it: a
                    // heart over a running focus session or craft job would
                    // pull attention away from the work Mochi is helping with.
                    if (_showStrokeHeart)
                      Positioned(
                        top: widget.size * 0.10,
                        right: widget.size * 0.16,
                        child: Opacity(
                          opacity: _strokeEase.value,
                          child: const Text(
                            '♡',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppColors.primarySage,
                            ),
                          ),
                        ),
                      ),
                    // Optional accessory
                    if (widget.accessory != null) widget.accessory!,
                    if (widget.showStateBadge)
                      Positioned(
                        bottom: widget.size * 0.10,
                        child: ExcludeSemantics(
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

/// Native Flutter artwork for Android V1. It deliberately keeps the character
/// separate from the motion transforms above, so every existing state shares
/// the same Mochi silhouette instead of falling back to a generic pet icon.
/// Immutable snapshot of the transforms composed for one frame.
class _MotionFrame {
  final double scale;
  final double dy;
  final double rotation;
  final double earRotation;
  final double tailRotation;
  final double eyeScaleY;
  final double headRotation;

  const _MotionFrame({
    required this.scale,
    required this.dy,
    required this.rotation,
    required this.earRotation,
    required this.tailRotation,
    required this.eyeScaleY,
    required this.headRotation,
  });
}
