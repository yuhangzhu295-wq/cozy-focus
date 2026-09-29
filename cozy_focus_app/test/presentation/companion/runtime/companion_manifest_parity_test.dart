import 'package:cozy_focus_app/presentation/companion/focus_phase.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_manifest_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_test_support.dart';

/// The authored JSON and the runtime Dart tables must not drift.
///
/// The manifests under `assets/companion/` are the authoring source; the runtime
/// reads Dart tables so it never has to `await` an asset load on the first frame.
/// That is only safe if the two are provably identical, which is what this test
/// establishes — field by field, not by spot check.
void main() {
  late CompanionCatalog fromJson;
  late CompanionCatalog bundled;

  setUp(() {
    fromJson = loadShippedCatalog();
    bundled = bundledCompanionCatalog();
  });

  test('the same companions are declared', () {
    expect(
      bundled.companionIds.map((id) => id.value).toSet(),
      fromJson.companionIds.map((id) => id.value).toSet(),
    );
    expect(bundled.defaultProfileId, fromJson.defaultProfileId);
  });

  test('every profile matches field for field', () {
    for (final id in fromJson.companionIds) {
      final a = fromJson.profileFor(id);
      final b = bundled.profileFor(id);

      expect(b.displayName, a.displayName, reason: '${id.value}.displayName');
      expect(b.posePack, a.posePack, reason: '${id.value}.posePack');
      expect(b.tagline, a.tagline, reason: '${id.value}.tagline');
      expect(b.traits, a.traits, reason: '${id.value}.traits');
      expect(b.runtimeAssetsAvailable, a.runtimeAssetsAvailable,
          reason: '${id.value}.runtimeAssets');
      expect(b.microMotion, a.microMotion, reason: '${id.value}.microMotion');
      expect(b.behaviorWeights, a.behaviorWeights,
          reason: '${id.value}.behaviorWeights');
      expect(b.tapOverlay, a.tapOverlay, reason: '${id.value}.tapOverlay');
      expect(b.longPressOverlay, a.longPressOverlay,
          reason: '${id.value}.longPressOverlay');
      expect(b.roomAnchors, a.roomAnchors, reason: '${id.value}.roomAnchors');
    }
  });

  test('every context slot matches, including phase and room-anchor keys', () {
    for (final context in CompanionBaseContext.values) {
      final slots = <String?>[
        null,
        'starting',
        'working',
        'deep_focus',
        'finishing',
        'seat',
        'lie',
        'front',
        'work',
      ];
      for (final slot in slots) {
        final phase = switch (slot) {
          'starting' => FocusPhase.starting,
          'working' => FocusPhase.working,
          'deep_focus' => FocusPhase.deepFocus,
          'finishing' => FocusPhase.finishing,
          _ => null,
        };
        final anchor =
            const {'seat', 'lie', 'front', 'work'}.contains(slot) ? slot : null;

        final a = fromJson.recipeFor(context, phase: phase, roomAnchor: anchor);
        final b = bundled.recipeFor(context, phase: phase, roomAnchor: anchor);

        final label = '${context.id}/${slot ?? 'default'}';
        expect(a == null, b == null, reason: '$label presence');
        if (a == null) continue;

        expect(
          b!.eligible.map((e) => e.id).toList(),
          a.eligible.map((e) => e.id).toList(),
          reason: '$label eligible',
        );
        expect(b.minDuration, a.minDuration, reason: '$label min');
        expect(b.maxDuration, a.maxDuration, reason: '$label max');
        expect(b.noImmediateRepeat, a.noImmediateRepeat,
            reason: '$label repeat');
        expect(b.glanceProbability, a.glanceProbability,
            reason: '$label glance');
      }
    }
  });

  test('every overlay recipe matches', () {
    for (final overlay in fromJson.overlayRecipes.keys) {
      final a = fromJson.overlayRecipes[overlay]!;
      final b = bundled.overlayRecipes[overlay]!;
      expect(b.minDuration, a.minDuration, reason: '$overlay min');
      expect(b.maxDuration, a.maxDuration, reason: '$overlay max');
      expect(b.restorePrevious, a.restorePrevious, reason: '$overlay restore');
    }
    expect(bundled.overlayRecipes.keys.toSet(),
        fromJson.overlayRecipes.keys.toSet());
  });

  test('every room recipe matches', () {
    expect(
      bundled.roomRecipes.keys.toSet(),
      fromJson.roomRecipes.keys.toSet(),
    );
    for (final itemId in fromJson.roomRecipes.keys) {
      final a = fromJson.roomRecipeFor(itemId)!;
      final b = bundled.roomRecipeFor(itemId)!;
      expect(b.anchor, a.anchor, reason: '$itemId anchor');
      expect(b.behavior, a.behavior, reason: '$itemId behavior');
      expect(b.requires, a.requires, reason: '$itemId requires');
    }
  });
}
