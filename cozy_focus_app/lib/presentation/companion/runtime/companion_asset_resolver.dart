import 'companion_catalog.dart';
import 'companion_id.dart';
import 'companion_pose.dart';
import 'companion_visual_provider.dart';

/// The outcome of asking "what asset satisfies (companion, pose)?".
///
/// Modelled as a value rather than a nullable string so the *reason* is
/// reportable. The V4.2.1 package requires the runtime to say `ASSET_GAP`
/// out loud when production art is missing, and a bare `null` cannot say that.
class CompanionAssetResolution {
  /// Whether a production-quality asset exists for the requested pose.
  final bool hasProductionAsset;

  /// The asset key, when one exists. Never a path a page should use directly.
  final String? assetKey;

  /// The companion the question was asked about.
  final CompanionId companionId;

  /// The pose the question was asked about.
  final CompanionPose pose;

  /// The pose pack that answered, when one was registered.
  final String? posePack;

  /// The gap reason, when [hasProductionAsset] is `false`.
  final String? gapReason;

  const CompanionAssetResolution({
    required this.hasProductionAsset,
    required this.companionId,
    required this.pose,
    this.assetKey,
    this.posePack,
    this.gapReason,
  });

  /// The stable token the gate reports use.
  static const String gapToken = 'ASSET_GAP';

  @override
  String toString() => hasProductionAsset
      ? 'CompanionAssetResolution(${companionId.value}/${pose.id} → $assetKey)'
      : 'CompanionAssetResolution(${companionId.value}/${pose.id} → $gapToken'
          '${gapReason == null ? '' : ': $gapReason'})';
}

/// Resolves `(companionId, pose)` to an asset, without any page knowing a path.
///
/// ## The rule this enforces
///
/// `docs/01_Companion_Runtime_Architecture_SPEC.md` §5: a page must never write
/// `Image.asset('dog_focus_read.png')`. The resolver is the only place that maps
/// a semantic pose onto something drawable, and it answers honestly when nothing
/// drawable exists.
class CompanionAssetResolver {
  final CompanionCatalog catalog;
  final CompanionVisualRegistry registry;

  const CompanionAssetResolver({
    required this.catalog,
    required this.registry,
  });

  /// Resolves [pose] for [companionId].
  CompanionAssetResolution resolve(
      CompanionId companionId, CompanionPose pose) {
    final profile = catalog.profileFor(companionId);
    final provider = registry.providerForPack(profile.posePack) ??
        registry.providerForCompanion(companionId);

    if (provider == null) {
      return CompanionAssetResolution(
        hasProductionAsset: false,
        companionId: companionId,
        pose: pose,
        posePack: profile.posePack,
        gapReason:
            'no visual provider registered for pack "${profile.posePack}"',
      );
    }

    if (!provider.productionPoses.contains(pose)) {
      return CompanionAssetResolution(
        hasProductionAsset: false,
        companionId: companionId,
        pose: pose,
        posePack: provider.posePackId,
        gapReason: 'pose "${pose.id}" has no production asset in pack '
            '"${provider.posePackId}"',
      );
    }

    return CompanionAssetResolution(
      hasProductionAsset: true,
      companionId: companionId,
      pose: pose,
      posePack: provider.posePackId,
      assetKey: '${provider.posePackId}/${pose.id}',
    );
  }

  /// Whether every pose this companion's recipes can select has production art.
  ///
  /// Used by the gate reports to state the asset gap per companion as a fact
  /// rather than as a claim.
  Map<CompanionPose, CompanionAssetResolution> audit(CompanionId companionId) {
    final result = <CompanionPose, CompanionAssetResolution>{};
    for (final pose in CompanionPose.values) {
      result[pose] = resolve(companionId, pose);
    }
    return result;
  }
}
