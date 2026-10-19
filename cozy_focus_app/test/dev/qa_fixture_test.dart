import 'dart:io';

import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/dev/qa_fixture.dart';
import 'package:cozy_focus_app/domain/growth/growth_level_curve.dart';
import 'package:cozy_focus_app/domain/models/craft_models.dart' as domain;
import 'package:cozy_focus_app/domain/models/pet_models.dart' as domain;
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
      await db.petDao.deleteMemoriesAt(
        petId: QaFixtureHarness.petId,
        moments: moments,
      );
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
