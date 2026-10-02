import '../runtime/companion_action_manifest.dart';
import 'sprite_animation_asset.dart';
import 'sprite_animation_manifest.dart';

/// The shipped animation contracts, as Dart data.
///
/// ## Why this exists alongside the JSON
///
/// `assets/companions/<companion>/animation_manifest.json` is the **authoring
/// source**. The runtime needs the contract *synchronously* — a page must be able
/// to ask "how many walk frames should there be" without an `await` between app
/// start and first paint.
///
/// So the same data is mirrored here, and
/// `sprite_animation_manifest_parity_test.dart` parses the shipped JSON and fails
/// if the two disagree in any field. Drift becomes a test failure rather than a
/// silently wrong contract.
///
/// ## It is still data
///
/// There is no companion behaviour and no species switch. Adding a companion is
/// a row here plus its JSON.
abstract final class SpriteAnimationManifestData {
  const SpriteAnimationManifestData._();

  /// The Mochi pack's contract — the only pack with an animation contract so
  /// far. The cat and rabbit packs ship frames but no production plan yet, which
  /// is why looking one up is a `null` rather than an error.
  static const SpriteAnimationManifest mochi = SpriteAnimationManifest(
    companionId: 'dog',
    posePack: 'mochi',
    canvasWidth: 1024,
    canvasHeight: 1024,
    groundBaseline: 919,
    centerAnchor: 511,
    anchorTolerancePx: 2,
    firstBatch: ['idle', 'walk', 'sit_down', 'stand_up'],
    assets: {
      'idle': SpriteAnimationAsset(
        actionId: 'idle',
        targetFrameCount: 6,
        fps: 5,
        loopMode: SpriteLoopMode.loop,
        role: SpriteAssetRole.ambient,
      ),
      'walk': SpriteAnimationAsset(
        actionId: 'walk',
        targetFrameCount: 6,
        fps: 8,
        loopMode: SpriteLoopMode.loop,
        role: SpriteAssetRole.ambient,
      ),
      'sit_down': SpriteAnimationAsset(
        actionId: 'sit_down',
        targetFrameCount: 4,
        fps: 8,
        loopMode: SpriteLoopMode.once,
        role: SpriteAssetRole.transition,
      ),
      'stand_up': SpriteAnimationAsset(
        actionId: 'stand_up',
        targetFrameCount: 4,
        fps: 8,
        loopMode: SpriteLoopMode.once,
        role: SpriteAssetRole.transition,
      ),
      'focus_write': SpriteAnimationAsset(
        actionId: 'focus_write',
        targetFrameCount: 4,
        fps: 5,
        loopMode: SpriteLoopMode.loop,
        role: SpriteAssetRole.task,
      ),
      'focus_read': SpriteAnimationAsset(
        actionId: 'focus_read',
        targetFrameCount: 3,
        fps: 5,
        loopMode: SpriteLoopMode.pingPong,
        role: SpriteAssetRole.task,
      ),
      'focus_think': SpriteAnimationAsset(
        actionId: 'focus_think',
        targetFrameCount: 3,
        fps: 4,
        loopMode: SpriteLoopMode.pingPong,
        role: SpriteAssetRole.task,
      ),
      'craft_work': SpriteAnimationAsset(
        actionId: 'craft_work',
        targetFrameCount: 4,
        fps: 5,
        loopMode: SpriteLoopMode.loop,
        role: SpriteAssetRole.task,
      ),
      'pause_rest': SpriteAnimationAsset(
        actionId: 'pause_rest',
        targetFrameCount: 2,
        fps: 3,
        loopMode: SpriteLoopMode.pingPong,
        role: SpriteAssetRole.rest,
      ),
      'sleep': SpriteAnimationAsset(
        actionId: 'sleep',
        targetFrameCount: 2,
        fps: 3,
        loopMode: SpriteLoopMode.loop,
        role: SpriteAssetRole.rest,
      ),
      'celebrate': SpriteAnimationAsset(
        actionId: 'celebrate',
        targetFrameCount: 5,
        fps: 8,
        loopMode: SpriteLoopMode.once,
        role: SpriteAssetRole.celebration,
      ),
      'tap_react': SpriteAnimationAsset(
        actionId: 'tap_react',
        targetFrameCount: 3,
        fps: 8,
        loopMode: SpriteLoopMode.once,
        role: SpriteAssetRole.interaction,
      ),
      'pet_react': SpriteAnimationAsset(
        actionId: 'pet_react',
        targetFrameCount: 3,
        fps: 6,
        loopMode: SpriteLoopMode.once,
        role: SpriteAssetRole.interaction,
      ),
    },
  );

  /// companion id -> contract, for companions that have one.
  static const Map<String, SpriteAnimationManifest> byCompanion = {
    'dog': mochi,
  };

  /// The contract for [companionId], or `null` when none is authored yet.
  static SpriteAnimationManifest? forCompanion(String companionId) =>
      byCompanion[companionId];
}
