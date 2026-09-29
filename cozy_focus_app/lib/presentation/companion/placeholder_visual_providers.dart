import 'package:flutter/material.dart';

import 'mochi_pose_spec.dart';
import 'procedural_companion_art.dart';
import 'runtime/companion_context.dart';
import 'runtime/companion_pose.dart';
import 'runtime/companion_presentation_intent.dart';
import 'runtime/companion_visual_provider.dart';

/// Visual providers for companions whose production art does not exist yet.
///
/// ## The rule these obey
///
/// The brief is explicit: *do not silently substitute dog artwork for missing
/// cat/rabbit production art*, and *if a production-quality visual is missing,
/// report ASSET_GAP*. The architecture may still be completed.
///
/// So each of these draws its own character — a cat with triangle ears, whiskers
/// and a slender tail; a rabbit with long ears and a puff tail — from the shared
/// pose vocabulary. They are placeholders, they are visibly not finished art, and
/// [productionPoses] is empty so every pose resolves to `ASSET_GAP`.
///
/// ## One engine, three companions
///
/// Nothing here is a focus engine. There is no `CatFocusEngine` and no
/// `RabbitFocusEngine`: all three companions are driven by the same
/// [CompanionBehaviorDirector] over the same shared `PetProgress`. These classes
/// only draw.
class CatVisualProvider extends CompanionVisualProvider {
  CatVisualProvider();

  @override
  String get posePackId => 'cat';

  @override
  Set<CompanionPose> get productionPoses => const <CompanionPose>{};

  @override
  Widget build(
    BuildContext context,
    CompanionPresentationIntent intent,
    CompanionVisualOptions options,
  ) =>
      PlaceholderCompanionAvatar(
        silhouette: CompanionSilhouettes.cat,
        intent: intent,
        options: options,
        poseSpec: MochiPoseSpecs.of(intent.pose),
      );
}

/// The rabbit's provider. See [CatVisualProvider] for the shared rationale.
class RabbitVisualProvider extends CompanionVisualProvider {
  RabbitVisualProvider();

  @override
  String get posePackId => 'rabbit';

  @override
  Set<CompanionPose> get productionPoses => const <CompanionPose>{};

  @override
  Widget build(
    BuildContext context,
    CompanionPresentationIntent intent,
    CompanionVisualOptions options,
  ) =>
      PlaceholderCompanionAvatar(
        silhouette: CompanionSilhouettes.rabbit,
        intent: intent,
        options: options,
        poseSpec: MochiPoseSpecs.of(intent.pose),
      );
}

/// Shared widget for a procedurally drawn companion.
///
/// It supplies the same semantics and gesture contract the approved Mochi
/// renderer does, so a placeholder companion is not a second-class citizen: it
/// responds to taps and long presses, carries a state badge, and is reachable by
/// a screen reader with its real name.
class PlaceholderCompanionAvatar extends StatelessWidget {
  final CompanionSilhouette silhouette;
  final CompanionPresentationIntent intent;
  final CompanionVisualOptions options;
  final MochiPoseSpec poseSpec;

  const PlaceholderCompanionAvatar({
    super.key,
    required this.silhouette,
    required this.intent,
    required this.options,
    required this.poseSpec,
  });

  /// The state word shown in the badge, in the app's own vocabulary.
  static String stateLabel(CompanionBaseContext context) {
    switch (context) {
      case CompanionBaseContext.home:
        return '空闲';
      case CompanionBaseContext.focus:
        return '专注中';
      case CompanionBaseContext.pause:
        return '暂停中';
      case CompanionBaseContext.complete:
        return '庆祝中';
      case CompanionBaseContext.craft:
        return '制作中';
      case CompanionBaseContext.room:
        return '在房间';
      case CompanionBaseContext.sleep:
        return '休息中';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = options.displayName;
    final state = stateLabel(intent.baseContext);
    final controller = options.controller;

    final art = ProceduralCompanionArt(
      silhouette: silhouette,
      pose: intent.pose,
      poseSpec: poseSpec,
      size: options.size,
      reducedMotion: intent.reducedMotion,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (options.message != null) ...[
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                options.message!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
        Semantics(
          button: controller != null,
          label: '$name $state',
          hint: controller != null ? '点一下会回应，长按可以摸摸头' : null,
          child: controller != null
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    controller.triggerInteract();
                    options.onTapReact?.call();
                  },
                  onLongPress: () {
                    controller.triggerStroke();
                    options.onLongPressReact?.call();
                  },
                  child: art,
                )
              : art,
        ),
        if (options.showStateBadge) ...[
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEDE6DA)),
              ),
              child: Text(
                '$name $state',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
