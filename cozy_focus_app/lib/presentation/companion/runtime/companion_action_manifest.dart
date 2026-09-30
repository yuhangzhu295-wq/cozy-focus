/// Data-driven sprite sequences for the companion renderer.
///
/// ## Where this sits in the pipeline
///
/// REAL BUSINESS STATE -> CompanionBehaviorDirector -> SEMANTIC ACTION
///   -> CompanionActionManifest -> CompanionSpriteSequence -> CompanionSpritePlayer
///
/// The director already chooses a *semantic* macro behaviour. This file maps that
/// behaviour onto a **frame sequence** — a list of image files, a frame rate, a
/// loop mode and a reduced-motion contract. It contains no dog, no cat, no rabbit
/// and no focus logic; a fourth companion arrives as another manifest row.
///
/// ## Macro action is not micro motion
///
/// A macro action is a different silhouette — a different sequence of drawings.
/// Micro motion (blink, breathe, ear, tail) stays in the layered renderer and is
/// layered *on top* where it helps. Nothing here may pretend a numeric difference
/// in a transform is a new macro action.
library;

import 'companion_pose.dart';

/// How a sequence repeats.
enum SpriteLoopMode {
  /// Restart from frame 0 after the last frame.
  loop('loop'),

  /// Play forward then backward, so the last frame connects to the first.
  pingPong('pingpong'),

  /// Play once and hold the final frame. Used by one-shot reactions.
  once('once');

  final String id;

  const SpriteLoopMode(this.id);

  static SpriteLoopMode fromId(String? id) {
    for (final mode in SpriteLoopMode.values) {
      if (mode.id == id) return mode;
    }
    return SpriteLoopMode.loop;
  }
}

/// One action's playback contract.
///
/// Declares what the sequence *is* — how many frames, how fast, how it repeats,
/// whether an overlay may interrupt it, and what Reduced Motion shows instead.
class CompanionActionSpec {
  /// The semantic action id, e.g. `focus_read`.
  final String actionId;

  /// Asset paths, in playback order. Never a page-visible path.
  final List<String> frames;

  /// Playback rate. The brief allows 4–8 fps; there is no 60 fps renderer.
  final int fps;

  /// How the sequence repeats.
  final SpriteLoopMode loopMode;

  /// Whether a tap/pet overlay may cut this action short.
  final bool interruptible;

  /// The frames Reduced Motion presents.
  ///
  /// Reduced motion preserves the *semantic* action — it never swaps the action
  /// for a different one — and only lowers how much moves.
  final List<int> reducedMotionFrames;

  /// The frame count the production brief targets for this action.
  final int targetFrameCount;

  const CompanionActionSpec({
    required this.actionId,
    required this.frames,
    this.fps = 5,
    this.loopMode = SpriteLoopMode.loop,
    this.interruptible = true,
    this.reducedMotionFrames = const [0],
    this.targetFrameCount = 1,
  });

  bool get isEmpty => frames.isEmpty;

  int get frameCount => frames.length;

  /// Whether this action has every frame the brief asks for.
  bool get isComplete => frames.length >= targetFrameCount;

  /// The frame to hold when motion is reduced.
  String? get reducedMotionFrame {
    if (frames.isEmpty) return null;
    final index = reducedMotionFrames.isEmpty ? 0 : reducedMotionFrames.first;
    return frames[index.clamp(0, frames.length - 1)];
  }

  /// The frame interval, from [fps]. Clamped so a bad manifest cannot divide by
  /// zero or spin the scheduler.
  Duration get frameDuration {
    final rate = fps < 1 ? 1 : (fps > 30 ? 30 : fps);
    return Duration(milliseconds: (1000 / rate).round());
  }

  factory CompanionActionSpec.fromJson(
    String actionId,
    Map<String, dynamic> json,
  ) {
    final rawFrames = json['frames'];
    if (rawFrames is! List) {
      throw const FormatException('action manifest: "frames" must be a list');
    }
    return CompanionActionSpec(
      actionId: actionId,
      frames: List<String>.unmodifiable(rawFrames.cast<String>()),
      fps: (json['fps'] as num?)?.toInt() ?? 5,
      loopMode: SpriteLoopMode.fromId(json['loopMode'] as String?),
      interruptible: json['interruptible'] as bool? ?? true,
      reducedMotionFrames: ((json['reducedMotionFrames'] as List?) ?? const [0])
          .map((e) => (e as num).toInt())
          .toList(growable: false),
      targetFrameCount: (json['targetFrameCount'] as num?)?.toInt() ??
          (rawFrames.isEmpty ? 0 : rawFrames.length),
    );
  }

  @override
  String toString() =>
      'CompanionActionSpec($actionId ${frames.length}f ${fps}fps $loopMode)';
}

/// One companion's sprite pack: its canvas contract and its actions.
///
/// The canvas contract is what stops a pose change from making the companion
/// jump: every frame of every action shares one canvas size, one ground baseline
/// and one centre anchor.
class CompanionActionManifest {
  final String companionId;

  /// The pose pack (visual provider) this manifest belongs to.
  final String posePack;

