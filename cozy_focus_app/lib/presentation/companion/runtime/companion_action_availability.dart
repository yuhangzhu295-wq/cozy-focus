import '../animation/sprite_animation_manifest.dart';
import '../animation/sprite_animation_manifest_data.dart';
import 'companion_action_manifest.dart';
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

  /// Whether the companion can perform [actionId].
  ///
  /// The action ids the room's furniture recipes carry are semantic companion
  /// actions — `room_sit`, `room_read`, `focus_read` — and those are the same
  /// vocabulary this set holds, so the question is a membership test rather than
  /// a translation. An id that is not in the vocabulary at all is `false`, which
  /// is the honest answer: nothing can schedule it.
  ///
  /// This exists so a caller holding an action *id* rather than a pose does not
  /// have to reach for the pose enum, and so there is one place that answers it.
  bool canPerform(String actionId) => schedulable.contains(actionId);

  /// Whether the companion can perform [actionId] **and be seen doing it**.
  ///
  /// Stricter than [canPerform], and the difference is the point. A declared
  /// fallback means the companion can be asked for an action and will draw
  /// something else — a real behaviour the director may schedule, reported
  /// through [fallbackOnly] so nothing counts it as a distinct action.
  ///
  /// But the room *commits* an action the player then watches. An action that
  /// draws something else is not the action it claims to be, and committing it
  /// would show the player a companion using furniture in a way it cannot. So the
  /// room requires the stricter answer — which is the same one the furniture
  /// panel already applies when deciding what to offer, and having both ask one
  /// question in one place is what stops the offer and the decision disagreeing.
  bool canShow(String actionId) =>
      schedulable.contains(actionId) && !fallbackOnly.contains(actionId);

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
  /// **Built-ins only.** An id this build does not ship resolves to the default
  /// companion's availability, mirroring what `CompanionCatalog.profileFor` and
  /// the visual registry do for the *shipped* three.
  ///
  /// That mirroring was right while every companion was compiled in, and it is
  /// wrong the moment a companion can be installed: an installed pack draws its
  /// own art, which is honest about the poses it does not ship, while this would
  /// hand its behaviour the dog's thirteen actions. The two answers would
  /// disagree — the pack would be asked for `focus_read` and draw an empty box.
  ///
  /// So a caller that can see installed packs must not use this entry point for
  /// them. Use [resolveForManifest] with the pack's own manifest, or
  /// `companionAvailabilityProvider`, which does that lookup.
  static CompanionActionAvailability resolve(String companionId) {
    final effectiveId =
        CompanionActionManifestData.forCompanion(companionId) != null
            ? companionId
            : CompanionManifestData.defaultProfileId.value;

    return resolveForManifest(
      companionId: effectiveId,
      manifest: CompanionActionManifestData.forCompanion(effectiveId),
      contract: SpriteAnimationManifestData.forCompanion(effectiveId),
    );
  }

  /// Availability for [companionId] from [manifest], whatever its origin.
  ///
  /// The one implementation. A built-in arrives here with the compiled-in
  /// manifest and its animation contract; an installed pack arrives with the
  /// manifest read from its own directory and **no contract**, because a
  /// contract is a statement about artwork we produced and there is none for a
  /// pack a user brought. That is why [contract] is optional rather than
  /// defaulted to the dog's: defaulting it would report the dog's plan as the
  /// pack's plan, which is the same defect in a different field.
  static CompanionActionAvailability resolveForManifest({
    required String companionId,
    required CompanionActionManifest? manifest,
    SpriteAnimationManifest? contract,
  }) {
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
      companionId: companionId,
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
