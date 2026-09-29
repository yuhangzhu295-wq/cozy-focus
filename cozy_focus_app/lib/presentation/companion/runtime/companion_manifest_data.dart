import 'behavior_recipe.dart';
import 'companion_catalog.dart';
import 'companion_context.dart';
import 'companion_id.dart';
import 'companion_profile.dart';
import 'room_interaction_recipe.dart';

/// The runtime form of the three companion manifests.
///
/// ## Why this exists alongside the JSON
///
/// The manifests under `assets/companion/` are the **authoring source**: they are
/// readable, diffable, and are what a designer or a future tool edits. The
/// runtime needs them *synchronously* — the presentation layer must know what a
/// companion is doing on the very first frame, without an `await` between app
/// start and the first pose, and without every widget test having to pump an
/// asynchronous load.
///
/// So the same data is expressed here as Dart tables. The two are kept honest by
/// `companion_manifest_parity_test.dart`, which parses the shipped JSON and fails
/// if this file and the assets disagree in any field. That makes drift a test
/// failure rather than a silent divergence.
///
/// ## It is still data
///
/// Nothing here is a species switch. The engine reads these tables generically —
/// which is why adding a fourth companion is a row in [profiles] plus a pose pack,
/// with no edit to the director, the renderer or any page.
abstract final class CompanionManifestData {
  const CompanionManifestData._();

  /// The companion a fresh install starts with.
  static const CompanionId defaultProfileId = CompanionId.dog;

  /// `context id → slot id → recipe`.
  static final Map<CompanionBaseContext, Map<String, BehaviorRecipe>>
      contextRecipes = {
    CompanionBaseContext.home: {
      'default': _recipe([CompanionMacroBehavior.idle], 6, 14),
    },
    CompanionBaseContext.focus: {
      'starting': _recipe(
        [CompanionMacroBehavior.prepare, CompanionMacroBehavior.focusRead],
        6,
        12,
      ),
      'working': _recipe(
        [
          CompanionMacroBehavior.focusRead,
          CompanionMacroBehavior.focusWrite,
          CompanionMacroBehavior.focusThink,
        ],
        8,
        20,
      ),
      'deep_focus': _recipe(
        [
          CompanionMacroBehavior.focusRead,
          CompanionMacroBehavior.focusWrite,
          CompanionMacroBehavior.focusThink,
        ],
        15,
        30,
        glanceProbability: 0.15,
      ),
      'finishing': _recipe(
        [
          CompanionMacroBehavior.focusWrite,
          CompanionMacroBehavior.focusRead,
          CompanionMacroBehavior.glance,
          CompanionMacroBehavior.finish,
        ],
        8,
        18,
      ),
    },
    CompanionBaseContext.pause: {
      'default': _recipe([CompanionMacroBehavior.rest], 10, 22),
    },
    CompanionBaseContext.complete: {
      'default': _recipe(
        [CompanionMacroBehavior.celebrate],
        6,
        12,
        noImmediateRepeat: false,
      ),
    },
    CompanionBaseContext.craft: {
      'default': _recipe(
        [CompanionMacroBehavior.craftWork],
        8,
        16,
        noImmediateRepeat: false,
      ),
    },
    CompanionBaseContext.room: {
      'default': _recipe(
        [CompanionMacroBehavior.roomRelax, CompanionMacroBehavior.idle],
        8,
        18,
      ),
      'seat': _recipe(
        [CompanionMacroBehavior.roomSit],
        12,
        26,
        noImmediateRepeat: false,
      ),
      'lie': _recipe(
        [CompanionMacroBehavior.roomSleep],
        16,
        34,
        noImmediateRepeat: false,
      ),
      'front': _recipe([CompanionMacroBehavior.roomRead], 12, 24),
      'work': _recipe([CompanionMacroBehavior.roomWork], 10, 22),
    },
    CompanionBaseContext.sleep: {
      'default': _recipe(
        [CompanionMacroBehavior.sleep],
        20,
        40,
        noImmediateRepeat: false,
      ),
    },
  };

  static BehaviorRecipe _recipe(
    List<CompanionMacroBehavior> eligible,
    int minSeconds,
    int maxSeconds, {
    bool noImmediateRepeat = true,
    double glanceProbability = 0.0,
  }) =>
      BehaviorRecipe(
        eligible: List.unmodifiable(eligible),
        minDuration: Duration(seconds: minSeconds),
        maxDuration: Duration(seconds: maxSeconds),
        noImmediateRepeat: noImmediateRepeat,
        glanceProbability: glanceProbability,
      );

