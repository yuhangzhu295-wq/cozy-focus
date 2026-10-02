import 'companion_action_manifest.dart';

/// The action packs the app ships, as Dart data.
///
/// ## Why this exists alongside the JSON
///
/// \`assets/companions/<companion>/manifest.json\` is the **authoring source**:
/// readable, diffable, and what the asset pipeline writes. The presentation layer
/// needs it *synchronously* — the first frame of a focus session must be the right
/// drawing without an \`await\` between app start and first paint.
///
/// So the same data is mirrored here, and
/// \`companion_action_manifest_parity_test.dart\` parses the shipped JSON and fails
/// if the two disagree in any field. Drift becomes a test failure rather than a
/// silently wrong animation.
///
/// ## It is still data
///
/// There is no species switch here. The engine reads these tables generically,
/// which is why a fourth companion is a row plus a frame set.
abstract final class CompanionActionManifestData {
  const CompanionActionManifestData._();

  /// \`companion id -> action pack\`.
  static const Map<String, CompanionActionManifest> manifests = {
    'dog': CompanionActionManifest(
      companionId: 'dog',
      posePack: 'mochi',
      canvasWidth: 1024,
      canvasHeight: 1024,
      groundBaseline: 919,
      centerAnchor: 511,
      actions: {
        'celebrate': CompanionActionSpec(
          actionId: 'celebrate',
          frames: [
            'assets/companions/dog/celebrate_000.png',
            'assets/companions/dog/celebrate_001.png',
            'assets/companions/dog/celebrate_002.png',
            'assets/companions/dog/celebrate_003.png',
            'assets/companions/dog/celebrate_004.png',
          ],
          fps: 8,
          loopMode: SpriteLoopMode.once,
          interruptible: false,
          reducedMotionFrames: [0],
          targetFrameCount: 5,
        ),
        'craft_work': CompanionActionSpec(
          actionId: 'craft_work',
          frames: [
            'assets/companions/dog/craft_work_000.png',
            'assets/companions/dog/craft_work_001.png',
            'assets/companions/dog/craft_work_002.png',
            'assets/companions/dog/craft_work_003.png',
          ],
          fps: 5,
          loopMode: SpriteLoopMode.loop,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 4,
        ),
        'focus_read': CompanionActionSpec(
          actionId: 'focus_read',
          frames: [
            'assets/companions/dog/focus_read_000.png',
            'assets/companions/dog/focus_read_001.png',
            'assets/companions/dog/focus_read_002.png',
          ],
          fps: 5,
          loopMode: SpriteLoopMode.pingPong,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 3,
        ),
        'focus_think': CompanionActionSpec(
          actionId: 'focus_think',
          frames: [
            'assets/companions/dog/focus_think_000.png',
            'assets/companions/dog/focus_think_001.png',
            'assets/companions/dog/focus_think_002.png',
          ],
          fps: 4,
          loopMode: SpriteLoopMode.pingPong,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 3,
        ),
        'focus_write': CompanionActionSpec(
          actionId: 'focus_write',
          frames: [
            'assets/companions/dog/focus_write_000.png',
            'assets/companions/dog/focus_write_001.png',
            'assets/companions/dog/focus_write_002.png',
            'assets/companions/dog/focus_write_003.png',
          ],
          fps: 5,
          loopMode: SpriteLoopMode.loop,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 4,
        ),
        'idle': CompanionActionSpec(
          actionId: 'idle',
          frames: [
            'assets/companions/dog/idle_000.png',
            'assets/companions/dog/idle_001.png',
            'assets/companions/dog/idle_002.png',
            'assets/companions/dog/idle_003.png',
            'assets/companions/dog/idle_004.png',
            'assets/companions/dog/idle_005.png',
          ],
          fps: 5,
          loopMode: SpriteLoopMode.loop,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 6,
        ),
        'pause_rest': CompanionActionSpec(
          actionId: 'pause_rest',
          frames: [
            'assets/companions/dog/pause_rest_000.png',
            'assets/companions/dog/pause_rest_001.png',
          ],
          fps: 3,
          loopMode: SpriteLoopMode.pingPong,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 2,
        ),
        'pet_react': CompanionActionSpec(
          actionId: 'pet_react',
          frames: [
            'assets/companions/dog/pet_react_000.png',
            'assets/companions/dog/pet_react_001.png',
            'assets/companions/dog/pet_react_002.png',
          ],
          fps: 6,
          loopMode: SpriteLoopMode.once,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 3,
        ),
        'sit_down': CompanionActionSpec(
          actionId: 'sit_down',
          frames: [
            'assets/companions/dog/sit_down_000.png',
            'assets/companions/dog/sit_down_001.png',
            'assets/companions/dog/sit_down_002.png',
            'assets/companions/dog/sit_down_003.png',
          ],
          fps: 8,
          loopMode: SpriteLoopMode.once,
          interruptible: false,
          reducedMotionFrames: [0],
          targetFrameCount: 4,
        ),
        'sleep': CompanionActionSpec(
          actionId: 'sleep',
          frames: [
            'assets/companions/dog/sleep_000.png',
            'assets/companions/dog/sleep_001.png',
          ],
          fps: 3,
          loopMode: SpriteLoopMode.loop,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 2,
        ),
        'stand_up': CompanionActionSpec(
          actionId: 'stand_up',
          frames: [
            'assets/companions/dog/stand_up_000.png',
            'assets/companions/dog/stand_up_001.png',
            'assets/companions/dog/stand_up_002.png',
            'assets/companions/dog/stand_up_003.png',
          ],
          fps: 8,
          loopMode: SpriteLoopMode.once,
          interruptible: false,
          reducedMotionFrames: [0],
          targetFrameCount: 4,
        ),
        'tap_react': CompanionActionSpec(
          actionId: 'tap_react',
          frames: [
            'assets/companions/dog/tap_react_000.png',
            'assets/companions/dog/tap_react_001.png',
            'assets/companions/dog/tap_react_002.png',
          ],
          fps: 8,
          loopMode: SpriteLoopMode.once,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 3,
        ),
        'walk': CompanionActionSpec(
          actionId: 'walk',
          frames: [
            'assets/companions/dog/walk_000.png',
            'assets/companions/dog/walk_001.png',
            'assets/companions/dog/walk_002.png',
            'assets/companions/dog/walk_003.png',
            'assets/companions/dog/walk_004.png',
            'assets/companions/dog/walk_005.png',
          ],
          fps: 8,
          loopMode: SpriteLoopMode.loop,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 6,
        ),
      },
      semanticFallback: {
        'celebrate': 'idle',
        'craft_work': 'idle',
        'finish': 'focus_write',
        'focus_read': 'idle',
        'focus_think': 'idle',
        'focus_write': 'idle',
        'glance': 'idle',
        'idle': 'idle',
        'micro_rest': 'pause_rest',
        'pause_rest': 'idle',
        'pet_react': 'idle',
        'prepare': 'idle',
        'room_read': 'focus_read',
        'room_relax': 'pause_rest',
        'room_sit': 'idle',
        'room_sleep': 'sleep',
        'room_work': 'focus_write',
        'sleep': 'pause_rest',
        'tap_react': 'idle',
      },
      drawAliases: {
        'finish': 'focus_write',
        'micro_rest': 'pause_rest',
        'room_read': 'focus_read',
        'room_relax': 'pause_rest',
        'room_sleep': 'sleep',
        'room_work': 'focus_write',
      },
    ),
    'cat': CompanionActionManifest(
      companionId: 'cat',
      posePack: 'cat',
      canvasWidth: 1024,
      canvasHeight: 1024,
      groundBaseline: 919,
      centerAnchor: 511,
      actions: {
        'celebrate': CompanionActionSpec(
          actionId: 'celebrate',
          frames: [
            'assets/companions/cat/celebrate_000.png',
            'assets/companions/cat/celebrate_001.png',
            'assets/companions/cat/celebrate_002.png',
            'assets/companions/cat/celebrate_003.png',
            'assets/companions/cat/celebrate_004.png',
          ],
          fps: 8,
          loopMode: SpriteLoopMode.once,
          interruptible: false,
          reducedMotionFrames: [0],
          targetFrameCount: 5,
        ),
        'craft_work': CompanionActionSpec(
          actionId: 'craft_work',
          frames: [
            'assets/companions/cat/craft_work_000.png',
            'assets/companions/cat/craft_work_001.png',
            'assets/companions/cat/craft_work_002.png',
            'assets/companions/cat/craft_work_003.png',
          ],
          fps: 5,
          loopMode: SpriteLoopMode.loop,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 4,
        ),
        'focus_read': CompanionActionSpec(
          actionId: 'focus_read',
          frames: [
            'assets/companions/cat/focus_read_000.png',
            'assets/companions/cat/focus_read_001.png',
            'assets/companions/cat/focus_read_002.png',
          ],
          fps: 5,
          loopMode: SpriteLoopMode.pingPong,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 3,
        ),
        'focus_think': CompanionActionSpec(
          actionId: 'focus_think',
          frames: [
            'assets/companions/cat/focus_think_000.png',
            'assets/companions/cat/focus_think_001.png',
            'assets/companions/cat/focus_think_002.png',
          ],
          fps: 4,
          loopMode: SpriteLoopMode.pingPong,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 3,
        ),
        'focus_write': CompanionActionSpec(
          actionId: 'focus_write',
          frames: [
            'assets/companions/cat/focus_write_000.png',
            'assets/companions/cat/focus_write_001.png',
            'assets/companions/cat/focus_write_002.png',
            'assets/companions/cat/focus_write_003.png',
          ],
          fps: 5,
          loopMode: SpriteLoopMode.loop,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 4,
        ),
        'idle': CompanionActionSpec(
          actionId: 'idle',
          frames: [
            'assets/companions/cat/idle_000.png',
            'assets/companions/cat/idle_001.png',
            'assets/companions/cat/idle_002.png',
            'assets/companions/cat/idle_003.png',
            'assets/companions/cat/idle_004.png',
            'assets/companions/cat/idle_005.png',
          ],
          fps: 5,
          loopMode: SpriteLoopMode.loop,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 6,
        ),
        'pause_rest': CompanionActionSpec(
          actionId: 'pause_rest',
          frames: [
            'assets/companions/cat/pause_rest_000.png',
            'assets/companions/cat/pause_rest_001.png',
          ],
          fps: 3,
          loopMode: SpriteLoopMode.pingPong,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 2,
        ),
        'pet_react': CompanionActionSpec(
          actionId: 'pet_react',
          frames: [
            'assets/companions/cat/pet_react_000.png',
            'assets/companions/cat/pet_react_001.png',
            'assets/companions/cat/pet_react_002.png',
          ],
          fps: 6,
          loopMode: SpriteLoopMode.once,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 3,
        ),
        'sit_down': CompanionActionSpec(
          actionId: 'sit_down',
          frames: [
            'assets/companions/cat/sit_down_000.png',
            'assets/companions/cat/sit_down_001.png',
            'assets/companions/cat/sit_down_002.png',
            'assets/companions/cat/sit_down_003.png',
          ],
          fps: 8,
          loopMode: SpriteLoopMode.once,
          interruptible: false,
          reducedMotionFrames: [0],
          targetFrameCount: 4,
        ),
        'sleep': CompanionActionSpec(
          actionId: 'sleep',
          frames: [
            'assets/companions/cat/sleep_000.png',
            'assets/companions/cat/sleep_001.png',
          ],
          fps: 3,
          loopMode: SpriteLoopMode.loop,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 2,
        ),
        'stand_up': CompanionActionSpec(
          actionId: 'stand_up',
          frames: [
            'assets/companions/cat/stand_up_000.png',
            'assets/companions/cat/stand_up_001.png',
            'assets/companions/cat/stand_up_002.png',
            'assets/companions/cat/stand_up_003.png',
          ],
          fps: 8,
          loopMode: SpriteLoopMode.once,
          interruptible: false,
          reducedMotionFrames: [0],
          targetFrameCount: 4,
        ),
        'tap_react': CompanionActionSpec(
          actionId: 'tap_react',
          frames: [
            'assets/companions/cat/tap_react_000.png',
            'assets/companions/cat/tap_react_001.png',
            'assets/companions/cat/tap_react_002.png',
          ],
          fps: 8,
          loopMode: SpriteLoopMode.once,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 3,
        ),
        'walk': CompanionActionSpec(
          actionId: 'walk',
          frames: [
            'assets/companions/cat/walk_000.png',
            'assets/companions/cat/walk_001.png',
            'assets/companions/cat/walk_002.png',
            'assets/companions/cat/walk_003.png',
            'assets/companions/cat/walk_004.png',
            'assets/companions/cat/walk_005.png',
          ],
          fps: 8,
          loopMode: SpriteLoopMode.loop,
          interruptible: true,
          reducedMotionFrames: [0],
          targetFrameCount: 6,
        ),
      },
      semanticFallback: {
        'celebrate': 'idle',
        'craft_work': 'idle',
        'finish': 'focus_write',
        'focus_read': 'idle',
        'focus_think': 'idle',
        'focus_write': 'idle',
        'glance': 'idle',
        'idle': 'idle',
        'micro_rest': 'pause_rest',
        'pause_rest': 'idle',
        'pet_react': 'idle',
        'prepare': 'idle',
        'room_read': 'focus_read',
        'room_relax': 'pause_rest',
        'room_sit': 'idle',
        'room_sleep': 'sleep',
        'room_work': 'focus_write',
        'sleep': 'pause_rest',
        'tap_react': 'idle',
      },
      drawAliases: {
        'finish': 'focus_write',
        'micro_rest': 'pause_rest',
        'room_read': 'focus_read',
        'room_relax': 'pause_rest',
        'room_sleep': 'sleep',
        'room_work': 'focus_write',
      },
    ),
  };

  /// The action pack for [companionId], or \`null\` when none ships.
  static CompanionActionManifest? forCompanion(String companionId) =>
      manifests[companionId];

  /// Every frame path the runtime may ask the bundle for.
  static List<String> get allFrames => [
        for (final manifest in manifests.values) ...manifest.allFrames,
      ];
}
