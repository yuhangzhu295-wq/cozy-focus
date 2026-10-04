import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/presentation/companion/collection/collection_acquisition.dart';

/// P29 — the collection must tell the truth about how an item is obtained.
///
/// Every assertion here is about the *derivation*: the view model must read the
/// live recipe, job, inventory and placement rather than hold its own copy. That
/// is what makes P29.1's rule testable — change a recipe and the detail changes
/// with it, with no edit to the collection catalog.
CraftRecipe _recipe({
  String id = 'sofa',
  String outputItemId = 'sofa',
  int minutes = 30,
  Map<String, int> costs = const {},
}) =>
    CraftRecipe(
      id: id,
      name: '温馨沙发',
      requiredMinutes: minutes,
      ingredientCosts: costs,
      outputItemId: outputItemId,
      outputQuantity: 1,
    );

CraftJob _job(String recipeId, {int progressSeconds = 0}) => CraftJob(
      id: 'job-1',
      userId: 'default_user',
      recipeId: recipeId,
      status: CraftJobStatus.inProgress,
      progressSeconds: progressSeconds,
      startedAt: DateTime(2026, 10, 3, 12),
      rewardClaimed: false,
    );

CollectionAcquisitionViewModel _vm({
  bool obtainable = true,
  List<CraftRecipe>? recipes,
  CraftJob? activeJob,
  CraftRecipe? activeRecipe,
  int ownedQuantity = 0,
  int placedCount = 0,
}) =>
    CollectionAcquisitionViewModel.from(
      itemId: 'sofa',
      itemName: '温馨布艺沙发',
      obtainable: obtainable,
      recipes: recipes ?? [_recipe()],
      activeJob: activeJob,
      activeRecipe: activeRecipe,
      ownedQuantity: ownedQuantity,
      placedCount: placedCount,
    );

