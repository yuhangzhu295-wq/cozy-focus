import 'package:flutter/material.dart';
import '../../domain/growth/mochi_growth_profile.dart';
import '../../domain/models/enums.dart';
import '../companion/focus_phase.dart';
import '../companion/mochi_pose_spec.dart';
import '../controllers/pet_motion_controller.dart';
import 'pet_idle_fallback_view.dart';
import 'rive_pet_adapter.dart';
import '../companion/runtime/companion_manifest_data.dart';

/// Unified presentation abstraction for Mochi motion.
/// Ships the Flutter fallback renderer and exposes a renderer-neutral optional
/// boundary without making an external animation SDK a release dependency.
class PetMotionView extends StatelessWidget {
  final PetVisualState visualState;
  final double size;
  final PetMotionController? controller;
  final IPetMotionScheduler? scheduler;
  final IPetRiveRenderer? riveRenderer;
  final bool enableRive;
  final Widget? accessory;
  final double? focusProgress;
  final double? craftProgress;
  final bool showStateBadge;

  /// The name the status card and the avatar label use.
  ///
  /// Required: see [PetIdleFallbackView.companionName] for why a default is the
  /// wrong shape here.
  final String companionName;

  /// Presentation-only growth profile; see [PetIdleFallbackView.growthProfile].
  final MochiGrowthProfile? growthProfile;

  /// Long-arc focus phase; see [PetIdleFallbackView.focusPhase].
  final FocusPhase? focusPhase;

  /// Real focus `categoryId`; see [PetIdleFallbackView.focusCategoryId].
  final String? focusCategoryId;

  /// The V4.2.1 pose; see [PetIdleFallbackView.poseSpec].
  final MochiPoseSpec? poseSpec;

  const PetMotionView({
    super.key,
    required this.visualState,
    this.companionName = CompanionManifestData.defaultDisplayName,
    this.size = 140,
    this.controller,
    this.scheduler,
    this.riveRenderer,
    this.enableRive = false,
    this.accessory,
    this.focusProgress,
    this.craftProgress,
    this.showStateBadge = true,
    this.growthProfile,
    this.focusPhase,
    this.focusCategoryId,
    this.poseSpec,
  });

  double? get _visualFocusProgress => _normalizeProgress(focusProgress);
  double? get _visualCraftProgress => _normalizeProgress(craftProgress);

  static double? _normalizeProgress(double? value) {
    return value?.clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    Widget buildContent(PetVisualState activeState) {
      final fallbackView = PetIdleFallbackView(
        visualState: activeState,
        companionName: companionName,
        size: size,
        controller: controller,
        scheduler: scheduler,
        accessory: accessory,
        focusProgress: _visualFocusProgress,
        craftProgress: _visualCraftProgress,
        showStateBadge: showStateBadge,
        growthProfile: growthProfile,
        focusPhase: focusPhase,
        focusCategoryId: focusCategoryId,
        poseSpec: poseSpec,
      );

      if (enableRive) {
        final renderer = riveRenderer ?? const RivePetAdapter();
        return renderer.buildRiveWidget(
          visualState: activeState,
          width: size,
          height: size,
          fit: BoxFit.contain,
          focusProgress: _visualFocusProgress,
          craftProgress: _visualCraftProgress,
          fallback: fallbackView,
        );
      }

      return fallbackView;
    }

    if (controller != null) {
      return ListenableBuilder(
        listenable: controller!,
        builder: (context, _) => buildContent(controller!.visualState),
      );
    }

    return buildContent(visualState);
  }
}
