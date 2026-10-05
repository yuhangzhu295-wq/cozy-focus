import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/growth/mochi_growth_profile.dart';
import '../../domain/models/enums.dart';
import '../controllers/craft_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/pet_motion_controller.dart';
import '../controllers/providers.dart';
import 'animation/animation_state.dart';
import 'animation/companion_animation_controller.dart';
import 'runtime/presentation_vitals.dart';
import 'runtime/companion_event.dart';
import 'companion_presentation_mapper.dart';
import 'focus_phase.dart';
import 'companion_selection.dart';
import 'pack/installed_pack_profiles.dart';
import 'companion_visual_registry.dart';
import 'runtime/companion_behavior_director.dart';
import 'runtime/companion_context.dart';
import 'runtime/companion_id.dart';
import 'runtime/companion_presentation_clock.dart';
import 'runtime/companion_random_source_provider.dart';
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

  /// Which companion to present. When omitted the persisted selection is used,
  /// falling back to the shipped default companion.
  final CompanionId? companionId;

  /// The room anchor the companion is bound to, when the page is the room.
  ///
  /// Supplying it is what puts the companion in the *room* base context, and the
  /// anchor id then selects the behaviour from the recipe catalog — `seat` gives
  /// `roomSit`, `lie` gives `roomSleep`, and so on. It is a presentation anchor,
  /// never a business coordinate: the placed `RoomItem`'s own position stays
  /// authoritative and is not read or written here.
  final String? roomAnchor;

  /// The action the room has already committed the companion to.
  ///
  /// A semantic behaviour id (`room_sit`, `pause_rest`, `focus_read`, …). It is
  /// the same vocabulary [CompanionMacroBehavior] uses, and the same one the
  /// furniture panel names to the player.
  ///
  /// Supplying it makes the room **action-authoritative**: the simulation
  /// decided what the companion is doing when the player tapped the furniture,
  /// so the presentation presents that instead of picking a second, independent
  /// behaviour from the anchor's ambient recipe. Without it the panel could name
  /// one action while the avatar drew another.
  ///
  /// Only the room sets this. Every other context leaves it null and keeps
  /// selecting from its own recipe.
  final String? companionAction;

  /// The companion's own condition, when the page has real vitals to hand.
  ///
  /// Read-only: the runtime reads it so behaviour can depend on how the
  /// companion is doing. A page that passes nothing gets neutral vitals, which
  /// contribute nothing.
  final PresentationVitals vitals;

  /// An animation to draw instead of the behaviour's pose.
  ///
  /// Locomotion supplies `walk` here while the companion travels. It is a
  /// *drawing* override, not a behaviour change: the director still believes the
  /// companion is on its way to write, and the badge and the semantics keep
  /// saying so. Null — the case for every caller that is not moving — leaves the
  /// pose in charge.
  final AnimationState? animationState;

  /// Whether the companion is travelling between two anchors.
  ///
  /// This is what makes the shipped transitions play. Starting a journey turns
  /// the performance into `stand_up → walk`, and arriving turns it into
  /// `sit_down → the behaviour's own pose`, both decided by the animation
  /// controller's posture hops rather than by a page naming the states.
  ///
  /// It is an animation fact rather than a behaviour one: the director is not
  /// told, because the companion is still on its way to the same place.
  final bool travelling;

  /// Reports each animation state the controller settles into, so a page can
  /// coordinate movement with the walk without naming animation states itself.
  ///
  /// The room uses this to start the pet's movement only when the walk actually
  /// begins — after `stand_up` has finished — so the pet does not slide across
  /// the floor while it is still getting up.
  final ValueChanged<AnimationState>? onAnimationStateChanged;

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
    this.roomAnchor,
    this.companionAction,
    this.animationState,
    this.vitals = PresentationVitals.neutral,
    this.travelling = false,
    this.onAnimationStateChanged,
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

  /// Turns the director's behaviour into a performance, including the posture
  /// transitions the behaviour layer has no vocabulary for.
  ///
  /// It is advanced off the presentation clock's own elapsed time rather than a
  /// timer of its own, so the app still has exactly one scheduler.
  final CompanionAnimationController _animation =
      CompanionAnimationController();

  /// The animation state already reported to [CompanionAvatar.onAnimationStateChanged].
  AnimationState? _reportedAnimation;

  /// Reduced motion, read from the platform once per dependency change.
  bool _reducedMotion = false;

  CompanionId get _companionId =>
      widget.companionId ?? ref.read(companionSelectionProvider);

  PetMotionController get _controller => widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = PetMotionController();
    }
    _registry = ref.read(companionVisualRegistryProvider);
    _director = CompanionBehaviorDirector(
      catalog: ref.read(companionCatalogProvider),
      context: _readContext(),
      // Read from the provider rather than constructed inline, so a widget test
      // can make behaviour selection deterministic. See
      // [companionRandomSourceProvider].
      random: ref.read(companionRandomSourceProvider),
    );
    // The opening pose is already in place; only later changes need a transition.
    _animation.settleAt(_director.intent);
    _animation.setTravelling(widget.travelling);

    // Business state is pushed into the director from provider listeners, never
    // from build, so a context change can never raise a rebuild-during-build.
    // A companion switch is a business-independent presentation change, but the
    // director must be rebuilt for it, so the selection is watched like any other
    // input rather than read once.
    ref.listenManual<CompanionId>(
      companionSelectionProvider,
      (_, __) => _sync(),
    );
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
        oldWidget.companionId != widget.companionId ||
        oldWidget.roomAnchor != widget.roomAnchor ||
        // The room re-decides while the companion stays at the same anchor —
        // sitting, then resting on the same sofa. Without this the new action
        // would never reach the director.
        oldWidget.companionAction != widget.companionAction) {
      _sync();
    }
    if (oldWidget.travelling != widget.travelling) {
      _animation.setTravelling(widget.travelling);
      _reportAnimationState();
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
    // The room anchor is the most specific signal: a page only supplies one when
    // it really is the room, and the anchor is what selects the behaviour.
    if (widget.roomAnchor != null) return CompanionBaseContext.room;

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
      // Read through the injected clock, not `DateTime.now()`. The time-of-day
      // band selects the ambient behaviour pool — a late-night companion is
      // offered sleep, a daytime one is not — so a raw reading made the
      // companion's presentation depend on when the app happened to run. In
      // production `focusClockProvider` *is* the system clock, so nothing
      // changes there; in a test it is the one seam that makes the band
      // controllable. This is the same fix the room simulation already carries.
      timeOfDay: TimeOfDayResolver.resolve(ref.read(focusClockProvider).now()),
      reducedMotion: _reducedMotion,
      roomAnchor: widget.roomAnchor,
      // The room's committed action, when it has one. `fromId` returns null for
      // an id this build does not know, which degrades to the recipe path rather
      // than throwing — the same treatment an unknown recipe entry gets.
      macroBehavior: CompanionMacroBehavior.fromId(widget.companionAction),
      vitals: widget.vitals,
    );
  }

  /// Reports the animation state when it changes, for a page coordinating
  /// movement with the walk. Called from the tick and from lifecycle changes.
  void _reportAnimationState() {
    final state = _animation.currentState;
    if (_reportedAnimation == state) return;
    _reportedAnimation = state;
    widget.onAnimationStateChanged?.call(state);
  }

  /// Pushes current business state into the director and the motion controller.
  void _sync() {
    if (!mounted) return;

    _director.updateContext(_readContext());
    // A provider update can rebuild this avatar before the presentation clock's
    // next tick. Hand the director's new intent to the animation layer now so
    // the two cannot present different behaviours during that frame.
    _animation.setIntent(_director.intent);
    _reportAnimationState();

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

  /// The provider that draws [id].
  ///
  /// Resolved through the *catalog's* profile first, so an id this build does
  /// not ship degrades to the default companion's pack rather than to an empty
  /// box. The profile already falls back that way; resolving the drawing any
  /// other way would let the name and the picture disagree — the companion would
  /// be called Mochi while nothing was drawn at all.
  CompanionVisualProvider _providerFor(CompanionId id) {
    final pack = ref.read(companionCatalogProvider).profileFor(id).posePack;
    return _registry.providerForPack(pack) ??
        _registry.providerForCompanion(id) ??
        _registry.providerForPack(
          ref.read(companionCatalogProvider).defaultProfileId.value,
        )!;
  }

  /// Rebuilds the registry and director when the installed set has changed.
  ///
  /// The director is replaced rather than mutated: it caches availability per
  /// companion id, and a companion installed a moment ago has no entry in that
  /// cache. Replacing it refreshes the data, not the role - this remains the one
  /// behaviour authority, and there is still exactly one of it.
  ///
  /// Cheap when nothing changed: the providers return the same instance, so the
  /// identity check exits before doing any work.
  void _refreshRuntimeIfInstalledSetChanged() {
    final registry = ref.read(companionVisualRegistryProvider);
    final catalog = ref.read(companionCatalogProvider);
    if (identical(registry, _registry) &&
        identical(catalog, _director.catalog)) {
      return;
    }
    _registry = registry;
    _director = CompanionBehaviorDirector(
      catalog: catalog,
      context: _readContext(),
      random: ref.read(companionRandomSourceProvider),
    );
    _animation.settleAt(_director.intent);
  }

  /// A gesture reaches the director through its event entry, not by calling
  /// `triggerOverlay` directly.
  ///
  /// Both routes end in the same place, so this is not a behaviour change — it
  /// is what makes the gesture half of the event model reachable in production
  /// instead of only from tests, and it leaves one way for a gesture to arrive
  /// rather than two.
  void _triggerTapReact() {
    _director.dispatch(CompanionEvent.tap);
  }

  void _triggerLongPressReact() {
    _director.dispatch(CompanionEvent.longPress);
  }

  @override
  Widget build(BuildContext context) {
    // Watched so the avatar follows business state changes.
    //
    // The catalog and the registry used to be read once at init, on the grounds
    // that they were constant for this widget's lifetime. That stopped being true
    // when a companion could be installed while the app is running: a pack that
    // arrives mid-session is in the catalog and the registry, and an avatar that
    // never looked again would keep drawing the old companion until it was
    // rebuilt. So the installed set is watched and the runtime is refreshed when
    // it changes.
    ref.watch(homeControllerProvider);
    ref.watch(craftControllerProvider);
    ref.watch(companionSelectionProvider);
    ref.watch(installedPackProfilesProvider);
    _refreshRuntimeIfInstalledSetChanged();

    return CompanionPresentationClock(
      director: _director,
      // The director's intent is the controller's input, so it is pushed in as
      // the intent changes rather than read during build.
      onIntentChanged: _animation.setIntent,
      // The controller's transitions do not change the director's intent, so
      // they have to be advanced off the tick rather than off a rebuild.
      onTick: (elapsed) {
        if (_animation.advanceTo(elapsed) && mounted) setState(() {});
        _reportAnimationState();
      },
      builder: (context, intent, elapsed) {
        return CompanionRenderer(
          intent: intent,
          provider: _providerFor(intent.companionId),
          options: CompanionVisualOptions(
            displayName: _director.profile.displayName,
            size: widget.size,
            message: widget.message,
            accessory: widget.accessory,
            showStateBadge: widget.showStateBadge,
            controller: _controller,
            focusProgress: widget.focusProgress,
            focusCategoryId: widget.focusCategoryId,
            onTapReact: _triggerTapReact,
            onLongPressReact: _triggerLongPressReact,
            // A page that names a state itself wins — the room's walk override is
            // the one case — and otherwise the controller's performance is drawn.
            animationState: widget.animationState ?? _animation.currentState,
          ),
        );
      },
    );
  }
}
