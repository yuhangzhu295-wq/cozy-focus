import 'package:flutter/material.dart';
import '../../domain/growth/mochi_growth_profile.dart';
import '../../domain/models/enums.dart';
import '../companion/focus_phase.dart';
import '../companion/mochi_pose_spec.dart';
import '../animations/pet_interaction_spec.dart';
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
/// 1. Uses the Android V1 Flutter fallback through [PetMotionView].
/// 2. Keeps an optional renderer boundary for future non-release renderers.
/// 3. Truthfully defaults to [PetIdleFallbackView] for idle micro-motions
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
  final double? focusProgress;
  final double? craftProgress;
  final bool showStateBadge;

  /// Presentation-only growth profile. `null` resolves to the youngest stage,
  /// so a page that omits it renders an un-grown Mochi rather than a random one.
  final MochiGrowthProfile? growthProfile;

  /// Long-arc focus phase; see [PetIdleFallbackView.focusPhase].
  final FocusPhase? focusPhase;

  /// Real focus `categoryId`; see [PetIdleFallbackView.focusCategoryId].
  final String? focusCategoryId;

  /// The V4.2.1 pose; see [PetIdleFallbackView.poseSpec].
  final MochiPoseSpec? poseSpec;

  /// Overrides the generated state label.
  ///
  /// [PetVisualState] has no "in the room" value, so a page that knows the
  /// companion is in the room would otherwise be announced as "空闲". The
  /// runtime knows the base context, so it supplies the truthful wording.
  final String? semanticLabelOverride;

  /// Invoked in addition to the controller's own reaction when Mochi is tapped.
  ///
  /// The V4.2.1 runtime routes the *overlay pose* through the behavior director,
  /// while the existing controller keeps owning the interact cooldown. Both are
  /// wanted, and neither replaces the other, so this is an addition rather than a
  /// second gesture path.
  final VoidCallback? onTapReact;

  /// Invoked in addition to the controller's own reaction on long press.
  final VoidCallback? onLongPressReact;

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
    this.focusProgress,
    this.craftProgress,
    this.showStateBadge = true,
    this.growthProfile,
    this.focusPhase,
    this.focusCategoryId,
    this.poseSpec,
    this.onTapReact,
    this.onLongPressReact,
    this.semanticLabelOverride,
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

  /// Whether Mochi responds to a touch in [state].
  ///
  /// Asked of the same two rules the controller enforces, so the semantics tree
  /// and the gesture wiring can never disagree with the actual behaviour.
  static bool _respondsToTouch(PetVisualState state) =>
      PetInteractionPriority.canInteractDuring(state) &&
      PetInteractionSpec.forState(state) != null;

  /// What a touch does in [state], in the user's words.
  ///
  /// It has to be per state because the response is: tapping a working Mochi
  /// gets a glance, tapping a sleeping one gets almost nothing. A single
  /// "tap to interact" hint would over-promise in four of the five states.
  static String? _touchHint(PetVisualState state) {
    if (!_respondsToTouch(state)) return null;
    return switch (PetInteractionSpec.forState(state)!.kind) {
      PetInteractionKind.friendly => '点一下会回应，长按可以摸摸头',
      PetInteractionKind.glance => '点一下会看你一眼，不会打断专注',
      PetInteractionKind.soothe => '点一下会安静地陪着你',
      PetInteractionKind.react => '点一下会回应一下，不会打断制作',
      PetInteractionKind.drowsy => '点一下会轻轻动一下，不会吵醒',
    };
  }

  @override
  Widget build(BuildContext context) {
    Widget buildAvatar(PetVisualState activeState) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null) ...[
            // The speech bubble must never be able to absorb a tap. It sits
            // directly above Mochi on the active-focus screen, where the timer
            // controls live, so an opaque bubble that appeared mid-gesture
            // could swallow a pause tap. `IgnorePointer` makes that structurally
            // impossible rather than merely unlikely.
            IgnorePointer(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            ),
          ],
          Semantics(
            button: controller != null && _respondsToTouch(activeState),
            label: semanticLabelOverride ?? _petSemanticLabel(activeState),
            hint: controller != null ? _touchHint(activeState) : null,
            onTap: controller != null && _respondsToTouch(activeState)
                ? () {
                    controller!.triggerInteract();
                    onTapReact?.call();
                  }
                : null,
            onLongPress: controller != null && _respondsToTouch(activeState)
                ? () {
                    controller!.triggerStroke();
                    onLongPressReact?.call();
                  }
                : null,
            child: controller != null
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      controller!.triggerInteract();
                      onTapReact?.call();
                    },
                    // Long press is the "轻抚" gesture: a hold, not a poke. It
                    // shares the interact gate but has its own cooldown, so the
                    // two gestures cannot swallow each other.
                    onLongPress: () {
                      controller!.triggerStroke();
                      onLongPressReact?.call();
                    },
                    child: PetMotionView(
                      visualState: activeState,
                      size: size,
                      controller: controller,
                      scheduler: scheduler,
                      riveRenderer: riveRenderer,
                      enableRive: enableRive,
                      accessory: accessory,
                      focusProgress: focusProgress,
                      craftProgress: craftProgress,
                      showStateBadge: showStateBadge,
                      growthProfile: growthProfile,
                      focusPhase: focusPhase,
                      focusCategoryId: focusCategoryId,
                      poseSpec: poseSpec,
                    ),
                  )
                : PetMotionView(
                    visualState: activeState,
                    size: size,
                    scheduler: scheduler,
                    riveRenderer: riveRenderer,
                    enableRive: enableRive,
                    accessory: accessory,
                    focusProgress: focusProgress,
                    craftProgress: craftProgress,
                    showStateBadge: showStateBadge,
                    growthProfile: growthProfile,
                    focusPhase: focusPhase,
                    focusCategoryId: focusCategoryId,
                  ),
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
