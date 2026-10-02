// P8 — characterisation tests for the Collection + Craft loop gaps.
//
// These do **not** assert that the gaps are desirable. They pin the current
// truth so the gaps cannot change silently, and so that whoever implements one
// of P8's remaining options is forced back to
// `outputs/ai_handoff/P8_COLLECTION_CRAFT_LOOP_DESIGN.md` to rewrite them.
//
// This is the project's own precedent for an open owner decision: see
// `mochi_copy_coverage_test.dart`, which "locks the current coverage so a
// cadence edit fails loudly and forces the review doc to be re-issued".
//
// Two of the four gaps have had their *truthfulness* half closed and the
// *mechanic* half deliberately left open:
//   G1 — the craft page no longer promises materials that do not exist, but
//        materials are still not implemented.
//   G3 — the collection total is now satisfiable, but the two preview entries
//        still have no acquisition path.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide FocusSession, Pet, CraftJob, CraftRecipe, InventoryItem, RoomItem;
import 'package:cozy_focus_app/data/repositories/drift_craft_repository.dart';
import 'package:cozy_focus_app/presentation/pages/pet_collection_page.dart';

/// The collection entries that have no craft recipe and no acquisition path.
///
/// G3 in the design doc. They are declared `obtainable: false` in the catalog,
/// so they no longer count toward completion — but they still cannot be earned,
/// which is the half that needs an owner decision.
const Set<String> kKnownUnobtainableCollectionIds = {
  'plant_succulent',
  'special_trophy',
};

void main() {
  late AppDatabase db;
  late DriftCraftRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftCraftRepository(db.craftDao);
  });

  tearDown(() => db.close());

  Future<Set<String>> craftableIds() async {
    final recipes = await repo.findAllRecipes();
    return {for (final recipe in recipes) recipe.outputItemId};
  }

  Set<String> catalogIds() => {for (final item in kCollectionCatalog) item.id};

  group('P8 G3 — the collection has entries the loop cannot deliver', () {
    test('exactly two catalog ids have no craft recipe', () async {
      final unobtainable = catalogIds().difference(await craftableIds());

      expect(
        unobtainable,
        kKnownUnobtainableCollectionIds,
        reason: 'A catalog entry gained or lost a craft path. Re-read '
            'P8_COLLECTION_CRAFT_LOOP_DESIGN.md §2 G3 and §3 before changing '
            'this expectation: the collection total is derived from this set.',
      );
    });

    test('the obtainable flag agrees with the recipe truth, both ways',
        () async {
      final craftable = await craftableIds();
      final flaggedUnobtainable = {
        for (final item in kCollectionCatalog)
          if (!item.obtainable) item.id,
      };
      final actuallyUnobtainable = catalogIds().difference(craftable);

      expect(
        flaggedUnobtainable,
        actuallyUnobtainable,
        reason: 'The `obtainable` flag and the recipe truth disagree. The flag '
            'drives the progress total the player sees, so a flag that is '
            'wrong in either direction makes that number a lie: too many '
            'flagged obtainable and the bar can never fill; too few and a '
            'reachable item is excluded from completion.',
      );
    });

    test('the progress total counts only obtainable entries', () async {
      final craftable = await craftableIds();
      final obtainable =
          kCollectionCatalog.where((item) => item.obtainable).toList();

      // Collecting everything reachable now reaches 100%, which it could not
      // while the two preview entries were counted.
      expect(obtainable, hasLength(8));
      expect(obtainable.length, craftable.length);
      expect(kCollectionCatalog.length - obtainable.length, 2);
    });
  });

  group('P8 G1 — recipe materials are declared but never authored', () {
    test('no seeded recipe declares an ingredient cost', () async {
      final recipes = await repo.findAllRecipes();
      expect(recipes, hasLength(8));

      for (final recipe in recipes) {
        expect(
          recipe.ingredientCosts,
          isEmpty,
          reason: 'A recipe now costs materials. The craft detail page already '
              'renders costs, so this is the moment to implement the rest of '
              'P8_COLLECTION_CRAFT_LOOP_DESIGN.md §3 Option A — a source for '
              'materials and an atomic charge at startJob — rather than to '
              'delete this expectation.',
        );
      }
    });

    test('the craft page no longer promises materials that do not exist',
        () async {
      // Asserted against the source text rather than the cost map, so that both
      // honest fixes are caught: implementing the mechanic, or changing the
      // copy. A false promise must not return without someone noticing.
      final source = File('lib/presentation/pages/craft_detail_page.dart')
          .readAsStringSync();

      expect(
        source,
        isNot(contains('材料会在专注中慢慢准备好')),
        reason: 'The promise that materials will be prepared during focus came '
            'back, but nothing produces a material. Either implement Option A '
            'or restore the honest empty state.',
      );
      expect(
        source,
        contains('这个配方不需要额外材料'),
        reason:
            'The honest empty state was removed. If materials are now real, '
            'delete this whole group and update the design doc; otherwise '
            'restore it.',
      );
    });
  });

  group('P8 G4 — craft and collection are two hand-kept lists', () {
    test('every craft-backed catalog id really is craftable', () async {
      final craftable = await craftableIds();
      final craftBacked = catalogIds().intersection(craftable);

      // Identity agreement only. Display names are allowed to differ today —
      // seven of eight do — and P8_COLLECTION_CRAFT_LOOP_DESIGN.md §3 Option C
      // owns that decision.
      expect(craftBacked, hasLength(8));
      for (final id in craftBacked) {
        expect(craftable, contains(id));
      }
    });

    test('no catalog id is a typo of a real recipe id', () async {
      final craftable = await craftableIds();
      for (final id in catalogIds()) {
        if (kKnownUnobtainableCollectionIds.contains(id)) continue;
        expect(
          craftable,
          contains(id),
          reason: 'Catalog id "$id" is neither craftable nor in the declared '
              'unobtainable set. Either it is a typo, or it is a new entry '
              'with no path — which is exactly the drift this test guards.',
        );
      }
    });
  });
}
