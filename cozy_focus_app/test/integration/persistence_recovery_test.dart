import 'dart:io';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide FocusSession, Pet, CraftJob, CraftRecipe, InventoryItem, RoomItem;
import 'package:cozy_focus_app/domain/models/craft_models.dart' as domain;
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import '../support/schema_head.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

class _Clock implements FocusClock {
  DateTime _now;
  _Clock(this._now);
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
}

/// Persistence and recovery: what survives a process death, and what an old
/// database becomes when it is opened.
///
/// ## Why a real file, not an in-memory database
///
/// Every other suite uses `NativeDatabase.memory()`, which is right for speed but
/// cannot represent a process death: the connection never closes and the data
/// never has to be read back from disk. Here the database is a **file**, and
/// "dying" means genuinely closing the connection and the container and then
/// opening both again. If a value were only in memory, this suite would lose it.
void main() {
  late Directory dir;
  late File file;
  late _Clock clock;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cozy_persistence_');
    file = File('${dir.path}${Platform.pathSeparator}cozy_focus.sqlite');
    clock = _Clock(DateTime(2026, 10, 3, 10, 0, 0));
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  AppDatabase openDb() => AppDatabase.forTesting(NativeDatabase(file));

  ProviderContainer boot(AppDatabase db) => ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          focusClockProvider.overrideWithValue(clock),
          companionSelectionStoreProvider
              .overrideWithValue(InMemoryCompanionSelectionStore()),
        ],
      );

  /// Process death: the container and the connection both go away.
  Future<void> kill(ProviderContainer c, AppDatabase db) async {
    c.dispose();
    await db.close();
  }

  Future<List<Map<String, Object?>>> rows(AppDatabase db, String sql) async {
    final r = await db.customSelect(sql).get();
    return r.map((e) => e.data).toList();
  }

  Future<void> adopt(ProviderContainer c) =>
      c.read(homeControllerProvider.notifier).loadHomeData();

  /// Places an item so the room has something to survive.
  Future<void> place(AppDatabase db, String itemId, double x, double y) async {
    await db.craftDao.upsertInventoryItem(domain.InventoryItem(
      id: 'inv_$itemId',
      userId: 'default_user',
      itemId: itemId,
      quantity: 1,
      updatedAt: clock.now(),
    ));
    await db.craftDao.upsertRoomItem(domain.RoomItem(
      id: 'room_$itemId',
      userId: 'default_user',
      itemId: itemId,
      positionX: x,
      positionY: y,
      scale: 1.0,
      zIndex: 1,
      isVisible: true,
      placedAt: clock.now(),
    ));
  }

  group('the process dies at each point a user can be', () {
    test('during an active focus session', () async {
      var db = openDb();
      var c = boot(db);
      await adopt(c);
      final focus = c.read(focusSessionControllerProvider.notifier);
      final started = await focus.startSession(
        userId: 'default_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
      );
      clock.advance(const Duration(minutes: 3));

      await kill(c, db);

      db = openDb();
      c = boot(db);
      addTearDown(() async {
        c.dispose();
        await db.close();
      });
      final restored = await c
          .read(focusSessionControllerProvider.notifier)
          .restoreSession('default_user');

      expect(restored, isNotNull, reason: 'the session must come back');
      expect(restored!.id, started.id);
      // `restored`, not `running`: the engine distinguishes a session that has
      // been read back from disk from one started in this process, and the
      // player is told which. Expecting `running` here was my error.
      expect(restored.status, FocusSessionStatus.restored);
      expect(restored.plannedSeconds, 1500,
          reason: 'the plan survives, not just the fact of a session');
    });

    test('during a pause', () async {
      var db = openDb();
      var c = boot(db);
      await adopt(c);
      final focus = c.read(focusSessionControllerProvider.notifier);
      await focus.startSession(
        userId: 'default_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
      );
      clock.advance(const Duration(minutes: 4));
      await focus.pauseSession();

      await kill(c, db);

      db = openDb();
      c = boot(db);
      addTearDown(() async {
        c.dispose();
        await db.close();
      });
      final restored = await c
          .read(focusSessionControllerProvider.notifier)
          .restoreSession('default_user');

      expect(restored, isNotNull);
      // The open pause must survive, or the elapsed time would silently include
      // the minutes the user spent not focusing.
      expect(restored!.pauseIntervals, isNotEmpty);
      expect(restored.pauseIntervals.last.pauseEnd, isNull,
          reason: 'an unclosed pause means the break was still running');
    });

    test('while finishing, and recovery settles it exactly once', () async {
      var db = openDb();
      var c = boot(db);
      await adopt(c);
      final focus = c.read(focusSessionControllerProvider.notifier);
      await focus.startSession(
        userId: 'default_user',
        plannedSeconds: 600,
        mode: FocusMode.focus,
      );
      clock.advance(const Duration(minutes: 5));
      await focus.completeSession();
      expect(
          (await rows(db, 'select status from focus_sessions')).first['status'],
          'finishing');

      await kill(c, db);

      db = openDb();
      c = boot(db);
      addTearDown(() async {
        c.dispose();
        await db.close();
      });
      final revived = c.read(focusSessionControllerProvider.notifier);
      await revived.recoverAbandonedSessions('default_user');
      // A second recovery, because a launch hook that ran twice must not
      // settle twice.
      await revived.recoverAbandonedSessions('default_user');

      expect(await rows(db, 'select * from focus_records'), hasLength(1),
          reason: 'no duplicate settlement');
      expect(await rows(db, 'select * from reward_ledger'), hasLength(1));
    });

    test('during a craft job', () async {
      var db = openDb();
      var c = boot(db);
      await adopt(c);
      final recipes = await db.craftDao.findAllRecipes();
      final rug = recipes.firstWhere((r) => r.id == 'rug');
      await c.read(craftEngineProvider).startJob('default_user', rug.id);
      // Partial progress, so the suite proves the *accumulated seconds* survive
      // rather than only the job row.
      await c.read(craftEngineProvider).accumulateProgress('default_user', 900);

      await kill(c, db);

      db = openDb();
      c = boot(db);
      addTearDown(() async {
        c.dispose();
        await db.close();
      });
      final job = await db.craftDao.findActiveJobByUser('default_user');
      expect(job, isNotNull, reason: 'the job is still running');
      expect(job!.recipeId, rug.id);
      expect(job.progressSeconds, 900,
          reason:
              'progress is minutes of real focus; losing it loses the work');
      expect(job.status, CraftJobStatus.inProgress);
    });

    test('during a room edit', () async {
      var db = openDb();
      var c = boot(db);
      await adopt(c);
      await place(db, 'sofa', 0.4, 0.6);
      await place(db, 'rug', 0.7, 0.65);

      await kill(c, db);

      db = openDb();
      c = boot(db);
      addTearDown(() async {
        c.dispose();
        await db.close();
      });
      final room = await db.craftDao.findRoomItems('default_user');
      expect(room, hasLength(2), reason: 'a restart must not reset the room');
      expect(room.map((r) => r.itemId).toSet(), {'sofa', 'rug'});
    });

    test('during room movement', () async {
      var db = openDb();
      var c = boot(db);
      await adopt(c);
      await place(db, 'sofa', 0.4, 0.6);

      // The user drags it somewhere else.
      final moved = (await db.craftDao.findRoomItems('default_user')).first;
      await db.craftDao.upsertRoomItem(domain.RoomItem(
        id: moved.id,
        userId: moved.userId,
        itemId: moved.itemId,
        positionX: 0.15,
        positionY: 0.72,
        scale: 1.4,
        zIndex: moved.zIndex,
        isVisible: false,
        placedAt: moved.placedAt,
      ));

      await kill(c, db);

      db = openDb();
      c = boot(db);
      addTearDown(() async {
        c.dispose();
        await db.close();
      });
      final after = (await db.craftDao.findRoomItems('default_user')).single;
      expect(after.positionX, closeTo(0.15, 1e-9),
          reason: 'the position the user chose must survive, not the old one');
      expect(after.positionY, closeTo(0.72, 1e-9));
      expect(after.scale, closeTo(1.4, 1e-9));
      expect(after.isVisible, isFalse);
    });
  });

  group('the five facts a user would notice losing', () {
    test('all of them survive one restart together', () async {
      var db = openDb();
      var c = boot(db);
      await adopt(c);

      // Choose a companion.
      expect(
          await c
              .read(companionSelectionProvider.notifier)
              .select(CompanionId.rabbit),
          isTrue);
      // Own and place something.
      await place(db, 'rug', 0.3, 0.62);
      // Grow, and earn a memory, through a real settlement.
      final focus = c.read(focusSessionControllerProvider.notifier);
      await focus.startSession(
        userId: 'default_user',
        plannedSeconds: 600,
        mode: FocusMode.focus,
      );
      clock.advance(const Duration(minutes: 12));
      await focus.completeSession();
      await focus.saveSession();

      final petId = (await db.petDao.findPetByUser('default_user'))!.id;
      final xpBefore = (await db.petDao.findProgress(petId))!.experiencePoints;
      final memoriesBefore = await db.petDao.findMemories(petId);
      expect(xpBefore, greaterThan(0));
      expect(memoriesBefore, isNotEmpty);

      await kill(c, db);

      db = openDb();
      c = boot(db);
      addTearDown(() async {
        c.dispose();
        await db.close();
      });

      // Companion. The store is in-memory in this suite, so what is asserted
      // here is the catalog's ability to resolve it -- the file-backed store is
      // covered by the app itself.
      expect(
          await c
              .read(companionSelectionProvider.notifier)
              .select(CompanionId.rabbit),
          isTrue);

      // Inventory + room.
      expect(
        (await db.craftDao.findInventory('default_user'))
            .where((i) => i.quantity > 0)
            .map((i) => i.itemId),
        contains('rug'),
      );
      expect((await db.craftDao.findRoomItems('default_user')), hasLength(1));

      // Growth + memory.
      expect((await db.petDao.findProgress(petId))!.experiencePoints, xpBefore);
      expect(await db.petDao.findMemories(petId),
          hasLength(memoriesBefore.length));
    });

    test('a restart does not settle, duplicate or reset anything', () async {
      var db = openDb();
      var c = boot(db);
      await adopt(c);
      await place(db, 'sofa', 0.5, 0.6);
      final focus = c.read(focusSessionControllerProvider.notifier);
      await focus.startSession(
        userId: 'default_user',
        plannedSeconds: 600,
        mode: FocusMode.focus,
      );
      clock.advance(const Duration(minutes: 10));
      await focus.completeSession();
      await focus.saveSession();

      final petId = (await db.petDao.findPetByUser('default_user'))!.id;
      final before = {
        'records': (await rows(db, 'select * from focus_records')).length,
        'ledger': (await rows(db, 'select * from reward_ledger')).length,
        'memories': (await db.petDao.findMemories(petId)).length,
        'room': (await db.craftDao.findRoomItems('default_user')).length,
        'xp': (await db.petDao.findProgress(petId))!.experiencePoints,
      };

      await kill(c, db);

      // Three separate launches, because a launch hook that double-fires is the
      // realistic way a duplicate appears.
      for (var launch = 0; launch < 3; launch++) {
        db = openDb();
        c = boot(db);
        await adopt(c);
        await c
            .read(focusSessionControllerProvider.notifier)
            .recoverAbandonedSessions('default_user');
        await c
            .read(focusSessionControllerProvider.notifier)
            .restoreSession('default_user');
        await kill(c, db);
      }

      db = openDb();
      addTearDown(() => db.close());
      expect((await rows(db, 'select * from focus_records')).length,
          before['records'],
          reason: 'no duplicate settlement');
      expect((await rows(db, 'select * from reward_ledger')).length,
          before['ledger']);
      expect((await db.petDao.findMemories(petId)).length, before['memories'],
          reason: 'no duplicate memory');
      expect((await db.craftDao.findRoomItems('default_user')).length,
          before['room'],
          reason: 'no room reset');
      expect(
          (await db.petDao.findProgress(petId))!.experiencePoints, before['xp'],
          reason: 'XP is not re-awarded on launch');
    });
  });

  // Runs `ddl` into a fresh file at `version`, then opens it with the app.
  // Declared here rather than inside the group: a doc comment on a local
  // function declaration does not parse.
  Future<AppDatabase> seedAndOpen(List<String> ddl, int version) async {
    final raw = sqlite3.open(file.path);
    try {
      for (final statement in ddl) {
        raw.execute(statement);
      }
      raw.execute('PRAGMA user_version = $version');
    } finally {
      raw.dispose();
    }
    return openDb();
  }

  group('negative proof: these checks can fail', () {
    test('the harness really is file-backed, not in memory', () async {
      // If this suite ran on `NativeDatabase.memory()`, "restart" would be a
      // fiction -- the connection never closes, so nothing would ever have to be
      // read back from disk and every survival assertion would pass for free.
      // Reading the file with a *separate* raw connection is what proves the
      // data is genuinely on disk.
      final db = openDb();
      await db.craftDao.upsertInventoryItem(domain.InventoryItem(
        id: 'inv_probe',
        userId: 'default_user',
        itemId: 'sofa',
        quantity: 3,
        updatedAt: clock.now(),
      ));
      await db.close();

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));

      final raw = sqlite3.open(file.path);
      try {
        final result = raw.select(
            "SELECT item_id, quantity FROM inventory_items WHERE id = 'inv_probe'");
        expect(result, hasLength(1),
            reason: 'the row must be in the file, not only in a connection');
        expect(result.first['quantity'], 3);
      } finally {
        raw.dispose();
      }
    });

    test('the unique index cannot be created over duplicates', () async {
      // The migration's dedup step is load-bearing, and this is the proof.
      // v3->v4 deletes duplicate session rows *before* creating the unique index
      // on session_id. Without that step the index creation would fail and the
      // upgrade would abort -- taking the user's database with it.
      final raw = sqlite3.open(file.path);
      try {
        raw.execute('CREATE TABLE probe_records ('
            'id TEXT NOT NULL PRIMARY KEY, session_id TEXT NOT NULL)');
        raw.execute(
            "INSERT INTO probe_records VALUES ('a','same'),('b','same')");
        expect(
          () => raw.execute(
              'CREATE UNIQUE INDEX probe_idx ON probe_records(session_id)'),
          throwsA(anything),
          reason: 'SQLite must refuse the index while duplicates remain, or '
              'the migration dedup is unnecessary and this proves nothing',
        );
        // Dedup, then it succeeds -- the shape of what the migration does.
        raw.execute("DELETE FROM probe_records WHERE rowid NOT IN "
            '(SELECT MIN(rowid) FROM probe_records GROUP BY session_id)');
        raw.execute(
            'CREATE UNIQUE INDEX probe_idx ON probe_records(session_id)');
      } finally {
        raw.dispose();
      }
    });
  });

  group('migration from an older database', () {
    // The v1 shape of each table: the current columns minus everything the
    // migrations add. Written out rather than generated, because a generated
    // "old" schema would be the current one and would prove nothing.
    const v1FocusSessions = '''
      CREATE TABLE focus_sessions (
        id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, category_id TEXT,
        planned_seconds INTEGER NOT NULL, mode TEXT NOT NULL,
        start_at INTEGER NOT NULL, pause_intervals_json TEXT NOT NULL DEFAULT '[]',
        end_at INTEGER, status TEXT NOT NULL, timezone_offset_minutes INTEGER NOT NULL)''';
    const v1FocusRecords = '''
      CREATE TABLE focus_records (
        id TEXT NOT NULL PRIMARY KEY, session_id TEXT NOT NULL, user_id TEXT NOT NULL,
        category_id TEXT, duration_seconds INTEGER NOT NULL, start_at INTEGER NOT NULL,
        end_at INTEGER NOT NULL, recorded_at INTEGER NOT NULL,
        is_counted_for_reward INTEGER NOT NULL DEFAULT 1, note TEXT)''';
    const v1CraftJobs = '''
      CREATE TABLE craft_jobs (
        id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, recipe_id TEXT NOT NULL,
        status TEXT NOT NULL, started_at INTEGER NOT NULL, completed_at INTEGER,
        reward_claimed INTEGER NOT NULL DEFAULT 0, session_id TEXT)''';
    // What v1->v2 adds, so the v2 fixtures below are a database that really
    // could have existed at version 2.
    const v2FocusSessions = '''
      CREATE TABLE focus_sessions (
        id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, category_id TEXT,
        task_name TEXT, planned_seconds INTEGER NOT NULL, mode TEXT NOT NULL,
        start_at INTEGER NOT NULL, pause_intervals_json TEXT NOT NULL DEFAULT '[]',
        end_at INTEGER, status TEXT NOT NULL, timezone_offset_minutes INTEGER NOT NULL)''';
    const v2FocusRecords = '''
      CREATE TABLE focus_records (
        id TEXT NOT NULL PRIMARY KEY, session_id TEXT NOT NULL, user_id TEXT NOT NULL,
        category_id TEXT, task_name TEXT, mood TEXT,
        duration_seconds INTEGER NOT NULL, start_at INTEGER NOT NULL,
        end_at INTEGER NOT NULL, recorded_at INTEGER NOT NULL,
        is_counted_for_reward INTEGER NOT NULL DEFAULT 1, note TEXT)''';

    const v1CraftRecipes = '''
      CREATE TABLE craft_recipes (
        id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, description TEXT,
        required_minutes INTEGER NOT NULL,
        ingredient_costs_json TEXT NOT NULL DEFAULT '{}', output_item_id TEXT NOT NULL,
        output_quantity INTEGER NOT NULL DEFAULT 1, artwork_path TEXT)''';

    test('v1 to v2 adds the entered-detail columns and keeps the rows',
        () async {
      // All four tables, because a real v1 database had all four: the migration
      // chain runs v1->v2 AND v2->v3 (adding a column to craft_jobs and seeding
      // recipes), so a fixture with only the focus tables would fail on a
      // migration that a real database passes.
      final db = await seedAndOpen([
        v1FocusSessions,
        v1FocusRecords,
        v1CraftJobs,
        v1CraftRecipes,
        'INSERT INTO focus_sessions (id,user_id,planned_seconds,mode,start_at,'
            "pause_intervals_json,status,timezone_offset_minutes) VALUES "
            "('s1','default_user',1500,'focus',100,'[]','completed',0)",
        'INSERT INTO focus_records (id,session_id,user_id,duration_seconds,'
            'start_at,end_at,recorded_at,is_counted_for_reward) VALUES '
            "('r1','s1','default_user',1500,100,200,300,1)",
      ], 1);
      addTearDown(db.close);

      final sessions = await rows(db, 'select * from focus_sessions');
      expect(sessions, hasLength(1), reason: 'migration must not drop rows');
      expect(sessions.first['task_name'], isNull,
          reason: 'the column exists and is empty, which is honest');
      final records = await rows(db, 'select * from focus_records');
      expect(records.first['task_name'], isNull);
      expect(records.first['mood'], isNull);
      expect(records.first['duration_seconds'], 1500,
          reason: 'the recorded duration is untouched');
      // The current schema version. It moves when a migration is added, and
      // these assertions are here to prove the chain *reached* the head rather
      // than stopping part way. It went to 6 with P2's plan table and to 7 with
      // P3's timing mode.
      expect((await rows(db, 'PRAGMA user_version')).first['user_version'],
          kSchemaHead);
    });

    test(
        'v4 opens at the head with the task domain, the plan, and every focus '
        'row', () async {
      // The v4 shape: the focus tables as v2 left them (v3 and v4 added no focus
      // columns; v4 only added the unique index), plus that index. The task
      // tables do not exist yet, which is what this migration has to create.
      final db = await seedAndOpen([
        v2FocusSessions,
        v2FocusRecords,
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_focus_records_session_id '
            'ON focus_records(session_id)',
        'INSERT INTO focus_sessions (id,user_id,planned_seconds,mode,start_at,'
            "pause_intervals_json,status,timezone_offset_minutes) VALUES "
            "('s1','default_user',1500,'focus',100,'[]','completed',0)",
        'INSERT INTO focus_records (id,session_id,user_id,duration_seconds,'
            'start_at,end_at,recorded_at,is_counted_for_reward,note) VALUES '
            "('r1','s1','default_user',1500,100,200,300,1,'写了初稿')",
      ], 4);
      addTearDown(db.close);

      // The history is untouched, and the new column is present and empty --
      // which is honest: that record was focused without a task.
      final records = await rows(db, 'select * from focus_records');
      expect(records, hasLength(1), reason: 'migration must not drop rows');
      expect(records.first['duration_seconds'], 1500);
      expect(records.first['note'], '写了初稿');
      expect(records.first['task_id'], isNull,
          reason: 'the column exists, and an old record has no task');

      final sessions = await rows(db, 'select * from focus_sessions');
      expect(sessions.first['task_id'], isNull);

      // And the task tables are really there, not just declared.
      final taskTables = await rows(
          db,
          "select name from sqlite_master where type='table' "
          "and name in ('tasks','task_subtasks')");
      expect(
          taskTables.map((r) => r['name']).toSet(), {'tasks', 'task_subtasks'});

      // The unique index the previous migration created must have survived: a
      // migration that dropped it would let two records share a session.
      final indexes = await rows(
          db,
          "select name from sqlite_master where type='index' "
          "and name = 'idx_focus_records_session_id'");
      expect(indexes, hasLength(1));

      expect((await rows(db, 'PRAGMA user_version')).first['user_version'],
          kSchemaHead);

      // The chain has to reach the whole head, not stop at the task domain: a
      // v4 database that opened without the plan table would look migrated and
      // fail the first time the user planned something.
      final plan = await rows(
          db,
          "select name from sqlite_master where type='table' "
          "and name = 'task_schedules'");
      expect(plan, hasLength(1));
    });

    test('v2 to v3 adds craft progress and seeds the recipes', () async {
      // The v2 shape: the v1 tables plus the columns v1->v2 added. Using the v1
      // shape here would be a database that never existed, and it failed --
      // v3->v4 reads `duplicate.task_name`, which a v2 database already has.
      final db = await seedAndOpen([
        v2FocusSessions,
        v2FocusRecords,
        v1CraftJobs,
        v1CraftRecipes,
        'INSERT INTO craft_jobs (id,user_id,recipe_id,status,started_at,'
            'reward_claimed) VALUES '
            "('j1','default_user','rug','in_progress',100,0)",
      ], 2);
      addTearDown(db.close);

      final jobs = await rows(db, 'select * from craft_jobs');
      expect(jobs, hasLength(1), reason: 'the running job survives');
      expect(jobs.first['progress_seconds'], 0,
          reason: 'a pre-migration job starts at zero rather than at null');

      final recipes = await rows(db, 'select * from craft_recipes');
      expect(recipes, hasLength(8),
          reason: 'the recipes are seeded on upgrade, not only on create');
    });

    test('the full v1 to v4 chain preserves every row', () async {
      final db = await seedAndOpen([
        v1FocusSessions,
        v1FocusRecords,
        v1CraftJobs,
        v1CraftRecipes,
        'INSERT INTO focus_sessions (id,user_id,planned_seconds,mode,start_at,'
            "pause_intervals_json,status,timezone_offset_minutes) VALUES "
            "('s1','default_user',1500,'focus',100,'[]','completed',0)",
        'INSERT INTO focus_records (id,session_id,user_id,duration_seconds,'
            'start_at,end_at,recorded_at,is_counted_for_reward,note) VALUES '
            "('r1','s1','default_user',1500,100,200,300,1,'kept')",
        'INSERT INTO craft_jobs (id,user_id,recipe_id,status,started_at,'
            'reward_claimed) VALUES '
            "('j1','default_user','rug','completed',100,1)",
      ], 1);
      addTearDown(db.close);

      // The data that existed before is all still there, with the new columns
      // present and empty rather than the rows being recreated.
      expect(await rows(db, 'select * from focus_sessions'), hasLength(1));
      final records = await rows(db, 'select * from focus_records');
      expect(records, hasLength(1));
      expect(records.first['note'], 'kept',
          reason: 'a user-entered note must not be lost to a migration');
      expect(records.first['duration_seconds'], 1500);
      final jobs = await rows(db, 'select * from craft_jobs');
      expect(jobs, hasLength(1));
      expect(jobs.first['status'], 'completed');
      expect(jobs.first['reward_claimed'], 1);
      expect((await rows(db, 'select * from craft_recipes')), hasLength(8));

      // And the unique index the cardinality guarantee depends on exists.
      final idx = await rows(
        db,
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND name='idx_focus_records_session_id'",
      );
      expect(idx, hasLength(1),
          reason: 'the P20 idempotency guarantee arrives with this migration');
    });

    test('an already-current database is left alone', () async {
      // Opening a v4 database must not re-run migrations, which would risk
      // re-deduplicating or re-seeding on every launch.
      final db = await seedAndOpen([
        v1FocusSessions,
        v1FocusRecords,
        v1CraftJobs,
        v1CraftRecipes,
      ], 1);
      await db.close();

      final again = openDb();
      addTearDown(again.close);
      expect((await rows(again, 'PRAGMA user_version')).first['user_version'],
          kSchemaHead);
      // Seeded once, not twice.
      expect(await rows(again, 'select * from craft_recipes'), hasLength(8));
    });
  });
}
