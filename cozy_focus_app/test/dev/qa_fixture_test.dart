import 'dart:io';

import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/data/repositories/drift_pet_repository.dart';
import 'package:cozy_focus_app/dev/qa_fixture.dart';
import 'package:cozy_focus_app/domain/growth/growth_level_curve.dart';
import 'package:cozy_focus_app/domain/models/craft_models.dart' as domain;
import 'package:cozy_focus_app/domain/models/enums.dart' show PetSpecies;
import 'package:cozy_focus_app/domain/models/pet_models.dart' as domain;
import 'package:cozy_focus_app/domain/models/sync_models.dart' as m;
import 'package:cozy_focus_app/domain/services/companion_memory.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_catalog.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:drift/drift.dart' show Variable;
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
      tasks: container.read(taskRepositoryProvider),
      sessions: container.read(focusSessionRepositoryProvider),
      records: container.read(focusRecordRepositoryProvider),
      notes: container.read(distractionRepositoryProvider),
      ledger: container.read(rewardLedgerRepositoryProvider),
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

  group('demo_day is a week the app can actually present', () {
    test('the timeline is causally possible', () async {
      await harness.seed(QaScenario.demoDay);

      // A task may not be completed before the focus that was about it, and no
      // focus may predate the task that caused it. Both are display bugs the
      // user reads as "the app is lying about when I did things".
      final rows = await db
          .customSelect(
            "select t.id as task_id, t.created_at as created, "
            "t.completed_at as completed, "
            "min(s.start_at) as first_focus, max(s.end_at) as last_focus "
            "from tasks t left join focus_sessions s "
            "  on s.task_id = t.id and s.user_id = t.user_id "
            "where t.id like 'qa_demo_task_%' "
            "group by t.id",
          )
          .get();
      expect(rows, isNotEmpty);
      for (final row in rows) {
        final created = row.data['created'] as int;
        final firstFocus = row.data['first_focus'] as int?;
        if (firstFocus != null) {
          expect(firstFocus, greaterThanOrEqualTo(created),
              reason: '${row.data['task_id']} was focused before it existed');
        }
        final completed = row.data['completed'] as int?;
        if (completed != null) {
          if (firstFocus != null) {
            expect(completed, greaterThanOrEqualTo(firstFocus),
                reason: '${row.data['task_id']} was completed before the focus '
                    'that completed it');
          } else {
            // No focus at all: the task still may not be completed before it
            // existed. Asserted separately so "no focus" is not a free pass.
            expect(completed, greaterThanOrEqualTo(created),
                reason: '${row.data['task_id']} was completed before it was '
                    'created');
          }
        }
      }
    });

    test('settlement alone writes the memory a settled session earns',
        () async {
      await harness.seed(QaScenario.demoDay);

      // The memory rule lives in settlement, not in the fixture. A fixture that
      // wrote ledger rows and XP by hand produced seven settled sessions with no
      // memory at all — a state the app cannot reach. This asserts the fixture
      // produced the memories the reward rule requires instead.
      final memories = await db.petDao.findMemories(QaFixtureHarness.petId);
      final contents = memories.map((m) => m.content).toList();

      // 第一次和你一起专注 — the first settled session of the week.
      expect(contents, contains('第一次和你一起专注'));
      // Growing from 0 XP into the 300-400 XP band crosses at least one level
      // boundary, so a level-up memory must exist.
      expect(contents.any((c) => c.startsWith('成长到 Lv.')), isTrue);
      // Two sessions are 50 minutes. Both are at the long-session threshold, so
      // both must leave a memory. Settling all seven at one fixed instant gave
      // them the same (pet, type, timestamp) id and the second was silently
      // dropped by INSERT OR IGNORE — a seed that looked complete and was one
      // memory short.
      expect(
        contents.where((c) => c.startsWith('陪你专注了 ')).toList(),
        ['陪你专注了 50 分钟', '陪你专注了 50 分钟'],
        reason: 'each long session must leave its own memory',
      );

      // The memories must also be in the order the sessions happened. Settling
      // the list as written (today first) gave the first-focus memory to today's
      // session and wrote level-ups backwards: the pet remembered its newest
      // session as its first, and reached Lv.2 before Lv.13.
      final byMoment = [...memories]
        ..sort((a, b) => a.happenedAt.compareTo(b.happenedAt));
      expect(byMoment.first.memoryType, 'first_focus',
          reason: 'the oldest settlement is the first focus');
      final levelUps = byMoment
          .where((m) => m.memoryType == 'level_up')
          .map((m) => m.content)
          .toList();
      expect(levelUps, isNotEmpty);
      final levels = levelUps
          .map((c) => int.parse(c.replaceAll(RegExp(r'[^0-9]'), '')))
          .toList();
      expect(levels, orderedEquals([...levels]..sort()),
          reason: 'levels must rise with time, not arrive out of order: '
              '$levels');
      // These ids are production-shaped (`mem_<pet>_<type>_<timestamp>`) because
      // settlement generated them. That is the point: a fixture-invented id would
      // prove the fixture wrote the memory, not the reward rule.
      expect(memories.every((m) => m.id.startsWith('mem_')), isTrue,
          reason: 'a settlement-generated memory must carry its production id');
    });

    test('reset removes the memories settlement wrote, and only those',
        () async {
      await harness.seed(QaScenario.demoDay);
      final memories = await db.petDao.findMemories(QaFixtureHarness.petId);
      expect(memories, isNotEmpty);

      // A memory that predates the QA run, so this can show up a reset that
      // removes everything it does not recognise.
      await db.petDao.addMemory(domain.PetMemory(
        id: 'mem_keep_me',
        petId: QaFixtureHarness.petId,
        memoryType: 'firstFocus',
        content: '这条不是 QA 产生的',
        happenedAt: DateTime(2020, 1, 1),
      ));

      await harness.reset();

      final after = await db.petDao.findMemories(QaFixtureHarness.petId);
      expect(after.map((m) => m.id), ['mem_keep_me'],
          reason: 'reset must remove exactly what the fixture caused');
    });

    test('reset undoes the whole demo week, and a re-seed rebuilds it',
        () async {
      await harness.seed(QaScenario.demoDay);
      final afterFirst = await db.petDao.findProgress(QaFixtureHarness.petId);
      expect(afterFirst!.experiencePoints, greaterThan(0));
      expect(await db.petDao.findMemories(QaFixtureHarness.petId), isNotEmpty);

      await harness.reset();

      // The sessions, records and ledger rows are what a re-seed skips, so if
      // they survive, the second seed does not re-run and the memories are never
      // rebuilt. A pet that earned a week and remembers none of it is the exact
      // bug this asserts is gone.
      final left = await db
          .customSelect(
            "select "
            "(select count(*) from focus_sessions where id like 'qa_demo_sess_%') s, "
            "(select count(*) from focus_records where session_id like "
            "'qa_demo_sess_%') r, "
            "(select count(*) from reward_ledger where session_id like "
            "'qa_demo_sess_%') l",
          )
          .getSingle();
      expect(left.data['s'], 0, reason: 'demo sessions must not outlive reset');
      expect(left.data['r'], 0, reason: 'demo records must not outlive reset');
      expect(left.data['l'], 0,
          reason: 'demo ledger rows must not outlive reset');

      await harness.seed(QaScenario.demoDay);
      final afterSecond = await db.petDao.findProgress(QaFixtureHarness.petId);
      expect(afterSecond!.experiencePoints, afterFirst.experiencePoints,
          reason: 'the week must come back exactly once, not twice');
      expect(await db.petDao.findMemories(QaFixtureHarness.petId), isNotEmpty,
          reason: 'the memories settlement earns must be rebuilt');
    });

    test('reset removes memories of both shapes, never an either/or', () async {
      // demo_day leaves settlement-generated memories (production ids);
      // memory_ready leaves qa_-prefixed ones. A reset that only ran one of the
      // two cleanups left the other kind behind.
      await harness.seed(QaScenario.demoDay);
      await harness.seed(QaScenario.memoryReady);
      await db.petDao.addMemory(domain.PetMemory(
        id: 'mem_keep_me',
        petId: QaFixtureHarness.petId,
        memoryType: 'firstFocus',
        content: '这条不是 QA 产生的',
        happenedAt: DateTime(2020, 1, 1),
      ));
      final before = await db.petDao.findMemories(QaFixtureHarness.petId);
      expect(before.length, greaterThan(3),
          reason: 'both kinds of memory should be present before reset');

      await harness.reset();

      final after = await db.petDao.findMemories(QaFixtureHarness.petId);
      expect(after.map((m) => m.id), ['mem_keep_me'],
          reason: 'both memory shapes must go, and nothing else');
    });

    for (final scenario in const [
      QaScenario.highMood,
      QaScenario.lateGrowth,
    ]) {
      test('${scenario.id} after demoDay cannot make the week count twice',
          () async {
        // The snapshot used to be taken when the overwriting scenario ran, which
        // is after demoDay had awarded the week. Reset then unwound the XP and
        // wrote the post-demo snapshot straight back, so the week survived and
        // the next demoDay awarded it again: 2550 XP / 510 minutes where one
        // week is 1275 / 255. Both overwriting scenarios are exercised, because
        // the bug is in the snapshot's timing, not in which field it overwrote.
        await harness.seed(QaScenario.demoDay);
        await harness.seed(scenario);
        await harness.reset();
        await harness.seed(QaScenario.demoDay);

        final progress = await db.petDao.findProgress(
          QaFixtureHarness.petId,
        );
        expect(progress!.experiencePoints, 1275,
            reason: '${scenario.id} after demoDay must not double the week');
        expect(progress.totalFocusMinutes, 255,
            reason: '${scenario.id} after demoDay must not double the minutes');
      });
    }

    test('reset keeps what a real session earned after the seed', () async {
      // The QA seed is not the only thing that writes progress. A user can
      // complete a real focus session between the seed and the reset; restoring
      // the pre-QA snapshot unconditionally would delete that session's XP while
      // leaving its ledger row and record in place.
      await harness.seed(QaScenario.demoDay);

      // The production settlement path, exactly as the app would run it.
      await db.settlementDao.settleAtomically(
        entry: m.RewardLedger(
          sessionId: 'real_sess_1',
          userId: 'default_user',
          focusCoinsEarned: 100,
          experienceEarned: 250,
          settledAt: DateTime(2026, 10, 18, 12),
        ),
        addedFocusSeconds: 50 * 60,
        now: DateTime(2026, 10, 18, 12),
      );
      final beforeReset = (await db.petDao.findProgress(
        QaFixtureHarness.petId,
      ))!;
      expect(beforeReset.experiencePoints, 1275 + 250);

      await harness.reset();

      final after = (await db.petDao.findProgress(QaFixtureHarness.petId))!;
      expect(after.experiencePoints, 250,
          reason: 'the demo week goes, the real session stays');
      expect(after.totalFocusMinutes, 50, reason: 'and so do its minutes');

      final realLedger = await db
          .customSelect(
            "select count(*) as c from reward_ledger "
            "where session_id = 'real_sess_1'",
          )
          .getSingle();
      expect(realLedger.read<int>('c'), 1,
          reason: 'the real ledger row must survive');
      final demoLedger = await db
          .customSelect(
            "select count(*) as c from reward_ledger "
            "where session_id like 'qa_demo_sess_%'",
          )
          .getSingle();
      expect(demoLedger.read<int>('c'), 0);
    });

    Future<void> settleReal(String id, int minutes, DateTime at) =>
        db.settlementDao.settleAtomically(
          entry: m.RewardLedger(
            sessionId: id,
            userId: 'default_user',
            focusCoinsEarned: minutes * 2,
            experienceEarned: minutes * 5,
            settledAt: at,
          ),
          addedFocusSeconds: minutes * 60,
          now: at,
        );

    test('a real session after the seed survives, then the week adds once',
        () async {
      await harness.seed(QaScenario.demoDay);
      await settleReal('real_a', 50, DateTime(2026, 10, 18, 12));

      await harness.reset();
      var progress = (await db.petDao.findProgress(QaFixtureHarness.petId))!;
      expect(progress.experiencePoints, 250);

      await harness.seed(QaScenario.demoDay);
      progress = (await db.petDao.findProgress(QaFixtureHarness.petId))!;
      expect(progress.experiencePoints, 250 + 1275,
          reason: 'the real session and exactly one demo week');
      expect(progress.totalFocusMinutes, 50 + 255);
    });

    test('a real session from before the seed is not counted twice', () async {
      // A pet the app already has, then a real session, then the QA seed. The
      // snapshot includes the session, so reset must not add it back on top of
      // itself. The pet is created the way the app creates it: settlement
      // before adoption would write a ledger row with no pet to award.
      await db.petDao.upsertPet(domain.Pet(
        id: QaFixtureHarness.petId,
        userId: 'default_user',
        species: PetSpecies.dog,
        characterId: 'mochi',
        name: 'Mochi',
        adoptedAt: DateTime(2026, 10, 1),
      ));
      await db.petDao.upsertProgress(domain.PetProgress(
        id: QaFixtureHarness.progressId,
        petId: QaFixtureHarness.petId,
        level: 1,
        experiencePoints: 0,
        totalFocusMinutes: 0,
        happinessScore: 100,
        updatedAt: DateTime(2026, 10, 1),
      ));
      await settleReal('real_b', 50, DateTime(2026, 10, 18, 9));
      await harness.seed(QaScenario.demoDay);

      await harness.reset();
      final progress = (await db.petDao.findProgress(QaFixtureHarness.petId))!;
      expect(progress.experiencePoints, 250,
          reason: 'the pre-seed session stays, once');
      expect(progress.totalFocusMinutes, 50);
    });

    test('two real sessions after the seed both survive', () async {
      await harness.seed(QaScenario.demoDay);
      await settleReal('real_c', 50, DateTime(2026, 10, 18, 12));
      await settleReal('real_d', 20, DateTime(2026, 10, 18, 13));

      await harness.reset();
      final progress = (await db.petDao.findProgress(QaFixtureHarness.petId))!;
      expect(progress.experiencePoints, 350);
      expect(progress.totalFocusMinutes, 70);
    });

    test('a real memory at a demo settlement moment is not deleted', () async {
      // The old reset derived three ids per demo moment and deleted them all.
      // If a real session had already created one of those ids, the demo
      // settlement created nothing of that type (INSERT OR IGNORE) and reset
      // still deleted the real memory. Only ids the fixture saw appear may go.
      await harness.seed(QaScenario.basePet);

      // The oldest demo session: today-5 days at 20:00 for 40 minutes. The
      // fixture's clock is fixed at 2026-10-03 12:00 in this file.
      final moment = DateTime(2026, 10, 3)
          .subtract(const Duration(days: 5))
          .add(const Duration(hours: 20, minutes: 40));
      final realId = CompanionMemory.idFor(
        QaFixtureHarness.petId,
        domain.PetMemoryType.firstFocus,
        moment,
      );
      await db.petDao.addMemory(domain.PetMemory(
        id: realId,
        petId: QaFixtureHarness.petId,
        memoryType: domain.PetMemoryType.firstFocus,
        content: '真实记忆，与演示结算同一时刻',
        happenedAt: moment,
      ));

      await harness.seed(QaScenario.demoDay);
      await harness.reset();

      final left = await db.petDao.findMemories(QaFixtureHarness.petId);
      expect(left.map((m) => m.id), contains(realId),
          reason: 'the fixture must not delete a memory it did not create');
    });

    test('reset puts a real craft job back and takes its item away', () async {
      await harness.seed(QaScenario.basePet);
      final recipe = await db
          .customSelect('select id, output_item_id from craft_recipes limit 1')
          .getSingle();
      final recipeId = recipe.read<String>('id');
      final itemId = recipe.read<String>('output_item_id');
      // Ten minutes, so the demo week's 255 minutes certainly finishes it. The
      // point is the rollback, not whether the seeded recipe happens to be
      // short enough.
      await db.customStatement(
        'update craft_recipes set required_minutes = 10 where id = ?',
        [recipeId],
      );
      await db.customStatement(
        'insert into craft_jobs (id, user_id, recipe_id, status, '
        'progress_seconds, started_at, reward_claimed) values '
        "('real_job', 'default_user', ?, 'inProgress', 0, 1790000000, 0)",
        [recipeId],
      );

      await harness.seed(QaScenario.demoDay);

      // The demo week's focus is far more than any recipe needs, so the real
      // job completes and its output lands in the inventory.
      final completed = (await db
              .customSelect(
                  "select status from craft_jobs where id = 'real_job'")
              .getSingle())
          .read<String>('status');
      expect(completed, 'completed',
          reason: 'the setup must actually complete the real job');

      await harness.reset();

      final job = await db
          .customSelect(
            "select status, progress_seconds from craft_jobs where id = 'real_job'",
          )
          .getSingle();
      expect(job.read<String>('status'), 'inProgress',
          reason: 'a real job must not be left completed by a QA seed');
      expect(job.read<int>('progress_seconds'), 0);
      final inv = (await db.customSelect(
        'select count(*) as c from inventory_items '
        'where user_id = ? and item_id = ?',
        variables: [
          Variable.withString('default_user'),
          Variable.withString(itemId),
        ],
      ).getSingle())
          .read<int>('c');
      expect(inv, 0,
          reason: 'the item the demo week granted must be taken back');
    });

    test('real craft progress made after the seed survives reset', () async {
      // The snapshot used to be an absolute state taken at the first seed. Real
      // focus completed between then and the reset was rolled back with the
      // demo week's own progress. Only the demo deltas may be removed.
      await harness.seed(QaScenario.basePet);
      final recipe = await db
          .customSelect('select id, output_item_id from craft_recipes limit 1')
          .getSingle();
      final recipeId = recipe.read<String>('id');
      final itemId = recipe.read<String>('output_item_id');
      await db.customStatement(
        'update craft_recipes set required_minutes = 10 where id = ?',
        [recipeId],
      );
      await db.customStatement(
        'insert into craft_jobs (id, user_id, recipe_id, status, '
        'progress_seconds, started_at, reward_claimed) values '
        "('real_job', 'default_user', ?, 'inProgress', 0, 1790000000, 0)",
        [recipeId],
      );

      // A real 5-minute session, after the first seed: 300 seconds of the job.
      await settleReal('real_e', 5, DateTime(2026, 10, 18, 11));
      var job = await db
          .customSelect(
            "select progress_seconds from craft_jobs where id = 'real_job'",
          )
          .getSingle();
      expect(job.read<int>('progress_seconds'), 300);

      await harness.seed(QaScenario.demoDay);
      await harness.reset();

      job = await db
          .customSelect(
            "select status, progress_seconds from craft_jobs where id = 'real_job'",
          )
          .getSingle();
      expect(job.read<int>('progress_seconds'), 300,
          reason: 'the demo week 15300 seconds go, the real 300 stay');
      expect(job.read<String>('status'), 'inProgress',
          reason: 'the completion was caused by the demo week');
      final inv = (await db.customSelect(
        'select count(*) as c from inventory_items '
        'where user_id = ? and item_id = ?',
        variables: [
          Variable.withString('default_user'),
          Variable.withString(itemId),
        ],
      ).getSingle())
          .read<int>('c');
      expect(inv, 0, reason: 'the item was granted by the demo completion');
    });

    test('reset does not reopen a job a real session completed', () async {
      // The demo week added part of the progress and recorded a delta; a real
      // session then finished the job. Reset must subtract the demo seconds but
      // leave the job completed — the completion was not the fixture's.
      await harness.seed(QaScenario.basePet);
      final recipe = await db
          .customSelect('select id, output_item_id from craft_recipes limit 1')
          .getSingle();
      final recipeId = recipe.read<String>('id');
      await db.customStatement(
        'update craft_recipes set required_minutes = 600 where id = ?',
        [recipeId],
      );
      await db.customStatement(
        'insert into craft_jobs (id, user_id, recipe_id, status, '
        'progress_seconds, started_at, reward_claimed) values '
        "('real_job', 'default_user', ?, 'inProgress', 0, 1790000000, 0)",
        [recipeId],
      );

      // 15300 seconds of demo focus: not enough for 36000.
      await harness.seed(QaScenario.demoDay);
      // 360 minutes of real focus finishes it (15300 + 21600 > 36000).
      await settleReal('real_f', 360, DateTime(2026, 10, 18, 13));
      var job = await db
          .customSelect(
            "select status, progress_seconds from craft_jobs where id = 'real_job'",
          )
          .getSingle();
      expect(job.read<String>('status'), 'completed');

      await harness.reset();

      job = await db
          .customSelect(
            "select status, progress_seconds from craft_jobs where id = 'real_job'",
          )
          .getSingle();
      expect(job.read<String>('status'), 'completed',
          reason: 'a real completion is not the fixture to undo');
      expect(job.read<int>('progress_seconds'), 21600,
          reason: '15300 demo seconds go, the real 21600 stay');
    });

    test('reset takes back one granted item, not the whole stack', () async {
      await harness.seed(QaScenario.basePet);
      // `table` is not one of the five items demoDay owns, so the row the
      // completion creates is not a qa_ row that reset removes outright.
      final recipe = await db
          .customSelect(
            "select id, output_item_id from craft_recipes where id = 'table'",
          )
          .getSingle();
      final recipeId = recipe.read<String>('id');
      final itemId = recipe.read<String>('output_item_id');
      await db.customStatement(
        'update craft_recipes set required_minutes = 10 where id = ?',
        [recipeId],
      );
      await db.customStatement(
        'insert into craft_jobs (id, user_id, recipe_id, status, '
        'progress_seconds, started_at, reward_claimed) values '
        "('real_job', 'default_user', ?, 'inProgress', 0, 1790000000, 0)",
        [recipeId],
      );
      await harness.seed(QaScenario.demoDay);

      // The user gains one more of the same item after the demo week.
      await db.customStatement(
        'update inventory_items set quantity = quantity + 1 '
        'where user_id = ? and item_id = ?',
        ['default_user', itemId],
      );

      await harness.reset();

      final qty = (await db.customSelect(
        'select quantity from inventory_items '
        'where user_id = ? and item_id = ?',
        variables: [
          Variable.withString('default_user'),
          Variable.withString(itemId),
        ],
      ).getSingleOrNull())
          ?.read<int>('quantity');
      expect(qty, 1,
          reason: 'only the demo-granted unit goes; the later real one stays');
    });

    test('a failure halfway through reset rolls the whole reset back',
        () async {
      await harness.seed(QaScenario.demoDay);
      final failing = QaFixtureHarness(
        // Fails on the LAST write of reset (the progress restore), after every
        // delete has already run. A failure at the first step would prove
        // nothing: nothing would have been deleted yet either way.
        pets: _FailingPets(db.petDao),
        craft: container.read(craftRepositoryProvider),
        tasks: container.read(taskRepositoryProvider),
        sessions: container.read(focusSessionRepositoryProvider),
        records: container.read(focusRecordRepositoryProvider),
        notes: container.read(distractionRepositoryProvider),
        ledger: container.read(rewardLedgerRepositoryProvider),
        db: db,
        clock: container.read(focusClockProvider),
      );

      await expectLater(failing.reset(), throwsA(isA<StateError>()));

      // Reset is one transaction, so the room failure must take back the
      // ledger, session and progress work that ran before it.
      final demo = (await db
              .customSelect(
                "select count(*) as c from reward_ledger "
                "where session_id like 'qa_demo_sess_%'",
              )
              .getSingle())
          .read<int>('c');
      expect(demo, 7, reason: 'a failed reset must not half-delete the week');
      final progress = (await db.petDao.findProgress(QaFixtureHarness.petId))!;
      expect(progress.experiencePoints, 1275);
    });

    test('reset removes the inventory rows the fixture created', () async {
      // Zeroing them left a database that differed from a single seed: the rows
      // were invisible to ownership but still there, and the next seed reused
      // them.
      await harness.seed(QaScenario.roomTwoAnchors);
      await harness.reset();

      final rows = (await db
              .customSelect(
                "select count(*) as c from inventory_items "
                "where substr(id, 1, 2) = 'qa'",
              )
              .getSingle())
          .read<int>('c');
      expect(rows, 0,
          reason: 'fixture inventory rows must be gone, not zeroed');
    });

    test('reset puts back progress that a scenario overwrote', () async {
      // A pet with real progress, created the way the app would have created it
      // and BEFORE the first QA seed: 100 XP, 10 minutes, 40% happiness. The
      // snapshot is taken at the first seed, so setting this after a seed would
      // be testing a state the fixture never sees.
      await db.petDao.upsertPet(domain.Pet(
        id: QaFixtureHarness.petId,
        userId: 'default_user',
        species: PetSpecies.dog,
        characterId: 'mochi',
        name: 'Mochi',
        adoptedAt: DateTime(2026, 10, 1),
      ));
      await db.petDao.upsertProgress(domain.PetProgress(
        id: QaFixtureHarness.progressId,
        petId: QaFixtureHarness.petId,
        level: GrowthLevelCurve.levelForXp(100),
        experiencePoints: 100,
        totalFocusMinutes: 10,
        happinessScore: 40,
        updatedAt: DateTime(2026, 10, 1),
      ));

      await harness.seed(QaScenario.lateGrowth);
      final grown = await db.petDao.findProgress(QaFixtureHarness.petId);
      expect(grown!.experiencePoints, greaterThan(100),
          reason: 'the scenario must actually overwrite the XP');

      await harness.reset();
      var after = await db.petDao.findProgress(QaFixtureHarness.petId);
      expect(after!.experiencePoints, 100,
          reason: 'lateGrowth has no ledger row, so reset must restore the '
              'value it overwrote');
      expect(after.totalFocusMinutes, 10);

      await harness.seed(QaScenario.highMood);
      expect(
          (await db.petDao.findProgress(QaFixtureHarness.petId))!
              .happinessScore,
          100);
      await harness.reset();
      after = await db.petDao.findProgress(QaFixtureHarness.petId);
      expect(after!.happinessScore, 40,
          reason: 'highMood must not permanently raise a real 40% to 100%');
      expect(after.experiencePoints, 100,
          reason: 'and the second reset must not lose the XP either');
    });

    test('reset clears the craft job, and re-seeding it does not collide',
        () async {
      await harness.seed(QaScenario.craftActive);
      // Make the recipe produce two, and give the player a real stack of the
      // output. Settlement still adds exactly ONE unit when the job completes;
      // rolling back `output_quantity` would take two and eat into the stack.
      final job = await db.customSelect(
        'select recipe_id from craft_jobs where id = ?',
        variables: [Variable.withString('qa_craft_job')],
      ).getSingle();
      final recipeId = job.read<String>('recipe_id');
      final recipe = await db.customSelect(
        'select output_item_id from craft_recipes where id = ?',
        variables: [Variable.withString(recipeId)],
      ).getSingle();
      final outputItem = recipe.read<String>('output_item_id');
      await db.customStatement(
        'update craft_recipes set output_quantity = 2 where id = ?',
        [recipeId],
      );
      await db.customStatement(
        'insert into inventory_items (id, user_id, item_id, quantity, updated_at) '
        "values ('real_inv', 'default_user', ?, 5, 1790990000)",
        [outputItem],
      );

      // demoDay's settlements advance and likely complete that job.
      await harness.seed(QaScenario.demoDay);

      // Whether the week completed it, so the inventory check only runs when
      // there was something to produce.
      final completed = (await db
                  .customSelect(
                    "select status from craft_jobs where id = 'qa_craft_job'",
                  )
                  .getSingle())
              .read<String>('status') ==
          'completed';

      await harness.reset();

      if (completed) {
        final stack = (await db
                .customSelect(
                  "select quantity from inventory_items where id = 'real_inv'",
                )
                .getSingle())
            .read<int>('quantity');
        expect(stack, 5,
            reason: 'reset must take back exactly the one unit the completion '
                'added, not the recipe output_quantity (2)');
        final rows = (await db.customSelect(
          'select count(*) as c from inventory_items '
          'where user_id = ? and item_id = ?',
          variables: [
            Variable.withString('default_user'),
            Variable.withString(outputItem),
          ],
        ).getSingle())
            .read<int>('c');
        expect(rows, 1,
            reason: 'and it must not delete the row the player owned');
      }

      final jobs = (await db
              .customSelect(
                "select count(*) as c from craft_jobs where id = 'qa_craft_job'",
              )
              .getSingle())
          .read<int>('c');
      expect(jobs, 0, reason: 'the fixture job must not outlive reset');

      // The exact failure this fixes: a second craftActive on a job that still
      // exists throws on the primary key.
      await harness.seed(QaScenario.craftActive);
      final again = (await db
              .customSelect(
                "select count(*) as c from craft_jobs where id = 'qa_craft_job'",
              )
              .getSingle())
          .read<int>('c');
      expect(again, 1, reason: 'the job must be re-creatable after reset');
    });

    test('the QA prefix cleanup does not treat _ as a wildcard', () async {
      // `qa_` as a LIKE pattern also matches `qaXmemory`. A real memory with a
      // look-alike id must survive the prefix cleanup.
      await db.petDao.addMemory(domain.PetMemory(
        id: 'qaXmemory',
        petId: QaFixtureHarness.petId,
        memoryType: 'first_focus',
        content: '不是 QA 创建的',
        happenedAt: DateTime(2020, 1, 2),
      ));
      await db.petDao.addMemory(domain.PetMemory(
        id: 'qa_mem_lookalike',
        petId: QaFixtureHarness.petId,
        memoryType: 'first_focus',
        content: '这个才是 QA 创建的',
        happenedAt: DateTime(2020, 1, 3),
      ));

      final removed = await db.petDao.deleteMemoriesWithIdPrefix('qa_');
      final left = await db.petDao.findMemories(QaFixtureHarness.petId);

      expect(removed, 1);
      expect(left.map((m) => m.id), ['qaXmemory'],
          reason: 'only the literal qa_ prefix may be deleted');
    });

    test('reset is scoped by id, not by a LIKE pattern', () async {
      await harness.seed(QaScenario.demoDay);

      // `_` is a single-character wildcard in SQL LIKE, so the old
      // `like 'qa_demo_sess_%'` also matched this row. Reset would have deleted
      // it without unwinding its reward — removing data the fixture never
      // created. The exact-id delete must leave it alone.
      await db.customStatement(
        "insert into focus_sessions (id, user_id, planned_seconds, mode, "
        "timing_mode, start_at, pause_intervals_json, end_at, status, "
        "timezone_offset_minutes) values "
        "('qaXdemo_sess_1', 'default_user', 1500, 'focus', 'countdown', "
        "1790990000, '[]', 1790991500, 'completed', 480)",
      );
      await db.customStatement(
        "insert into reward_ledger (session_id, user_id, focus_coins_earned, "
        "experience_earned, settled_at) values "
        "('qaXdemo_sess_1', 'default_user', 50, 125, 1790991500)",
      );

      await harness.reset();

      final survivor = (await db
              .customSelect(
                "select count(*) as c from focus_sessions "
                "where id = 'qaXdemo_sess_1'",
              )
              .getSingle())
          .read<int>('c');
      final ledger = (await db
              .customSelect(
                "select count(*) as c from reward_ledger "
                "where session_id = 'qaXdemo_sess_1'",
              )
              .getSingle())
          .read<int>('c');
      expect(survivor, 1,
          reason: 'a row the fixture did not create must survive');
      expect(ledger, 1, reason: 'and so must its ledger row');
    });

    test('every id reset will delete actually exists after a seed', () async {
      await harness.seed(QaScenario.demoDay);

      // Not a LIKE count. `_` is a wildcard, so a count with
      // `like 'qa_demo_sess_%'` stays at 7 if one exact id is missing and a
      // look-alike such as `qaXdemo_sess_7` is present — the same trap that made
      // the old reset delete rows it did not create. Check the ids themselves.
      for (var n = 1; n <= QaFixtureHarness.demoSessionCount; n++) {
        final found = await db.customSelect(
          'select count(*) as c from focus_sessions where id = ?',
          variables: [Variable.withString('qa_demo_sess_$n')],
        ).getSingle();
        expect(found.read<int>('c'), 1,
            reason:
                'reset deletes by this exact id, so the seed must write it');
      }
      final total = (await db
              .customSelect(
                "select count(*) as c from focus_sessions "
                "where id like 'qa_demo_sess_%'",
              )
              .getSingle())
          .read<int>('c');
      expect(total, QaFixtureHarness.demoSessionCount,
          reason: 'and it must not write any extra demo session');
    });

    test('reset clears the tasks, plans and notes the fixture created',
        () async {
      await harness.seed(QaScenario.demoDay);
      // A row the fixture did not create, at the same table.
      await db.customStatement(
        "insert into tasks (id, user_id, title, estimated_seconds, status, "
        "created_at, sort_order) values "
        "('real_task', 'default_user', '真实任务', 1500, 'open', 1790990000, 0)",
      );

      await harness.reset();

      for (final table in const [
        'tasks',
        'task_schedules',
        'distraction_notes'
      ]) {
        final n = (await db
                .customSelect(
                  'select count(*) as c from $table where '
                  "${table == 'tasks' ? 'id' : table == 'task_schedules' ? 'task_id' : 'id'} "
                  "like 'qa_demo_%'",
                )
                .getSingle())
            .read<int>('c');
        expect(n, 0, reason: '$table still holds fixture rows after reset');
      }
      final real = (await db
              .customSelect(
                "select count(*) as c from tasks where id = 'real_task'",
              )
              .getSingle())
          .read<int>('c');
      expect(real, 1, reason: 'reset must not touch a task it did not create');
    });

    test('a real memory at the same moment as a demo settlement survives',
        () async {
      await harness.seed(QaScenario.demoDay);

      // The demo settlements wrote memories at their own end times. A real
      // memory can share one of those moments; deleting by (pet, moment) took it
      // with them, because the same moment is not the same origin.
      final demoMoment = (await db.petDao.findMemories(
        QaFixtureHarness.petId,
      ))
          .first
          .happenedAt;
      await db.petDao.addMemory(domain.PetMemory(
        id: 'mem_real_at_same_moment',
        petId: QaFixtureHarness.petId,
        memoryType: 'first_focus',
        content: '真实记忆，只是时间相同',
        happenedAt: demoMoment,
      ));

      await harness.reset();

      final after = await db.petDao.findMemories(QaFixtureHarness.petId);
      expect(after.map((m) => m.id), ['mem_real_at_same_moment'],
          reason: 'only the ids settlement wrote may be removed');
    });

    test('an interrupted seed resumed mid-week awards nothing twice', () async {
      await harness.seed(QaScenario.demoDay);

      // The state a process killed between writing a session and settling it
      // leaves: the session and its record are there, the ledger row is not,
      // AND the pet never got the reward. Removing only the ledger would leave
      // the XP already awarded, which is a different state ("the ledger row was
      // lost after settlement") — the one this test used to build by accident.
      for (final id in const [
        'qa_demo_sess_6',
        'qa_demo_sess_7',
      ]) {
        await db.customStatement(
            'delete from reward_ledger where session_id = ?', [id]);
      }
      final beforeUnwind = (await db.petDao.findProgress(
        QaFixtureHarness.petId,
      ))!;
      // 50 + 40 minutes at 5 XP/min.
      await db.petDao.upsertProgress(domain.PetProgress(
        id: beforeUnwind.id,
        petId: beforeUnwind.petId,
        level: beforeUnwind.level,
        experiencePoints: beforeUnwind.experiencePoints - 450,
        totalFocusMinutes: beforeUnwind.totalFocusMinutes - 90,
        happinessScore: beforeUnwind.happinessScore,
        updatedAt: beforeUnwind.updatedAt,
      ));
      // The memories those two settlements wrote have to go too. Leaving them
      // means re-settling lands on the same (pet, type, timestamp) ids and is
      // ignored by INSERT OR IGNORE, so the test could not tell "rebuilt" from
      // "never removed" — it would pass either way.
      final moments = <DateTime>[];
      for (final id in const ['qa_demo_sess_6', 'qa_demo_sess_7']) {
        final session = await db.customSelect(
          'select end_at from focus_sessions where id = ?',
          variables: [Variable.withString(id)],
        ).getSingle();
        moments.add(DateTime.fromMillisecondsSinceEpoch(
          (session.read<int?>('end_at') ?? 0) * 1000,
        ));
      }
      final memoriesBefore =
          await db.petDao.findMemories(QaFixtureHarness.petId);
      await db.petDao.deleteMemoriesByIds([
        for (final moment in moments)
          for (final type in const [
            domain.PetMemoryType.firstFocus,
            domain.PetMemoryType.levelUp,
            domain.PetMemoryType.longSession,
          ])
            CompanionMemory.idFor(QaFixtureHarness.petId, type, moment),
      ]);
      final memoriesAfterCut =
          await db.petDao.findMemories(QaFixtureHarness.petId);
      expect(memoriesAfterCut.length, lessThan(memoriesBefore.length),
          reason: 'the interrupted settlements must leave no memory behind');

      final before = (await db.petDao.findProgress(QaFixtureHarness.petId))!;
      final xpBefore = before.experiencePoints;
      final minutesBefore = before.totalFocusMinutes;

      await harness.seed(QaScenario.demoDay);
      final after = (await db.petDao.findProgress(QaFixtureHarness.petId))!;

      // Only the two missing sessions may have been added: exactly 90 minutes
      // (50 + 40) and the XP that goes with them, not the whole week again.
      expect(after.totalFocusMinutes - minutesBefore, 90,
          reason: 'a resumed seed must settle only what was missing');
      expect(after.experiencePoints - xpBefore, 450,
          reason: '90 minutes at 5 XP/min is 450 XP, not the week again');

      // And the whole week is present exactly once.
      final ledger = await db
          .customSelect(
            "select count(*) as n from reward_ledger where session_id like "
            "'qa_demo_sess_%'",
          )
          .getSingle();
      expect(ledger.data['n'], 7);
      // The memories those settlements earn are back, and the two long-session
      // ones are exact because they depend only on the session's length. The
      // TOTAL is not asserted: a level-up memory is derived from the XP before
      // and after its own settlement, so replaying two sessions on top of an
      // already-earned week can cross a different number of levels than the
      // original run did. That is the app's own behaviour — settlement continues
      // from the XP the pet has, it does not rewrite history — and pinning the
      // count would encode an invariant the product does not have.
      final memoriesAfter = await db.petDao.findMemories(
        QaFixtureHarness.petId,
      );
      expect(memoriesAfter.length, greaterThan(memoriesAfterCut.length),
          reason: 'the missing settlements must earn their memories back');
      expect(
        memoriesAfter.where((m) => m.content.startsWith('陪你专注了 ')).length,
        2,
        reason: 'both 50-minute sessions still earn their long-session memory',
      );
    });

    test('every row it writes is internally consistent', () async {
      await harness.seed(QaScenario.demoDay);

      final tasks = await db
          .customSelect(
            "select count(*) as n from tasks where id like 'qa_demo_task_%'",
          )
          .getSingle();
      expect(tasks.data['n'], 5);

      final records = await db
          .customSelect(
            "select * from focus_records where session_id like 'qa_demo_sess_%'",
          )
          .get();
      expect(records, hasLength(7));

      // A record without its session would be a history row that cannot be
      // reopened; a session without its record would be a focus block the
      // reports never count. Both directions are checked because either one
      // alone passes when the fixture writes them together by accident.
      for (final row in records) {
        final sessionId = row.data['session_id'] as String;
        final session = await db.customSelect(
          'select * from focus_sessions where id = ?',
          variables: [Variable.withString(sessionId)],
        ).getSingleOrNull();
        expect(session, isNotNull, reason: 'record $sessionId has no session');
        expect(
          session!.data['planned_seconds'],
          row.data['duration_seconds'],
          reason: 'a record must last exactly as long as its session',
        );
      }

      // Coins and XP follow RewardService's own rule, so the ledger and the pet
      // cannot disagree with the sessions that earned them.
      final ledger = await db
          .customSelect(
            "select * from reward_ledger where session_id like 'qa_demo_sess_%'",
          )
          .get();
      expect(ledger, hasLength(7));
      var xp = 0;
      for (final row in ledger) {
        final minutes = (row.data['experience_earned'] as int) ~/ 5;
        expect(row.data['focus_coins_earned'], minutes * 2);
        xp += row.data['experience_earned'] as int;
      }

      final progress = await db.petDao.findProgress(
        QaFixtureHarness.petId,
      );
      expect(progress, isNotNull);
      expect(progress!.experiencePoints, xp);
      expect(progress.level, GrowthLevelCurve.levelForXp(xp));

      final openNotes = await db
          .customSelect(
            "select count(*) as n from distraction_notes "
            "where id like 'qa_demo_note_%' and status = 'open'",
          )
          .getSingle();
      expect(openNotes.data['n'], 4);
    });

    test('a second run does not double the week', () async {
      await harness.seed(QaScenario.demoDay);
      final firstXp = (await db.petDao.findProgress(
        QaFixtureHarness.petId,
      ))!
          .experiencePoints;
      await harness.seed(QaScenario.demoDay);

      final counts = await db
          .customSelect(
            "select "
            "(select count(*) from tasks where id like 'qa_demo_task_%') as t, "
            "(select count(*) from focus_records where session_id like 'qa_demo_sess_%') "
            "as r, "
            "(select count(*) from distraction_notes "
            "where id like 'qa_demo_note_%') as n",
          )
          .getSingle();
      expect(counts.data['t'], 5);
      expect(counts.data['r'], 7);
      expect(counts.data['n'], 5);
      expect(
        (await db.petDao.findProgress(QaFixtureHarness.petId))!
            .experiencePoints,
        firstXp,
        reason: 're-seeding must not award the week twice',
      );
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

/// A pet repository whose progress write throws, to prove reset is atomic.
///
/// The restore is the last write reset performs, so this failure lands after
/// every delete. Without the enclosing transaction the week would be gone and
/// the test would see a half-reset database.
class _FailingPets extends DriftPetRepository {
  _FailingPets(super.dao);

  @override
  Future<void> savePetProgress(domain.PetProgress progress) async {
    throw StateError('the progress restore failed');
  }
}
