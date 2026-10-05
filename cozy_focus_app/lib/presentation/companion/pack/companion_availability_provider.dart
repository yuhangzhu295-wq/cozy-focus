/// What a companion can actually be asked to do, whoever made it.
///
/// ## Why this is not the resolver's job
///
/// `CompanionActionAvailabilityResolver.resolve` answers from the compiled-in
/// table, which knows the three shipped companions. An installed pack is not in
/// that table, so the resolver falls back to the default companion — and that
/// fallback is now a lie: it hands a pack the dog's thirteen actions while the
/// pack's own artwork is honest about the poses it does not ship. The behaviour
/// side and the drawing side would disagree, and the pack would be asked for
/// `focus_read` and draw an empty box.
///
/// The resolver cannot fix that alone, because reading installed packs means
/// reading a manifest off disk, and the resolver is deliberately a pure function
/// of shipped data — usable from the director, from a test and from a gate
/// report with no container.
///
/// So the lookup lives here, in one place, and everything that asks "can this
/// companion do X" asks it here. The alternative is each caller remembering to
/// check the installed set first, and the one that forgets is the one that asks
/// a pack for art it does not have.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../animation/sprite_animation_manifest_data.dart';
import '../runtime/companion_action_availability.dart';
import '../runtime/companion_id.dart';
import 'companion_pack_completeness.dart';
import 'installed_pack_profiles.dart';

/// A function that answers availability for any companion id.
typedef CompanionAvailabilityLookup = CompanionActionAvailability Function(
    String companionId);

/// Availability for any companion: the built-in three, or an installed pack.
///
/// Watches the installed profiles, so a pack installed while the app is running
/// is answered from its own manifest immediately rather than after a restart.
final companionAvailabilityProvider = Provider<CompanionAvailabilityLookup>(
  (ref) {
    final installed = ref.watch(installedPackProfilesProvider);
    return (companionId) {
      final pack = installed[CompanionId(companionId)];
      if (pack == null) {
        // A built-in, or an id this build does not ship at all. Both are the
        // resolver's business, and its fallback is right for them.
        return CompanionActionAvailabilityResolver.resolve(companionId);
      }
      // An installed pack, answered from its own manifest and with no contract:
      // a contract is a statement about artwork we produced, and there is none
      // for a pack a user brought. Defaulting it to the dog's would report the
      // dog's plan as the pack's plan.
      return CompanionActionAvailabilityResolver.resolveForManifest(
        companionId: companionId,
        manifest: pack.manifest,
      );
    };
  },
);

/// A function that reports completeness for any companion id.
typedef CompanionCompletenessLookup = CompanionPackCompleteness Function(
    String companionId);

/// How complete each companion's action set is.
///
/// The built-in three report complete: they ship the whole production
/// vocabulary, and a test asserts that rather than trusting it. An installed
/// pack reports what it really ships, with its fallbacks counted separately —
/// see [CompanionPackCompleteness] for why a fallback is neither ready nor
/// missing.
final companionCompletenessProvider = Provider<CompanionCompletenessLookup>(
  (ref) {
    final installed = ref.watch(installedPackProfilesProvider);
    return (companionId) {
      final pack = installed[CompanionId(companionId)];
      if (pack == null) {
        return CompanionPackCompleteness.complete(
          SpriteAnimationManifestData.productionActionIds,
        );
      }
      return CompanionPackCompleteness.of(pack.manifest);
    };
  },
);
