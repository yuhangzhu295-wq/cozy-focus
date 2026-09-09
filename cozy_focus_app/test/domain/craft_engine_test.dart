import 'package:flutter_test/flutter_test.dart';
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/repositories/i_craft_repository.dart';
import 'package:cozy_focus_app/domain/services/craft_engine.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';

// ── Fake Repository ──────────────────────────────────────────────────────────

class FakeCraftRepository implements ICraftRepository {
  final Map<String, CraftRecipe> _recipes = {};
  final Map<String, CraftJob> _jobs = {};
  final Map<String, InventoryItem> _inventory = {};
  final Map<String, RoomItem> _roomItems = {};

  void seedRecipe(CraftRecipe r) => _recipes[r.id] = r;

  @override
  Future<List<CraftRecipe>> findAllRecipes() async => _recipes.values.toList();

  @override
  Future<CraftRecipe?> findRecipeById(String id) async => _recipes[id];

  @override
  Future<CraftJob?> findJobById(String id) async => _jobs[id];

  @override
  Future<CraftJob?> findActiveJobByUser(String userId) async {
    for (final j in _jobs.values) {
      if (j.userId == userId &&
          (j.status == CraftJobStatus.inProgress ||
              j.status == CraftJobStatus.pending)) {
        return j;
      }
    }
    return null;
  }

  @override
  Future<List<CraftJob>> findJobsByUser(String userId) async =>
      _jobs.values.where((j) => j.userId == userId).toList();

  @override
  Future<void> saveJob(CraftJob job) async => _jobs[job.id] = job;

  @override
  Future<void> updateJob(CraftJob job) async => _jobs[job.id] = job;

  @override
  Future<bool> startJobIfNoneActive(String userId, CraftJob newJob) async {
    for (final j in _jobs.values) {
      if (j.userId == userId &&
          (j.status == CraftJobStatus.inProgress ||
              j.status == CraftJobStatus.pending)) {
        return false;
      }
    }
    _jobs[newJob.id] = newJob;
    return true;
  }

  @override
  Future<InventoryItem?> findInventoryItem(String userId, String itemId) async {
    final key = '$userId:$itemId';
    return _inventory[key];
  }

  @override
  Future<List<InventoryItem>> findInventory(String userId) async =>
      _inventory.values.where((i) => i.userId == userId).toList();

  @override
  Future<void> upsertInventoryItem(InventoryItem item) async {
    final key = '${item.userId}:${item.itemId}';
    _inventory[key] = item;
  }

  @override
  Future<List<RoomItem>> findRoomItems(String userId) async =>
      _roomItems.values.where((r) => r.userId == userId).toList();

  @override
  Future<void> placeRoomItem(RoomItem item) async => _roomItems[item.id] = item;

  @override
  Future<void> updateRoomItem(RoomItem item) async =>
      _roomItems[item.id] = item;

  @override
  Future<void> removeRoomItem(String id) async => _roomItems.remove(id);

  @override
  Future<RoomPlacementResult> placeRoomItemIfAvailable(RoomItem item) async {
    final key = '${item.userId}:${item.itemId}';
    final inv = _inventory[key];
    if (inv == null || inv.quantity <= 0) {
      return RoomPlacementResult.inventoryMissing;
    }
    final placedCount =
        _roomItems.values.where((r) => r.itemId == item.itemId).length;
    if (placedCount >= inv.quantity) {
      return RoomPlacementResult.inventoryExhausted;
    }
    _roomItems[item.id] = item;
    return RoomPlacementResult.placed;
  }
}

// ── Fixed Clock ──────────────────────────────────────────────────────────────

class FakeClock implements FocusClock {
  DateTime _now;
  FakeClock(this._now);
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

CraftRecipe _recipe({int minutes = 30}) => CraftRecipe(
      id: 'sofa',
      name: '温馨沙发',
      requiredMinutes: minutes,
      ingredientCosts: const {},
      outputItemId: 'sofa',
      outputQuantity: 1,
    );

const _userId = 'user-1';

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late FakeCraftRepository repo;
  late FakeClock clock;
  late CraftEngine engine;

  setUp(() {
    repo = FakeCraftRepository();
    clock = FakeClock(DateTime(2026, 1, 1, 9, 0));
    engine = CraftEngine(craftRepo: repo, clock: clock);
    repo.seedRecipe(_recipe());
  });

  group('CraftEngine — startJob', () {
    test('creates a CraftJob with status inProgress', () async {
      final job = await engine.startJob(_userId, 'sofa');
      expect(job.status, CraftJobStatus.inProgress);
      expect(job.userId, _userId);
      expect(job.recipeId, 'sofa');
      expect(job.progressSeconds, 0);
    });

    test('throws StateError when user already has active job', () async {
      await engine.startJob(_userId, 'sofa');
      await expectLater(engine.startJob(_userId, 'sofa'), throwsStateError);
    });

    test('throws ArgumentError for unknown recipe', () async {
      await expectLater(
        engine.startJob(_userId, 'unknown-recipe'),
        throwsArgumentError,
      );
    });

    test('persists job in repository', () async {
      final job = await engine.startJob(_userId, 'sofa');
      final persisted = await repo.findJobById(job.id);
      expect(persisted, isNotNull);
      expect(persisted!.id, job.id);
    });
  });

