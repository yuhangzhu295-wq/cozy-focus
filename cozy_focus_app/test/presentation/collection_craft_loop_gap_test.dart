// P8 — characterisation tests for the Collection + Craft loop gaps.
//
// These do **not** assert that the gaps are desirable. They pin the current
// truth so the gaps cannot change silently, and so that whoever implements one
// of P8's three options is forced back to
// `outputs/ai_handoff/P8_COLLECTION_CRAFT_LOOP_DESIGN.md` to rewrite them.
//
// This is the project's own precedent for an open owner decision: see
// `mochi_copy_coverage_test.dart`, which "locks the current coverage so a
// cadence edit fails loudly and forces the review doc to be re-issued".
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide FocusSession, Pet, CraftJob, CraftRecipe, InventoryItem, RoomItem;
import 'package:cozy_focus_app/data/repositories/drift_craft_repository.dart';
import 'package:cozy_focus_app/presentation/pages/pet_collection_page.dart';

/// The collection entries that have no craft recipe and no acquisition path.
///
/// G3 in the design doc. They render as 未收集 forever, and the page's progress
/// bar counts them, so the bar is capped at 8/10.
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
            'this expectation: the collection total, and therefore the '
            'progress bar the player sees, is derived from this set.',
      );
    });

    test('the progress denominator counts them, so it can never complete',
        () async {
      final obtainable = catalogIds().intersection(await craftableIds());

      // 8 obtainable of 10 shown. If this ever becomes equal, the bar can
      // finally reach 100% and G3 is closed.
      expect(obtainable.length, 8);
      expect(kCollectionCatalog.length, 10);
      expect(obtainable.length, lessThan(kCollectionCatalog.length));
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

    test('the craft page still promises materials the engine does not charge',
        () async {
      // The sentence is user-visible and currently false. Asserting the source
      // text rather than re-checking the cost map means both honest fixes are
      // caught: implementing the mechanic, or deleting the promise.
      final source = File('lib/presentation/pages/craft_detail_page.dart')
          .readAsStringSync();

      expect(
        source,
        contains('材料会在专注中慢慢准备好'),
        reason: 'The craft page no longer promises materials. If that is '
            'because Option A was implemented, this whole group is obsolete and '
            'should be deleted along with the doc note; if the copy was simply '
            'removed, update P8_COLLECTION_CRAFT_LOOP_DESIGN.md §2 G1 to say so.',
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
