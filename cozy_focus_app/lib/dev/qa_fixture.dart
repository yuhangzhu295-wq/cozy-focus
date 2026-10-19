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

import 'package:drift/drift.dart' show UpdateKind, Variable;
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
import '../domain/services/focus_clock.dart';
import '../domain/services/companion_memory.dart';
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
  Future<QaResetReport> reset() async {
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

    // The exact memory ids those settlements wrote. Deleting by (pet, moment)
    // would also take a real memory that happens to share the moment — same
    // moment is not same origin — so the ids are built with the same function
    // settlement uses.
    final memoryIds = <String>[
      for (final moment in await _demoSettlementMoments())
        for (final type in const [
          domain.PetMemoryType.firstFocus,
          domain.PetMemoryType.levelUp,
          domain.PetMemoryType.longSession,
        ])
          CompanionMemory.idFor(petId, type, moment),
    ];

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
    // Plus the ones other scenarios wrote, whose ids do carry the prefix. Both
    // paths run, never one instead of the other: demo_day + memory_ready leaves
    // memories of two shapes, and an either/or left one kind behind.
    memories += await db.petDao.deleteMemoriesWithIdPrefix(idPrefix);

    // The craft job a scenario started, and what settlement did to it. A
    // completed job added its recipe's output to the inventory; leaving that
    // increment behind would make a later reset look like it cleaned up while
    // the player still owned something the QA week produced. The job itself
    // must go or re-seeding craftActive hits its primary key.
    final job = await db.customSelect(
      'select recipe_id, status from craft_jobs where id = ?',
      variables: [Variable.withString('${idPrefix}craft_job')],
    ).getSingleOrNull();
    if (job != null) {
      final recipeId = job.data['recipe_id'] as String?;
      final wasCompleted = job.data['status'] == 'completed';
      await db.customStatement(
        'delete from craft_jobs where id = ?',
        ['${idPrefix}craft_job'],
      );
      if (wasCompleted && recipeId != null) {
        final recipe = await db.customSelect(
          'select output_item_id, output_quantity from craft_recipes '
          'where id = ?',
          variables: [Variable.withString(recipeId)],
        ).getSingleOrNull();
        final itemId = recipe?.data['output_item_id'] as String?;
        // Settlement's completion path adds ONE unit (`_incrementInventory`
        // writes `existing.quantity + 1` and inserts `quantity: 1`), so that is
        // what has to come back. Subtracting the recipe's `output_quantity`
        // would take more than the completion ever added whenever a recipe
        // produces more than one.
        const produced = 1;
        if (itemId != null) {
          final inv = await db.customSelect(
            'select id, quantity from inventory_items '
            'where user_id = ? and item_id = ?',
            variables: [
              Variable.withString(userId),
              Variable.withString(itemId),
            ],
          ).getSingleOrNull();
          if (inv != null) {
            final invId = inv.data['id'] as String;
            final left =
                ((inv.data['quantity'] as int) - produced).clamp(0, 1 << 30);
            if (left == 0 && !invId.startsWith(idPrefix)) {
              // Created by the completion, so it goes with it.
              await db.customStatement(
                'delete from inventory_items where id = ?',
                [invId],
              );
            } else {
              await db.customStatement(
                'update inventory_items set quantity = ? where id = ?',
                [left, invId],
              );
            }
          }
        }
      }
    }

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
    var revoked = await db.customUpdate(
      'delete from inventory_items where user_id = ? and substr(id, 1, ?) = ?',
      variables: [
        Variable.withString(userId),
        Variable.withInt(idPrefix.length),
        Variable.withString(idPrefix),
      ],
      updateKind: UpdateKind.delete,
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
    await _rewardServiceAt(end).settle(session);
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

  /// The `settledAt` of every demo session that ever settled.
  ///
  /// Read back from the ledger rather than stored, so it survives a fixture
  /// rebuild. A session deleted before its memory was wiped keeps its ledger
  /// row and so still lists its moment.
  Future<List<DateTime>> _demoSettlementMoments() async {
    final ids = <String>{
      for (var n = 1; n <= demoSessionCount; n++) '${idPrefix}demo_sess_$n',
    };
    final moments = <DateTime>[];
    for (final row in await ledger.findForUser(userId)) {
      if (ids.contains(row.sessionId)) moments.add(row.settledAt);
    }
    return moments;
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

/// A clock pinned to one instant, for seeding a session that already ended.
class _FixedMoment implements FocusClock {
  const _FixedMoment(this.moment);
  final DateTime moment;

  @override
  DateTime now() => moment;
}
