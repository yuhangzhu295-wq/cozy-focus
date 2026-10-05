/// Draws a companion from an installed pack.
///
/// One generic class, instantiated per pack from that pack's own validated
/// manifest. The brief forbids a provider class per custom pet, and this is why
/// it is not needed: a pack is data, and the only thing that differs between two
/// of them is which data and which directory.
///
/// It draws through the same `CompanionSpriteAvatar` and the same
/// `CompanionSpritePlayer` as every built-in companion, differing only in the
/// frame source. Nothing here knows about species, about the import path, or
/// about how the pack arrived.
library;

import 'package:flutter/widgets.dart';

import '../runtime/companion_action_manifest.dart';
import '../runtime/companion_frame_source.dart';
import '../runtime/companion_pose.dart';
import '../runtime/companion_presentation_intent.dart';
import '../runtime/companion_sprite_art.dart';
import '../runtime/companion_visual_provider.dart';

class PackBackedCompanionVisualProvider extends CompanionVisualProvider {
  /// The pack's validated manifest. Its actions are what this provider can draw.
  final CompanionActionManifest manifest;

  /// The pack's directory.
  final CompanionFrameSource frameSource;

  PackBackedCompanionVisualProvider({
    required this.manifest,
    required this.frameSource,
  });

  @override
  String get posePackId => manifest.posePack;

  /// The poses this pack draws with its own frames.
  ///
  /// Empty is a truthful answer for a pack that ships nothing, and it is what
  /// makes the runtime report an asset gap rather than substitute another
  /// companion's artwork.
  @override
  Set<CompanionPose> get productionPoses => {
        for (final pose in CompanionPose.values)
          if (manifest.hasExactAction(pose)) pose,
      };

  @override
  Widget build(
    BuildContext context,
    CompanionPresentationIntent intent,
    CompanionVisualOptions options,
  ) {
    // An animation state with no pose behind it - walk, the stand/sit
    // transitions - is asked for by id, the same way the built-in provider asks.
    final state = options.animationState;
    final spec = state != null
        ? manifest.specFor(state.assetActionId)
        : manifest.specForRendering(intent.pose);

    if (spec == null) {
      // The pack has no frames for this pose and no declared alias for it.
      // Drawing nothing is the honest answer: borrowing a built-in's art would
      // report a custom companion that is not actually there.
      return SizedBox.square(dimension: options.size);
    }

    return CompanionSpriteAvatar(
      spec: spec,
      intent: intent,
      options: options,
      frameSource: frameSource,
    );
  }
}
