/// Debug-only QA fixture harness.
///
/// ## Why this exists
///
/// The P17 walk verification needed a room with two anchors, and the only way to
/// reach that state was editing the SQLite file by hand. That went wrong in three
/// separate ways — the WAL sidecar was left behind, the file was replaced while
/// its journals existed, and `adb shell "cat >"` truncated it — and each failure
/// looked identical from the outside ("the app lost its data"). None of them were
/// product defects; all of them were fixture defects.
///
/// This replaces that with seeding through the **same repositories the app
/// uses**, so a fixture cannot produce a state the app itself could not.
///
/// ## It is not reachable from the shipping build
///
/// Nothing under `lib/` outside `lib/dev/` imports this file, and the release
/// entry point is `lib/main.dart`. The fixture entry point is
/// `lib/dev/qa_fixture_main.dart`, which is only reachable with
/// `flutter run -t lib/dev/qa_fixture_main.dart`. `qa_fixture_guard_test.dart`
/// fails if that stops being true, and [QaFixtureHarness.seed] refuses to run
/// outside a debug build as a second line of defence.
///
/// ## It is QA infrastructure, not product behaviour
///
/// No product code path calls into this. It adds no route, no button and no
/// visible affordance to the shipping UI.
library;

import 'package:flutter/foundation.dart';

import '../core/auth/current_user.dart';
import '../data/local/app_database.dart';
import '../domain/growth/growth_level_curve.dart';
import '../domain/models/craft_models.dart' as domain;
import '../domain/models/enums.dart';
import '../domain/models/pet_models.dart' as domain;
import '../domain/repositories/i_craft_repository.dart';
import '../domain/repositories/i_pet_repository.dart';
import '../domain/services/focus_clock.dart';
import '../presentation/companion/room/furniture_catalog.dart';
import '../presentation/companion/room/furniture_entity.dart';

/// The states a QA run can be put into.
///
/// Deliberately a closed set rather than a generic database editor: a fixture
/// that can write anything can write a state the app could never reach, which is
/// the thing this harness exists to prevent.
enum QaScenario {
  /// The pet row onboarding would have created, and nothing else.
  basePet('base_pet'),

  /// A room with two anchors, so the companion has somewhere to travel to.
  /// This is the P17 walk fixture.
  roomTwoAnchors('room_two_anchors'),

  /// Every item in the furniture catalog owned and placed.
  allFurnitureOwned('all_furniture_owned'),

  /// Happiness at its maximum, as the growth page reads it.
  highMood('high_mood'),

  /// A high level, with the XP derived from the level curve rather than chosen.
  lateGrowth('late_growth'),

  /// A craft job in progress.
  craftActive('craft_active'),

  /// Memories present, so the growth page has something to show.
  memoryReady('memory_ready');

  /// The name used on the command line (`--dart-define=QA_SCENARIO=...`).
  final String id;
  const QaScenario(this.id);

