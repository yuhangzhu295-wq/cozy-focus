import 'package:flutter/material.dart';

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

  const CompanionSpriteAvatar({
    super.key,
    required this.spec,
    required this.intent,
    required this.options,
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