  final int canvasWidth;
  final int canvasHeight;

  /// The y of the ground contact line, in canvas units.
  final int groundBaseline;

  /// The x of the character's vertical centre, in canvas units.
  final int centerAnchor;

  /// actionId -> spec.
  final Map<String, CompanionActionSpec> actions;

  /// requested action -> same-species fallback action.
  ///
  /// The brief forbids silently showing another species. A missing action
  /// degrades *within* the species: requested -> semantic sibling -> idle.
  final Map<String, String> semanticFallback;

  /// requested action -> the action whose *drawing* it reuses.
  ///
  /// A strict subset of [semanticFallback], and the only map rendering consults.
  /// A behaviour-only chain such as `celebrate -> idle` belongs in
  /// [semanticFallback] but must never become a drawing: replacing a celebration
  /// with a placid idle drawing is worse than the caller's own fallback.
  final Map<String, String> drawAliases;

  const CompanionActionManifest({
    required this.companionId,
    required this.posePack,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.groundBaseline,
    required this.centerAnchor,
    required this.actions,
    this.semanticFallback = const {},
    this.drawAliases = const {},
  });

  /// The action ids this companion really ships.
  Set<String> get actionIds => actions.keys.toSet();

  /// The spec for [actionId], or `null` when it is not shipped.
  CompanionActionSpec? specFor(String actionId) => actions[actionId];

  /// Resolves [pose] to an action this companion really has.
  ///
  /// Returns `null` only when even `idle` is missing — the one case the caller
  /// must handle by falling back to the non-sprite renderer rather than by
  /// borrowing another companion's art.
  CompanionActionSpec? resolve(CompanionPose pose) {
    final direct = actions[pose.id];
    if (direct != null && !direct.isEmpty) return direct;

    final fallbackId = semanticFallback[pose.id];
    if (fallbackId != null) {
      final fallback = actions[fallbackId];
      if (fallback != null && !fallback.isEmpty) return fallback;
    }

    final idle = actions['idle'];
    if (idle != null && !idle.isEmpty) return idle;
    return null;
  }

  /// Resolves [pose] for *rendering*, which is stricter than [resolve].
  ///
  /// It honours only the explicitly declared [drawAliases] entries — the
  /// room anchors that stand for a focus action — and returns `null` otherwise.
  ///
  /// It deliberately does **not** fall through to `idle`. Substituting the idle
  /// sequence for, say, `celebrate` would replace a rig pose that carries a
  /// confetti accent with a placid idle drawing, which is a worse answer than the
  /// caller's own fallback. `idle` as a last resort is a *behaviour selection*
  /// rule (see [resolve]); it is not a drawing rule.
  CompanionActionSpec? specForRendering(CompanionPose pose) {
    final direct = actions[pose.id];
    if (direct != null && !direct.isEmpty) return direct;
    final fallbackId = drawAliases[pose.id];
    if (fallbackId == null) return null;
    final fallback = actions[fallbackId];
    if (fallback == null || fallback.isEmpty) return null;
    return fallback;
  }

  /// Whether [pose] is served by its *own* action rather than a fallback.
  ///
  /// This is the honest per-pose answer the asset gate reports: a partial pack
  /// lands as a partial improvement instead of claiming the whole companion.
  bool hasExactAction(CompanionPose pose) {
    final spec = actions[pose.id];
    return spec != null && !spec.isEmpty;
  }

  /// Every frame path in the pack, for precaching.
  List<String> get allFrames =>
      [for (final spec in actions.values) ...spec.frames];

  /// Action ids whose frame count is below the production brief.
  List<String> get incompleteActions => [
        for (final e in actions.entries)
          if (!e.value.isComplete) e.key
      ]..sort();

  factory CompanionActionManifest.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'];
    if (rawActions is! Map) {
      throw const FormatException('action manifest: "actions" must be a map');
    }
    final actions = <String, CompanionActionSpec>{};
    for (final entry in rawActions.entries) {
      actions[entry.key as String] = CompanionActionSpec.fromJson(
        entry.key as String,
        (entry.value as Map).cast<String, dynamic>(),
      );
    }
    final canvas =
        (json['canvas'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CompanionActionManifest(
      companionId: json['companionId'] as String? ?? '',
      posePack: json['posePack'] as String? ?? '',
      canvasWidth: (canvas['width'] as num?)?.toInt() ?? 1024,
      canvasHeight: (canvas['height'] as num?)?.toInt() ?? 1024,
      groundBaseline: (json['groundBaseline'] as num?)?.toInt() ?? 0,
      centerAnchor: (json['centerAnchor'] as num?)?.toInt() ?? 0,
      actions: Map.unmodifiable(actions),
      semanticFallback: ((json['semanticFallback'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k as String, v as String),
      ),
      drawAliases: ((json['drawAliases'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k as String, v as String),
      ),
    );
  }

  @override
  String toString() => 'CompanionActionManifest($companionId pack=$posePack '
      '${actions.length} actions ${canvasWidth}x$canvasHeight)';
}
