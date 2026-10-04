import 'dart:io';
import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_action_resolver.dart';
import 'package:cozy_focus_app/presentation/companion/room/room_simulation.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MutableClock implements FocusClock {
  DateTime _now;
  _MutableClock(this._now);
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
}

/// The golden business flow, end to end, in one place.
///
/// ## What this is for
///
/// Every other suite tests a slice. This walks the whole chain a real user takes
/// — adopt, choose, focus, pause, resume, complete, save, settle, grow, craft,
/// own, place, walk, remember, restart — and asserts the **cardinality** that the
/// slices cannot see from where they stand:
///
/// > one session → exactly one record → exactly one settlement → exactly one reward.
///
/// A duplicate settlement is invisible to a unit test of `RewardService` and
/// invisible to a widget test of the reward page. It is only visible from here.
///
/// ## The clock is injected and time is never waited
///
/// The session engine reads `FocusClock`, so `advance()` moves a 30-minute
/// session in microseconds. Nothing in this file sleeps.
///
/// ## Setup seeds prerequisites, never the outcome
///
/// Crafting a rug requires an owned recipe and accumulated focus seconds, so the
/// test starts a craft job — a precondition. It does **not** write the XP, the
/// record, the ledger row, the memory or the inventory item; those are what the
/// assertions are about, and writing them would make the test agree with itself.
void main() {
  late AppDatabase db;
  late _MutableClock clock;
  late ProviderContainer container;
  late Directory selectionDir;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _MutableClock(DateTime(2026, 10, 3, 10, 0, 0));
    // A real directory, so the companion selection is genuinely persisted. An
    // in-memory store here would make the restart assertion below vacuous: it
    // would assert that a value written two lines earlier is still readable two
    // lines later, in the same object.
    selectionDir = Directory.systemTemp.createTempSync('cozy_golden_sel_');
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider.overrideWithValue(clock),
        companionSelectionStoreProvider.overrideWithValue(
          FileCompanionSelectionStore(directoryOverride: selectionDir),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    // Best-effort. On Windows the selection file's handle can outlive the read
    // by a moment, and a failed cleanup is a harness annoyance rather than a
    // result -- it must not turn a passing test red.
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        if (selectionDir.existsSync()) {
          selectionDir.deleteSync(recursive: true);
        }
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    // All attempts failed. Say so rather than abandoning the directory in
    // silence -- on a machine where something holds the handle this would
    // otherwise accumulate temp directories with no signal at all.
    // ignore: avoid_print
    print('WARNING: could not remove ${selectionDir.path}; leaving it behind');
  });

  /// A container over the same database — a restart, not a reset.
  /// A container over the same database *and the same selection file*.
  ///
  /// The file matters: `companionSelectionStoreProvider` is overridden in both
  /// places, so pointing the restart at a fresh store would make the
  /// "survives a restart" assertion below prove nothing.
  ProviderContainer restart() => ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          focusClockProvider.overrideWithValue(clock),
          companionSelectionStoreProvider.overrideWithValue(
            FileCompanionSelectionStore(directoryOverride: selectionDir),
          ),
        ],
      );

  Future<List<Map<String, Object?>>> rows(String sql) async {
    final result = await db.customSelect(sql).get();
    return result.map((r) => r.data).toList();
  }

  group('the golden flow', () {
    test('fresh user through focus, craft, room, memory and restart', () async {
      // ── 1. fresh user ────────────────────────────────────────────────────
      await container.read(homeControllerProvider.notifier).loadHomeData();
      final pet = await db.petDao.findPetByUser('default_user');
      expect(pet, isNotNull, reason: 'a fresh user adopts the companion');
      expect(await db.petDao.findProgress(pet!.id), isNotNull);

      // ── 2. companion selection ───────────────────────────────────────────
      final selection = container.read(companionSelectionProvider.notifier);
      expect(await selection.select(CompanionId.rabbit), isTrue);
      expect(container.read(companionSelectionProvider), CompanionId.rabbit);

      // ── 3. craft prerequisite (a job, not a result) ──────────────────────
      final recipes = await db.craftDao.findAllRecipes();
      final rug = recipes.firstWhere((r) => r.id == 'rug');
      expect(rug.requiredMinutes, 30,
          reason: 'the flow below is sized to this recipe; if it changes, '
              'resize the session rather than letting the test drift');
      await container
          .read(craftEngineProvider)
          .startJob('default_user', rug.id);

      // ── 4. focus start ───────────────────────────────────────────────────
      final focus = container.read(focusSessionControllerProvider.notifier);
      final session = await focus.startSession(
        userId: 'default_user',
        plannedSeconds: 3600,
        mode: FocusMode.focus,
        taskName: 'Golden flow',
      );
      expect(session.status, FocusSessionStatus.running);
      expect(container.read(focusSessionControllerProvider).session?.status,
          FocusSessionStatus.running);

      // ── 5. pause ─────────────────────────────────────────────────────────
      clock.advance(const Duration(minutes: 10));
      await focus.pauseSession();
      expect(container.read(focusSessionControllerProvider).session?.status,
          FocusSessionStatus.paused);

      // ── 6. resume ────────────────────────────────────────────────────────
      await focus.resumeSession();
      clock.advance(const Duration(minutes: 20));

      // ── 7. complete ──────────────────────────────────────────────────────
      final finished = await focus.completeSession();
      expect(finished.status, FocusSessionStatus.finishing,
          reason: 'complete stops the clock; it does not settle');

      // Nothing is settled yet — this is the state the completion page shows.
      expect((await rows('select count(*) as n from focus_records')).first['n'],
          0);

      // ── 8. save ──────────────────────────────────────────────────────────
      await focus.saveSession();

      // ── 9-11. record → settlement → reward, exactly once each ────────────
      final records = await rows('select * from focus_records');
      expect(records, hasLength(1), reason: 'one session, one record');
      expect(records.first['duration_seconds'], 1800,
          reason: '30 minutes of the 60-minute plan actually elapsed');

      final ledger = await rows('select * from reward_ledger');
      expect(ledger, hasLength(1), reason: 'one session, one settlement');
      // RewardService: 2 coins and 5 XP per whole minute.
      expect(ledger.first['focus_coins_earned'], 60);
      expect(ledger.first['experience_earned'], 150);

      // ── 12. growth ───────────────────────────────────────────────────────
      final progress = await db.petDao.findProgress(pet.id);
      expect(progress!.experiencePoints, 150,
          reason: 'the XP the ledger promised is the XP the pet holds');
      expect(progress.level, 2, reason: '150 XP at 100/level is level 2');

      // ── 13-14. craft completes and the item is owned ─────────────────────
      final job = await db.craftDao.findJobById(
          (await rows('select id from craft_jobs')).first['id']! as String);
      expect(job!.status, CraftJobStatus.completed,
          reason: '30 focus minutes satisfies a 30-minute recipe');
      final inventory = await db.craftDao.findInventory('default_user');
      expect(inventory.map((i) => i.itemId), contains('rug'));

      // ── 15. room placement ───────────────────────────────────────────────
      final craft = container.read(craftControllerProvider.notifier);
      await craft.loadAll();
      final owned = (await db.craftDao.findInventory('default_user'))
          .firstWhere((i) => i.itemId == 'rug');
      expect(owned.quantity, greaterThan(0));
      await craft.placeItem('rug', 0.3, 0.62);
      final placed = await db.craftDao.findRoomItems('default_user');
      expect(placed, hasLength(1), reason: 'the rug is in the room');

      // ── 16-18. anchor, walk, furniture use ───────────────────────────────
      final room = container.read(roomSimulationProvider.notifier);
      room.start();
      room.evaluateNow();
      final state = container.read(roomSimulationProvider);
      expect(state.activity.anchorId, isNotEmpty,
          reason: 'the companion is bound to an anchor');
      // The simulation commits to the rug and the effect lands on the vitals.
      expect(state.cause, isNotNull);
      room.requestAction(
        itemId: 'rug',
        actionId: 'sit',
        roomItemId: placed.first.id,
      );
      expect(
          container.read(roomSimulationProvider).activity.anchorId, isNotEmpty);
      room.stop();

      // ── 19. memory ───────────────────────────────────────────────────────
      final memories = await db.petDao.findMemories(pet.id);
      // Two, and that is correct rather than a duplicate: 150 XP both makes this
      // the first settled session AND crosses level 1 -> 2, and
      // `CompanionMemory.earnedBy` earns a memory for each. An expectation of
      // one here was wrong, not the product.
      expect(memories, hasLength(2));
      expect(memories.map((m) => m.memoryType).toSet(),
          {'first_focus', 'level_up'});

      // ── 20. restart ──────────────────────────────────────────────────────
      final after = restart();
      addTearDown(after.dispose);
      // Read the persisted selection back from the file the app would read on
      // the next launch, **without selecting anything first**.
      //
      // Selecting would defeat the point twice over: `CompanionSelection.select`
      // writes the value before the assertion reads it, and it short-circuits on
      // an unchanged state — so the assertion would observe its own write rather
      // than what survived the restart, and a regression in which the first
      // container's `write()` silently failed would leave it green.
      final persisted = await FileCompanionSelectionStore(
        directoryOverride: selectionDir,
      ).read();
      expect(persisted, CompanionId.rabbit,
          reason: 'the chosen companion must survive a restart, read back from '
              'the file rather than re-selected');
      expect(await db.craftDao.findRoomItems('default_user'), hasLength(1));
      expect((await db.petDao.findProgress(pet.id))!.experiencePoints, 150);
      expect(await db.petDao.findMemories(pet.id), hasLength(2));

      // ── 21. daily routine ────────────────────────────────────────────────
      // The room decides by the clock, so moving the clock changes the routine
      // without touching any state. Midday and late night must not agree.
      final midday =
          _routineCauseFor(container, clock, DateTime(2026, 10, 3, 12));
      final night =
          _routineCauseFor(container, clock, DateTime(2026, 10, 3, 23, 30));
      expect(midday, isNot(night),
          reason: 'the companion must not behave identically at noon and at '
              'half past eleven at night');
    });
  });

  group('cardinality survives repetition', () {
    test('a repeated save is refused, and cannot double the record', () async {
      await container.read(homeControllerProvider.notifier).loadHomeData();
      final focus = container.read(focusSessionControllerProvider.notifier);
      await focus.startSession(
        userId: 'default_user',
        plannedSeconds: 600,
        mode: FocusMode.focus,
      );
      clock.advance(const Duration(minutes: 5));
      await focus.completeSession();
      await focus.saveSession();

      // Saving clears the in-memory session, so a second save is a *guarded
      // misuse* and throws rather than writing again. That is stronger than
      // idempotency, and it is why `AppBottomNav` gates on `isCompleted` before
      // flushing -- after a save that flag is false, so the double call the P14
      // fix could otherwise make is unreachable.
      await expectLater(focus.saveSession(), throwsA(isA<StateError>()));

      expect(await rows('select * from focus_records'), hasLength(1));
      expect(await rows('select * from reward_ledger'), hasLength(1));
    });

    test('recovery of an abandoned session settles it exactly once', () async {
      // A session stranded in `finishing` is what a process death leaves behind:
      // `complete` persisted the status but nothing settled it. This is the path
      // `recoverAbandonedSessions` exists for, and the only path that actually
      // reaches the idempotency guard -- recovery skips a session still held in
      // memory, so an already-saved session is never a candidate at all. An
      // earlier version of this test saved first and therefore proved nothing.
      await container.read(homeControllerProvider.notifier).loadHomeData();
      final focus = container.read(focusSessionControllerProvider.notifier);
      await focus.startSession(
        userId: 'default_user',
        plannedSeconds: 600,
        mode: FocusMode.focus,
      );
      clock.advance(const Duration(minutes: 5));
      await focus.completeSession();

      expect((await rows('select status from focus_sessions')).first['status'],
          'finishing',
          reason: 'this is the state a killed process leaves');

      // The process dies: a fresh container over the same database.
      final revived = restart();
      addTearDown(revived.dispose);
      final revivedFocus =
          revived.read(focusSessionControllerProvider.notifier);

      await revivedFocus.recoverAbandonedSessions('default_user');
      expect(await rows('select * from focus_records'), hasLength(1),
          reason: 'the stranded session is settled on the next launch');
      expect(await rows('select * from reward_ledger'), hasLength(1));

      // Recovering again must not write a second one.
      await revivedFocus.recoverAbandonedSessions('default_user');
      await revivedFocus.recoverAbandonedSessions('default_user');
      expect(await rows('select * from focus_records'), hasLength(1));
      expect(await rows('select * from reward_ledger'), hasLength(1));
      // 5 minutes does not cross a level, so this session earns only the
      // first-focus memory -- and recovery must not add a second copy of it.
      expect(
          await db.petDao.findMemories(
            (await db.petDao.findPetByUser('default_user'))!.id,
          ),
          hasLength(1));
    });

    test('the database itself refuses a second record for one session',
        () async {
      // The negative proof for the cardinality assertions above, and the reason
      // they are worth having.
      //
      // Disabling the Dart-side guard in `_persistRecord` does **not** make the
      // recovery test fail -- it was tried, and the suite stayed green. The
      // guarantee is not that check, which is an optimisation; it is the unique
      // index on `session_id` declared at `focus_records_table.dart:22`. This
      // proves the index is load-bearing by trying to defeat it.
      await container.read(homeControllerProvider.notifier).loadHomeData();
      final focus = container.read(focusSessionControllerProvider.notifier);
      final session = await focus.startSession(
        userId: 'default_user',
        plannedSeconds: 600,
        mode: FocusMode.focus,
      );
      clock.advance(const Duration(minutes: 5));
      await focus.completeSession();
      await focus.saveSession();
      expect(await rows('select * from focus_records'), hasLength(1));

      // A second record for the same session under a different record id: the
      // shape a duplicate settlement would actually take.
      await expectLater(
        db.customInsert(
          'insert into focus_records (id, session_id, user_id, duration_seconds,'
          ' start_at, end_at, recorded_at, is_counted_for_reward)'
          " values ('duplicate_probe', ?, 'default_user', 300, 0, 0, 0, 1)",
          variables: [Variable.withString(session.id)],
        ),
        throwsA(anything),
        reason: 'the unique index on session_id is the real guard',
      );
      expect(await rows('select * from focus_records'), hasLength(1));
    });

    test('a second session adds exactly one more of each', () async {
      await container.read(homeControllerProvider.notifier).loadHomeData();
      final focus = container.read(focusSessionControllerProvider.notifier);
      for (var i = 0; i < 2; i++) {
        await focus.startSession(
          userId: 'default_user',
          plannedSeconds: 600,
          mode: FocusMode.focus,
        );
        clock.advance(const Duration(minutes: 5));
        await focus.completeSession();
        await focus.saveSession();
      }
      expect(await rows('select * from focus_records'), hasLength(2));
      expect(await rows('select * from reward_ledger'), hasLength(2));
      // Two sessions of 5 minutes at 5 XP = 50.
      expect(
        (await db.petDao.findProgress(
          (await db.petDao.findPetByUser('default_user'))!.id,
        ))!
            .experiencePoints,
        50,
      );
    });
  });

  group('P14 regression: leaving by the tab bar still settles', () {
    test('the destination reads settled truth, not a pending zero', () async {
      // The defect P14 fixed: the completion page promised +XP, the user tapped
      // a tab, and the records page answered 0 minutes until a restart. The
      // flush `AppBottomNav` performs is `saveSession`, so this asserts the
      // state that call produces is the one the destination reads.
      await container.read(homeControllerProvider.notifier).loadHomeData();
      final focus = container.read(focusSessionControllerProvider.notifier);
      await focus.startSession(
        userId: 'default_user',
        plannedSeconds: 600,
        mode: FocusMode.focus,
      );
      clock.advance(const Duration(minutes: 8));
      await focus.completeSession();

      // Nothing settled while the completion page is on screen.
      expect((await rows('select count(*) as n from focus_records')).first['n'],
          0);

      // What the tab bar does before navigating.
      await focus.saveSession();

      // What the records page reads.
      expect((await rows('select count(*) as n from focus_records')).first['n'],
          1);
      expect((await rows('select count(*) as n from reward_ledger')).first['n'],
          1);
      expect(
        (await db.petDao.findProgress(
          (await db.petDao.findPetByUser('default_user'))!.id,
        ))!
            .experiencePoints,
        greaterThan(0),
        reason: 'the growth page must not read zero after the promise',
      );
    });
  });
}

/// The room's decision cause at [when], with the clock moved there.
///
/// Rebuilt from the room's own resolver rather than restated here, so this
/// measures the shipped decision rather than a copy of it.
RoomDecisionCause _routineCauseFor(
  ProviderContainer container,
  _MutableClock clock,
  DateTime when,
) {
  final current = clock.now();
  clock.advance(when.difference(current));
  final room = container.read(roomSimulationProvider.notifier);
  room.start();
  // Let any live player commitment expire before reading.
  //
  // A dwell is measured in *loop* time, and this helper stops the loop after
  // each read, so no loop time accrues between calls. Without this the read
  // would return the action the player chose earlier rather than the routine's
  // decision for this hour -- and `evaluateNow` no longer bypasses a live
  // commitment, which is the whole point of P28.
  room.debugAdvance(const Duration(seconds: 40));
  room.evaluateNow();
  final cause = container.read(roomSimulationProvider).cause;
  room.stop();
  return cause;
}