void main() {
  group('catalog item → recipe resolution', () {
    test('a matching recipe is found by outputItemId, not by id', () {
      // The recipe's own id happens to equal the item id for the shipped data,
      // so this uses a recipe whose ids differ: resolution must go through
      // `outputItemId`, or a renamed recipe would silently detach.
      final vm =
          _vm(recipes: [_recipe(id: 'recipe-sofa', outputItemId: 'sofa')]);
      expect(vm.recipe, isNotNull);
      expect(vm.recipe!.id, 'recipe-sofa');
      expect(vm.status, CollectionAcquisitionStatus.craftable);
    });

    test('no matching recipe means unavailable, not "not collected"', () {
      final vm = _vm(recipes: [_recipe(outputItemId: 'desk')]);
      expect(vm.status, CollectionAcquisitionStatus.unavailable);
      expect(vm.statusLine, '未开放');
    });

    test('a preview entry is unavailable even if a recipe claims it', () {
      // The two disagreeing is a configuration problem; the honest answer is
      // that it cannot be obtained.
      final vm = _vm(obtainable: false);
      expect(vm.status, CollectionAcquisitionStatus.unavailable);
    });
  });

  group('the duration comes from live recipe data', () {
    test('the detail shows the recipe duration', () {
      expect(_vm(recipes: [_recipe(minutes: 90)]).requiredMinutes, 90);
    });

    test('changing the recipe changes the detail, with no catalog edit', () {
      // P29.1's actual test: the same item, two different recipes.
      final short = _vm(recipes: [_recipe(minutes: 30)]);
      final long = _vm(recipes: [_recipe(minutes: 180)]);
      expect(short.requiredMinutes, 30);
      expect(long.requiredMinutes, 180);
      expect(short.requiredSeconds, 1800);
      expect(long.requiredSeconds, 10800);
    });

    test('materials are read, and today there are none', () {
      final none = _vm();
      expect(none.requiresMaterials, isFalse,
          reason: 'every shipped recipe seeds an empty ingredient map, so '
              'crafting costs time only and the detail says so');
      final some = _vm(recipes: [
        _recipe(costs: {'wood': 3})
      ]);
      expect(some.requiresMaterials, isTrue,
          reason: 'a recipe that one day costs something shows it with no '
              'change to the view model');
      expect(some.ingredientCosts, {'wood': 3});
    });
  });

  group('the five acquisition states', () {
    test('UNAVAILABLE offers no CTA at all', () {
      final vm = _vm(recipes: const []);
      expect(vm.status, CollectionAcquisitionStatus.unavailable);
      expect(vm.ctaLabel, isNull);
      expect(vm.ctaRoute, isNull);
      expect(vm.isTappable, isFalse,
          reason:
              'a card that opens a detail with nothing to do is a dead end');
    });

    test('CRAFTABLE routes to the real craft detail', () {
      final vm = _vm();
      expect(vm.status, CollectionAcquisitionStatus.craftable);
      expect(vm.ctaLabel, '开始制作');
      expect(vm.ctaRoute, '/craft/detail/sofa');
    });

    test('CRAFTING shows real progress against the real target', () {
      final recipe = _recipe(minutes: 30);
      final vm = _vm(
        recipes: [recipe],
        activeJob: _job('sofa', progressSeconds: 900),
        activeRecipe: recipe,
      );
      expect(vm.status, CollectionAcquisitionStatus.crafting);
      expect(vm.progressSeconds, 900);
      expect(vm.requiredSeconds, 1800);
      expect(vm.progressFraction, closeTo(0.5, 0.001));
      expect(vm.ctaLabel, '继续专注');
      expect(vm.ctaRoute, '/craft/detail/sofa');
    });

    test('a running job for a different recipe does not claim this item', () {
      final other = _recipe(id: 'desk', outputItemId: 'desk');
      final vm = _vm(
        recipes: [_recipe()],
        activeJob: _job('desk', progressSeconds: 600),
        activeRecipe: other,
      );
      expect(vm.status, CollectionAcquisitionStatus.craftable,
          reason: 'crafting the desk is not progress on the sofa');
      expect(vm.progressSeconds, 0);
    });

    test('OWNED routes to the inventory, where placement begins', () {
      final vm = _vm(ownedQuantity: 1);
      expect(vm.status, CollectionAcquisitionStatus.owned);
      expect(vm.statusLine, '已拥有 x1');
      expect(vm.ctaLabel, '去房间摆放');
      expect(vm.ctaRoute, '/inventory',
          reason: 'the inventory owns the put-it-in-the-room action; sending '
              'the player to the room would be a button that does not do what '
              'it says');
    });

    test('PLACED is detected from the real room rows', () {
      final vm = _vm(ownedQuantity: 1, placedCount: 1);
      expect(vm.status, CollectionAcquisitionStatus.placed);
      expect(vm.statusLine, '已摆放');
      expect(vm.ctaLabel, '查看房间');
      expect(vm.ctaRoute, '/room');
    });

    test('an owned item with a copy still unplaced reports owned', () {
      // Owned twice, one in the room: there is still something to place, and
      // 已摆放 would hide it.
      final vm = _vm(ownedQuantity: 2, placedCount: 1);
      expect(vm.status, CollectionAcquisitionStatus.owned);
      expect(vm.statusLine, '已拥有 x2');
      expect(vm.ctaRoute, '/inventory');
    });

    test('placed wins over owned once every copy is placed', () {
      final vm = _vm(ownedQuantity: 2, placedCount: 2);
      expect(vm.status, CollectionAcquisitionStatus.placed);
    });

    test('crafting outranks placed: real progress is never hidden', () {
      final recipe = _recipe();
      final vm = _vm(
        recipes: [recipe],
        activeJob: _job('sofa', progressSeconds: 60),
        activeRecipe: recipe,
        ownedQuantity: 1,
        placedCount: 1,
      );
      expect(vm.status, CollectionAcquisitionStatus.crafting,
          reason: 'a running job is live work; hiding it behind 已摆放 would '
              'lose real progress the player is waiting on');
    });
  });

  group('every route is one that exists', () {
    test('no status invents a destination', () {
      const realRoutes = {
        '/craft/detail/sofa',
        '/inventory',
        '/room',
      };
      final vms = [
        _vm(),
        _vm(ownedQuantity: 1),
        _vm(ownedQuantity: 1, placedCount: 1),
        _vm(
          activeJob: _job('sofa', progressSeconds: 60),
          activeRecipe: _recipe(),
        ),
      ];
      for (final vm in vms) {
        final route = vm.ctaRoute;
        expect(route, isNotNull);
        expect(realRoutes, contains(route),
            reason: '${vm.status} routes to $route, which is not a route the '
                'app has');
      }
    });
  });
}