  /// Parses a scenario name, or `null` when it is not one.
  static QaScenario? fromId(String? id) {
    for (final s in QaScenario.values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// What a seed run did, so a caller can print it rather than guess.
class QaSeedReport {
  final QaScenario scenario;
  final List<String> steps;
  final Map<String, int> counts;

  const QaSeedReport({
    required this.scenario,
    required this.steps,
    required this.counts,
  });

  @override
  String toString() =>
      'QaSeedReport(${scenario.id}: ${steps.join(', ')}; $counts)';
}

/// What a reset run removed.
class QaResetReport {
  final int roomItems;
  final int inventoryRowsRevoked;
  final int memories;

  const QaResetReport({
    required this.roomItems,
    required this.inventoryRowsRevoked,
    required this.memories,
  });

  int get total => roomItems + inventoryRowsRevoked + memories;

  @override
  String toString() => 'QaResetReport(room $roomItems, inventory '
      '$inventoryRowsRevoked, memories $memories)';
}

/// Seeds predefined QA states through the app's own repositories.
class QaFixtureHarness {
  /// Every id this harness creates starts with this.
  ///
  /// It is the whole isolation mechanism. [reset] deletes only rows carrying it,
  /// so a QA run cannot remove state it did not create — which is what makes
  /// "reset the QA state" safe to offer at all.
  static const String idPrefix = 'qa_';

  /// The pet and progress ids production uses.
  ///
  /// Copied deliberately from `HomeController`'s adoption path rather than
  /// invented: a fixture pet with a different id would be a *second* pet, and
  /// every assertion made against it would be about a companion the app never
  /// shows.
  static const String petId = 'mochi_pet_id';
  static const String progressId = 'mochi_progress_id';

  final IPetRepository pets;
  final ICraftRepository craft;
  final AppDatabase db;
  final FocusClock clock;
  final String userId;

  QaFixtureHarness({
    required this.pets,
    required this.craft,
    required this.db,
    required this.clock,
    this.userId = localMvpUserId,
  });

  DateTime get _now => clock.now();

  /// Seeds [scenario]. Running it twice leaves the same state, not twice of it.
  Future<QaSeedReport> seed(QaScenario scenario) async {
    if (!kDebugMode) {
      throw StateError(
        'QaFixtureHarness is debug-only. A release build must not be able to '
        'seed fixture state; if this threw, something reachable from '
        'lib/main.dart is importing lib/dev/.',
      );
    }
    final steps = <String>[];

    // Every scenario starts from the base pet, because a room with no companion
    // is not a state the app can present.
    await _ensureBasePet();
    steps.add('base_pet');

    switch (scenario) {
      case QaScenario.basePet:
        break;
      case QaScenario.roomTwoAnchors:
        await _own(FurnitureCatalog.entities['rug']!);
        await _own(FurnitureCatalog.entities['sofa']!);
        steps.add('two_anchors');
      case QaScenario.allFurnitureOwned:
        for (final entity in FurnitureCatalog.entities.values) {
          await _own(entity);
        }
        steps.add('all_furniture');
      case QaScenario.highMood:
        await _writeProgress(happiness: 100);
        steps.add('happiness_100');
      case QaScenario.lateGrowth:
        // The XP comes from the curve, not from a number typed here: if the
        // curve changes, the fixture follows instead of drifting into a level
        // the app would never report.
        await _writeProgress(xp: GrowthLevelCurve.xpForLevel(20));
        steps.add('level_${GrowthLevelCurve.levelForXp(
          GrowthLevelCurve.xpForLevel(20),
        )}');
      case QaScenario.craftActive:
        final recipes = await craft.findAllRecipes();
        if (recipes.isEmpty) {
          throw StateError('no craft recipes are seeded; cannot start a job');
        }
        // `startJobIfNoneActive` refuses when one is already running, which is
        // what makes this idempotent rather than additive.
        await craft.startJobIfNoneActive(
          userId,
          domain.CraftJob(
            id: '${idPrefix}craft_job',
            userId: userId,
            recipeId: recipes.first.id,
            status: CraftJobStatus.inProgress,
            progressSeconds: 0,
            startedAt: _now,
            rewardClaimed: false,
          ),
        );
        steps.add('craft_job_${recipes.first.id}');
      case QaScenario.memoryReady:
        await _addMemoryOnce('${idPrefix}mem_first',
            domain.PetMemoryType.firstFocus, '第一次和你一起专注');
        await _addMemoryOnce(
            '${idPrefix}mem_level', domain.PetMemoryType.levelUp, '成长到 Lv.2');
        steps.add('memories');
    }

    return QaSeedReport(
      scenario: scenario,
      steps: steps,
      counts: await _counts(),
    );
  }

  /// Removes only the rows this harness created.
  ///
  /// Inventory is *revoked* rather than deleted: ownership is `quantity > 0` in
  /// the app's own rule (`RoomSimulationController._unlockedItemIds`), so zeroing
  /// the quantity takes the item away through the same contract the app reads.
  /// There is no delete for inventory rows in the repository, and inventing one
  /// to satisfy a fixture would be a production change for a QA need.
  Future<QaResetReport> reset() async {
    var roomItems = 0;
    for (final item in await craft.findRoomItems(userId)) {
      if (item.id.startsWith(idPrefix)) {
        await craft.removeRoomItem(item.id);
        roomItems++;
      }
    }

    var revoked = 0;
    for (final item in await craft.findInventory(userId)) {
      if (item.id.startsWith(idPrefix) && item.quantity > 0) {
        await craft.upsertInventoryItem(domain.InventoryItem(
          id: item.id,
          userId: item.userId,
          itemId: item.itemId,
          quantity: 0,
          updatedAt: _now,
        ));
        revoked++;
      }
    }

    final memories = await db.petDao.deleteMemoriesWithIdPrefix(idPrefix);
    return QaResetReport(
      roomItems: roomItems,
      inventoryRowsRevoked: revoked,
      memories: memories,
    );
  }

  // ── primitives ─────────────────────────────────────────────────────────────

  /// The adoption `HomeController` performs, with the same ids and defaults.
  Future<void> _ensureBasePet() async {
    final existing = await pets.findPetByUser(userId);
    if (existing == null) {
      await pets.savePet(domain.Pet(
        id: petId,
        userId: userId,
        species: PetSpecies.dog,
        characterId: 'mochi',
        name: 'Mochi',
        adoptedAt: _now,
      ));
    }
    if (await pets.findPetProgress(petId) == null) {
      await pets.savePetProgress(domain.PetProgress(
        id: progressId,
        petId: petId,
        level: GrowthLevelCurve.minLevel,
        experiencePoints: 0,
        totalFocusMinutes: 0,
        happinessScore: 100,
        updatedAt: _now,
      ));
    }
  }

  /// Writes progress, keeping whatever the scenario did not change.
  ///
  /// `level` is derived from the XP rather than passed in, because the read path
  /// derives it too (`PetDao._mapProgress`) — storing a level the XP does not
  /// earn would create a row that contradicts itself.
  Future<void> _writeProgress({int? xp, int? happiness}) async {
    final current = await pets.findPetProgress(petId);
    if (current == null) {
      throw StateError('base pet missing; _ensureBasePet must run first');
    }
    final newXp = xp ?? current.experiencePoints;
    await pets.savePetProgress(domain.PetProgress(
      id: current.id,
      petId: current.petId,
      level: GrowthLevelCurve.levelForXp(newXp),
      experiencePoints: newXp,
      totalFocusMinutes: current.totalFocusMinutes,
      happinessScore: happiness ?? current.happinessScore,
      updatedAt: _now,
    ));
  }

  /// Owns [entity] and places it, through the repository's upserts.
  ///
  /// Positions are a fixed grid derived from the index in the catalog, so the
  /// same scenario always produces the same room and two runs cannot stack two
  /// items on one spot.
  ///
  /// Both steps check first, and that is not defensive padding.
  /// `inventory_items` is unique on `(user_id, item_id)`, so a second row for an
  /// item the player already owns is a **constraint violation** rather than a
  /// harmless duplicate — this fixture hit `UNIQUE constraint failed:
  /// inventory_items.user_id, inventory_items.item_id` the first time it was
  /// pointed at a database with a sofa already in it. Leaving an existing row
  /// alone is also what keeps the QA prefix meaningful: the fixture never takes
  /// over a real item, so `reset` never revokes one.
  Future<void> _own(FurnitureEntity entity) async {
    final index = FurnitureCatalog.entities.keys.toList().indexOf(entity.id);

    final owned = await craft.findInventoryItem(userId, entity.id);
    if (owned == null || owned.quantity <= 0) {
      await craft.upsertInventoryItem(domain.InventoryItem(
        id: '${idPrefix}inv_${entity.id}',
        userId: userId,
        itemId: entity.id,
        quantity: 1,
        updatedAt: _now,
      ));
    }

    final placed = await craft.findRoomItems(userId);
    if (placed.any((r) => r.itemId == entity.id)) return;
    await craft.placeRoomItem(domain.RoomItem(
      id: '${idPrefix}room_${entity.id}',
      userId: userId,
      itemId: entity.id,
      positionX: 0.18 + 0.14 * index,
      positionY: 0.62,
      scale: 1.0,
      zIndex: index,
      isVisible: true,
      placedAt: _now,
    ));
  }

  /// Adds a memory unless one with this id already exists.
  ///
  /// `IPetRepository.addMemory` is a plain insert, not an upsert, so a second
  /// seed run would throw on the primary key. Checking first is what makes
  /// MEMORY_READY idempotent.
  Future<void> _addMemoryOnce(String id, String type, String content) async {
    final existing = await pets.findMemories(petId, limit: 200);
    if (existing.any((m) => m.id == id)) return;
    await pets.addMemory(domain.PetMemory(
      id: id,
      petId: petId,
      memoryType: type,
      content: content,
      happenedAt: _now,
    ));
  }

  Future<Map<String, int>> _counts() async {
    final inventory = await craft.findInventory(userId);
    final room = await craft.findRoomItems(userId);
    final memories = await pets.findMemories(petId, limit: 200);
    return {
      'inventory_owned': inventory.where((i) => i.quantity > 0).length,
      'room_items': room.length,
      'memories': memories.length,
    };
  }
}
