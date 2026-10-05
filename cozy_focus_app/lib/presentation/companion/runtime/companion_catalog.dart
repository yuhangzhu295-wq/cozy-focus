import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../focus_phase.dart';
import 'behavior_recipe.dart';
import 'companion_context.dart';
import 'companion_id.dart';
import 'companion_profile.dart';
import 'room_interaction_recipe.dart';

/// The loaded, immutable manifests that drive the companion runtime.
///
/// ## Why the runtime is data-driven rather than switch-driven
///
/// Everything the director needs to make a decision — which behaviours are
/// eligible, how long they dwell, whether they may repeat, what a companion is
/// called, which anchor it uses on a sofa — lives in three JSON manifests. The
/// engine reads them generically. That is what makes the final architecture gate
/// (`FOURTH_COMPANION_PAGE_EDITS_REQUIRED = NO`) true by construction rather than
/// by discipline: there is no per-species code path to forget to update.
///
/// ## Failure policy
///
/// A malformed manifest throws at load. A *missing* optional section degrades:
/// an unknown companion id falls back to [defaultProfile], and a context with no
/// recipe simply schedules nothing. The presentation layer must never crash
/// because a manifest is incomplete.
class CompanionCatalog {
  final Map<CompanionId, CompanionProfile> profiles;

  /// `contextId → slotId → recipe`.
  final Map<String, Map<String, BehaviorRecipe>> _contextRecipes;

  /// `overlayId → recipe`.
  final Map<String, OverlayRecipe> overlayRecipes;

  /// `itemId → recipe`.
  final Map<String, RoomInteractionRecipe> roomRecipes;

  /// The id used when a stored selection is unknown.
  final CompanionId defaultProfileId;

  CompanionCatalog({
    required Map<CompanionId, CompanionProfile> profiles,
    required Map<String, Map<String, BehaviorRecipe>> contextRecipes,
    required Map<String, OverlayRecipe> overlayRecipes,
    required Map<String, RoomInteractionRecipe> roomRecipes,
    required this.defaultProfileId,
  })  : profiles = Map.unmodifiable(profiles),
        _contextRecipes = contextRecipes,
        overlayRecipes = Map.unmodifiable(overlayRecipes),
        roomRecipes = Map.unmodifiable(roomRecipes);

  /// A copy with [extra] profiles added, sharing every recipe.
  ///
  /// The recipes are shared rather than copied on purpose: an installed companion
  /// behaves through the same behaviour data as a built-in one, which is the
  /// architecture rule that a companion's origin must not change how it behaves.
  /// Only the identity differs.
  CompanionCatalog withProfiles(Map<CompanionId, CompanionProfile> extra) {
    if (extra.isEmpty) return this;
    return CompanionCatalog(
      profiles: {...profiles, ...extra},
      contextRecipes: _contextRecipes,
      overlayRecipes: overlayRecipes,
      roomRecipes: roomRecipes,
      defaultProfileId: defaultProfileId,
    );
  }

  /// Every companion the catalog knows about, in manifest order.
  List<CompanionId> get companionIds => profiles.keys.toList(growable: false);

  /// The profile for [id].
  ///
  /// An unknown id — a stale stored selection, a companion removed in a later
  /// build — resolves to [defaultProfileId] rather than throwing. This is the
  /// "unknown id → safe dog fallback" contract, expressed once here instead of
  /// at every call site.
  CompanionProfile profileFor(CompanionId id) {
    final exact = profiles[id];
    if (exact != null) return exact;
    final fallback = profiles[defaultProfileId];
    if (fallback != null) return fallback;
    // Only reachable if the manifest declared no profiles at all; still total.
    return CompanionProfile(
        id: defaultProfileId,
        displayName: defaultProfileId.value,
        posePack: defaultProfileId.value);
  }

  /// Whether [id] is a known companion.
  bool hasCompanion(CompanionId id) => profiles.containsKey(id);

  /// The recipe slot key for [context].
  ///
  /// * `focus` is keyed by phase, so a session's phase selects the behaviour mix.
  /// * `room` is keyed by the presentation anchor (`seat` / `lie` / `front` /
  ///   `work`), so furniture decides the behaviour through data.
  /// * everything else uses `default`.
  static String slotFor(
    CompanionBaseContext context, {
    FocusPhase? phase,
    String? roomAnchor,
  }) {
    switch (context) {
      case CompanionBaseContext.focus:
        return switch (phase) {
          FocusPhase.starting => 'starting',
          FocusPhase.working => 'working',
          FocusPhase.deepFocus => 'deep_focus',
          FocusPhase.finishing => 'finishing',
          null => 'working',
        };
      case CompanionBaseContext.room:
        return roomAnchor ?? 'default';
      case CompanionBaseContext.home:
      case CompanionBaseContext.pause:
      case CompanionBaseContext.complete:
      case CompanionBaseContext.craft:
      case CompanionBaseContext.sleep:
        return 'default';
    }
  }

