import 'package:flutter/material.dart';
import 'companion_frame_source.dart';

import 'companion_action_manifest.dart';
import 'companion_action_manifest_data.dart';
import 'companion_context.dart';
import 'companion_pose.dart';
import 'companion_presentation_intent.dart';
import 'companion_sprite_player.dart';
import 'companion_visual_provider.dart';

/// The shared sprite presentation used by every companion.
///
/// ## Why one widget rather than one per species
///
/// A sprite pack is already species-agnostic: frames, a frame rate and a loop
/// mode. The only thing a companion contributes is which pack it uses, so the
/// chrome (message, gesture, badge, semantics) is identical for all of them. The
/// companion key is *data* — a lookup into [CompanionActionManifestData] — not a
/// branch on a species.
///
/// ## Falling back honestly
///
/// [specFor] returns `null` when the companion ships no sequence for a pose, and
/// the caller then draws whatever real art it has. That is the only fallback
/// allowed: a companion never borrows another companion's frames.
abstract final class CompanionSpriteArt {
  const CompanionSpriteArt._();

  /// The spec for `(companionKey, pose)`, or `null` when none ships.
  static CompanionActionSpec? specFor(String companionKey, CompanionPose pose) {
    final manifest = CompanionActionManifestData.forCompanion(companionKey);
    if (manifest == null) return null;
    final spec = manifest.specFor(pose.id);
    if (spec == null || spec.isEmpty) return null;
    return spec;
  }

  /// The spec to *draw* for `(companionKey, pose)`.
  ///
  /// Unlike [specFor], this honours the pack's semantic fallback, so a room
  /// anchor reuses the sprite action it stands for — `bookshelf → focus_read`,
  /// `desk → focus_write` — instead of needing a duplicate room-only sequence.
  /// The fallback never leaves the species: it can only reach an action in this
  /// companion's own pack.
  ///
  /// Returns `null` only when the pack has no sequence at all to offer, which is
  /// the caller's cue to draw whatever real art it has.
  static CompanionActionSpec? resolveFor(
    String companionKey,
    CompanionPose pose,
  ) {
    final manifest = CompanionActionManifestData.forCompanion(companionKey);
    if (manifest == null) return null;
    return manifest.specForRendering(pose);
  }

  /// The spec for a raw action id, for animations that are not poses.
  ///
  /// `walk`, `sit_down` and `stand_up` are animation states with no
  /// [CompanionPose] behind them, so they cannot be reached through [resolveFor]
  /// — there is no pose to look up. This is how the locomotion layer asks for
  /// the walk sequence directly.
  ///
  /// Returns `null` when the pack ships no such sequence, which is the honest
  /// answer while the walk frames are still in production: the caller then draws
  /// whatever real art it has rather than pretending a transform is a walk.
  static CompanionActionSpec? specForAction(
    String companionKey,
    String actionId,
  ) {
    final manifest = CompanionActionManifestData.forCompanion(companionKey);
    if (manifest == null) return null;
    final spec = manifest.specFor(actionId);
    if (spec == null || spec.isEmpty) return null;
    return spec;
  }

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
}

/// Draws a companion from a production sprite sequence, with the gesture, badge
/// and accessibility contract the app uses everywhere.
class CompanionSpriteAvatar extends StatelessWidget {
  final CompanionActionSpec spec;
  final CompanionPresentationIntent intent;
  final CompanionVisualOptions options;

  /// Where the frames' bytes come from.
  ///
  /// Bundled assets by default, which is every built-in pack. A pack-backed
  /// provider passes the installed pack's directory. The widget, the player and
  /// everything below them are unchanged either way.
  final CompanionFrameSource frameSource;

  const CompanionSpriteAvatar({
    super.key,
    required this.spec,
    required this.intent,
    required this.options,
    this.frameSource = const CompanionFrameSource.assets(),
  });

  @override
  Widget build(BuildContext context) {
    final name = options.displayName;
    final state = CompanionSpriteArt.stateLabel(intent.baseContext);
    final controller = options.controller;

    final art = CompanionSpritePlayer(
      spec: spec,
      size: options.size,
      reducedMotion: intent.reducedMotion,
      semanticLabel: '$name $state',
      frameSource: frameSource,
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
        // The wrapper supplies the whole name, so it excludes what it wraps: the
        // sprite carries `'$name $state'` as its own `semanticLabel`, and
        // without this the two merged and the device tree read
        // `小猫 空闲\n小猫 空闲, 点一下会回应，长按可以摸摸头`.
        //
        // Found the moment a companion came from an imported pack: until then the
        // home avatar drew through the rig, whose wrapper already excludes. This
        // path only runs for a companion with a sprite spec.
        //
        // Excluding also drops the child's gestures, so both are mirrored here —
        // a named wrapper with no action of its own is a button that cannot be
        // pressed.
        Semantics(
          excludeSemantics: true,
          button: controller != null,
          label: '$name $state',
          hint: controller != null ? '点一下会回应，长按可以摸摸头' : null,
          onTap: controller != null
              ? () {
                  controller.triggerInteract();
                  options.onTapReact?.call();
                }
              : null,
          onLongPress: controller != null
              ? () {
                  controller.triggerStroke();
                  options.onLongPressReact?.call();
                }
              : null,
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
