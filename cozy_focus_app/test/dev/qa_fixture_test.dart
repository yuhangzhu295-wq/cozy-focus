import 'dart:io';

import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/dev/qa_fixture.dart';
import 'package:cozy_focus_app/domain/growth/growth_level_curve.dart';
import 'package:cozy_focus_app/domain/models/craft_models.dart' as domain;
import 'package:cozy_focus_app/domain/models/pet_models.dart' as domain;
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_catalog.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Clock implements FocusClock {
  final DateTime _now;
  _Clock(this._now);
  @override
  DateTime now() => _now;
}

/// The QA fixture harness, and the three claims the brief asks to be proven:
/// it does not touch production code paths, a release build cannot reach it,
/// and running it twice does not duplicate business truth.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late QaFixtureHarness harness;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider.overrideWithValue(_Clock(DateTime(2026, 10, 3, 12))),
      ],
    );
    harness = QaFixtureHarness(
      pets: container.read(petRepositoryProvider),
      craft: container.read(craftRepositoryProvider),
      db: db,
      clock: container.read(focusClockProvider),
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('release cannot reach the fixture', () {
    test('nothing outside lib/dev/ references the harness', () {
      // The load-bearing guard. The fixture is only safe while the shipping tree
      // cannot see it, and "we did not import it" is not a property that stays
      // true on its own — the next person to want a seeded state will reach for
      // it from a page. This is what stops that.
      final offenders = <String>[];

      final lib = Directory('lib');
      expect(lib.existsSync(), isTrue,
          reason: 'lib/ must exist for this guard to mean anything');

      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // The fixture's own directory is the one place it is allowed.
        if (entity.path.replaceAll(r'\', '/').startsWith('lib/dev/')) continue;
        // Reachability, not mentions. Dart cannot use a type without importing
        // it, so scanning import/export directives is complete — and unlike a
        // token scan it does not fire on a doc comment that merely names the
        // fixture, which is what `PetDao.deleteMemoriesWithIdPrefix` carries
        // when it explains why it exists.
        for (final line in entity.readAsLinesSync()) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('import ') &&
              !trimmed.startsWith('export ')) {
            continue;
          }
          if (trimmed.contains('dev/qa_fixture')) {
            offenders.add('${entity.path}: $trimmed');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'the QA fixture must not be reachable from the shipping '
              'build; the release entry point is lib/main.dart:\n'
              '${offenders.join('\n')}');
    });

    test('the shipping entry point does not import the fixture', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main.contains('dev/'), isFalse,
          reason: 'lib/main.dart must not pull in lib/dev/');
    });
  });

  group('scenarios seed the state they claim', () {
    test('base_pet mirrors the production adoption, not a second pet',
        () async {
      await harness.seed(QaScenario.basePet);
      final pet = await db.petDao.findPetByUser('default_user');
      expect(pet, isNotNull);
      // The same ids HomeController writes, so the app shows THIS companion
      // rather than a parallel one nobody can see.
      expect(pet!.id, QaFixtureHarness.petId);
      final progress = await db.petDao.findProgress(pet.id);
      expect(progress!.id, QaFixtureHarness.progressId);
    });

    test('room_two_anchors places two catalog items', () async {
      final report = await harness.seed(QaScenario.roomTwoAnchors);
      expect(report.counts['room_items'], 2);
      expect(report.counts['inventory_owned'], 2);
    });

    test('all_furniture_owned uses the catalog as the source of truth',
        () async {
      // Not a hard-coded list: if a piece of furniture is added to the catalog
      // the fixture follows, which is what "do not duplicate the definitions"
      // means in practice.
      final report = await harness.seed(QaScenario.allFurnitureOwned);
      expect(
          report.counts['inventory_owned'], FurnitureCatalog.entities.length);
      expect(report.counts['room_items'], FurnitureCatalog.entities.length);
    });

    test('late_growth derives the level from the curve', () async {
      await harness.seed(QaScenario.lateGrowth);
      final progress = await db.petDao.findProgress(QaFixtureHarness.petId);
      final xp = GrowthLevelCurve.xpForLevel(20);
      expect(progress!.experiencePoints, xp);
      // The stored level must agree with the XP, or the row contradicts itself.
      expect(progress.level, GrowthLevelCurve.levelForXp(xp));
    });

    test('high_mood writes happiness where the app reads it', () async {
      await harness.seed(QaScenario.highMood);
      final progress = await db.petDao.findProgress(QaFixtureHarness.petId);
      expect(progress!.happinessScore, 100);
    });

    test('craft_active starts a job from a real recipe', () async {
      await harness.seed(QaScenario.craftActive);
      final job = await db.craftDao.findActiveJobByUser('default_user');
      expect(job, isNotNull);
      final recipes = await db.craftDao.findAllRecipes();
      expect(recipes.map((r) => r.id), contains(job!.recipeId));
    });

    test('memory_ready writes memories the growth page can read', () async {
      await harness.seed(QaScenario.memoryReady);
      final memories = await db.petDao.findMemories(QaFixtureHarness.petId);
      expect(memories, hasLength(2));
      expect(memories.map((m) => m.id),
          everyElement(startsWith(QaFixtureHarness.idPrefix)));
    });
  });

  group('idempotency', () {
    // The brief's list: no duplicate pet, inventory row, memory, settlement or
    // ledger entry. Every scenario is run twice and the business truth counted.
    for (final scenario in QaScenario.values) {
      test('${scenario.id} seeded twice is the same state', () async {
        final first = await harness.seed(scenario);
        final second = await harness.seed(scenario);

        expect(second.counts, first.counts,
            reason: 'a second seed must not add anything');

        // And the counts are checked against the database, not just each other.
        expect((await db.petDao.findPetByUser('default_user')), isNotNull);
        expect(
          (await db.petDao.findMemories(QaFixtureHarness.petId))
              .where((m) => m.id.startsWith(QaFixtureHarness.idPrefix))
              .map((m) => m.id)
              .toSet()
              .length,
          (await db.petDao.findMemories(QaFixtureHarness.petId))
              .where((m) => m.id.startsWith(QaFixtureHarness.idPrefix))
              .length,
          reason: 'memory ids must be unique, not appended',
        );
        final owned = (await db.craftDao.findInventory('default_user'))
            .where((i) => i.quantity > 0)
            .map((i) => i.itemId)
            .toList();
        expect(owned.toSet().length, owned.length,
            reason: 'no item may be owned twice');
      });
    }

    test('the pet is never duplicated', () async {
      await harness.seed(QaScenario.basePet);
      await harness.seed(QaScenario.basePet);
      final pets = await db.petDao.findPetByUser('default_user');
      expect(pets, isNotNull);
      // A second pet row would be a second companion; the table is keyed by id
      // and the harness reuses the production id, so this cannot happen.
      final all =
          await db.customSelect('select count(*) as n from pets').getSingle();
      expect(all.data['n'], 1);
    });
  });

  group('reset removes only what the fixture created', () {
    test('reset clears QA rows', () async {
      await harness.seed(QaScenario.roomTwoAnchors);
      final report = await harness.reset();
      expect(report.total, greaterThan(0));
      expect(await db.craftDao.findRoomItems('default_user'), isEmpty);
      expect(
        (await db.craftDao.findInventory('default_user'))
            .where((i) => i.quantity > 0),
        isEmpty,
      );
    });

    test('reset does not delete state the fixture did not create', () async {
      // The property that makes a reset safe to offer at all. A real memory and
      // a real owned item are written first, exactly as settlement would, and
      // must survive.
      await db.petDao.addMemory(domain.PetMemory(
        id: 'mem_mochi_pet_id_first_focus_1',
        petId: QaFixtureHarness.petId,
        memoryType: domain.PetMemoryType.firstFocus,
        content: '第一次和你一起专注',
        happenedAt: DateTime(2026, 10, 1),
      ));
      await db.craftDao.upsertInventoryItem(domain.InventoryItem(
        id: 'inv_real_sofa',
        userId: 'default_user',
        itemId: 'sofa',
        quantity: 1,
        updatedAt: DateTime(2026, 10, 1),
      ));
      await db.craftDao.upsertRoomItem(domain.RoomItem(
        id: 'room_real_sofa',
        userId: 'default_user',
        itemId: 'sofa',
        positionX: 0.5,
        positionY: 0.5,
        scale: 1.0,
        zIndex: 1,
        isVisible: true,
        placedAt: DateTime(2026, 10, 1),
      ));

      await harness.seed(QaScenario.roomTwoAnchors);
      await harness.reset();

      final memories = await db.petDao.findMemories(QaFixtureHarness.petId);
      expect(
          memories.map((m) => m.id), contains('mem_mochi_pet_id_first_focus_1'),
          reason: 'a production memory must survive a QA reset');

      final owned = (await db.craftDao.findInventory('default_user'))
          .where((i) => i.quantity > 0)
          .toList();
      expect(owned.map((i) => i.itemId), contains('sofa'),
          reason: 'a production item must survive a QA reset');

      final room = await db.craftDao.findRoomItems('default_user');
      expect(room.map((i) => i.id), contains('room_real_sofa'),
          reason: 'a production placement must survive a QA reset');
    });

    test('the QA prefix cannot collide with a production id', () {
      // The reset is only safe because production ids never start with it.
      // `CompanionMemory._idFor` produces `mem_<pet>_<type>_<ts>`.
      expect(QaFixtureHarness.idPrefix, 'qa_');
      expect(
          'mem_mochi_pet_id_first_focus_1'
              .startsWith(QaFixtureHarness.idPrefix),
          isFalse);
      expect('mochi_pet_id'.startsWith(QaFixtureHarness.idPrefix), isFalse);
    });
  });

  group('the fixture cannot invent a state the app could not reach', () {
    test('an unknown scenario name is rejected rather than defaulted', () {
      expect(QaScenario.fromId('not_a_scenario'), isNull);
      expect(QaScenario.fromId(null), isNull);
      expect(QaScenario.fromId('room_two_anchors'), QaScenario.roomTwoAnchors);
    });

    test('every scenario is reachable by its documented id', () {
      for (final s in QaScenario.values) {
        expect(QaScenario.fromId(s.id), s);
      }
    });
  });
}
