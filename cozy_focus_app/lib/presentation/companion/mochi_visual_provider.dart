import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/growth/mochi_growth_profile.dart';
import '../../domain/models/enums.dart';
import '../controllers/home_controller.dart';
import '../widgets/pet_avatar_widget.dart';
import 'focus_phase.dart';
import 'mochi_pose_spec.dart';
import 'runtime/companion_context.dart';
import 'runtime/companion_id.dart';
import 'runtime/companion_pose.dart';
import 'runtime/companion_presentation_intent.dart';
import 'runtime/companion_visual_provider.dart';

/// Mochi's visual provider — the leaf where dog-specific drawing lives.
///
/// ## This is the only place that knows what Mochi looks like
///
/// Every species-specific decision for the dog ends here. Above it, the runtime
/// deals in [CompanionPose] and never in art. That is what lets a fourth
/// companion be added without touching the director, the renderer, or any page.
///
/// ## It draws the approved V4.1 art
///
/// The provider does not redraw Mochi. It drives the existing approved layered
/// renderer through [PetAvatarWidget], adding the V4.2.1 pose as a posture plus a
/// prop. Mochi's identity is therefore preserved exactly, and the pose layer is
/// additive.
///
/// ## The asset gap is declared, not hidden
///
/// [productionPoses] is empty, and that is the truthful answer: the V4.2.1
/// package states the transparent pose packs are still a production task
/// (`docs/08_Runtime_Asset_GAP.md`). The poses are carried by code-drawn fallback
/// props, and the runtime reports `ASSET_GAP` for every one of them rather than
/// claiming finished art.
class MochiVisualProvider extends CompanionVisualProvider {
  MochiVisualProvider();

  @override
  String get posePackId => 'mochi';

  @override
  Set<CompanionPose> get productionPoses => const <CompanionPose>{};

  @override
  Widget build(
    BuildContext context,
    CompanionPresentationIntent intent,
    CompanionVisualOptions options,
  ) {
    return _MochiPoseAvatar(
      intent: intent,
      options: options,
      poseSpec: MochiPoseSpecs.of(intent.pose),
    );
  }
}

/// The widget half of the Mochi provider.
///
/// A [ConsumerWidget] because the growth profile is real business data
/// (`PetProgress`) that the generic runtime must not be handed: growth is a
/// Mochi presentation concern, so it is resolved here and nowhere above.
class _MochiPoseAvatar extends ConsumerWidget {
  final CompanionPresentationIntent intent;
  final CompanionVisualOptions options;
  final MochiPoseSpec poseSpec;

  const _MochiPoseAvatar({
    required this.intent,
    required this.options,
    required this.poseSpec,
  });

  /// Maps the runtime's base context onto the renderer's existing state enum.
  ///
  /// The overlay deliberately does not appear here: an overlay changes the
  /// *pose*, never the base state, so a tap during focus must not make the badge
  /// or the state machine claim Mochi stopped focusing.
  static PetVisualState visualStateFor(CompanionBaseContext context) {
    switch (context) {
      case CompanionBaseContext.home:
        return PetVisualState.idle;
      case CompanionBaseContext.focus:
        return PetVisualState.focus;
      case CompanionBaseContext.pause:
        return PetVisualState.pause;
      case CompanionBaseContext.complete:
        return PetVisualState.celebrate;
      case CompanionBaseContext.craft:
        return PetVisualState.craft;
      case CompanionBaseContext.room:
        return PetVisualState.idle;
      case CompanionBaseContext.sleep:
        return PetVisualState.sleep;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final growth = MochiGrowthProfile.fromProgress(
        ref.watch(homeControllerProvider).petProgress);

    return PetAvatarWidget(
      visualState: visualStateFor(intent.baseContext),
      size: options.size,
      message: options.message,
      controller: options.controller,
      accessory: options.accessory,
      focusProgress: options.focusProgress,
      craftProgress: intent.craftProgress,
      showStateBadge: options.showStateBadge,
      growthProfile: growth,
      // The existing work-cycle beats still run inside the focus state; the pose
      // refines which work silhouette is shown, it does not replace the cycle.
      focusPhase: FocusPhaseResolver.resolve(intent.focusProgress),
      focusCategoryId: options.focusCategoryId,
      poseSpec: poseSpec,
      onTapReact: options.onTapReact,
      onLongPressReact: options.onLongPressReact,
    );
  }
}

/// The app-wide visual registry.
///
/// The single centralised registration point the fourth-companion contract
/// allows. A new companion adds one provider here; nothing else changes.
CompanionVisualRegistry buildCompanionVisualRegistry() {
  final registry = CompanionVisualRegistry();
  registry.register(MochiVisualProvider(), companionId: CompanionId.dog);
  return registry;
}
