import 'package:flutter/material.dart';
import '../../domain/models/enums.dart';
import '../animations/pet_motion_view.dart';
import '../animations/rive_pet_adapter.dart';
import '../controllers/pet_motion_controller.dart';
import '../theme/app_theme.dart';

/// Centralized Pet presentation widget for Mochi.
/// Preserves full compatibility with Phase 2-5 callers:
/// - [visualState] (idle, focus, pause, celebrate, sleep, craft, etc.)
/// - [size] (defaults to 140)
/// - [message] (optional speech bubble)
///
/// Under the hood, delegates rendering to [PetMotionView], which:
/// 1. Uses [RivePetAdapter] if a real .riv asset is present and enabled.
/// 2. Truthfully defaults to [PetIdleFallbackView] for idle micro-motions
///    (breathe, sway, blink, ear-twitch, tail-idle) and safe fallback states.
class PetAvatarWidget extends StatelessWidget {
  final PetVisualState visualState;
  final double size;
  final String? message;
  final PetMotionController? controller;
  final IPetMotionScheduler? scheduler;
  final IPetRiveRenderer? riveRenderer;
  final bool enableRive;
  final Widget? accessory;

  const PetAvatarWidget({
    super.key,
    required this.visualState,
    this.size = 140,
    this.message,
    this.controller,
    this.scheduler,
    this.riveRenderer,
    this.enableRive = false,
    this.accessory,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildAvatar(PetVisualState activeState) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          PetMotionView(
            visualState: activeState,
            size: size,
            controller: controller,
            scheduler: scheduler,
            riveRenderer: riveRenderer,
            enableRive: enableRive,
            accessory: accessory,
          ),
        ],
      );
    }

    if (controller != null) {
      return ListenableBuilder(
        listenable: controller!,
        builder: (context, _) => buildAvatar(controller!.visualState),
      );
    }

    return buildAvatar(visualState);
  }
}
