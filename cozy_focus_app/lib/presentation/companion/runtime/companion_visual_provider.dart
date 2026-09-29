import 'package:flutter/widgets.dart';

import '../../controllers/pet_motion_controller.dart';
import 'companion_id.dart';
import 'companion_pose.dart';
import 'companion_presentation_intent.dart';

/// Everything a visual provider needs to draw one intent.
///
/// Deliberately generic: a size, an optional message, an optional accessory, and
/// the shared motion controller. Nothing Mochi-specific appears here, so a new
/// companion's provider is handed the same request shape.
class CompanionVisualOptions {
  final double size;
  final String? message;
  final Widget? accessory;
  final bool showStateBadge;
  final PetMotionController? controller;

  /// Long-arc focus progress, already resolved by the caller from business truth.
  final double? focusProgress;

  /// The real focus category id, for a presentation-only work flavour.
  final String? focusCategoryId;

  const CompanionVisualOptions({
    this.size = 140,
    this.message,
    this.accessory,
    this.showStateBadge = true,
    this.controller,
    this.focusProgress,
    this.focusCategoryId,
  });
}

/// The leaf that actually draws a companion.
///
/// ## Why the species boundary lives here
///
/// `docs/01_Companion_Runtime_Architecture_SPEC.md` §10 and §5 require that the
/// generic runtime never know `dog` / `cat` / `rabbit`, and that pages never know
/// an asset path. Both are satisfied by putting every species-specific drawing
/// decision behind this interface: a provider is registered per pose pack, the
/// renderer looks one up by id, and no `if (species == ...)` exists above this
/// line anywhere in the codebase.
///
/// A provider may legitimately have no production asset for a pose — the shipped
/// V4.2.1 package states plainly that the transparent pose packs are still a
/// production task (`docs/08_Runtime_Asset_GAP.md`). A provider must therefore
/// declare what it really has in [productionPoses] and fall back honestly rather
/// than pretending a transform is a new pose.
abstract class CompanionVisualProvider {
  /// The pose-pack id this provider serves, matching `CompanionProfile.posePack`.
  String get posePackId;

  /// The poses this provider can draw from a *production-quality* asset.
  ///
  /// Empty is a truthful answer. It is what makes the runtime report
  /// `ASSET_GAP` instead of silently substituting another companion's artwork.
  Set<CompanionPose> get productionPoses;

  /// Builds the visual for [intent].
  ///
  /// Implementations must present the semantic pose honestly: when no production
  /// asset exists they render their own fallback for that pose, and they must
  /// never draw a different companion.
  Widget build(
    BuildContext context,
    CompanionPresentationIntent intent,
    CompanionVisualOptions options,
  );
}

/// Maps a companion to the provider that draws it.
///
/// Registration is the single centralised catalog touch-point the fourth-companion
/// contract allows: one profile, one pose pack, one registration here.
class CompanionVisualRegistry {
  final Map<String, CompanionVisualProvider> _byPack = {};
  final Map<CompanionId, CompanionVisualProvider> _byCompanion = {};

  CompanionVisualRegistry();

  /// Registers [provider] for its pack, and optionally for a companion id.
  void register(
    CompanionVisualProvider provider, {
    CompanionId? companionId,
  }) {
    _byPack[provider.posePackId] = provider;
    if (companionId != null) _byCompanion[companionId] = provider;
  }

  /// The provider for [posePack], or `null`.
  CompanionVisualProvider? providerForPack(String posePack) =>
      _byPack[posePack];

  /// The provider registered for [id], or `null`.
  CompanionVisualProvider? providerForCompanion(CompanionId id) =>
      _byCompanion[id];

  /// Every registered pack id, for diagnostics and tests.
  List<String> get registeredPacks => _byPack.keys.toList(growable: false);

  /// A registry containing only [providers], for tests.
  factory CompanionVisualRegistry.of(
    Iterable<CompanionVisualProvider> providers,
  ) {
    final registry = CompanionVisualRegistry();
    for (final provider in providers) {
      registry.register(provider);
    }
    return registry;
  }
}