  /// `overlay id → recipe`.
  static final Map<CompanionOverlay, OverlayRecipe> overlayRecipes = {
    CompanionOverlay.tapReact: _overlay(600, 1200),
    CompanionOverlay.petReact: _overlay(1000, 2000),
    CompanionOverlay.greeting: _overlay(1200, 2000),
    CompanionOverlay.unlockReact: _overlay(1500, 2500),
  };

  static OverlayRecipe _overlay(int minMs, int maxMs) => OverlayRecipe(
        minDuration: Duration(milliseconds: minMs),
        maxDuration: Duration(milliseconds: maxMs),
        restorePrevious: true,
      );

  /// The three V1 companions.
  static final Map<CompanionId, CompanionProfile> profiles = {
    CompanionId.dog: _profile(
      id: CompanionId.dog,
      displayName: 'Mochi',
      posePack: 'mochi',
      microMotion: const ['breathe', 'blink', 'ear_twitch', 'sprout_sway'],
      weights: const {
        'focus_read': 0.3,
        'focus_write': 0.4,
        'focus_think': 0.3
      },
    ),
    CompanionId.cat: _profile(
      id: CompanionId.cat,
      displayName: '小猫',
      posePack: 'cat',
      microMotion: const ['breathe', 'blink', 'ear_flick', 'tail_sweep'],
      weights: const {
        'focus_read': 0.25,
        'focus_write': 0.5,
        'focus_think': 0.25
      },
    ),
    CompanionId.rabbit: _profile(
      id: CompanionId.rabbit,
      displayName: '小兔',
      posePack: 'rabbit',
      microMotion: const ['breathe', 'blink', 'ear_perk'],
      weights: const {
        'focus_read': 0.45,
        'focus_write': 0.25,
        'focus_think': 0.3
      },
    ),
  };

  static CompanionProfile _profile({
    required CompanionId id,
    required String displayName,
    required String posePack,
    required List<String> microMotion,
    required Map<String, double> weights,
  }) =>
      CompanionProfile(
        id: id,
        displayName: displayName,
        posePack: posePack,
        // The shipped package states the transparent pose packs are still a
        // production task, so no profile may claim runtime art.
        runtimeAssetsAvailable: false,
        microMotion: microMotion,
        behaviorWeights: weights,
        tapOverlay: CompanionOverlay.tapReact,
        longPressOverlay: CompanionOverlay.petReact,
        roomAnchors: const {
          'seat': CompanionMacroBehavior.roomSit,
          'lie': CompanionMacroBehavior.roomSleep,
          'front': CompanionMacroBehavior.roomRead,
          'work': CompanionMacroBehavior.roomWork,
        },
      );

  /// Furniture → behaviour, mirroring `docs/06`.
  static final Map<String, RoomInteractionRecipe> roomRecipes = {
    'sofa': _room('sofa', 'seat', CompanionMacroBehavior.roomSit),
    'rug': _room('rug', 'seat', CompanionMacroBehavior.roomSit),
    'bed': _room('bed', 'lie', CompanionMacroBehavior.roomSleep),
    'bookshelf': _room('bookshelf', 'front', CompanionMacroBehavior.roomRead),
    'desk': _room('desk', 'work', CompanionMacroBehavior.roomWork),
  };

  static RoomInteractionRecipe _room(
    String itemId,
    String anchor,
    CompanionMacroBehavior behavior,
  ) =>
      RoomInteractionRecipe(
        itemId: itemId,
        anchor: anchor,
        behavior: behavior,
        requires: const ['owned', 'placed', 'visible'],
      );
}

/// The catalog the app runs on.
///
/// Built from [CompanionManifestData]; see that class for why the runtime does
/// not `await` an asset load on the first frame.
CompanionCatalog bundledCompanionCatalog() => CompanionCatalog(
      profiles: CompanionManifestData.profiles,
      contextRecipes: CompanionManifestData.contextRecipes
          .map((context, slots) => MapEntry(context.id, slots)),
      overlayRecipes: CompanionManifestData.overlayRecipes
          .map((overlay, recipe) => MapEntry(overlay.id, recipe)),
      roomRecipes: CompanionManifestData.roomRecipes,
      defaultProfileId: CompanionManifestData.defaultProfileId,
    );
