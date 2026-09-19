import 'package:flutter/material.dart';
import '../../domain/models/enums.dart';
import '../controllers/pet_motion_controller.dart';
import 'pet_idle_fallback_view.dart';
import 'rive_pet_adapter.dart';

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

  const PetMotionView({
    super.key,
    required this.visualState,
    this.size = 140,
    this.controller,
    this.scheduler,
    this.riveRenderer,
    this.enableRive = false,
    this.accessory,
    this.focusProgress,
    this.craftProgress,
    this.showStateBadge = true,
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
        size: size,
        controller: controller,
        scheduler: scheduler,
        accessory: accessory,
        focusProgress: _visualFocusProgress,
        craftProgress: _visualCraftProgress,
        showStateBadge: showStateBadge,
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
