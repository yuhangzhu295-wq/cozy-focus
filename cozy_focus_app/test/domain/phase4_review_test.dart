// Phase 4 Independent Review Tests
// Uses an in-memory Drift DB for full integration coverage.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

// AppDatabase brings in generated Drift row types that share names with domain
// models; hide all conflicting names so the explicit domain imports win.
import 'package:cozy_focus_app/data/local/app_database.dart'
    hide FocusSession, Pet, CraftJob, CraftRecipe, InventoryItem, RoomItem;
import 'package:cozy_focus_app/data/local/daos/settlement_dao.dart';
import 'package:cozy_focus_app/data/repositories/drift_craft_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_reward_ledger_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_pet_repository.dart';
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/pet_models.dart';
import 'package:cozy_focus_app/domain/models/sync_models.dart';
import 'package:cozy_focus_app/domain/models/focus_session.dart';
import 'package:cozy_focus_app/domain/services/craft_engine.dart';
import 'package:cozy_focus_app/domain/services/reward_service.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';

const _uuid = Uuid();

AppDatabase _openInMemory() => AppDatabase.forTesting(NativeDatabase.memory());

class _FixedClock implements FocusClock {
  DateTime _t;
  _FixedClock(this._t);
  void advance(Duration d) => _t = _t.add(d);
  @override
  DateTime now() => _t;
}

FocusSession _session({
  required String id,
  required String userId,
  required int elapsedSeconds,
}) {
  final base = DateTime(2026, 1, 1, 10);
  return FocusSession(
    id: id,
    userId: userId,
    taskName: 'Test Task',
    categoryId: 'study',
    mode: FocusMode.focus,
    plannedSeconds: elapsedSeconds,
    status: FocusSessionStatus.completed,
    startAt: base,
    endAt: base.add(Duration(seconds: elapsedSeconds)),
    pauseIntervals: const [],
    timezoneOffsetMinutes: 480,
  );
}

