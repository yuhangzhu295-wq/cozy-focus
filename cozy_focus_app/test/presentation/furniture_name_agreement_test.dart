import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart' hide Pet;
import 'package:cozy_focus_app/data/repositories/drift_craft_repository.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_catalog.dart';
import 'package:cozy_focus_app/presentation/pages/pet_collection_page.dart';

/// One object, one user-facing name — and the craft recipe is the authority.
///
/// ## The defect this closes (D3)
///
/// The same furniture id carried up to three different names:
///
/// | id | recipe | collection | furniture |
/// |---|---|---|---|
/// | sofa | 温馨沙发 | 温馨布艺沙发 | 沙发 |
/// | desk | 窗边书桌 | 专注写字台 | 书桌 |
///
/// Seven of the eight recipe-backed collection items disagreed with their
/// recipe, and two of the five room furniture labels did. So the sofa was
/// called three things depending on which screen you were on, and none of them
/// was wrong on its own — which is exactly why nothing caught it.
///
/// ## Why this test reads all three surfaces
///
/// A test that only checked the two lists against each other would pass while
/// both drifted away from the recipe. This one reads the **seeded database**,
/// which is the recipe truth, and then asks each display surface to agree with
/// it. The furniture catalog and the collection catalog are `const` tables, so
/// there is no way to make them *derive* the name at compile time; a test that
/// compares them to the seed is the guard that stops them drifting again.
void main() {
  late AppDatabase db;
  late DriftCraftRepository craftRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    craftRepo = DriftCraftRepository(db.craftDao);
    // The seed runs on open; give it a turn to finish before reading.
    await db.craftDao.findAllRecipes();
  });

  tearDown(() async => db.close());

  test('every recipe-backed furniture item shows the recipe name', () async {
    final recipes = await craftRepo.findAllRecipes();
    expect(recipes, isNotEmpty,
        reason: 'the seed did not run, so this test would assert nothing');

    final byId = {for (final r in recipes) r.id: r.name};

    for (final entity in FurnitureCatalog.entities.values) {
      final recipeName = byId[entity.id];
      if (recipeName == null) {
        continue; // furniture with no recipe: not D3's scope
      }
      expect(entity.label, recipeName,
          reason: 'the room calls ${entity.id} "${entity.label}" while its '
              'recipe calls it "$recipeName"');
    }
  });

  test('every recipe-backed collection item shows the recipe name', () async {
    final recipes = await craftRepo.findAllRecipes();
    final byId = {for (final r in recipes) r.id: r.name};

    var compared = 0;
    for (final item in kCollectionCatalog) {
      final recipeName = byId[item.id];
      if (recipeName == null) {
        continue;
      }
      compared++;
      expect(item.name, recipeName,
          reason: 'the collection calls ${item.id} "${item.name}" while its '
              'recipe calls it "$recipeName"');
    }
    // The count matters: if every id stopped matching, the loop above would
    // pass vacuously.
    expect(compared, greaterThanOrEqualTo(8),
        reason: 'only $compared collection items were compared against a '
            'recipe, so most of the catalog went unchecked');
  });

  test('no id has two names anywhere', () async {
    final recipes = await craftRepo.findAllRecipes();
    final byId = {for (final r in recipes) r.id: r.name};

    final names = <String, Set<String>>{};
    for (final e in FurnitureCatalog.entities.values) {
      names.putIfAbsent(e.id, () => <String>{}).add(e.label);
    }
    for (final i in kCollectionCatalog) {
      names.putIfAbsent(i.id, () => <String>{}).add(i.name);
    }
    for (final entry in names.entries) {
      final recipeName = byId[entry.key];
      if (recipeName != null) entry.value.add(recipeName);
      expect(entry.value.length, 1,
          reason: '${entry.key} is called ${entry.value.join(" / ")}');
    }
  });

  test('the sofa and the desk are the two that used to disagree', () async {
    // The concrete regression, named. If a future edit reverts either of these
    // the failure says which one rather than only that "something drifted".
    final recipes = await craftRepo.findAllRecipes();
    final byId = {for (final r in recipes) r.id: r.name};

    expect(FurnitureCatalog.entities['sofa']!.label, byId['sofa']);
    expect(FurnitureCatalog.entities['sofa']!.label, '温馨沙发');
    expect(FurnitureCatalog.entities['desk']!.label, byId['desk']);
    expect(FurnitureCatalog.entities['desk']!.label, '窗边书桌');

    final sofa = kCollectionCatalog.firstWhere((i) => i.id == 'sofa');
    expect(sofa.name, '温馨沙发');
    expect(sofa.name, isNot('温馨布艺沙发'),
        reason: 'the collection name that used to disagree with the recipe');
  });
}
