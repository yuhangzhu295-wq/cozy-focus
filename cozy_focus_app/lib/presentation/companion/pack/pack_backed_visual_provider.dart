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

  /// The spec this pack would draw, or null when it has nothing for it.
  ///
  /// Separated from [build] so the decision is assertable without a widget tree.
  /// That matters more than it sounds: rendering a pack means reading frames
  /// from disk, and a widget test that waits on a file-backed image stream hangs
  /// rather than fails — so the choice between "draw the state", "draw the pose"
  /// and "draw nothing" has to be testable on its own.
  CompanionActionSpec? specFor(
    CompanionPresentationIntent intent,
    CompanionVisualOptions options,
  ) {
    // An animation state with no pose behind it - walk, the stand/sit
    // transitions - is asked for by id, the same way the built-in provider asks.
    //
    // But only if this pack actually ships that action. A state is an *override*
    // of the pose, and an override the pack has no art for is not available to
    // it: forcing it would draw an empty box where the companion was. So the
    // override is declined and the pose path is taken instead, which is exactly
    // what `animationState == null` means. The pack is not asked to fake a walk
    // and no other companion's art is borrowed - the companion is simply shown
    // doing what it can, and the capability report still says `walk` is missing.
    final state = options.animationState;
    final stateSpec =
        state == null ? null : manifest.specFor(state.assetActionId);
    return stateSpec ?? manifest.specForRendering(intent.pose);
  }

  @override
  Widget build(
    BuildContext context,
    CompanionPresentationIntent intent,
    CompanionVisualOptions options,
  ) {
    final spec = specFor(intent, options);

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