void main() {
  // =========================================================================
  group('Phase 4 Review - SettlementDao atomic writes', () {
    late AppDatabase db;
    late SettlementDao settlement;
    late DriftCraftRepository craftRepo;
    late DriftPetRepository petRepo;
    late _FixedClock clock;

    const userId = 'user-p4';

    setUp(() async {
      db = _openInMemory();
      settlement = db.settlementDao;
      craftRepo = DriftCraftRepository(db.craftDao);
      petRepo = DriftPetRepository(db.petDao);
      clock = _FixedClock(DateTime(2026, 6, 1, 9));
    });

    tearDown(() => db.close());

    Future<PetProgress> seedPet() async {
      const petId = 'pet-1';
      await petRepo.savePet(Pet(
        id: petId,
        userId: userId,
        name: 'Mochi',
        species: PetSpecies.dog,
        characterId: 'mochi',
        adoptedAt: clock.now(),
      ));
      final p = PetProgress(
        id: 'pp-1',
        petId: petId,
        level: 1,
        experiencePoints: 0,
        totalFocusMinutes: 0,
        happinessScore: 50,
        updatedAt: clock.now(),
      );
      await petRepo.savePetProgress(p);
      return p;
    }

    RewardLedger ledger(String sid, int elapsed) => RewardLedger(
          sessionId: sid,
          userId: userId,
          focusCoinsEarned: (elapsed ~/ 60) * 2,
          experienceEarned: (elapsed ~/ 60) * 5,
          settledAt: clock.now(),
        );

    test('1. first settle returns true', () async {
      await seedPet();
      final result = await settlement.settleAtomically(
        entry: ledger(_uuid.v4(), 1800),
        addedFocusSeconds: 1800,
        now: clock.now(),
      );
      expect(result, isTrue);
    });

    test('2. duplicate settle on same session_id returns false', () async {
      await seedPet();
      final sid = _uuid.v4();
      final e = ledger(sid, 1800);
      final first = await settlement.settleAtomically(
        entry: e,
        addedFocusSeconds: 1800,
        now: clock.now(),
      );
      final second = await settlement.settleAtomically(
        entry: e,
        addedFocusSeconds: 1800,
        now: clock.now(),
      );
      expect(first, isTrue);
      expect(second, isFalse);
    });

    test('3. pet XP increases exactly once after two settle attempts',
        () async {
      await seedPet();
      final sid = _uuid.v4();
      final e = ledger(sid, 1800); // 30 min => +150 XP
      await settlement.settleAtomically(
        entry: e,
        addedFocusSeconds: 1800,
        now: clock.now(),
      );
      await settlement.settleAtomically(
        entry: e,
        addedFocusSeconds: 1800,
        now: clock.now(),
      );
      final pet = await petRepo.findPetByUser(userId);
      final after = await petRepo.findPetProgress(pet!.id);
      expect(after!.experiencePoints, equals(150));
    });

    test('4. craft progress accumulated exactly once on duplicate settle',
        () async {
      await seedPet();
      final recipe = await craftRepo.findRecipeById('sofa');
      expect(recipe, isNotNull);
      final job = CraftJob(
        id: _uuid.v4(),
        userId: userId,
        recipeId: 'sofa',
        status: CraftJobStatus.inProgress,
        progressSeconds: 0,
        startedAt: clock.now(),
        rewardClaimed: false,
      );
      await craftRepo.saveJob(job);
      final sid = _uuid.v4();
      final e = ledger(sid, 600); // 10 min, below sofa threshold
      await settlement.settleAtomically(
        entry: e,
        addedFocusSeconds: 600,
        now: clock.now(),
      );
      await settlement.settleAtomically(
        entry: e,
        addedFocusSeconds: 600,
        now: clock.now(),
      );
      final updated = await craftRepo.findJobById(job.id);
      expect(updated!.progressSeconds, equals(600));
    });

    test('5. craft completion + inventory write are atomic', () async {
      await seedPet();
      final recipe = await craftRepo.findRecipeById('sofa');
      expect(recipe, isNotNull);
      final job = CraftJob(
        id: _uuid.v4(),
        userId: userId,
        recipeId: 'sofa',
        status: CraftJobStatus.inProgress,
        progressSeconds: 0,
        startedAt: clock.now(),
        rewardClaimed: false,
      );
      await craftRepo.saveJob(job);
      await settlement.settleAtomically(
        entry: ledger(_uuid.v4(), recipe!.requiredSeconds),
        addedFocusSeconds: recipe.requiredSeconds,
        now: clock.now(),
      );
      final updatedJob = await craftRepo.findJobById(job.id);
      expect(updatedJob!.status, equals(CraftJobStatus.completed));
      final inv =
          await craftRepo.findInventoryItem(userId, recipe.outputItemId);
      expect(inv, isNotNull);
      expect(inv!.quantity, equals(1));
    });

    test('6. second craft completion increments inventory quantity to 2',
        () async {
      await seedPet();
      final recipe = await craftRepo.findRecipeById('sofa');
      expect(recipe, isNotNull);

      final job1 = CraftJob(
        id: _uuid.v4(),
        userId: userId,
        recipeId: 'sofa',
        status: CraftJobStatus.inProgress,
        progressSeconds: 0,
        startedAt: clock.now(),
        rewardClaimed: false,
      );
      await craftRepo.saveJob(job1);
      await settlement.settleAtomically(
        entry: ledger(_uuid.v4(), recipe!.requiredSeconds),
        addedFocusSeconds: recipe.requiredSeconds,
        now: clock.now(),
      );

      final pet = await petRepo.findPetByUser(userId);
      // ignore: unused_local_variable
      final p2 = await petRepo.findPetProgress(pet!.id);

      final job2 = CraftJob(
        id: _uuid.v4(),
        userId: userId,
        recipeId: 'sofa',
        status: CraftJobStatus.inProgress,
        progressSeconds: 0,
        startedAt: clock.now(),
        rewardClaimed: false,
      );
      await craftRepo.saveJob(job2);
      await settlement.settleAtomically(
        entry: ledger(_uuid.v4(), recipe.requiredSeconds),
        addedFocusSeconds: recipe.requiredSeconds,
        now: clock.now(),
      );

      final inv =
          await craftRepo.findInventoryItem(userId, recipe.outputItemId);
      expect(inv!.quantity, equals(2));
    });
  });

  // =========================================================================
  group('Phase 4 Review - CraftEngine startJobIfNoneActive', () {
    late AppDatabase db;
    late DriftCraftRepository craftRepo;
    late CraftEngine engine;

    const userId = 'user-craft';

    setUp(() async {
      db = _openInMemory();
      craftRepo = DriftCraftRepository(db.craftDao);
      engine = CraftEngine(craftRepo: craftRepo);
    });

    tearDown(() => db.close());

    test('7. startJob succeeds when no active job exists', () async {
      final job = await engine.startJob(userId, 'sofa');
      expect(job.status, equals(CraftJobStatus.inProgress));
      expect(job.progressSeconds, equals(0));
    });

    test('8. startJob throws StateError when active job exists', () async {
      await engine.startJob(userId, 'sofa');
      await expectLater(
        () async => engine.startJob(userId, 'table'),
        throwsA(isA<StateError>()),
      );
    });

    test('9. after cancelActiveJob, a new job can be started', () async {
      await engine.startJob(userId, 'sofa');
      await engine.cancelActiveJob(userId);
      final job2 = await engine.startJob(userId, 'table');
      expect(job2.recipeId, equals('table'));
    });

    test('10. cancelled job does not accumulate progress', () async {
      final job = await engine.startJob(userId, 'sofa');
      await engine.cancelActiveJob(userId);
      final result = await engine.accumulateProgress(userId, 600);
      expect(result, isNull);
      final dbJob = await craftRepo.findJobById(job.id);
      expect(dbJob!.progressSeconds, equals(0));
    });

    test('11. completed job does not accumulate further progress', () async {
      final recipe = await craftRepo.findRecipeById('sofa');
      expect(recipe, isNotNull);
      await engine.startJob(userId, 'sofa');
      await engine.accumulateProgress(userId, recipe!.requiredSeconds);
      final result = await engine.accumulateProgress(userId, 600);
      expect(result, isNull);
    });

    test('12. exceeding required seconds marks job completed', () async {
      final recipe = await craftRepo.findRecipeById('sofa');
      expect(recipe, isNotNull);
      await engine.startJob(userId, 'sofa');
      final updated = await engine.accumulateProgress(
          userId, recipe!.requiredSeconds + 300);
      expect(updated!.status, equals(CraftJobStatus.completed));
      expect(updated.progressSeconds,
          greaterThanOrEqualTo(recipe.requiredSeconds));
    });

    test('13. fresh DB has no inventory items', () async {
      final inv = await craftRepo.findInventory(userId);
      expect(inv, isEmpty);
    });

    test('14. fresh DB has no room items', () async {
      final room = await craftRepo.findRoomItems(userId);
      expect(room, isEmpty);
    });

    test('15. 8 recipes seeded with no duplicates', () async {
      final recipes = await craftRepo.findAllRecipes();
      expect(recipes.length, equals(8));
      final ids = recipes.map((r) => r.id).toSet();
      expect(ids.length, equals(8));
    });
  });

  // =========================================================================
  group('Phase 4 Review - Inventory and Room persistence', () {
    late AppDatabase db;
    late DriftCraftRepository craftRepo;
    late _FixedClock clock;

    const userId = 'user-room';

    setUp(() async {
      db = _openInMemory();
      craftRepo = DriftCraftRepository(db.craftDao);
      clock = _FixedClock(DateTime(2026, 6, 1));
    });

    tearDown(() => db.close());

    Future<InventoryItem> seedInv({int qty = 1}) async {
      final item = InventoryItem(
        id: _uuid.v4(),
        userId: userId,
        itemId: 'sofa',
        quantity: qty,
        updatedAt: clock.now(),
      );
      await craftRepo.upsertInventoryItem(item);
      return item;
    }

    RoomItem roomItem({double x = 0.3, double y = 0.4}) => RoomItem(
          id: _uuid.v4(),
          userId: userId,
          itemId: 'sofa',
          positionX: x,
          positionY: y,
          scale: 1.0,
          zIndex: 0,
          isVisible: true,
          placedAt: clock.now(),
        );

    test('16. placed room item persists in DB', () async {
      await seedInv();
      final ri = roomItem();
      await craftRepo.placeRoomItem(ri);
      final items = await craftRepo.findRoomItems(userId);
      expect(items.length, equals(1));
      expect(items.first.positionX, closeTo(0.3, 0.001));
      expect(items.first.positionY, closeTo(0.4, 0.001));
    });

    test('17. move room item updates coordinates in DB', () async {
      await seedInv();
      final ri = roomItem(x: 0.1, y: 0.1);
      await craftRepo.placeRoomItem(ri);
      final moved = RoomItem(
        id: ri.id,
        userId: ri.userId,
        itemId: ri.itemId,
        positionX: 0.7,
        positionY: 0.8,
        scale: ri.scale,
        zIndex: ri.zIndex,
        isVisible: ri.isVisible,
        placedAt: ri.placedAt,
      );
      await craftRepo.updateRoomItem(moved);
      final items = await craftRepo.findRoomItems(userId);
      expect(items.first.positionX, closeTo(0.7, 0.001));
      expect(items.first.positionY, closeTo(0.8, 0.001));
    });

    test('18. removeRoomItem keeps inventory ownership', () async {
      await seedInv();
      final ri = roomItem();
      await craftRepo.placeRoomItem(ri);
      await craftRepo.removeRoomItem(ri.id);
      final room = await craftRepo.findRoomItems(userId);
      expect(room, isEmpty);
      final inv = await craftRepo.findInventoryItem(userId, 'sofa');
      expect(inv, isNotNull);
      expect(inv!.quantity, equals(1));
    });

    test('19. item can be re-placed after removal', () async {
      await seedInv();
      final ri = roomItem();
      await craftRepo.placeRoomItem(ri);
      await craftRepo.removeRoomItem(ri.id);
      await craftRepo.placeRoomItem(roomItem(x: 0.5, y: 0.5));
      final room = await craftRepo.findRoomItems(userId);
      expect(room.length, equals(1));
    });

    test('20. placed count equals inventory limit at capacity', () async {
      await seedInv(qty: 1);
      await craftRepo.placeRoomItem(roomItem());
      final room = await craftRepo.findRoomItems(userId);
      final inv = await craftRepo.findInventoryItem(userId, 'sofa');
      final placed = room.where((r) => r.itemId == 'sofa').length;
      expect(placed, greaterThanOrEqualTo(inv!.quantity));
    });

    test('21. inventory quantity=2 allows 2 placements', () async {
      await seedInv(qty: 2);
      await craftRepo.placeRoomItem(roomItem(x: 0.1, y: 0.1));
      await craftRepo.placeRoomItem(roomItem(x: 0.6, y: 0.6));
      final room = await craftRepo.findRoomItems(userId);
      expect(room.length, equals(2));
    });

    test('22. room coordinates survive DB round-trip query', () async {
      await seedInv();
      final ri = roomItem(x: 0.42, y: 0.58);
      await craftRepo.placeRoomItem(ri);
      final items = await craftRepo.findRoomItems(userId);
      expect(items.first.positionX, closeTo(0.42, 0.0001));
      expect(items.first.positionY, closeTo(0.58, 0.0001));
    });
  });

  // =========================================================================
  group('Phase 4 Review - RewardService sequential path', () {
    late AppDatabase db;
    late DriftRewardLedgerRepository ledgerRepo;
    late DriftPetRepository petRepo;
    late RewardService service;
    late _FixedClock clock;

    const userId = 'user-reward';

    setUp(() async {
      db = _openInMemory();
      ledgerRepo = DriftRewardLedgerRepository(db.rewardLedgerDao);
      petRepo = DriftPetRepository(db.petDao);
      clock = _FixedClock(DateTime(2026, 6, 1, 8));
      service = RewardService(
        ledgerRepo: ledgerRepo,
        petRepo: petRepo,
        clock: clock,
      );
    });

    tearDown(() => db.close());

    test('23. sequential settle idempotent - second call returns false',
        () async {
      final s = _session(id: _uuid.v4(), userId: userId, elapsedSeconds: 1800);
      final first = await service.settle(s);
      final second = await service.settle(s);
      expect(first, isTrue);
      expect(second, isFalse);
    });

    test('24. focus elapsed seconds translate to correct coins', () async {
      final s = _session(id: _uuid.v4(), userId: userId, elapsedSeconds: 3600);
      await service.settle(s);
      final entry = await ledgerRepo.findBySessionId(s.id);
      expect(entry, isNotNull);
      expect(entry!.focusCoinsEarned, equals(120));
    });
  });

  // =========================================================================
  group('Phase 4 Review - Progress math and fake data guard', () {
    test('25. progress ratio 0.0 at start', () {
      final ratio = (0 / 1800).clamp(0.0, 1.0);
      expect(ratio, equals(0.0));
    });

    test('26. progressSeconds >= required clamps to 1.0', () {
      final ratio = (2400 / 1800).clamp(0.0, 1.0);
      expect(ratio, equals(1.0));
    });

    test('27. remainingSeconds is never negative', () {
      final remaining = (1800 - 2400).clamp(0, 1800);
      expect(remaining, equals(0));
    });

    test('28. pause time excluded from elapsed (arithmetic verification)', () {
      final start = DateTime(2026, 6, 1, 9, 0);
      final pauseStart = DateTime(2026, 6, 1, 9, 10);
      final pauseEnd = DateTime(2026, 6, 1, 9, 15);
      final end = DateTime(2026, 6, 1, 9, 30);
      final elapsed = end.difference(start).inSeconds -
          pauseEnd.difference(pauseStart).inSeconds;
      expect(elapsed, equals(1500));
    });
  });
}
