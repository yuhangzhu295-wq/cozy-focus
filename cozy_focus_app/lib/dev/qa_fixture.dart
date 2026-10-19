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

  /// The production reward settlement, wired exactly as `providers.dart` wires
  /// it (atomic DAO included). `demo_day` settles its sessions through this
  /// rather than writing ledger and progress rows itself, so the state it
  /// produces is indistinguishable from one the app reached on its own —
  /// including the memories, the happiness bump and the craft progress that a
  /// hand-written ledger row would silently omit.
  final RewardService rewardService;
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
    required this.rewardService,
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
    // Unwind the pet first. Settlement already added the demo week's XP,
    // minutes and happiness to the pet, so deleting the ledger without giving
    // those back leaves a pet that has earned the week twice — once before the
    // reset and once after the re-seed. What to remove is read from the ledger
    // rows that are about to go, so it is exactly what was awarded.
    var demoXp = 0;
    var demoMinutes = 0;
    for (final row in await ledger.findForUser(userId)) {
      if (!row.sessionId.startsWith('${idPrefix}demo_sess_')) continue;
      demoXp += row.experienceEarned;
      demoMinutes += row.experienceEarned ~/ 5;
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

    final moments = await _demoSettlementMoments();
    await db.customStatement(
      "delete from reward_ledger where session_id like '${idPrefix}demo_sess_%'",
    );
    await db.customStatement(
      "delete from focus_records where session_id like '${idPrefix}demo_sess_%'",
    );
    await db.customStatement(
      "delete from focus_sessions where id like '${idPrefix}demo_sess_%'",
    );
    var memories = await db.petDao.deleteMemoriesAt(
      petId: petId,
      moments: moments,
    );
    // Plus the ones other scenarios wrote, whose ids do carry the prefix. Both
    // paths run, never one instead of the other: demo_day + memory_ready leaves
    // memories of two shapes, and an either/or left one kind behind.
    memories += await db.petDao.deleteMemoriesWithIdPrefix(idPrefix);

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
    await rewardService.settle(session);
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

    var seededSessions = 0;
    var index = 0;
    for (final spec in sessionSpecs) {
      index++;
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

  /// The `settledAt` of every demo session that ever settled.
  ///
  /// Read back from the ledger rather than stored, so it survives a fixture
  /// rebuild. A session deleted before its memory was wiped keeps its ledger
  /// row and so still lists its moment.
  Future<List<DateTime>> _demoSettlementMoments() async {
    final moments = <DateTime>[];
    for (final row in await ledger.findForUser(userId)) {
      if (row.sessionId.startsWith('${idPrefix}demo_sess_')) {
        moments.add(row.settledAt);
      }
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
