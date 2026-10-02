import '../runtime/companion_action_manifest.dart';

/// What an animation is *for*, in the life loop's vocabulary.
///
/// The role is what lets the behaviour layer ask for "something ambient" rather
/// than naming a specific action, and it is how a future growth stage adds
/// eligible behaviours without the pool being a hand-written list per stage.
enum SpriteAssetRole {
  /// Ambient life: breathing, walking. Always available, never task-bound.
  ambient('ambient'),

  /// Work done during a focus session or a craft job.
  task('task'),

  /// A reaction to the player.
  interaction('interaction'),

  /// Getting from one posture to another. Never a destination.
  transition('transition'),

  /// Resting or asleep.
  rest('rest'),

  /// A completed task, celebrated.
  celebration('celebration');

  final String id;

  const SpriteAssetRole(this.id);

  static SpriteAssetRole? fromId(String? id) {
    if (id == null) return null;
    for (final role in SpriteAssetRole.values) {
      if (role.id == id) return role;
    }
    return null;
  }
}

/// One animation's **production contract**.
///
/// ## Why this is not [CompanionActionSpec]
///
/// A [CompanionActionSpec] describes art that *ships*: it holds frame paths, and
/// the runtime draws from it. This describes art that must be *produced*: a
/// target frame count, a rate and a role, with no paths — because the frames may
/// not exist yet.
///
/// Keeping them apart is what lets the pipeline state a gap honestly. An action
/// with a contract and no frames is *planned*; an action with frames is
/// *produced*. Collapsing the two would force either a manifest full of empty
/// frame lists (which the runtime's own invariants forbid) or a silent claim
/// that planned art is finished.
class SpriteAnimationAsset {
  /// The action id, matching the runtime manifest's key, e.g. `walk`.
  final String actionId;

  /// How many frames the asset brief asks for.
  ///
  /// Production intent, never a transcription of what is on disk — the same
  /// rule the runtime manifest's own `targetFrameCount` follows.
  final int targetFrameCount;

  /// Playback rate the produced frames must be authored for.
  final int fps;

  /// How the sequence repeats once produced.
  final SpriteLoopMode loopMode;

  /// What the animation is for.
  final SpriteAssetRole role;

  const SpriteAnimationAsset({
    required this.actionId,
    required this.targetFrameCount,
    required this.fps,
    required this.loopMode,
    required this.role,
  });

  factory SpriteAnimationAsset.fromJson(
    String actionId,
    Map<String, dynamic> json,
  ) {
    final target = (json['targetFrameCount'] as num?)?.toInt();
    if (target == null || target < 1) {
      throw FormatException(
        'sprite asset "$actionId": targetFrameCount must be >= 1',
      );
    }
    final role = SpriteAssetRole.fromId(json['role'] as String?);
    if (role == null) {
      throw FormatException('sprite asset "$actionId": unknown role '
          '"${json['role']}"');
    }
    return SpriteAnimationAsset(
      actionId: actionId,
      targetFrameCount: target,
      fps: (json['fps'] as num?)?.toInt() ?? 5,
      loopMode: SpriteLoopMode.fromId(json['loopMode'] as String?),
      role: role,
    );
  }

  /// Whether this is a one-shot sequence rather than a loop.
  bool get isOneShot => loopMode == SpriteLoopMode.once;

  @override
  String toString() => 'SpriteAnimationAsset($actionId ${targetFrameCount}f '
      '${fps}fps ${loopMode.id} ${role.id})';
}
