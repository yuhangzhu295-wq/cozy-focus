import 'package:flutter/material.dart';
import '../../domain/models/enums.dart';
import '../controllers/pet_motion_controller.dart';
import 'pet_idle_fallback_view.dart';
import 'rive_pet_adapter.dart';

/// Unified presentation abstraction for Mochi motion.
/// Supports Rive runtime rendering via [IPetRiveRenderer] when enabled/available,
/// and truthfully delegates to [PetIdleFallbackView] when .riv asset is absent or in fallback mode.
class PetMotionView extends StatelessWidget {
  final PetVisualState visualState;
  final double size;
  final PetMotionController? controller;
  final IPetMotionScheduler? scheduler;
  final IPetRiveRenderer? riveRenderer;
  final bool enableRive;
  final Widget? accessory;

  const PetMotionView({
    super.key,
    required this.visualState,
    this.size = 140,
    this.controller,
    this.scheduler,
    this.riveRenderer,
    this.enableRive = false,
    this.accessory,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildContent(PetVisualState activeState) {
      final fallbackView = PetIdleFallbackView(
        visualState: activeState,
        size: size,
        controller: controller,
        scheduler: scheduler,
        accessory: accessory,
      );

      if (enableRive) {
        final renderer = riveRenderer ?? const RivePetAdapter();
        return renderer.buildRiveWidget(
          visualState: activeState,
          width: size,
          height: size,
          fit: BoxFit.contain,
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
