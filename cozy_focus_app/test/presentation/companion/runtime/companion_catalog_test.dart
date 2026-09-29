import 'package:cozy_focus_app/presentation/companion/focus_phase.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_test_support.dart';

void main() {
  group('CompanionCatalog parses the shipped manifests', () {
    late CompanionCatalog catalog;

    setUp(() => catalog = loadShippedCatalog());

    test('declares the three V1 companions', () {
      expect(
        catalog.companionIds.map((id) => id.value).toSet(),
        {'dog', 'cat', 'rabbit'},
      );
    });

    test('the default companion is dog, and Mochi is its display name', () {
      expect(catalog.defaultProfileId, CompanionId.dog);
      expect(catalog.profileFor(CompanionId.dog).displayName, 'Mochi');
    });

    test('every profile declares a pose pack and its runtime asset status', () {
      for (final id in catalog.companionIds) {
        final profile = catalog.profileFor(id);
        expect(profile.posePack, isNotEmpty, reason: id.value);
        // The shipped package states the transparent pose packs are still a
        // production task, so every profile must say GAP rather than claim art.
        expect(profile.runtimeAssetsAvailable, isFalse, reason: id.value);
      }
    });

    test('an unknown companion id falls back to the default profile', () {
      final profile = catalog.profileFor(const CompanionId('unicorn'));
      expect(profile.id, CompanionId.dog);
      expect(catalog.hasCompanion(const CompanionId('unicorn')), isFalse);
    });

    test('focus recipes are keyed by phase and match the SPEC', () {
      final starting = catalog.recipeFor(
        CompanionBaseContext.focus,
        phase: FocusPhase.starting,
      );
      final working = catalog.recipeFor(
        CompanionBaseContext.focus,
        phase: FocusPhase.working,
      );
      final deep = catalog.recipeFor(
        CompanionBaseContext.focus,
        phase: FocusPhase.deepFocus,
      );

      expect(starting!.eligible, contains(CompanionMacroBehavior.prepare));
      expect(working!.eligible, {
        CompanionMacroBehavior.focusRead,
        CompanionMacroBehavior.focusWrite,
        CompanionMacroBehavior.focusThink,
      });
      // 8–20s working, 15–30s deep focus, per docs/04.
      expect(working.minDuration.inSeconds, 8);
      expect(working.maxDuration.inSeconds, 20);
      expect(deep!.minDuration.inSeconds, 15);
      expect(deep.maxDuration.inSeconds, 30);
      expect(deep.glanceProbability, 0.15);
    });

    test('pause never offers a focus behaviour', () {
      final pause = catalog.recipeFor(CompanionBaseContext.pause);
      expect(pause, isNotNull);
      expect(
        pause!.eligible.any(CompanionMacroBehavior.focusBehaviors.contains),
        isFalse,
      );
    });

    test('craft offers only craft work, so an idle craft job cannot animate',
        () {
      final craft = catalog.recipeFor(CompanionBaseContext.craft);
      expect(craft!.eligible, [CompanionMacroBehavior.craftWork]);
    });

    test('the room anchor selects the behaviour through data', () {
      expect(
        catalog
            .recipeFor(CompanionBaseContext.room, roomAnchor: 'seat')!
            .eligible,
        [CompanionMacroBehavior.roomSit],
      );
      expect(
        catalog
            .recipeFor(CompanionBaseContext.room, roomAnchor: 'lie')!
            .eligible,
        [CompanionMacroBehavior.roomSleep],
      );
      expect(
        catalog
            .recipeFor(CompanionBaseContext.room, roomAnchor: 'front')!
            .eligible,
        [CompanionMacroBehavior.roomRead],
      );
      // An anchor with no dedicated recipe still gets the ambient room recipe
      // rather than nothing at all.
      expect(
        catalog
            .recipeFor(CompanionBaseContext.room, roomAnchor: 'nowhere')!
            .eligible,
        contains(CompanionMacroBehavior.roomRelax),
      );
    });

    test('room item recipes mirror docs/06 and require owned+placed+visible',
        () {
      final sofa = catalog.roomRecipeFor('sofa');
      expect(sofa!.behavior, CompanionMacroBehavior.roomSit);
      expect(sofa.anchor, 'seat');
      expect(sofa.requires, ['owned', 'placed', 'visible']);

      expect(catalog.roomRecipeFor('bed')!.behavior,
          CompanionMacroBehavior.roomSleep);
      expect(catalog.roomRecipeFor('bookshelf')!.behavior,
          CompanionMacroBehavior.roomRead);
      expect(catalog.roomRecipeFor('desk')!.behavior,
          CompanionMacroBehavior.roomWork);
      expect(catalog.roomRecipeFor('not-a-real-item'), isNull);
    });

    test(
        'every overlay declares a duration range and restores the previous macro',
        () {
      for (final overlay in CompanionOverlay.values) {
        if (!overlay.isActive) continue;
        final recipe = catalog.overlayRecipeFor(overlay);
        expect(recipe, isNotNull, reason: overlay.id);
        expect(recipe!.maxDuration, greaterThanOrEqualTo(recipe.minDuration));
        expect(recipe.restorePrevious, isTrue, reason: overlay.id);
      }
      expect(catalog.overlayRecipeFor(CompanionOverlay.none), isNull);
    });
  });

  group('CompanionPose', () {
    test('round-trips every wire id', () {
      for (final pose in CompanionPose.values) {
        expect(CompanionPose.fromId(pose.id), pose);
      }
    });

    test('an unknown wire id resolves to null rather than throwing', () {
      expect(CompanionPose.fromId('not_a_pose'), isNull);
      expect(CompanionPose.fromId(null), isNull);
    });

    test('overlay poses are marked as overlays and macro poses are not', () {
      expect(CompanionPose.tapReact.isOverlay, isTrue);
      expect(CompanionPose.petReact.isOverlay, isTrue);
      expect(CompanionPose.focusRead.isOverlay, isFalse);
    });
  });

  group('CompanionMacroBehavior', () {
    test('maps one-to-one onto a pose', () {
      for (final behavior in CompanionMacroBehavior.values) {
        expect(behavior.pose, isNotNull);
      }
      expect(CompanionMacroBehavior.focusRead.pose, CompanionPose.focusRead);
      expect(CompanionMacroBehavior.rest.pose, CompanionPose.rest);
    });

    test('exposes the focus behaviour set exactly once', () {
      expect(CompanionMacroBehavior.focusBehaviors, {
        CompanionMacroBehavior.prepare,
        CompanionMacroBehavior.focusRead,
        CompanionMacroBehavior.focusWrite,
        CompanionMacroBehavior.focusThink,
        CompanionMacroBehavior.microRest,
        CompanionMacroBehavior.glance,
        CompanionMacroBehavior.finish,
      });
    });
  });
}
