import '../animation/sprite_animation_manifest_data.dart';
import 'companion_action_manifest_data.dart';
import 'companion_manifest_data.dart';
import 'companion_pose.dart';

/// Which semantic actions a companion can actually be asked to play, and which
/// of them it can only draw as a fallback.
///
/// ## Why this exists
///
/// The behaviour recipes are shared data: the same `focus/working` recipe lists
/// `focus_read`, `focus_write` and `focus_think` for every companion. But the
/// cat ships no `focus_write` sequence. Without a gate the director would select
/// it and the app would claim a variety of behaviour the companion does not
/// have — the "silently map everything to idle and call it variety" failure.
///
/// ## Missing is not the same as fallback
///
/// These are two different answers and the brief treats them differently:
///
/// * **Missing** — the pack never names the pose. It is not schedulable. A
///   behaviour that does not exist cannot be selected; `stretch` on a pack with
///   no stretch art is exactly this case.
/// * **Fallback** — the pack *names* the pose (`semanticFallback`) but has no
///   drawing of its own, so it will be drawn as something else. It stays
///   schedulable, because the behaviour is real, and it is reported through
///   [hasOwnDrawing] so a caller never counts it as a distinct behaviour or a
///   completed asset.
///
/// Collapsing the two would either invent behaviours a pack has no art for, or
/// delete real ones the moment their art is thin.
class CompanionActionAvailability {
  /// The companion this was resolved for.
  final String companionId;

  /// Pose ids the pack names and can therefore be asked for.
  final Set<String> schedulable;

  /// Pose ids the pack names but has no drawing of its own for.
  ///
  /// A subset of [schedulable]. These are the ones that degrade at draw time.
  final Set<String> fallbackOnly;

  /// Pose ids that have a production contract but no frames yet.
  ///
  /// Contracted-but-unproduced is a *different* answer from both of the above:
  /// the work is planned. It is reported so the gate can name it, never used to
  /// schedule anything.
  final Set<String> planned;

  /// actionId -> contracted frame count, for the gate's report.
  final Map<String, int> targets;

  const CompanionActionAvailability({
    required this.companionId,
    required this.schedulable,
    this.fallbackOnly = const {},
    this.planned = const {},
    this.targets = const {},
  });

  /// Whether [pose] may be selected for this companion.
  bool canSchedule(CompanionPose pose) => schedulable.contains(pose.id);

  /// Whether the pack draws [pose] itself rather than something else.
  ///
  /// `false` for a pose that will be drawn as its fallback. A behaviour chosen
  /// on a `false` is a graceful degradation, not a distinct behaviour.
  bool hasOwnDrawing(CompanionPose pose) => !fallbackOnly.contains(pose.id);

  /// Whether [actionId] is contracted but not yet produced.
  bool isPlanned(String actionId) => planned.contains(actionId);

  /// How many poses this companion can be asked for. For diagnostics and tests.
  int get schedulableCount => schedulable.length;

  /// How many of those will be drawn as something else.
  int get fallbackCount => fallbackOnly.length;

  @override
  String toString() => 'CompanionActionAvailability($companionId '
      '${schedulable.length} schedulable, ${fallbackOnly.length} fallback'
      '${planned.isEmpty ? '' : ', ${planned.length} planned'})';
}

/// Resolves [CompanionActionAvailability] for a companion.
///
/// A pure function of the shipped data — the runtime action manifest for what
/// can be drawn, and the animation contract for what is planned. No repository,
/// no widget tree, no business state, so it is usable from the director, from a
/// test and from a gate report without a container.
abstract final class CompanionActionAvailabilityResolver {
  const CompanionActionAvailabilityResolver._();

  /// Availability for [companionId].
  ///
  /// An id this build does not ship resolves to the **default companion's**
  /// availability, mirroring what `CompanionCatalog.profileFor` and the visual
  /// registry already do. Anything else would leave an unknown id with no
  /// behaviour at all while its picture still rendered, which is the one
  /// combination the runtime is built to avoid.
  static CompanionActionAvailability resolve(String companionId) {
    final effectiveId =
        CompanionActionManifestData.forCompanion(companionId) != null
            ? companionId
            : CompanionManifestData.defaultProfileId.value;

    final manifest = CompanionActionManifestData.forCompanion(effectiveId);
    final contract = SpriteAnimationManifestData.forCompanion(effectiveId);

    final schedulable = <String>{};
    final fallbackOnly = <String>{};
    if (manifest != null) {
      for (final pose in CompanionPose.values) {
        if (!manifest.namesAction(pose.id)) continue;
        // Named, and something to draw. `resolve` is the behaviour-side answer:
        // the exact sequence, or the pack's declared fallback.
        final spec = manifest.resolve(pose);
        if (spec == null || spec.isEmpty) continue;
        schedulable.add(pose.id);
        // Named but drawn as something else.
        if (manifest.specForRendering(pose) == null) {
          fallbackOnly.add(pose.id);
        }
      }
    }

    final planned = <String>{};
    final targets = <String, int>{};
    if (contract != null) {
      for (final asset in contract.assets.values) {
        targets[asset.actionId] = asset.targetFrameCount;
        final spec = manifest?.specFor(asset.actionId);
        if (spec == null || spec.frames.isEmpty) planned.add(asset.actionId);
      }
    }

    return CompanionActionAvailability(
      companionId: effectiveId,
      schedulable: Set.unmodifiable(schedulable),
      fallbackOnly: Set.unmodifiable(fallbackOnly),
      planned: Set.unmodifiable(planned),
      targets: Map.unmodifiable(targets),
    );
  }

  /// Availability for every companion that ships a pack.
  static Map<String, CompanionActionAvailability> resolveAll() => {
        for (final id in CompanionActionManifestData.manifests.keys)
          id: resolve(id),
      };
}
