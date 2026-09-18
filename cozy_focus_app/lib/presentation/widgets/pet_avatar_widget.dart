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

  String _petSemanticLabel(PetVisualState state) {
    switch (state) {
      case PetVisualState.idle:
        return 'Mochi 空闲';
      case PetVisualState.focus:
        return 'Mochi 专注中';
      case PetVisualState.craft:
        return 'Mochi 制作中';
      case PetVisualState.pause:
        return 'Mochi 暂停中';
      case PetVisualState.celebrate:
        return 'Mochi 庆祝中';
      case PetVisualState.sleep:
        return 'Mochi 休息中';
      case PetVisualState.greeting:
        return 'Mochi 打招呼';
      case PetVisualState.interact:
        return 'Mochi 互动中';
    }
  }

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
          if (controller != null)
            Semantics(
              button: activeState == PetVisualState.idle,
              label: _petSemanticLabel(activeState),
              hint: activeState == PetVisualState.idle ? '仅空闲时可互动' : null,
              onTap: activeState == PetVisualState.idle
                  ? () {
                      controller!.triggerInteract();
                    }
                  : null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  controller!.triggerInteract();
                },
                child: PetMotionView(
                  visualState: activeState,
                  size: size,
                  controller: controller,
                  scheduler: scheduler,
                  riveRenderer: riveRenderer,
                  enableRive: enableRive,
                  accessory: accessory,
                ),
              ),
            )
          else
            PetMotionView(
              visualState: activeState,
              size: size,
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
