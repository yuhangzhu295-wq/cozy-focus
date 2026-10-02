// P7 Slice 1 — placement control.
//
// The three attributes below were already persisted and already consumed by the
// anchor registry and the companion's feet maths; what was missing was the write
// path. These tests exercise that path through the controller against an
// in-memory database, and assert the *derived* consequences — draw order, the
// anchor set, the feet line — rather than only the stored row.
//
// `debugState` is the read-only view of a `StateNotifier`'s state from outside
// the class, and is what the existing controller tests use.
// ignore_for_file: deprecated_member_use
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide FocusSession, Pet, CraftJob, CraftRecipe, InventoryItem, RoomItem;
import 'package:cozy_focus_app/data/repositories/drift_craft_repository.dart';
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/services/craft_engine.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/companion/room/anchor_point.dart';
import 'package:cozy_focus_app/presentation/companion/room/companion_placement.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/room_presence.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';

class _FixedClock implements FocusClock {
  final DateTime _t;
  _FixedClock(this._t);
  @override
  DateTime now() => _t;
}

void main() {
  late AppDatabase db;
  late DriftCraftRepository repo;
  late CraftController controller;

  const userId = 'p7-placement-user';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftCraftRepository(db.craftDao);
    controller = CraftController(
      repo: repo,
      engine: CraftEngine(craftRepo: repo),
      clock: _FixedClock(DateTime(2026, 10, 1, 10)),
      userId: userId,
    );
    await controller.loadAll();
  });

  tearDown(() => db.close());

  Future<void> seed(String itemId, {int quantity = 3}) =>
      repo.upsertInventoryItem(InventoryItem(
        id: 'inv-$itemId',
        userId: userId,
        itemId: itemId,
        quantity: quantity,
        updatedAt: DateTime(2026, 10, 1),
      ));

  /// Places [itemId] and returns the persisted row.
  ///
  /// The inventory is seeded through the repository, so the controller's mirror
  /// has to be refreshed before placing — otherwise `placeItem` would find no
  /// stock, and the anchor registry, which reads the same mirror, would derive
  /// nothing.
  Future<RoomItem> place(String itemId, double x, double y) async {
    await seed(itemId);
    await controller.refreshInventoryAndRoom();
    await controller.placeItem(itemId, x, y);
    // placeItem re-reads from the database, so the last row is the newest.
    return controller.debugState.roomItems.last;
  }

  /// The anchors the current placement defines, built the way the app builds
  /// them — through the real catalog and the real seat-surface table.
  Map<String, AnchorPoint> anchors() => FurnitureAnchorRegistry.build(
        placed: controller.debugState.roomItems,
        owned: controller.debugState.inventory,
        eligibleItemIds: FurnitureCatalog.itemIds,
        surfaceFractionFor: PetRoomPresenceResolver.seatSurfaceFraction,
      );

  List<String> drawOrder() =>
      controller.debugState.roomItems.map((r) => r.id).toList();

  group('P7 placement control — scale', () {
    test('1. setRoomItemScale persists the value and mirrors it into state',
        () async {
      final sofa = await place('sofa', 0.3, 0.6);

      await controller.setRoomItemScale(sofa.id, 1.4);

      final persisted = (await repo.findRoomItems(userId)).single;
      expect(persisted.scale, closeTo(1.4, 1e-9));
      expect(controller.debugState.roomItems.single.scale, closeTo(1.4, 1e-9));
      expect(controller.debugState.error, isNull);
    });

    test('2. an out-of-range scale is clamped, never rejected', () async {
      final sofa = await place('sofa', 0.3, 0.6);

      await controller.setRoomItemScale(sofa.id, 9.0);
      expect(controller.debugState.roomItems.single.scale,
          CraftController.maxRoomItemScale);

      await controller.setRoomItemScale(sofa.id, 0.01);
      expect(controller.debugState.roomItems.single.scale,
          CraftController.minRoomItemScale);
    });

    test('3. resizing one item leaves every other row untouched', () async {
      final sofa = await place('sofa', 0.2, 0.5);
      final bed = await place('bed', 0.8, 0.5);
      final bedBefore =
          controller.debugState.roomItems.firstWhere((r) => r.id == bed.id);

      await controller.setRoomItemScale(sofa.id, 1.6);

      final bedAfter =
          controller.debugState.roomItems.firstWhere((r) => r.id == bed.id);
      expect(bedAfter.scale, bedBefore.scale);
      expect(bedAfter.positionX, bedBefore.positionX);
      expect(bedAfter.positionY, bedBefore.positionY);
      expect(bedAfter.zIndex, bedBefore.zIndex);
      expect(bedAfter.isVisible, bedBefore.isVisible);
    });

    test('4. a scale change moves the companion\'s feet, so scale is wired',
        () async {
      final bed = await place('bed', 0.5, 0.5);
      const canvasHeight = 800.0;

      final anchorBefore =
          FurnitureAnchorRegistry.forRoomItem(anchors(), bed.id)!;
      final feetBefore = CompanionPlacement.feetYFor(
        anchor: anchorBefore,
        canvasHeight: canvasHeight,
      );

      await controller.setRoomItemScale(bed.id, 1.8);

      final anchorAfter =
          FurnitureAnchorRegistry.forRoomItem(anchors(), bed.id)!;
      final feetAfter = CompanionPlacement.feetYFor(
        anchor: anchorAfter,
        canvasHeight: canvasHeight,
      );

      // The bed's surface sits above its centre, so a taller sprite lifts the
      // resting line. A no-op here would mean `scale` is still dead data.
      expect(feetAfter, isNot(closeTo(feetBefore, 0.01)));
      expect(anchorAfter.scale, closeTo(1.8, 1e-9));
    });
  });

  group('P7 placement control — z-order', () {
    test('5. bringRoomItemToFront moves the item to the end of draw order',
        () async {
      final sofa = await place('sofa', 0.2, 0.5);
      final desk = await place('desk', 0.5, 0.5);
      final bed = await place('bed', 0.8, 0.5);

      await controller.bringRoomItemToFront(sofa.id);

      expect(drawOrder(), [desk.id, bed.id, sofa.id]);
      final persisted = await repo.findRoomItems(userId);
      expect(persisted.last.id, sofa.id);
    });

    test('6. sendRoomItemToBack moves the item to the front of draw order',
        () async {
      final sofa = await place('sofa', 0.2, 0.5);
      final desk = await place('desk', 0.5, 0.5);
      final bed = await place('bed', 0.8, 0.5);

      await controller.sendRoomItemToBack(bed.id);

      expect(drawOrder(), [bed.id, sofa.id, desk.id]);
      final persisted = await repo.findRoomItems(userId);
      expect(persisted.first.id, bed.id);
    });

    test('7. z values stay dense 0..n-1 with no duplicate after a restack',
        () async {
      final sofa = await place('sofa', 0.2, 0.5);
      final desk = await place('desk', 0.5, 0.5);
      final bed = await place('bed', 0.8, 0.5);

      await controller.bringRoomItemToFront(sofa.id);
      await controller.sendRoomItemToBack(bed.id);
      await controller.bringRoomItemToFront(desk.id);

      final zs =
          (await repo.findRoomItems(userId)).map((r) => r.zIndex).toList();
      expect(zs, [0, 1, 2]);
      expect(zs.toSet().length, 3);
    });

    test('8. restacking does not disturb positions or visibility', () async {
      final sofa = await place('sofa', 0.25, 0.4);
      final desk = await place('desk', 0.75, 0.6);

      await controller.bringRoomItemToFront(sofa.id);

      final sofaAfter =
          controller.debugState.roomItems.firstWhere((r) => r.id == sofa.id);
      final deskAfter =
          controller.debugState.roomItems.firstWhere((r) => r.id == desk.id);
      expect(sofaAfter.positionX, closeTo(0.25, 1e-9));
      expect(sofaAfter.positionY, closeTo(0.4, 1e-9));
      expect(deskAfter.positionX, closeTo(0.75, 1e-9));
      expect(deskAfter.isVisible, isTrue);
    });
  });

  group('P7 placement control — visibility', () {
    test('9. hiding an item drops its anchor but keeps its row', () async {
      final sofa = await place('sofa', 0.3, 0.6);
      expect(anchors(), isNotEmpty);

      await controller.setRoomItemVisible(sofa.id, false);

      // The row survives...
      expect(controller.debugState.roomItems.single.id, sofa.id);
      expect((await repo.findRoomItems(userId)).single.isVisible, isFalse);
      // ...but the companion has nowhere to go for it.
      expect(anchors(), isEmpty);
    });

    test('10. showing it again restores the anchor', () async {
      final sofa = await place('sofa', 0.3, 0.6);

      await controller.setRoomItemVisible(sofa.id, false);
      expect(anchors(), isEmpty);

      await controller.setRoomItemVisible(sofa.id, true);
      expect(anchors(), isNotEmpty);
      expect(anchors().values.single.roomItemId, sofa.id);
    });
  });

  group('P7 placement control — safety', () {
    test('11. an unknown id is a silent no-op', () async {
      await place('sofa', 0.3, 0.6);

      await controller.setRoomItemScale('does-not-exist', 1.5);
      await controller.setRoomItemVisible('does-not-exist', false);
      await controller.bringRoomItemToFront('does-not-exist');
      await controller.sendRoomItemToBack('does-not-exist');

      expect(controller.debugState.error, isNull);
      expect(controller.debugState.roomItems.length, 1);
    });

    test('12. placement control cannot touch the business economy', () async {
      final sofa = await place('sofa', 0.2, 0.5);
      final bed = await place('bed', 0.8, 0.5);

      List<String> inventorySnapshot() => controller.debugState.inventory
          .map((i) => '${i.id}:${i.itemId}:${i.quantity}')
          .toList();
      final inventoryBefore = inventorySnapshot();
      final recipesBefore = controller.debugState.recipes.length;

      await controller.setRoomItemScale(sofa.id, 1.7);
      await controller.setRoomItemVisible(bed.id, false);
      await controller.bringRoomItemToFront(sofa.id);
      await controller.sendRoomItemToBack(bed.id);

      // Quantities are the reward economy's own truth; placement must not mint
      // or consume a single one of them.
      expect(inventorySnapshot(), inventoryBefore);
      expect(controller.debugState.recipes.length, recipesBefore);
      expect(controller.debugState.activeJob, isNull);
      expect(controller.debugState.activeRecipe, isNull);
    });
  });
}
