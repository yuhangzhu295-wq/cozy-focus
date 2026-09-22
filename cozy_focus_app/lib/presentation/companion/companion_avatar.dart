import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/growth/mochi_growth_profile.dart';
import '../../domain/models/enums.dart';
import '../controllers/craft_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/pet_motion_controller.dart';
import '../widgets/pet_avatar_widget.dart';
import 'companion_presentation_mapper.dart';
import 'focus_phase.dart';

/// The single, business-driven Mochi presentation used across pages.
///
/// Pages must never hard-code a [PetVisualState] for the companion. They place
/// a [CompanionAvatar] and it derives the pet's state (and progress bindings)
/// from the real controllers, so Mochi can never claim to be idle while a
/// focus session or a craft job is actually running.
///
/// Derivation is deliberately read-only. It watches [homeControllerProvider]
/// (which loads itself) and [craftControllerProvider] (which is loaded by the
/// pages that own craft flows), and it never starts a timer of its own — the
/// focus session ticker stays owned solely by the focus flow.
class CompanionAvatar extends ConsumerStatefulWidget {
  final double size;
  final String? message;
  final bool showStateBadge;
  final Widget? accessory;

  /// Optional externally owned controller. When omitted the avatar owns one and
  /// disposes it with itself.
  final PetMotionController? controller;

  /// Optional explicit visual state.
  ///
  /// [CompanionPresentationMapper] can tell "a session is active" but not
  /// "the session is paused", so a page that knows better (the focus screen)
  /// passes the state it derived from the session engine. When omitted, the
  /// state is derived from business controllers as before.
  final PetVisualState? visualStateOverride;

  /// Optional explicit focus progress (`elapsed / target`).
  ///
  /// The focus screen already computes this from the session engine, so it can
  /// hand it over rather than have the avatar re-derive it. The long-arc focus
  /// phase is resolved from it — see [FocusPhaseResolver].
  final double? focusProgress;

  /// The real `categoryId` of the running focus task, if any.
  ///
  /// Used only to pick a presentation-only work flavour. The avatar does not
  /// watch the focus session provider (it deliberately never owns the focus
  /// ticker), so the page supplies this.
  final String? focusCategoryId;

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
  });

  @override
  ConsumerState<CompanionAvatar> createState() => _CompanionAvatarState();
}

class _CompanionAvatarState extends ConsumerState<CompanionAvatar> {
  PetMotionController? _ownedController;
  ProviderSubscription<HomeUIState>? _homeSubscription;
  ProviderSubscription<CraftState>? _craftSubscription;

  PetMotionController get _controller => widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = PetMotionController();
    }
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
  void dispose() {
    _homeSubscription?.close();
    _craftSubscription?.close();
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CompanionAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A page can change what it wants Mochi to present *after* the first frame —
    // the collection page overrides the state for a moment when a real unlock
    // happens. That has to be pushed into the controller rather than merely
    // passed down as a parameter: `PetAvatarWidget` reads `controller.visualState`
    // whenever a controller is supplied, so a changed parameter alone would be
    // ignored and the override would silently never appear.
    if (oldWidget.visualStateOverride != widget.visualStateOverride ||
        oldWidget.focusProgress != widget.focusProgress ||
        oldWidget.focusCategoryId != widget.focusCategoryId) {
      _sync();
    }
  }

  PetVisualState _deriveVisualState() {
    final override = widget.visualStateOverride;
    if (override != null) return override;
    final homeState = ref.read(homeControllerProvider);
    final craftState = ref.read(craftControllerProvider);
    return CompanionPresentationMapper.visualStateFor(
      hasActiveSession: homeState.hasActiveSession,
      hasActiveCraft: craftState.activeJob != null,
    );
  }

  /// Resolves Mochi's growth from the real `PetProgress` truth.
  ///
  /// Read-only: it derives a stage from XP and happiness and writes nothing
  /// back. `PetProgress.level` itself is now derived from XP in the data layer
  /// too, so the stored and presented values can no longer disagree.
  MochiGrowthProfile _growthProfile() {
    final homeState = ref.read(homeControllerProvider);
    return MochiGrowthProfile.fromProgress(homeState.petProgress);
  }

  /// Pushes business state into the motion controller.
  ///
  /// Runs from provider listeners, never during build, so it cannot raise a
  /// rebuild-during-build error.
  void _sync() {
    if (!mounted) return;
    final visualState = _deriveVisualState();
    if (_controller.visualState != visualState) {
      _controller.updateState(visualState);
    }
    // Growth owns the blink / ear-twitch cadence, so the controller has to be
    // told whenever the stage moves. Idempotent when the stage is unchanged.
    final growth = _growthProfile();
    _controller.updateMotionCadence(
      blinkIntervalScale: growth.blinkIntervalScale,
      earTwitchIntervalScale: growth.earTwitchIntervalScale,
    );
  }

  double? _craftProgress() {
    final craftState = ref.read(craftControllerProvider);
    final job = craftState.activeJob;
    final requiredSeconds = craftState.activeRecipe?.requiredSeconds ?? 0;
    if (job == null || requiredSeconds <= 0) return null;
    return CompanionPresentationMapper.normalizedProgress(
      job.progressSeconds,
      requiredSeconds,
    );
  }

  /// Resolves the long-arc focus phase from the real session progress.
  ///
  /// Only the focus visual state has a work cycle, so a phase is reported only
  /// then — a paused session must not keep presenting work beats.
  FocusPhase? _focusPhase() {
    if (_deriveVisualState() != PetVisualState.focus) return null;
    return FocusPhaseResolver.resolve(widget.focusProgress);
  }

  @override
  Widget build(BuildContext context) {
    // Watch so the avatar follows business state changes.
    ref.watch(homeControllerProvider);
    ref.watch(craftControllerProvider);

    return PetAvatarWidget(
      visualState: _deriveVisualState(),
      size: widget.size,
      message: widget.message,
      controller: _controller,
      accessory: widget.accessory,
      focusProgress: widget.focusProgress,
      focusPhase: _focusPhase(),
      focusCategoryId: widget.focusCategoryId,
      craftProgress: _craftProgress(),
      showStateBadge: widget.showStateBadge,
      growthProfile: _growthProfile(),
    );
  }
}
