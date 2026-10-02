import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/growth/mochi_growth_profile.dart';
import '../../domain/models/enums.dart';
import '../controllers/home_controller.dart';
import '../widgets/pet_avatar_widget.dart';
import 'focus_phase.dart';
import 'mochi_pose_spec.dart';
import 'runtime/companion_action_manifest.dart';
import 'runtime/companion_action_manifest_data.dart';
import 'runtime/companion_context.dart';
import 'runtime/companion_pose.dart';
import 'runtime/companion_presentation_intent.dart';
import 'runtime/companion_sprite_art.dart';
import 'runtime/companion_visual_provider.dart';

/// Mochi's visual provider — the leaf where dog-specific drawing lives.
///
/// ## This is the only place that knows what Mochi looks like
///
/// Every species-specific decision for the dog ends here. Above it, the runtime
/// deals in [CompanionPose] and never in art. That is what lets a fourth
/// companion be added without touching the director, the renderer, or any page.
///
/// ## Two renderers, one identity
///
/// The provider prefers a **production sprite sequence** when the action pack has
/// one for the requested pose — a different drawing per action, which is what a
/// macro action actually is. For any pose the pack does not cover it keeps the
/// approved V4.1 layered rig plus the pose posture, rather than substituting a
/// neighbouring action's sprites: a missing action degrades to the best drawing
/// that really exists, never to a different action pretending to be it.
///
/// ## The asset gap is declared per pose, not per companion
///
/// [productionPoses] is exactly the set of poses with a shipped sprite sequence.
/// A partial pack therefore lands as a partial improvement, and the resolver
/// still reports `ASSET_GAP` for the rest.
class MochiVisualProvider extends CompanionVisualProvider {
  MochiVisualProvider();

  /// The companion id whose action pack this provider draws.
  static const String companionKey = 'dog';

  /// Poses where the approved layered rig stays authoritative.
  ///
  /// `idle` is the one action whose entire content *is* micro-motion — breathe,
  /// blink, ear twitch, sprout sway — and whose cadence is driven by the real
  /// growth stage. Replacing it with a short sequence would make the companion
  /// less alive, not more, and would drop that growth integration. The sprite
  /// pack exists to give the *macro* actions a distinct silhouette, which is
  /// precisely what `idle` does not need.
  ///
  /// This is a rendering-fidelity decision, not an asset gap: the idle sequence
  /// still ships and still counts as a production pose.
  static const Set<String> layeredPoses = {'idle'};

  @override
  String get posePackId => 'mochi';

  /// The poses Mochi ships a real sprite sequence for.
  static final Set<CompanionPose> spritePoses = _spritePoses();

  static Set<CompanionPose> _spritePoses() {
    final manifest = CompanionActionManifestData.forCompanion(companionKey);
    if (manifest == null) return const <CompanionPose>{};
    return {
      for (final pose in CompanionPose.values)
        if (manifest.hasExactAction(pose)) pose,
    };
  }

  @override
  Set<CompanionPose> get productionPoses => spritePoses;

  @override
  Widget build(
    BuildContext context,
    CompanionPresentationIntent intent,
    CompanionVisualOptions options,
  ) {
    // An animation state the behaviour has no pose for — `walk` while the
    // companion is travelling — takes precedence, and is *not* subject to the
    // layered-idle exception below: that exception exists to prefer the rig for
    // a standing idle, not to keep the rig while the character is walking.
    final animationSpec = options.animationState == null
        ? null
        : CompanionSpriteArt.specForAction(
            companionKey,
            options.animationState!.assetActionId,
          );

    // Resolved, not exact: a room anchor reuses the action it stands for
    // (bookshelf reads, desk writes) rather than needing its own sequence.
    final spec = animationSpec ??
        CompanionSpriteArt.resolveFor(companionKey, intent.pose);
    final useLayered =
        animationSpec == null && layeredPoses.contains(intent.pose.id);

    return _MochiPoseAvatar(
      intent: intent,
      options: options,
      poseSpec: MochiPoseSpecs.of(intent.pose),
      spriteSpec: useLayered ? null : spec,
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

  /// The production sequence for this pose, when the dog pack ships one.
  final CompanionActionSpec? spriteSpec;

  const _MochiPoseAvatar({
    required this.intent,
    required this.options,
    required this.poseSpec,
    this.spriteSpec,
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
      spriteSpec: spriteSpec,
      semanticLabelOverride: intent.baseContext == CompanionBaseContext.room
          ? '${options.displayName} 在房间'
          : null,
      onTapReact: options.onTapReact,
      onLongPressReact: options.onLongPressReact,
    );
  }
}
