import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/growth/mochi_growth_profile.dart';
import '../../domain/models/enums.dart';
import '../controllers/craft_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/pet_motion_controller.dart';
import 'companion_presentation_mapper.dart';
import 'focus_phase.dart';
import 'mochi_visual_provider.dart';
import 'runtime/companion_behavior_director.dart';
import 'runtime/companion_context.dart';
import 'runtime/companion_id.dart';
import 'runtime/companion_manifest_data.dart';
import 'runtime/companion_presentation_clock.dart';
import 'runtime/companion_renderer.dart';
import 'runtime/companion_visual_provider.dart';
import 'time_of_day.dart';

/// The single, business-driven companion presentation used across pages.
///
/// ## What changed in the V4.2.1 reconstruction
///
/// It used to derive a `PetVisualState` and hand it to the renderer. It now
/// drives the [CompanionBehaviorDirector]: real business state becomes a
/// [CompanionContext], the director schedules a macro behaviour from the data
/// manifests, and a visual provider draws the resulting pose.
///
/// Pages are unaffected. They still place a `CompanionAvatar` and pass nothing
/// but a size and an optional message. They still never name a state, an asset or
/// a species — which is why no page needed editing for this change, and why none
/// will need editing for the next companion.
///
/// ## It owns no business state
///
/// Every input is a read of an existing controller. Nothing is written back. The
/// focus session, craft job, XP and records remain owned exactly where they were;
/// this widget only decides how the companion *looks* while they run.
class CompanionAvatar extends ConsumerStatefulWidget {
  final double size;
  final String? message;
  final bool showStateBadge;
  final Widget? accessory;

  /// Optional externally owned motion controller. When omitted the avatar owns
  /// one and disposes it with itself.
  final PetMotionController? controller;

  /// Optional explicit visual state.
  ///
  /// A page that knows better than the coarse controller derivation (the focus
  /// screen knows a session is *paused*) passes the state it derived. It is
  /// mapped onto a base context, so the director still owns the behaviour.
  final PetVisualState? visualStateOverride;

  /// Optional explicit focus progress (`elapsed / target`).
  final double? focusProgress;

  /// The real `categoryId` of the running focus task, if any.
  final String? focusCategoryId;

  /// Which companion to present. Defaults to the shipped default companion.
  final CompanionId? companionId;

  const CompanionAvatar({
    super.key,
    this.size = 140,
    this.message,
    this.showStateBadge = true,
    this.accessory,
    this.controller,
    this.visualStateOverride,
    this.focusProgress,
    this.focusCategoryId,
    this.companionId,
  });

  @override
  ConsumerState<CompanionAvatar> createState() => _CompanionAvatarState();
}

class _CompanionAvatarState extends ConsumerState<CompanionAvatar> {
  PetMotionController? _ownedController;
  ProviderSubscription<HomeUIState>? _homeSubscription;
  ProviderSubscription<CraftState>? _craftSubscription;

  late final CompanionBehaviorDirector _director;
  late final CompanionVisualRegistry _registry;

  /// Reduced motion, read from the platform once per dependency change.
  bool _reducedMotion = false;

  CompanionId get _companionId => widget.companionId ?? CompanionId.dog;

