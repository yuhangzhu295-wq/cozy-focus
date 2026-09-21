import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/enums.dart';
import '../controllers/craft_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/pet_motion_controller.dart';
import '../widgets/pet_avatar_widget.dart';
import 'companion_presentation_mapper.dart';

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

  const CompanionAvatar({
    super.key,
    this.size = 140,
    this.message,
    this.showStateBadge = true,
    this.accessory,
    this.controller,
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

  PetVisualState _deriveVisualState() {
    final homeState = ref.read(homeControllerProvider);
    final craftState = ref.read(craftControllerProvider);
    return CompanionPresentationMapper.visualStateFor(
      hasActiveSession: homeState.hasActiveSession,
      hasActiveCraft: craftState.activeJob != null,
    );
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
      craftProgress: _craftProgress(),
      showStateBadge: widget.showStateBadge,
    );
  }
}
