// ignore_for_file: deprecated_member_use
// Phase 4 Controller Tests — CraftController
// Tests all controller actions against in-memory DB:
// loadAll, startJob, cancelJob, placeItem, moveRoomItem, removeRoomItem,
// refreshInventoryAndRoom, error handling.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide FocusSession, Pet, CraftJob, CraftRecipe, InventoryItem, RoomItem;
import 'package:cozy_focus_app/data/repositories/drift_craft_repository.dart';
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/craft_engine.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';

class _ControllerClock implements FocusClock {
  final DateTime _t;
  _ControllerClock(this._t);
  @override
  DateTime now() => _t;
}

void main() {
  group('CraftController Tests', () {
    late AppDatabase db;
    late DriftCraftRepository repo;
    late CraftEngine engine;
    late CraftController controller;

    const testUserId = 'test-controller-user';

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = DriftCraftRepository(db.craftDao);
      engine = CraftEngine(craftRepo: repo);
      controller = CraftController(
        repo: repo,
        engine: engine,
        clock: _ControllerClock(DateTime(2026, 6, 1, 9)),
        userId: testUserId,
      );
    });

    tearDown(() => db.close());

    test('1. loadAll populates recipes and resets isLoading', () async {
      expect(controller.debugState.recipes, isEmpty);
      await controller.loadAll();
      expect(controller.debugState.recipes.length, equals(8));
      expect(controller.debugState.isLoading, isFalse);
      expect(controller.debugState.error, isNull);
    });

    test('2. startJob sets activeJob and activeRecipe', () async {
      await controller.loadAll();
      await controller.startJob('sofa');

      expect(controller.debugState.activeJob, isNotNull);
      expect(controller.debugState.activeJob!.recipeId, equals('sofa'));
      expect(controller.debugState.activeJob!.status,
          equals(CraftJobStatus.inProgress));
      expect(controller.debugState.activeRecipe, isNotNull);
      expect(controller.debugState.activeRecipe!.id, equals('sofa'));
      expect(controller.debugState.isLoading, isFalse);
    });

    test('3. cancelJob clears activeJob and activeRecipe', () async {
      await controller.loadAll();
      await controller.startJob('sofa');
      expect(controller.debugState.activeJob, isNotNull);

      await controller.cancelJob();
      expect(controller.debugState.activeJob, isNull);
      expect(controller.debugState.activeRecipe, isNull);
      expect(controller.debugState.isLoading, isFalse);
    });

    test('4. placeItem persists RoomItem and updates state', () async {
      // Seed inventory so domain guard passes.
      await repo.upsertInventoryItem(InventoryItem(
        id: 'inv-sofa-1',
        userId: testUserId,
        itemId: 'sofa',
        quantity: 1,
        updatedAt: DateTime(2026, 6, 1, 9),
      ));
      await controller.loadAll();
      await controller.placeItem('sofa', 0.25, 0.5);

      expect(controller.debugState.roomItems.length, equals(1));
      final placed = controller.debugState.roomItems.first;
      expect(placed.itemId, equals('sofa'));
      expect(placed.positionX, closeTo(0.25, 0.001));
      expect(placed.positionY, closeTo(0.5, 0.001));

      // verify in repo
      final inRepo = await repo.findRoomItems(testUserId);
      expect(inRepo.length, equals(1));
    });

    test('5. moveRoomItem updates coordinates in state and DB', () async {
      await repo.upsertInventoryItem(InventoryItem(
        id: 'inv-sofa-2',
        userId: testUserId,
        itemId: 'sofa',
        quantity: 1,
        updatedAt: DateTime(2026, 6, 1, 9),
      ));
      await controller.loadAll();
      await controller.placeItem('sofa', 0.1, 0.1);
      final itemId = controller.debugState.roomItems.first.id;

      await controller.moveRoomItem(itemId, 0.8, 0.9);
      final moved = controller.debugState.roomItems.first;
      expect(moved.positionX, closeTo(0.8, 0.001));
      expect(moved.positionY, closeTo(0.9, 0.001));

      final inRepo = await repo.findRoomItems(testUserId);
      expect(inRepo.first.positionX, closeTo(0.8, 0.001));
      expect(inRepo.first.positionY, closeTo(0.9, 0.001));
    });

    test('6. removeRoomItem deletes placement from state and DB', () async {
      await repo.upsertInventoryItem(InventoryItem(
        id: 'inv-sofa-3',
        userId: testUserId,
        itemId: 'sofa',
        quantity: 1,
        updatedAt: DateTime(2026, 6, 1, 9),
      ));
      await controller.loadAll();
      await controller.placeItem('sofa', 0.5, 0.5);
      expect(controller.debugState.roomItems.length, equals(1));

      final itemId = controller.debugState.roomItems.first.id;
      await controller.removeRoomItem(itemId);

      expect(controller.debugState.roomItems, isEmpty);
      final inRepo = await repo.findRoomItems(testUserId);
      expect(inRepo, isEmpty);
    });

    test('7. refreshInventoryAndRoom picks up external DB changes', () async {
      await controller.loadAll();
      expect(controller.debugState.inventory, isEmpty);

      await repo.upsertInventoryItem(InventoryItem(
        id: 'inv-ext-1',
        userId: testUserId,
        itemId: 'bookshelf',
        quantity: 1,
        updatedAt: DateTime.now(),
      ));

      await controller.refreshInventoryAndRoom();
      expect(controller.debugState.inventory.length, equals(1));
      expect(controller.debugState.inventory.first.itemId, equals('bookshelf'));
    });

    test('8. startJob with invalid recipe sets error on state', () async {
      await controller.loadAll();
      await controller.startJob('nonexistent_recipe');

      expect(controller.debugState.error, isNotNull);
      expect(controller.debugState.isLoading, isFalse);
    });
  });
}
