import 'sprite_animation_asset.dart';

/// A companion pack's animation contract: its canvas, its anchor, and the
/// animations it ships or plans to ship.
///
/// ## Where this sits
///
/// ```text
/// animation_manifest.json   the asset pipeline's contract (this file)
///   -> SpriteAnimationManifest   parsed, synchronous
///     -> SpriteAnimationManifestData   the Dart mirror the runtime reads
/// companion_action_manifest_data.dart   what actually ships (frame paths)
/// ```
///
/// The runtime manifest says what can be drawn. This says what must be
/// produced, including animations that do not exist yet — which is the whole
/// point, because a pipeline that can only describe finished work cannot state
/// a gap.
///
/// ## It decides no business
///
/// Its vocabulary is frame counts, frame rates, a canvas and an anchor. There is
/// no companion behaviour, no level, no vitals and no repository here.
class SpriteAnimationManifest {
  /// The companion id, matching the runtime manifest.
  final String companionId;

  /// The pose pack, matching `CompanionProfile.posePack`.
  final String posePack;

  /// The canvas every frame of this pack must be authored on.
  final int canvasWidth;
  final int canvasHeight;

  /// The y every frame's ground contact line must sit on.
  final int groundBaseline;

  /// The x every frame's character centre must sit on.
  final int centerAnchor;

  /// How far a measured anchor may sit from the contract before it is a defect.
  ///
  /// A tolerance rather than an exact match because the art is measured from
  /// rendered pixels: an anti-aliased paw edge lands a pixel either side. Two
  /// pixels is tight enough that a genuinely misplaced frame is caught and loose
  /// enough that a correct one is not failed for its fringe.
  final int anchorTolerancePx;

  /// The action ids being produced in the current batch.
  ///
  /// Data rather than a comment, so "which animations are we making right now"
  /// is answerable by the gate instead of by reading a changelog.
  final List<String> firstBatch;

  /// actionId -> contract.
  final Map<String, SpriteAnimationAsset> assets;

  const SpriteAnimationManifest({
    required this.companionId,
    required this.posePack,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.groundBaseline,
    required this.centerAnchor,
    this.anchorTolerancePx = 2,
    this.firstBatch = const [],
    required this.assets,
  });

  /// The contract for [actionId], or `null` when the pack has none.
  SpriteAnimationAsset? assetFor(String actionId) => assets[actionId];

  /// Every action id the pack has a contract for.
  Set<String> get actionIds => assets.keys.toSet();

  /// Whether [actionId] is being produced in the current batch.
  bool isFirstBatch(String actionId) => firstBatch.contains(actionId);

  /// The frame count the brief asks for, or `null` when there is no contract.
  int? targetFor(String actionId) => assets[actionId]?.targetFrameCount;

  factory SpriteAnimationManifest.fromJson(Map<String, dynamic> json) {
    final canvas =
        (json['canvas'] as Map?)?.cast<String, dynamic>() ?? const {};
    final width = (canvas['width'] as num?)?.toInt();
    final height = (canvas['height'] as num?)?.toInt();
    if (width == null || height == null) {
      throw const FormatException('animation manifest: canvas needs width '
          'and height');
    }

    final rawAssets = json['assets'];
    if (rawAssets is! Map) {
      throw const FormatException('animation manifest: "assets" must be a map');
    }
    final assets = <String, SpriteAnimationAsset>{};
    for (final entry in rawAssets.entries) {
      assets[entry.key as String] = SpriteAnimationAsset.fromJson(
        entry.key as String,
        (entry.value as Map).cast<String, dynamic>(),
      );
    }

    final batch = ((json['firstBatch'] as List?) ?? const [])
        .map((e) => e as String)
        .toList(growable: false);
    for (final actionId in batch) {
      if (!assets.containsKey(actionId)) {
        throw FormatException('animation manifest: firstBatch names '
            '"$actionId", which has no contract');
      }
    }

    return SpriteAnimationManifest(
      companionId: json['companionId'] as String? ?? '',
      posePack: json['posePack'] as String? ?? '',
      canvasWidth: width,
      canvasHeight: height,
      groundBaseline: (json['groundBaseline'] as num?)?.toInt() ?? 0,
      centerAnchor: (json['centerAnchor'] as num?)?.toInt() ?? 0,
      anchorTolerancePx: (json['anchorTolerancePx'] as num?)?.toInt() ?? 2,
      firstBatch: batch,
      assets: Map.unmodifiable(assets),
    );
  }

  @override
  String toString() => 'SpriteAnimationManifest($companionId pack=$posePack '
      '${assets.length} assets '
      '${canvasWidth}x$canvasHeight baseline=$groundBaseline '
      'centre=$centerAnchor)';
}