  PetMotionController get _controller => widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = PetMotionController();
    }
    _registry = buildCompanionVisualRegistry();
    _director = CompanionBehaviorDirector(
      catalog: bundledCompanionCatalog(),
      context: _readContext(),
    );

    // Business state is pushed into the director from provider listeners, never
    // from build, so a context change can never raise a rebuild-during-build.
    _homeSubscription = ref.listenManual<HomeUIState>(
      homeControllerProvider,
      (_, __) => _sync(),
      fireImmediately: true,
    );
    _craftSubscription = ref.listenManual<CraftState>(
      craftControllerProvider,
      (_, __) => _sync(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduced != _reducedMotion) {
      _reducedMotion = reduced;
      _sync();
    }
  }

  @override
  void didUpdateWidget(covariant CompanionAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A page can change what it wants presented *after* the first frame — the
    // collection page overrides the state for a moment when a real unlock
    // happens. That has to be pushed into the director, not merely passed down,
    // or the override would silently never appear.
    if (oldWidget.visualStateOverride != widget.visualStateOverride ||
        oldWidget.focusProgress != widget.focusProgress ||
        oldWidget.focusCategoryId != widget.focusCategoryId ||
        oldWidget.companionId != widget.companionId) {
      _sync();
    }
  }

  @override
  void dispose() {
    _homeSubscription?.close();
    _craftSubscription?.close();
    _ownedController?.dispose();
    super.dispose();
  }

  /// Maps the page's optional override and the real controllers onto a base
  /// context.
  ///
  /// The order matters and is the same precedence the pre-V4.2.1 mapper used:
  /// an explicit page override wins, then a live session, then a live craft job,
  /// then idle. Keeping one precedence is what stops the badge and the behaviour
  /// from ever disagreeing.
  CompanionBaseContext _baseContextFor({
    required HomeUIState home,
    required CraftState craft,
  }) {
    final override = widget.visualStateOverride;
    if (override != null) {
      switch (override) {
        case PetVisualState.pause:
          return CompanionBaseContext.pause;
        case PetVisualState.sleep:
          return CompanionBaseContext.sleep;
        case PetVisualState.craft:
          return CompanionBaseContext.craft;
        case PetVisualState.focus:
          return CompanionBaseContext.focus;
        case PetVisualState.celebrate:
          return CompanionBaseContext.complete;
        case PetVisualState.idle:
        case PetVisualState.greeting:
        case PetVisualState.interact:
          return CompanionBaseContext.home;
      }
    }
    if (home.hasActiveSession) return CompanionBaseContext.focus;
    if (craft.activeJob != null) return CompanionBaseContext.craft;
    return CompanionBaseContext.home;
  }

  double? _craftProgress(CraftState craft) {
    final job = craft.activeJob;
    final requiredSeconds = craft.activeRecipe?.requiredSeconds ?? 0;
    if (job == null || requiredSeconds <= 0) return null;
    return CompanionPresentationMapper.normalizedProgress(
      job.progressSeconds,
      requiredSeconds,
    );
  }

  /// Builds the current business snapshot.
  CompanionContext _readContext() {
    final home = ref.read(homeControllerProvider);
    final craft = ref.read(craftControllerProvider);

    return CompanionContext(
      companionId: _companionId,
      baseContext: _baseContextFor(home: home, craft: craft),
      // The phase is what makes a running session *grounded*: without it the
      // director would refuse to schedule work behaviour, which is the same rule
      // that stops an idle craft job animating.
      hasActiveSession: home.hasActiveSession,
      focusPhase: FocusPhaseResolver.resolve(widget.focusProgress),
      focusProgress: widget.focusProgress,
      craftProgress: _craftProgress(craft),
      growthStage: MochiGrowthProfile.fromProgress(home.petProgress).stage,
      timeOfDay: TimeOfDayResolver.resolve(DateTime.now()),
      reducedMotion: _reducedMotion,
    );
  }

  /// Pushes current business state into the director and the motion controller.
  void _sync() {
    if (!mounted) return;

    _director.updateContext(_readContext());

    // Growth owns the blink / ear-twitch cadence, so the controller has to be
    // told whenever the stage moves. Idempotent when the stage is unchanged.
    final home = ref.read(homeControllerProvider);
    final growth = MochiGrowthProfile.fromProgress(home.petProgress);
    _controller.updateMotionCadence(
      blinkIntervalScale: growth.blinkIntervalScale,
      earTwitchIntervalScale: growth.earTwitchIntervalScale,
    );

    // Keep the legacy controller's visual state in step, so the micro-motion
    // gating (which states sustain ambient motion) stays correct.
    final visualState = _legacyVisualStateFor(_director.context.baseContext);
    if (_controller.visualState != visualState) {
      _controller.updateState(visualState);
    }
  }

  static PetVisualState _legacyVisualStateFor(CompanionBaseContext context) {
    switch (context) {
      case CompanionBaseContext.home:
      case CompanionBaseContext.room:
        return PetVisualState.idle;
      case CompanionBaseContext.focus:
        return PetVisualState.focus;
      case CompanionBaseContext.pause:
        return PetVisualState.pause;
      case CompanionBaseContext.complete:
        return PetVisualState.celebrate;
      case CompanionBaseContext.craft:
        return PetVisualState.craft;
      case CompanionBaseContext.sleep:
        return PetVisualState.sleep;
    }
  }

  void _triggerTapReact() {
    _director.triggerOverlay(_director.profile.tapOverlay);
  }

  void _triggerLongPressReact() {
    _director.triggerOverlay(_director.profile.longPressOverlay);
  }

  @override
  Widget build(BuildContext context) {
    // Watch so the avatar follows business state changes.
    ref.watch(homeControllerProvider);
    ref.watch(craftControllerProvider);

    return CompanionPresentationClock(
      director: _director,
      builder: (context, intent) => CompanionRendererFor(
        intent: intent,
        registry: _registry,
        options: CompanionVisualOptions(
          size: widget.size,
          message: widget.message,
          accessory: widget.accessory,
          showStateBadge: widget.showStateBadge,
          controller: _controller,
          focusProgress: widget.focusProgress,
          focusCategoryId: widget.focusCategoryId,
          onTapReact: _triggerTapReact,
          onLongPressReact: _triggerLongPressReact,
        ),
      ),
    );
  }
}