  group('CraftEngine — accumulateProgress', () {
    test('increments progressSeconds correctly', () async {
      await engine.startJob(_userId, 'sofa');
      final updated = await engine.accumulateProgress(_userId, 600); // 10 min
      expect(updated, isNotNull);
      expect(updated!.progressSeconds, 600);
    });

    test('does not change status before threshold', () async {
      await engine.startJob(_userId, 'sofa');
      final updated = await engine.accumulateProgress(_userId, 900); // 15 min
      expect(updated!.status, CraftJobStatus.inProgress);
    });

    test('marks completed and writes InventoryItem when threshold reached',
        () async {
      await engine.startJob(_userId, 'sofa');
      // 30 min = 1800 seconds
      final updated = await engine.accumulateProgress(_userId, 1800);
      expect(updated!.status, CraftJobStatus.completed);
      final item = await repo.findInventoryItem(_userId, 'sofa');
      expect(item, isNotNull);
      expect(item!.quantity, 1);
    });

    test('accumulating past threshold also completes job', () async {
      await engine.startJob(_userId, 'sofa');
      final updated = await engine.accumulateProgress(_userId, 9999);
      expect(updated!.status, CraftJobStatus.completed);
    });

    test('increments existing inventory quantity on second completion',
        () async {
      // First job
      await engine.startJob(_userId, 'sofa');
      await engine.accumulateProgress(_userId, 1800);
      // Second job (active job completed, can start new one)
      await engine.startJob(_userId, 'sofa');
      await engine.accumulateProgress(_userId, 1800);
      final item = await repo.findInventoryItem(_userId, 'sofa');
      expect(item!.quantity, 2);
    });

    test('returns null when no active job exists', () async {
      final result = await engine.accumulateProgress(_userId, 600);
      expect(result, isNull);
    });
  });

  group('CraftEngine — cancelActiveJob', () {
    test('sets active job status to cancelled', () async {
      final job = await engine.startJob(_userId, 'sofa');
      await engine.cancelActiveJob(_userId);
      final persisted = await repo.findJobById(job.id);
      expect(persisted!.status, CraftJobStatus.cancelled);
    });

    test('after cancel, a new job can be started', () async {
      await engine.startJob(_userId, 'sofa');
      await engine.cancelActiveJob(_userId);
      final newJob = await engine.startJob(_userId, 'sofa');
      expect(newJob.status, CraftJobStatus.inProgress);
    });

    test('does nothing when no active job', () async {
      // Should not throw
      await engine.cancelActiveJob(_userId);
    });
  });

  group('CraftEngine — cancelJob by id', () {
    test('cancels specific job by id', () async {
      final job = await engine.startJob(_userId, 'sofa');
      await engine.cancelJob(job.id);
      final persisted = await repo.findJobById(job.id);
      expect(persisted!.status, CraftJobStatus.cancelled);
    });

    test('does nothing for unknown job id', () async {
      await engine.cancelJob('nonexistent-id');
    });
  });

  group('CraftEngine — getActiveCraftJob', () {
    test('returns null when no active job', () async {
      final result = await engine.getActiveCraftJob(_userId);
      expect(result, isNull);
    });

    test('returns job and recipe when active', () async {
      await engine.startJob(_userId, 'sofa');
      final result = await engine.getActiveCraftJob(_userId);
      expect(result, isNotNull);
      expect(result!.job.recipeId, 'sofa');
      expect(result.recipe.id, 'sofa');
    });

    test('returns null after job is cancelled', () async {
      await engine.startJob(_userId, 'sofa');
      await engine.cancelActiveJob(_userId);
      final result = await engine.getActiveCraftJob(_userId);
      expect(result, isNull);
    });

    test('returns null after job is completed', () async {
      await engine.startJob(_userId, 'sofa');
      await engine.accumulateProgress(_userId, 1800);
      final result = await engine.getActiveCraftJob(_userId);
      expect(result, isNull);
    });
  });

  group('CraftEngine — no fake progress', () {
    test('progressSeconds starts at 0, not a hardcoded positive value',
        () async {
      final job = await engine.startJob(_userId, 'sofa');
      expect(job.progressSeconds, 0,
          reason: 'Job must start with zero progress, not fake data');
    });

    test('progress bar value is 0.0 at start', () async {
      final job = await engine.startJob(_userId, 'sofa');
      final recipe = _recipe();
      final progress = recipe.requiredSeconds > 0
          ? (job.progressSeconds / recipe.requiredSeconds).clamp(0.0, 1.0)
          : 0.0;
      expect(progress, 0.0);
    });

    test('cancelled job does not add inventory item', () async {
      await engine.startJob(_userId, 'sofa');
      await engine.cancelActiveJob(_userId);
      final item = await repo.findInventoryItem(_userId, 'sofa');
      expect(item, isNull, reason: 'Cancelling must not write inventory items');
    });

    test('partial progress does not complete job', () async {
      await engine.startJob(_userId, 'sofa');
      await engine.accumulateProgress(_userId, 1799); // 1 second short
      final item = await repo.findInventoryItem(_userId, 'sofa');
      expect(item, isNull,
          reason: 'Inventory must only be created on job completion');
    });
  });
}