  /// The recipe governing [context], or `null` when none is declared.
  ///
  /// Falls back from the specific slot to the context's `default` slot, so a room
  /// anchor with no dedicated recipe still schedules the ambient room recipe
  /// instead of freezing.
  BehaviorRecipe? recipeFor(
    CompanionBaseContext context, {
    FocusPhase? phase,
    String? roomAnchor,
  }) {
    final slots = _contextRecipes[context.id];
    if (slots == null || slots.isEmpty) return null;
    final slot = slotFor(context, phase: phase, roomAnchor: roomAnchor);
    return slots[slot] ?? slots['default'];
  }

  /// The overlay recipe for [overlay], or `null` when the overlay is `none`.
  OverlayRecipe? overlayRecipeFor(CompanionOverlay overlay) =>
      overlayRecipes[overlay.id];

  /// The room recipe for [itemId], or `null` when the item has no interaction.
  RoomInteractionRecipe? roomRecipeFor(String itemId) => roomRecipes[itemId];

  /// Builds a catalog from already-decoded manifest maps.
  ///
  /// Pure, so tests can parse the shipped JSON without a Flutter binding and
  /// assert the real data rather than a hand-built double.
  factory CompanionCatalog.fromJson({
    required Map<String, dynamic> behaviorRecipes,
    required Map<String, dynamic> companionProfiles,
    required Map<String, dynamic> roomInteractionRecipes,
  }) {
    final profiles = <CompanionId, CompanionProfile>{};
    final rawProfiles = companionProfiles['profiles'];
    if (rawProfiles is Map) {
      for (final entry in rawProfiles.entries) {
        final id = CompanionId(entry.key as String);
        profiles[id] = CompanionProfile.fromJson(
          id,
          (entry.value as Map).cast<String, dynamic>(),
        );
      }
    }

    final contextRecipes = <String, Map<String, BehaviorRecipe>>{};
    final rawContexts = behaviorRecipes['contexts'];
    if (rawContexts is Map) {
      for (final contextEntry in rawContexts.entries) {
        final slots = <String, BehaviorRecipe>{};
        final rawSlots = contextEntry.value;
        if (rawSlots is Map) {
          for (final slotEntry in rawSlots.entries) {
            slots[slotEntry.key as String] = BehaviorRecipe.fromJson(
              (slotEntry.value as Map).cast<String, dynamic>(),
            );
          }
        }
        contextRecipes[contextEntry.key as String] = slots;
      }
    }

    final overlays = <String, OverlayRecipe>{};
    final rawOverlays = behaviorRecipes['overlays'];
    if (rawOverlays is Map) {
      for (final entry in rawOverlays.entries) {
        overlays[entry.key as String] = OverlayRecipe.fromJson(
          (entry.value as Map).cast<String, dynamic>(),
        );
      }
    }

    final rooms = <String, RoomInteractionRecipe>{};
    final rawRooms = roomInteractionRecipes['recipes'];
    if (rawRooms is Map) {
      for (final entry in rawRooms.entries) {
        rooms[entry.key as String] = RoomInteractionRecipe.fromJson(
          entry.key as String,
          (entry.value as Map).cast<String, dynamic>(),
        );
      }
    }

    final declaredDefault =
        CompanionId(companionProfiles['defaultProfile'] as String? ?? 'dog');
    final defaultId = profiles.containsKey(declaredDefault)
        ? declaredDefault
        : (profiles.keys.isEmpty ? CompanionId.dog : profiles.keys.first);

    return CompanionCatalog(
      profiles: profiles,
      contextRecipes: contextRecipes,
      overlayRecipes: overlays,
      roomRecipes: rooms,
      defaultProfileId: defaultId,
    );
  }

  /// Asset paths, named once so the loader and the tests cannot disagree.
  static const String behaviorRecipesAsset =
      'assets/companion/behavior_recipes.json';
  static const String companionProfilesAsset =
      'assets/companion/companion_profiles.json';
  static const String roomInteractionRecipesAsset =
      'assets/companion/room_interaction_recipes.json';

  /// Loads the shipped manifests from the asset bundle.
  static Future<CompanionCatalog> loadFromAssets({
    AssetBundle? bundle,
  }) async {
    final b = bundle ?? rootBundle;
    final behavior = jsonDecode(await b.loadString(behaviorRecipesAsset))
        as Map<String, dynamic>;
    final profiles = jsonDecode(await b.loadString(companionProfilesAsset))
        as Map<String, dynamic>;
    final rooms = jsonDecode(await b.loadString(roomInteractionRecipesAsset))
        as Map<String, dynamic>;
    return CompanionCatalog.fromJson(
      behaviorRecipes: behavior,
      companionProfiles: profiles,
      roomInteractionRecipes: rooms,
    );
  }

  /// The catalog used when the bundle cannot be read.
  ///
  /// Deliberately minimal rather than a second copy of the manifest: it exists so
  /// a load failure degrades to "no scheduled behaviour" instead of a crash, and
  /// the empty recipe map makes that visible in tests rather than hiding it.
  static CompanionCatalog empty({CompanionId? defaultId}) => CompanionCatalog(
        profiles: const {},
        contextRecipes: const {},
        overlayRecipes: const {},
        roomRecipes: const {},
        defaultProfileId: defaultId ?? CompanionId.dog,
      );
}
