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
/// `flutter run -t lib/dev/qa_fixture_main.dart`. the guard test in
/// `test/dev/qa_fixture_test.dart` fails if that stops being true, and [QaFixtureHarness.seed] refuses to run
/// outside a debug build as a second line of defence.
///
/// ## It is QA infrastructure, not product behaviour
///
/// No product code path calls into this. It adds no route, no button and no
/// visible affordance to the shipping UI.
library;

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart';

import '../core/auth/current_user.dart';
import '../data/local/app_database.dart';
import '../domain/growth/growth_level_curve.dart';
import '../domain/models/craft_models.dart' as domain;
import '../domain/models/distraction_note.dart' as m;
import '../domain/models/enums.dart';
import '../domain/models/enums.dart' as m;
import '../domain/models/focus_record.dart' as m;
import '../domain/models/focus_session.dart' as m;
import '../domain/models/pet_models.dart' as domain;
import '../domain/models/task.dart' as m;
import '../domain/models/task_schedule.dart' as m;
import '../domain/repositories/i_craft_repository.dart';
import '../domain/repositories/i_distraction_repository.dart';
import '../domain/repositories/i_focus_record_repository.dart';
import '../domain/repositories/i_focus_session_repository.dart';
import '../domain/repositories/i_pet_repository.dart';
import '../domain/repositories/i_reward_ledger_repository.dart';
import '../domain/repositories/i_task_repository.dart';
import '../domain/services/companion_memory.dart';
import '../domain/services/focus_clock.dart';
import '../domain/services/reward_service.dart';
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
  memoryReady('memory_ready'),

  /// A week of ordinary use: five tasks, today's plan, six finished focus
  /// sessions, and an inbox with three open notes.
  ///
  /// Exists because screenshots taken against an empty database have twice been
  /// read as missing features — the category chips only render for categories
  /// that have notes, so an empty inbox looks like an inbox without filters.
  /// Seeding through the repositories makes the screenshots show what a user
  /// with a week of use would see, and makes that state repeatable.
  demoDay('demo_day');

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
  /// How many sessions `demo_day` creates.
  ///
  /// Named because `reset()` needs the exact id set, and deriving it from a
  /// pattern is what let `LIKE 'qa_demo_sess_%'` also match `qaXdemo_sess_1`
  /// (`_` is a single-character wildcard in SQL). A test asserts this matches
  /// the number actually seeded, so the two cannot drift.
  static const int demoSessionCount = 7;

  static const String petId = 'mochi_pet_id';
  static const String progressId = 'mochi_progress_id';

  final IPetRepository pets;
  final ICraftRepository craft;
  final ITaskRepository tasks;
  final IFocusSessionRepository sessions;
  final IFocusRecordRepository records;
  final IDistractionRepository notes;
  final IRewardLedgerRepository ledger;
  final AppDatabase db;
  final FocusClock clock;

  final String userId;

  QaFixtureHarness({
    required this.pets,
    required this.craft,
    required this.tasks,
    required this.sessions,
    required this.records,
    required this.notes,
    required this.ledger,
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

    // The pre-QA progress, captured before the scenario changes anything. It has
    // to be here and not at the overwrite: `demoDay -> highMood` would otherwise
    // snapshot the pet *after* the demo week was awarded, and reset would write
    // that snapshot back after unwinding the same XP — the week survived, and
    // the next demoDay awarded it a second time (reproduced on a device:
    // 2550 XP / 510 minutes where one week is 1275 / 255).
    //
    // After `_ensureBasePet` rather than before: on a fresh database there is no
    // progress row until adoption creates one, and a snapshot of "nothing" is
    // not a snapshot. The base pet is 0 XP / 0 minutes, which is the pre-QA
    // state this restores.
    await _rememberProgressForReset();

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
      case QaScenario.demoDay:
        steps.addAll(await _seedDemoDay());
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
  /// Removes every row this fixture created, atomically.
  ///
  /// One transaction for the whole reset, not one per step. The restore path
  /// reads the non-demo ledger and then writes the pet's progress; a settlement
  /// landing between those two statements would have its XP overwritten while
  /// its ledger row survived. A transaction also makes reset all-or-nothing: a
  /// failure halfway leaves the previous state rather than half the demo week.
  Future<QaResetReport> reset() => db.transaction(_reset);

  Future<QaResetReport> _reset() async {
    // Repair a crash that landed between a settlement and its bookkeeping
    // before deciding what to undo. The ledger proves whether it ran.
    await _foldPendingCraft();

    // Everything demo_day caused, in reverse order of what caused it. The
    // sessions, records and ledger rows carry the QA prefix, so "the rows this
    // fixture created" is answerable by id — no guessing by timestamp.
    //
    // The memories are the one thing that does NOT carry the prefix: settlement
    // generated them with production-shaped ids (`mem_<pet>_<type>_<ts>`),
    // deliberately, and that is exactly why deleting them has to be tied to the
    // sessions that earned them. Their `happenedAt` is the settled moment of one
    // of the demo sessions, so the ledger rows are the source of truth for which
    // moments to remove. Deleting the ledger rows FIRST would lose that link, so
    // the moments are collected before anything is deleted.
    //
    // This is also why the sessions must go: they are what a re-seed skips. With
    // the session left behind, settlement's idempotency gate returns false and
    // the memory is never rebuilt, so a seed → reset → seed cycle would leave a
    // pet that earned the week and remembers none of it.
    // Everything below is scoped by the ids this fixture created, not by a
    // pattern. `like 'qa_demo_sess_%'` looks equivalent and is not: `_` is a
    // single-character wildcard in SQL LIKE, so it also matches `qaXdemo_sess_1`,
    // and it carries no user scoping at all. A pattern-based delete that catches
    // a session the fixture did not create would remove its ledger row without
    // unwinding its reward.
    final demoIds = <String>[
      for (var n = 1; n <= demoSessionCount; n++) '${idPrefix}demo_sess_$n',
    ];

    // The pet's progress. When a snapshot exists it is authoritative: it was
    // taken before the first seed touched anything, so restoring it undoes both
    // the demo week and any scenario that overwrote XP or happiness. Restoring
    // *and* unwinding would apply the removal twice in one order and cancel it
    // in another; this is one rule, not two.
    //
    // The ledger unwind below is the fallback for a database seeded before the
    // snapshot existed (or by an older build): settlement already added the
    // week's XP, and deleting the ledger without giving it back would leave a
    // pet that earns it again on the next seed.
    final hasSnapshot = await _hasSavedProgress();
    var demoXp = 0;
    var demoMinutes = 0;
    if (!hasSnapshot) {
      for (final row in await ledger.findForUser(userId)) {
        if (!demoIds.contains(row.sessionId)) continue;
        demoXp += row.experienceEarned;
        demoMinutes += row.experienceEarned ~/ 5;
      }
    }
    final beforeReset = await pets.findPetProgress(petId);
    if (beforeReset != null && (demoXp > 0 || demoMinutes > 0)) {
      final newXp = (beforeReset.experiencePoints - demoXp).clamp(0, 1 << 40);
      await pets.savePetProgress(domain.PetProgress(
        id: beforeReset.id,
        petId: beforeReset.petId,
        level: GrowthLevelCurve.levelForXp(newXp),
        experiencePoints: newXp,
        totalFocusMinutes:
            (beforeReset.totalFocusMinutes - demoMinutes).clamp(0, 1 << 40),
        // Left as it is: happiness is a state, not an event, and unwinding it
        // would invent a number the app never had.
        happinessScore: beforeReset.happinessScore,
        updatedAt: _now,
      ));
    }

    // The exact memory ids the demo settlements inserted, recorded as they were
    // created. Deriving them from (moment, type) looked equivalent and is not:
    // a real session that settled at the same instant can own the id for one of
    // the three types, and the demo settlement then creates nothing of that
    // type — deleting the derived id would take the real memory. Only the ids
    // this fixture actually saw appear are removed.
    final memoryIds = await _demoMemoryIds();

    for (final table in const ['reward_ledger', 'focus_records']) {
      await db.customStatement(
        "delete from $table where session_id in "
        "(${List.filled(demoIds.length, '?').join(',')})",
        demoIds,
      );
    }
    await db.customStatement(
      'delete from focus_sessions where id in '
      '(${List.filled(demoIds.length, '?').join(',')})',
      demoIds,
    );
    var memories = await db.petDao.deleteMemoriesByIds(memoryIds);
    await db.customStatement(
      'delete from app_settings where key = ?',
      [_demoMemoryIdsKey],
    );
    // Plus the ones other scenarios wrote, whose ids do carry the prefix. Both
    // paths run, never one instead of the other: demo_day + memory_ready leaves
    // memories of two shapes, and an either/or left one kind behind.
    memories += await db.petDao.deleteMemoriesWithIdPrefix(idPrefix);

    // The craft job a scenario started, and what settlement did to it. A
    // completed job added its recipe's output to the inventory; leaving that
    // increment behind would make a later reset look like it cleaned up while
    // the player still owned something the QA week produced. The job itself
    // must go or re-seeding craftActive hits its primary key.
    //
    // Only the row. The unit its completion granted is taken back by
    // `_restoreCraftFromReset`, which records it as a demo grant; rolling it
    // back here as well would decrement the same item twice.
    await db.customStatement(
      'delete from craft_jobs where id = ?',
      ['${idPrefix}craft_job'],
    );

    await _restoreCraftFromReset();

    var roomItems = 0;
    for (final item in await craft.findRoomItems(userId)) {
      if (item.id.startsWith(idPrefix)) {
        await craft.removeRoomItem(item.id);
        roomItems++;
      }
    }

    // Deleted, not zeroed. A zero-quantity row is invisible to ownership (the
    // app reads `quantity > 0`) but it is still a row: after reset -> seed the
    // database differs from a single seed, and the old rows get reused. The
    // prefix says the fixture created them, so removing them is exactly
    // "restore the pre-QA state". Player-owned rows have no prefix and are not
    // touched here; the craft rollback above already took back the one unit a
    // completed job added to one of those.
    // Exactly the units the fixture granted, restored to the quantity each row
    // had before the grant: `-1` means the row did not exist and is removed,
    // `0` means a zero-quantity row existed and is left at zero.
    var revoked = 0;
    for (final part in await _savedPairs(_inventoryGrantedKey)) {
      final itemId = part.$1;
      final created = part.$2 == '-1';
      final row = await db.customSelect(
        'select id, quantity from inventory_items '
        'where user_id = ? and item_id = ?',
        variables: [Variable.withString(userId), Variable.withString(itemId)],
      ).getSingleOrNull();
      if (row == null) continue;
      final id = row.read<String>('id');
      final left = (row.read<int>('quantity') - 1).clamp(0, 1 << 40);
      if (left == 0 && created) {
        await db.customStatement(
          'delete from inventory_items where id = ?',
          [id],
        );
      } else {
        await db.customStatement(
          'update inventory_items set quantity = ? where id = ?',
          [left, id],
        );
      }
      revoked++;
    }
    await db.customStatement(
      'delete from app_settings where key = ?',
      [_inventoryGrantedKey],
    );

    // The tasks, their placements and the inbox notes are this fixture's too.
    // They used to survive a reset, so a seed → reset → seed cycle started on
    // top of the previous week's tasks and notes.
    final taskIds = <String>[
      for (final name in const [
        'report',
        'read',
        'desk',
        'mail',
        'walk',
      ])
        '${idPrefix}demo_task_$name',
    ];
    await db.customStatement(
      'delete from task_schedules where task_id in '
      '(${List.filled(taskIds.length, '?').join(',')})',
      taskIds,
    );
    await db.customStatement(
      'delete from tasks where id in '
      '(${List.filled(taskIds.length, '?').join(',')})',
      taskIds,
    );
    final noteIds = <String>[
      for (var n = 1; n <= 5; n++) '${idPrefix}demo_note_$n',
    ];
    await db.customStatement(
      'delete from distraction_notes where id in '
      '(${List.filled(noteIds.length, '?').join(',')})',
      noteIds,
    );

    // Last, so it overrides the demo unwind when both happened.
    await _restoreProgressFromReset();

    return QaResetReport(
      roomItems: roomItems,
      inventoryRowsRevoked: revoked,
      memories: memories,
    );
  }

  // ── primitives ─────────────────────────────────────────────────────────────

  /// Writes one finished focus session and settles it through production.
  ///
  /// ## Why this does not drive the engine
  ///
  /// `FocusSessionEngine` starts a session at `clock.now()`, and a QA run has a
  /// fixed clock — so it can only ever produce a session that starts "now". A
  /// week of history is the whole point of `demo_day`, so the timestamps have
  /// to be written. Everything after the timestamps goes through production:
  /// the record is inserted by [IFocusRecordRepository], and the reward is
  /// settled by [RewardService] through [IAtomicSettlement], which is what
  /// writes the ledger row, the pet's XP and minutes, the happiness bump, the
  /// memories (first focus, level-up, long session) and any craft progress —
  /// all in one transaction, exactly once per session.
  ///
  /// The alternative, which this replaces, computed the coins and XP here and
  /// wrote them straight to the ledger and the pet. That produced a state the
  /// app cannot reach: seven settled sessions with no memory at all, because
  /// the reward rule lives in settlement, not at the call site. A screenshot of
  /// it looked like a week of play and was missing everything play leaves
  /// behind.
  ///
  /// Idempotent: [RewardService.settle] returns false for a session already in
  /// the ledger, and the record insert is skipped when one exists.
  Future<void> _settlePastSession({
    required String id,
    required String? categoryId,
    required String? taskId,
    required String? taskName,
    required String? mood,
    required String? gains,
    required DateTime start,
    required int minutes,
  }) async {
    final end = start.add(Duration(minutes: minutes));
    final session = m.FocusSession(
      id: id,
      userId: userId,
      categoryId: categoryId,
      taskName: taskName,
      taskId: taskId,
      plannedSeconds: minutes * 60,
      mode: m.FocusMode.focus,
      startAt: start,
      pauseIntervals: const [],
      endAt: end,
      status: m.FocusSessionStatus.completed,
      timezoneOffsetMinutes: start.timeZoneOffset.inMinutes,
    );
    await sessions.save(session);

    if (await records.findBySessionId(id) == null) {
      await records.insert(m.FocusRecord(
        id: '${id}_rec',
        sessionId: id,
        userId: userId,
        categoryId: categoryId,
        taskName: taskName,
        taskId: taskId,
        mood: mood,
        gains: gains,
        durationSeconds: minutes * 60,
        startAt: start,
        endAt: end,
        recordedAt: end,
        isCountedForReward: true,
      ));
    }

    // The memory ids this settlement could create, recorded as "absent before"
    // rather than diffed afterwards. Three properties follow:
    //   - no list limit: the check is by exact id, not "the latest 500";
    //   - no collision: an id that already exists (a real memory) is not
    //     recorded, so reset cannot delete it;
    //   - crash-safe: the record is written before the settlement, so a process
    //     killed between settle and bookkeeping still knows what to remove.
    final candidates = <String>[
      for (final type in const [
        domain.PetMemoryType.firstFocus,
        domain.PetMemoryType.levelUp,
        domain.PetMemoryType.longSession,
      ])
        CompanionMemory.idFor(petId, type, end),
    ];
    await _rememberAbsentMemoryIds(candidates);

    // Settlement, not this fixture, decides the reward. It writes the ledger,
    // the pet, the memories and the craft job in one transaction.
    //
    // It is given a clock that reads THIS session's end. The shared QA clock is
    // a single instant, so settling all seven at "now" gives every memory the
    // same timestamp — and `CompanionMemory._idFor` builds the id from
    // (pet, type, timestamp). Two 50-minute sessions would then earn one
    // `longSession` memory between them, the second silently dropped by the
    // INSERT OR IGNORE. Settling at each session's own end keeps the ids
    // distinct, which is also what a real week looks like.
    // Recover an expectation left by a previous crash before writing this one.
    await _foldPendingCraft();
    final craftBefore = await _activeCraftState();
    await _writeCraftPending(
      sessionId: id,
      seconds: minutes * 60,
      before: craftBefore,
    );
    await _rewardServiceAt(end).settle(session);
    await _foldPendingCraft();
  }

  /// Seeds a week of ordinary use, and reports what it wrote.
  ///
  /// Every row goes through the same repository the app writes through, so the
  /// fixture cannot produce a state the app could not: a record always has its
  /// session, a reward always matches its minutes, and the pet's level is
  /// derived from the XP it earned rather than typed in.
  ///
  /// Idempotent by existence check on fixed ids. Running it twice does not
  /// double the week, which is what makes it safe to re-run before a screenshot
  /// pass.
  Future<List<String>> _seedDemoDay() async {
    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    final steps = <String>[];

    // ── tasks ────────────────────────────────────────────────────────────────
    final taskSpecs =
        <(String, String, String?, int, String?, m.TaskStatus, DateTime?)>[
      (
        '${idPrefix}demo_task_report',
        '写完本周周报',
        'work',
        40 * 60,
        '把三个项目的进展收一下',
        m.TaskStatus.open,
        null,
      ),
      (
        '${idPrefix}demo_task_read',
        '读完《深度工作》第三章',
        'study',
        50 * 60,
        '做两页笔记',
        m.TaskStatus.open,
        null,
      ),
      (
        '${idPrefix}demo_task_desk',
        '整理书桌和阳台',
        'life',
        25 * 60,
        null,
        m.TaskStatus.open,
        null,
      ),
      (
        '${idPrefix}demo_task_mail',
        '回复客户邮件',
        'work',
        25 * 60,
        null,
        m.TaskStatus.done,
        today.add(const Duration(hours: 10, minutes: 25)),
      ),
      (
        '${idPrefix}demo_task_walk',
        '傍晚散步 30 分钟',
        'life',
        25 * 60,
        null,
        m.TaskStatus.done,
        today.subtract(const Duration(days: 1)).add(
              const Duration(hours: 19, minutes: 40),
            ),
      ),
    ];
    for (final spec in taskSpecs) {
      if (await tasks.findById(spec.$1) != null) continue;
      await tasks.insert(m.Task(
        id: spec.$1,
        userId: userId,
        title: spec.$2,
        categoryId: spec.$3,
        estimatedSeconds: spec.$4,
        note: spec.$5,
        status: spec.$6,
        completedAt: spec.$7,
        // Six days back, so it predates the oldest focus session below. A task
        // created after the focus it was done for would be a timeline where the
        // work happened before the thing that caused it.
        createdAt: today.subtract(const Duration(days: 6)).add(
              const Duration(hours: 9),
            ),
      ));
    }
    steps.add('tasks');

    // A user with a week of focus has made something with the coins. Without
    // this the room screen only ever shows its empty state, which reads as a
    // missing feature rather than as a state the user has not reached yet.
    for (final id in ['rug', 'sofa', 'desk', 'bookshelf', 'bed']) {
      final entity = FurnitureCatalog.entities[id];
      if (entity != null) await _own(entity);
    }
    steps.add('furniture');

    // ── today's plan ─────────────────────────────────────────────────────────
    await tasks.schedule(
      taskId: '${idPrefix}demo_task_report',
      userId: userId,
      startAt: today.add(const Duration(hours: 14)),
      plannedSeconds: 40 * 60,
    );
    await tasks.schedule(
      taskId: '${idPrefix}demo_task_read',
      userId: userId,
      startAt: today.add(const Duration(hours: 20)),
      plannedSeconds: 50 * 60,
    );
    await tasks.schedule(
      taskId: '${idPrefix}demo_task_mail',
      userId: userId,
      startAt: today.add(const Duration(hours: 9, minutes: 30)),
      plannedSeconds: 25 * 60,
    );
    final mailDate = m.dayKeyFor(today);
    final mailPlan =
        await tasks.findScheduleOn('${idPrefix}demo_task_mail', mailDate);
    if (mailPlan != null && mailPlan.status != m.TaskScheduleStatus.done) {
      await tasks.updateSchedule(
        mailPlan.copyWith(status: m.TaskScheduleStatus.done),
      );
    }
    steps.add('plan');

    // ── a week of finished sessions ──────────────────────────────────────────
    // (days ago, hour, minutes, category, task id, task name, mood, gains)
    final sessionSpecs =
        <(int, int, int, String?, String?, String?, String?, String?)>[
      (
        0,
        10,
        25,
        'work',
        '${idPrefix}demo_task_mail',
        '回复客户邮件',
        'good',
        'finishedGoal'
      ),
      (
        1,
        15,
        50,
        'study',
        '${idPrefix}demo_task_read',
        '读完《深度工作》第三章',
        'flow',
        'clearerThinking,learnedSomething'
      ),
      (1, 21, 25, 'life', null, null, 'okay', 'betterMood'),
      (
        2,
        14,
        40,
        'work',
        '${idPrefix}demo_task_report',
        '写完本周周报',
        'good',
        'moreFocused'
      ),
      (3, 9, 25, 'study', null, '整理笔记', 'okay', null),
      (4, 16, 50, 'work', null, '写方案初稿', 'flow', 'newIdeas,moreFocused'),
      (5, 20, 40, 'life', null, null, 'good', 'betterMood'),
    ];

    // Settle in the order the sessions happened, oldest first.
    //
    // The ids stay tied to the spec's position, but the ORDER matters:
    // `CompanionMemory` decides "第一次和你一起专注" from settledCount == 1 and
    // decides a level-up by comparing the XP before and after each settlement.
    // Walking the list as written (today, then backwards) gave the first-focus
    // memory to today's session and wrote level-ups in reverse chronological
    // order — a timeline where the pet remembered its newest session as its
    // first, and reached Lv.2 before Lv.13.
    final ordered =
        <(int, (int, int, int, String?, String?, String?, String?, String?))>[
      for (var n = 0; n < sessionSpecs.length; n++) (n + 1, sessionSpecs[n]),
    ]..sort((a, b) {
            int endOf(
                    (
                      int,
                      int,
                      int,
                      String?,
                      String?,
                      String?,
                      String?,
                      String?
                    ) spec) =>
                today
                    .subtract(Duration(days: spec.$1))
                    .add(Duration(hours: spec.$2, minutes: spec.$3))
                    .millisecondsSinceEpoch;
            return endOf(a.$2).compareTo(endOf(b.$2));
          });

    var seededSessions = 0;
    for (final (index, spec) in ordered) {
      final id = '${idPrefix}demo_sess_$index';
      final minutes = spec.$3;

      // An unfinished session is finished, not skipped. A process killed
      // between the session write and settlement leaves exactly that: a session
      // with no ledger row, which settlement's idempotency gate would let
      // through — if anything called it. Skipping on "session exists" is what
      // made that state permanent, so the check is on the ledger instead: an
      // already-settled session is left alone, an unsettled one is settled now.
      if (await ledger.findBySessionId(id) != null) continue;

      // Only sessions in the future of the app's own start are re-created; the
      // clock is fixed for a QA run, so a session "in the past" cannot be
      // started. _settlePastSession writes it directly instead.
      await _settlePastSession(
        id: id,
        categoryId: spec.$4,
        taskId: spec.$5,
        taskName: spec.$6,
        mood: spec.$7,
        gains: spec.$8,
        start: today
            .subtract(Duration(days: spec.$1))
            .add(Duration(hours: spec.$2)),
        minutes: minutes,
      );
      seededSessions++;
    }

    if (seededSessions == 0) {
      debugPrint('demo_day: every session already settled, nothing to add');
    }

    // The pet's XP, minutes, happiness, memories and craft progress were all
    // written by settlement itself, exactly once, inside its transaction. This
    // fixture deliberately writes none of that: a fixture that recomputed the
    // reward rule would be a second copy of a rule that already exists, and the
    // two would drift on the day the rule changes.
    steps.add('sessions');

    // ── the inbox ────────────────────────────────────────────────────────────
    final noteSpecs = <(String, String?, m.DistractionNoteStatus, int)>[
      ('查一下明天的高铁票', 'life', m.DistractionNoteStatus.open, 0),
      ('回复设计稿的评论', 'work', m.DistractionNoteStatus.open, 0),
      ('把读书笔记同步到云盘', 'study', m.DistractionNoteStatus.open, 0),
      ('顺手把快递取了', 'life', m.DistractionNoteStatus.handled, 1),
      ('给妈妈打个电话', 'life', m.DistractionNoteStatus.open, 2),
    ];
    var noteIndex = 0;
    for (final spec in noteSpecs) {
      noteIndex++;
      final id = '${idPrefix}demo_note_$noteIndex';
      if (await notes.findById(id) != null) continue;
      final createdAt =
          now.subtract(Duration(days: spec.$4, minutes: 20 * noteIndex));
      await notes.insert(m.DistractionNote(
        id: id,
        userId: userId,
        text: spec.$1,
        categoryId: spec.$2,
        status: spec.$3,
        createdAt: createdAt,
        handledAt: spec.$3 == m.DistractionNoteStatus.handled
            ? createdAt.add(const Duration(minutes: 12))
            : null,
        sessionId: spec.$4 == 0 ? '${idPrefix}demo_sess_1' : null,
      ));
    }
    steps.add('inbox');

    return steps;
  }

  /// The production [RewardService], told what time it is.
  ///
  /// Same repositories, same atomic settlement DAO as `providers.dart`; only the
  /// clock differs, so settlement records the moment the session actually
  /// ended. Constructing it here is not a second copy of the reward rule — the
  /// rule still lives in [RewardService] and [IAtomicSettlement].
  RewardService _rewardServiceAt(DateTime when) => RewardService(
        ledgerRepo: ledger,
        petRepo: pets,
        clock: _FixedMoment(when),
        atomicSettlement: db.settlementDao,
      );

  /// The memory ids the demo settlements created, in `app_settings`.
  ///
  /// Recorded by `_settlePastSession` after each settlement, because the only
  /// honest answer to "which memories are the fixture's" is "the ones it saw
  /// appear". A comma-separated list is enough: ids are
  /// `mem_<pet>_<type>_<microseconds>` and contain no commas.
  static const String _demoMemoryIdsKey = 'qa_demo_memory_ids';

  Future<List<String>> _demoMemoryIds() async {
    final row = await db.customSelect(
      'select value from app_settings where key = ?',
      variables: [Variable.withString(_demoMemoryIdsKey)],
    ).getSingleOrNull();
    if (row == null) return const [];
    return row
        .read<String>('value')
        .split(',')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  /// Records the candidate ids that do NOT exist yet.
  ///
  /// Called before the settlement. An id that already exists belongs to a real
  /// memory and is never recorded, so reset cannot delete it; an id that does
  /// not exist can only be created by the settlement that is about to run, and
  /// recording it first makes the bookkeeping crash-safe.
  Future<void> _rememberAbsentMemoryIds(List<String> candidates) async {
    final absent = <String>[];
    for (final id in candidates) {
      final row = await db.customSelect(
        'select 1 as present from pet_memories where id = ?',
        variables: [Variable.withString(id)],
      ).getSingleOrNull();
      if (row == null) absent.add(id);
    }
    if (absent.isEmpty) return;
    final merged = <String>{...await _demoMemoryIds(), ...absent}.toList();
    await db.customStatement(
      'insert or replace into app_settings (key, value) values (?, ?)',
      [_demoMemoryIdsKey, merged.join(',')],
    );
  }

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
    // Scenarios that OVERWRITE progress (lateGrowth sets XP, highMood sets
    // happiness) have nothing in a ledger for reset to reverse. Without this,
    // `lateGrowth → reset` left the pet at Lv.20 forever and `highMood → reset`
    // left a real 40% happiness at 100. The value is saved once, before the
    // first overwrite, so a second scenario cannot save a mutated value as if
    // it were the original.
    await _rememberProgressForReset();
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

  /// The `app_settings` key holding the progress a scenario overwrote.
  static const String _savedProgressKey = 'qa_saved_progress';

  /// Saves the pet's progress once, before a scenario overwrites it.
  ///
  /// `app_settings` rather than a field: a seed and a reset can be separate
  /// process runs (the QA entry point seeds, the app then runs, a later reset
  /// runs), and an in-memory field would not survive that. The key carries the
  /// QA prefix so it is visibly fixture bookkeeping.
  Future<void> _rememberProgressForReset() async {
    // One transaction, because the two reads have to describe the same instant.
    // Read the pet first and the ledger second, and a real settlement landing
    // between them writes a snapshot of "0 XP, ledger already contains 250":
    // reset then computes a delta of zero and deletes the 250 the user earned.
    // The transaction is what makes the pair a consistent snapshot; the ledger
    // totals alone cannot tell whether the pet read saw the same settlement.
    await db.transaction(() async {
      final existing = await db.customSelect(
        'select value from app_settings where key = ?',
        variables: [Variable.withString(_savedProgressKey)],
      ).getSingleOrNull();
      if (existing != null) return;
      final progress = await pets.findPetProgress(petId);
      if (progress == null) return;
      // The ledger totals at snapshot time, so reset can tell what a real
      // settlement added AFTER the QA run started from what was already there.
      // Without them, restoring the snapshot would wipe a genuine session the
      // user completed between seeding and resetting — the session and its
      // ledger row would survive, the XP would not.
      final totals = await _nonDemoLedgerTotals();
      await db.customStatement(
        'insert or replace into app_settings (key, value) values (?, ?)',
        [
          _savedProgressKey,
          '${progress.experiencePoints},${progress.totalFocusMinutes},'
              '${progress.happinessScore},${totals.xp},${totals.minutes},'
              '${totals.count}',
        ],
      );
    });
  }

  /// The items this fixture actually granted a unit of.
  ///
  /// Recorded by `_own` only when it grants (the player did not already own the
  /// item), and cleared by reset. Subtracting "one unit from every qa_ row" was
  /// wrong in both directions: a seed that granted nothing still enabled the
  /// subtraction, and a row holding real units lost one per reset cycle.
  static const String _inventoryGrantedKey = 'qa_inventory_granted';

  static const String _craftDeltasKey = 'qa_demo_craft_deltas';
  static const String _craftCompletedKey = 'qa_demo_craft_completed';
  static const String _craftGrantedKey = 'qa_demo_craft_granted';
  static const String _craftPendingKey = 'qa_demo_craft_pending';

  /// The in-progress craft jobs, in the order settlement will consider them.
  Future<Map<String, ({int progress, String? itemId, int quantity})>>
      _activeCraftState() async {
    // The same predicate settlement uses, with no extra filter and no extra
    // ordering. Settlement excludes nothing and sorts nothing, so a fixture
    // that excluded its own job or imposed rowid order could disagree with it
    // when several jobs are active — and then attribute the advance to a job
    // settlement never touched. Repeating the query is the closest the fixture
    // can get to "the job settlement will pick".
    final jobs = await db.customSelect(
      "select id, recipe_id, progress_seconds from craft_jobs "
      "where user_id = ? and status = 'inProgress'",
      variables: [Variable.withString(userId)],
    ).get();
    final state = <String, ({int progress, String? itemId, int quantity})>{};
    for (final job in jobs) {
      final id = job.read<String>('id');
      final recipeId = job.read<String>('recipe_id');
      final recipe = await db.customSelect(
        'select output_item_id from craft_recipes where id = ?',
        variables: [Variable.withString(recipeId)],
      ).getSingleOrNull();
      final itemId = recipe?.read<String?>('output_item_id');
      var quantity = -1;
      if (itemId != null) {
        final inv = await db.customSelect(
          'select quantity from inventory_items '
          'where user_id = ? and item_id = ?',
          variables: [Variable.withString(userId), Variable.withString(itemId)],
        ).getSingleOrNull();
        quantity = inv?.read<int>('quantity') ?? -1;
      }
      state[id] = (
        progress: job.read<int>('progress_seconds'),
        itemId: itemId,
        quantity: quantity,
      );
    }
    return state;
  }

  /// Writes what the settlement about to run is expected to do, before it runs.
  ///
  /// Settlement adds exactly `addedFocusSeconds` to the first in-progress job.
  /// Recording that expectation first is what makes the bookkeeping survive a
  /// process killed between the settlement committing and the totals being
  /// updated: `_foldPendingCraft` reads the ledger to decide whether the
  /// expectation actually happened.
  Future<void> _writeCraftPending({
    required String sessionId,
    required int seconds,
    required Map<String, ({int progress, String? itemId, int quantity})> before,
  }) async {
    if (before.isEmpty) return;
    final jobId = before.keys.first;
    final job = before[jobId]!;
    // `progressBefore` lets the fold decide whether THIS settlement completed
    // the job, without needing a separate completion record that could be lost
    // to a crash.
    await db.customStatement(
      'insert or replace into app_settings (key, value) values (?, ?)',
      [
        _craftPendingKey,
        '$sessionId|$jobId|$seconds|${job.progress}|${job.itemId ?? ''}|'
            '${job.quantity < 0 ? 0 : 1}',
      ],
    );
  }

  /// Folds a pending expectation into the totals if its settlement committed.
  ///
  /// The ledger row is the proof: `settleAtomically` writes it in the same
  /// transaction that advances the job, so a ledger row means the progress was
  /// added. No row means the settlement never ran, and the expectation is
  /// discarded rather than subtracted from progress that was never added.
  Future<void> _foldPendingCraft() async {
    // One transaction: read, decide, accumulate, clear. A crash between the
    // delete and the write would otherwise lose the only record that the
    // settlement advanced the job.
    await db.transaction(() async {
      final row = await db.customSelect(
        'select value from app_settings where key = ?',
        variables: [Variable.withString(_craftPendingKey)],
      ).getSingleOrNull();
      if (row == null) return;
      await db.customStatement(
        'delete from app_settings where key = ?',
        [_craftPendingKey],
      );
      final bits = row.read<String>('value').split('|');
      if (bits.length < 3) return;
      final sessionId = bits[0];
      final jobId = bits[1];
      final seconds = int.tryParse(bits[2]);
      if (seconds == null) return;
      final settled = await db.customSelect(
        'select 1 as present from reward_ledger where session_id = ?',
        variables: [Variable.withString(sessionId)],
      ).getSingleOrNull();
      if (settled == null) return;
      await _addCraftDelta(jobId, seconds);

      // Was the job completed by THIS settlement? It completes when the
      // progress crosses the recipe's requirement, and the settlement adds
      // exactly `seconds`, so the arithmetic decides without a second record.
      final job = await db.customSelect(
        'select status, recipe_id, progress_seconds from craft_jobs '
        'where id = ?',
        variables: [Variable.withString(jobId)],
      ).getSingleOrNull();
      if (job == null || job.read<String>('status') != 'completed') return;
      // A pending written by an older build has three fields. The baseline is
      // still recoverable: a completion means the settlement added exactly
      // `seconds` to the progress it found, so `current - seconds` is that
      // progress. Without this the legacy record folded the delta and left a
      // completed job and its item behind.
      final progressBefore = bits.length > 3
          ? int.tryParse(bits[3])
          : job.read<int>('progress_seconds') - seconds;
      if (progressBefore == null) return;
      final recipe = await db.customSelect(
        'select required_minutes, output_item_id from craft_recipes '
        'where id = ?',
        variables: [Variable.withString(job.read<String>('recipe_id'))],
      ).getSingleOrNull();
      final required = recipe?.read<int>('required_minutes');
      if (required == null) return;
      if (progressBefore + seconds < required * 60) return;

      final completed = await _savedList(_craftCompletedKey);
      if (!completed.contains(jobId)) {
        completed.add(jobId);
        await _saveList(_craftCompletedKey, completed);
      }
      final itemId = bits.length > 4 && bits[4].isNotEmpty
          ? bits[4]
          : recipe?.read<String?>('output_item_id');
      if (itemId != null) {
        // Whether the inventory row existed before the completion. A legacy
        // record has no flag and its origin cannot be proved: the generated
        // `inv_<user>_<item>_<ms>` shape is also what an earlier settlement
        // creates. The safe answer is "existed", which keeps the row at zero
        // instead of deleting what may be the player's.
        final existed = bits.length > 5 ? bits[5] : '1';
        final granted = await _savedCraftGrants();
        granted.putIfAbsent(itemId, () => existed);
        await db.customStatement(
          'insert or replace into app_settings (key, value) values (?, ?)',
          [
            _craftGrantedKey,
            granted.entries.map((e) => '${e.key}:${e.value}').join(';'),
          ],
        );
      }
    });
  }

  Future<void> _addCraftDelta(String jobId, int seconds) async {
    final deltas = <String, int>{};
    for (final part in await _savedPairs(_craftDeltasKey)) {
      final value = int.tryParse(part.$2);
      if (value != null) deltas[part.$1] = value;
    }
    deltas[jobId] = (deltas[jobId] ?? 0) + seconds;
    await db.customStatement(
      'insert or replace into app_settings (key, value) values (?, ?)',
      [
        _craftDeltasKey,
        deltas.entries.map((e) => '${e.key}:${e.value}').join(';'),
      ],
    );
  }

  Future<List<String>> _savedList(String key) async {
    final row = await db.customSelect(
      'select value from app_settings where key = ?',
      variables: [Variable.withString(key)],
    ).getSingleOrNull();
    if (row == null) return <String>[];
    return row
        .read<String>('value')
        .split(',')
        .where((v) => v.isNotEmpty)
        .toList();
  }

  Future<void> _saveList(String key, List<String> values) async {
    await db.customStatement(
      'insert or replace into app_settings (key, value) values (?, ?)',
      [key, values.join(',')],
    );
  }

  /// The craft grants, in both formats this file has written.
  ///
  /// Current: `item:existed;...`. Older builds wrote a comma-separated list of
  /// item ids; those carry `?` as the origin, which reset resolves from the row
  /// id (a `qa_` row was created by the fixture) or, when that is not decisive,
  /// treats as pre-existing so a player row is kept.
  Future<Map<String, String>> _savedCraftGrants() async {
    final row = await db.customSelect(
      'select value from app_settings where key = ?',
      variables: [Variable.withString(_craftGrantedKey)],
    ).getSingleOrNull();
    if (row == null) return <String, String>{};
    final value = row.read<String>('value');
    if (value.isEmpty) return <String, String>{};
    final out = <String, String>{};
    if (value.contains(':')) {
      for (final part in value.split(';')) {
        final bits = part.split(':');
        if (bits.length == 2 && bits[0].isNotEmpty) out[bits[0]] = bits[1];
      }
    } else {
      for (final item in value.split(',')) {
        if (item.isNotEmpty) out[item] = '?';
      }
    }
    return out;
  }

  Future<List<(String, String)>> _savedPairs(String key) async {
    final row = await db.customSelect(
      'select value from app_settings where key = ?',
      variables: [Variable.withString(key)],
    ).getSingleOrNull();
    if (row == null) return const [];
    final out = <(String, String)>[];
    for (final part in row.read<String>('value').split(';')) {
      final bits = part.split(':');
      if (bits.length == 2 && bits[0].isNotEmpty) out.add((bits[0], bits[1]));
    }
    return out;
  }

  /// Takes back exactly what the demo settlements caused.
  ///
  /// - progress: subtract the summed delta (the demo's own seconds), leaving any
  ///   real progress made before, between, or after;
  /// - status: reopen only a job the demo settlements completed. A job a real
  ///   settlement completed is left completed — the comment that said this was
  ///   impossible was wrong, because real focus can finish the job between two
  ///   demo settlements;
  /// - inventory: take back one unit per item the demo completion granted, so
  ///   items the user gained afterwards survive.
  Future<void> _restoreCraftFromReset() async {
    final deltas = <String, int>{};
    for (final part in await _savedPairs(_craftDeltasKey)) {
      final seconds = int.tryParse(part.$2);
      if (seconds != null) deltas[part.$1] = seconds;
    }
    final completed = await _savedList(_craftCompletedKey);
    final granted = await _savedCraftGrants();
    if (deltas.isEmpty && completed.isEmpty && granted.isEmpty) return;

    for (final entry in deltas.entries) {
      final row = await db.customSelect(
        'select progress_seconds from craft_jobs where id = ?',
        variables: [Variable.withString(entry.key)],
      ).getSingleOrNull();
      if (row == null) continue;
      final left =
          (row.read<int>('progress_seconds') - entry.value).clamp(0, 1 << 40);
      await db.customStatement(
        'update craft_jobs set progress_seconds = ? where id = ?',
        [left, entry.key],
      );
    }
    for (final jobId in completed) {
      await db.customStatement(
        "update craft_jobs set status = 'inProgress', completed_at = null "
        'where id = ? and status = ?',
        [jobId, 'completed'],
      );
    }
    for (final entry in granted.entries) {
      final itemId = entry.key;
      final row = await db.customSelect(
        'select id, quantity from inventory_items '
        'where user_id = ? and item_id = ?',
        variables: [Variable.withString(userId), Variable.withString(itemId)],
      ).getSingleOrNull();
      if (row == null) continue;
      final existed = entry.value == '0'
          ? true
          : entry.value == '-1'
              ? false
              // Unknown legacy origin: a fixture-prefixed row was created by
              // this fixture; anything else is kept.
              : !row.read<String>('id').startsWith(idPrefix);
      final left = (row.read<int>('quantity') - 1).clamp(0, 1 << 40);
      if (left == 0 && !existed) {
        await db.customStatement(
          'delete from inventory_items where user_id = ? and item_id = ?',
          [userId, itemId],
        );
      } else {
        await db.customStatement(
          'update inventory_items set quantity = ? '
          'where user_id = ? and item_id = ?',
          [left, userId, itemId],
        );
      }
    }
    await db.customStatement(
      'delete from app_settings where key in (?, ?, ?, ?)',
      [
        _craftDeltasKey,
        _craftCompletedKey,
        _craftGrantedKey,
        _craftPendingKey,
      ],
    );
  }

  /// XP, minutes and settlement count from real (non-demo) sessions.
  ///
  /// Only the demo week is the fixture's to undo. Every other ledger row is the
  /// user's own work, including anything settled between the seed and the reset.
  Future<({int xp, int minutes, int count})> _nonDemoLedgerTotals() async {
    var xp = 0;
    var minutes = 0;
    var count = 0;
    for (final row in await ledger.findForUser(userId)) {
      if (row.sessionId.startsWith('${idPrefix}demo_sess_')) continue;
      xp += row.experienceEarned;
      minutes += row.experienceEarned ~/ 5;
      count++;
    }
    return (xp: xp, minutes: minutes, count: count);
  }

  /// Whether a pre-QA snapshot exists.
  Future<bool> _hasSavedProgress() async {
    final row = await db.customSelect(
      'select 1 as present from app_settings where key = ?',
      variables: [Variable.withString(_savedProgressKey)],
    ).getSingleOrNull();
    return row != null;
  }

  /// Puts the saved progress back, and forgets it.
  ///
  /// Runs after the demo ledger unwind, so when both an overwriting scenario
  /// and `demo_day` ran, the saved value (the true pre-QA state) wins.
  Future<void> _restoreProgressFromReset() async {
    final row = await db.customSelect(
      'select value from app_settings where key = ?',
      variables: [Variable.withString(_savedProgressKey)],
    ).getSingleOrNull();
    if (row == null) return;
    final parts = row.read<String>('value').split(',');
    await db.customStatement(
      'delete from app_settings where key = ?',
      [_savedProgressKey],
    );
    if (parts.length < 3) return;
    var xp = int.tryParse(parts[0]);
    var minutes = int.tryParse(parts[1]);
    var happiness = int.tryParse(parts[2]);
    if (xp == null || minutes == null || happiness == null) return;

    // Add back what real sessions settled after the snapshot. The snapshot is
    // the state before the QA run; the user's own work since then is not the
    // fixture's to delete. Six-part snapshots carry the ledger totals that make
    // this measurable; a three-part snapshot (older build) has no baseline, so
    // nothing is added and the old behaviour stands.
    if (parts.length >= 6) {
      final snapXp = int.tryParse(parts[3]);
      final snapMinutes = int.tryParse(parts[4]);
      final snapCount = int.tryParse(parts[5]);
      if (snapXp != null && snapMinutes != null && snapCount != null) {
        final now = await _nonDemoLedgerTotals();
        xp += (now.xp - snapXp).clamp(0, 1 << 40);
        minutes += (now.minutes - snapMinutes).clamp(0, 1 << 40);
        // Settlement adds 5 happiness per session, clamped at 100.
        happiness = (happiness + 5 * (now.count - snapCount).clamp(0, 100))
            .clamp(0, 100);
      }
    }

    final current = await pets.findPetProgress(petId);
    if (current == null) return;
    await pets.savePetProgress(domain.PetProgress(
      id: current.id,
      petId: current.petId,
      level: GrowthLevelCurve.levelForXp(xp),
      experiencePoints: xp,
      totalFocusMinutes: minutes,
      happinessScore: happiness,
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
      // The write and its bookkeeping are one transaction: a process stopped
      // between them would leave a unit no later seed records (the item now
      // looks owned) and no reset can attribute.
      await db.transaction(() async {
        // Reuse the existing row when there is one. A zero-quantity row with a
        // non-fixture id already occupies (user, item), which is unique, so
        // inserting a fixture row for the same item would violate it.
        await craft.upsertInventoryItem(domain.InventoryItem(
          id: owned?.id ?? '${idPrefix}inv_${entity.id}',
          userId: userId,
          itemId: entity.id,
          quantity: 1,
          updatedAt: _now,
        ));
        final granted = <String, String>{
          for (final pair in await _savedPairs(_inventoryGrantedKey))
            pair.$1: pair.$2,
        };
        // Whether a row already existed. Reset subtracts the one unit this
        // granted and removes the row only when it created it — restoring an
        // absolute pre-grant quantity would delete units the player gained
        // afterwards. The FIRST grant decides: if the fixture created the row,
        // a later grant in the same cycle (after the player emptied it) must
        // not relabel it as a pre-existing row.
        granted.putIfAbsent(entity.id, () => owned == null ? '-1' : '0');
        await db.customStatement(
          'insert or replace into app_settings (key, value) values (?, ?)',
          [
            _inventoryGrantedKey,
            granted.entries.map((e) => '${e.key}:${e.value}').join(';'),
          ],
        );
      });
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

/// A clock pinned to one instant, for seeding a session that already ended.
class _FixedMoment implements FocusClock {
  const _FixedMoment(this.moment);
  final DateTime moment;

  @override
  DateTime now() => moment;
}
