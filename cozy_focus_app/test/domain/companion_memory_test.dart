// P9 — companion memory.
//
// Three layers are covered:
//   1. the pure decision (CompanionMemory.earnedBy), which both settlement
//      paths share;
//   2. the atomic path, through the real SettlementDao transaction;
//   3. the sequential fallback path in RewardService.
//
// The point of covering 2 and 3 separately is that they must not disagree: a
// user would otherwise hold different memories depending on which path ran,
// with nothing anywhere reporting the difference.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide
        FocusSession,
        Pet,
        PetMemory,
        CraftJob,
        CraftRecipe,
        InventoryItem,
        RoomItem;
import 'package:cozy_focus_app/data/repositories/drift_pet_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_reward_ledger_repository.dart';
import 'package:cozy_focus_app/domain/growth/growth_level_curve.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/focus_session.dart';
import 'package:cozy_focus_app/domain/models/pet_models.dart';
import 'package:cozy_focus_app/domain/models/sync_models.dart';
import 'package:cozy_focus_app/domain/services/companion_memory.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/domain/services/reward_service.dart';

class _FixedClock implements FocusClock {
  final DateTime _t;
  _FixedClock(this._t);
  @override
  DateTime now() => _t;
}

FocusSession _session({
  required String id,
  required String userId,
  required int elapsedSeconds,
}) {
  final base = DateTime(2026, 1, 1, 10);
  return FocusSession(
    id: id,
    userId: userId,
    taskName: 'Test Task',
    categoryId: 'study',
    mode: FocusMode.focus,
    plannedSeconds: elapsedSeconds,
    status: FocusSessionStatus.completed,
    startAt: base,
    endAt: base.add(Duration(seconds: elapsedSeconds)),
    pauseIntervals: const [],
    timezoneOffsetMinutes: 480,
  );
}

void main() {
  const userId = 'user-p9';
  const petId = 'pet-p9';
  final settledAt = DateTime(2026, 6, 1, 9);

  /// Under the long-session threshold, so a test about another rule is not
  /// silently also testing this one.
  const shortSession = 25 * 60;

  // ── 1. The pure decision ────────────────────────────────────────────────
  group('P9 the decision needs no invented number', () {
    test('the first settlement earns first_focus, the second does not', () {
      final first = CompanionMemory.earnedBy(
        petId: petId,
        settledCount: 1,
        previousXp: 0,
        newXp: 0,
        at: settledAt,
        sessionSeconds: shortSession,
      );
      expect(first.map((m) => m.memoryType), [PetMemoryType.firstFocus]);

      final second = CompanionMemory.earnedBy(
        petId: petId,
        settledCount: 2,
        previousXp: 0,
        newXp: 0,
        at: settledAt,
        sessionSeconds: shortSession,
      );
      expect(second, isEmpty);
    });

    test('crossing a level earns level_up, and the threshold is the curve', () {
      final previousXp = GrowthLevelCurve.xpForLevel(2) - 5;
      final newXp = GrowthLevelCurve.xpForLevel(2) + 5;

      final earned = CompanionMemory.earnedBy(
        petId: petId,
        settledCount: 2,
        previousXp: previousXp,
        newXp: newXp,
        at: settledAt,
        sessionSeconds: shortSession,
      );

      expect(earned.map((m) => m.memoryType), [PetMemoryType.levelUp]);
      expect(earned.single.content, contains('Lv.2'));
    });

    test('a settlement that does not cross a level earns nothing', () {
      final earned = CompanionMemory.earnedBy(
        petId: petId,
        settledCount: 5,
        previousXp: 10,
        newXp: 35,
        at: settledAt,
        sessionSeconds: shortSession,
      );
      expect(earned, isEmpty);
    });

    test('the same pet, type and moment produce one id, not two', () {
      PetMemory only(int count) => CompanionMemory.earnedBy(
            petId: petId,
            settledCount: count,
            previousXp: 0,
            newXp: 0,
            at: settledAt,
            sessionSeconds: shortSession,
          ).single;

      expect(only(1).id, only(1).id);
    });
  });

  // ── 1b. D4 — the one rule that did need a number ────────────────────────
  group('D4 a long session is remembered, and the threshold is 50 minutes', () {
    List<String> typesFor(int seconds) => CompanionMemory.earnedBy(
          petId: petId,
          settledCount: 5, // not the first, so first_focus stays out of the way
          previousXp: 10, // no level crossing either
          newXp: 35,
          at: settledAt,
          sessionSeconds: seconds,
        ).map((m) => m.memoryType).toList();

    test('the approved threshold is 50 minutes, stated once', () {
      expect(CompanionMemory.longSessionThreshold, 50 * 60);
    });

    test('49:59 is not long enough', () {
      expect(typesFor(50 * 60 - 1), isNot(contains(PetMemoryType.longSession)));
    });

    test('exactly 50:00 is', () {
      // The boundary is inclusive: "达到 50 分钟" means reaching it counts.
      expect(typesFor(50 * 60), contains(PetMemoryType.longSession));
    });

    test('a much longer session is also remembered, and says its own length',
        () {
      final earned = CompanionMemory.earnedBy(
        petId: petId,
        settledCount: 5,
        previousXp: 10,
        newXp: 35,
        at: settledAt,
        sessionSeconds: 90 * 60,
      );
      final long =
          earned.firstWhere((m) => m.memoryType == PetMemoryType.longSession);
      // The content names the session, not the threshold — a 90-minute session
      // must not read as "50 minutes".
      expect(long.content, contains('90'));
      expect(long.content, isNot(contains('50')));
    });

    test('the threshold is not reachable by a session that did not run', () {
      // Zero seconds is what an unstarted or instantly-ended session settles as.
      expect(typesFor(0), isEmpty);
    });

    test('long_session is inside the closed set, so nothing invented it', () {
      for (final t in typesFor(60 * 60)) {
        expect(PetMemoryType.all, contains(t));
      }
    });
  });

  // ── 2 and 3. Both settlement paths ──────────────────────────────────────
  group('P9 settlement records memories', () {
    late AppDatabase db;
    late DriftPetRepository petRepo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      petRepo = DriftPetRepository(db.petDao);

      await petRepo.savePet(Pet(
        id: petId,
        userId: userId,
        characterId: 'mochi',
        species: PetSpecies.dog,
        name: 'Mochi',
        adoptedAt: settledAt,
      ));
      await petRepo.savePetProgress(PetProgress(
        id: 'progress-$petId',
        petId: petId,
        level: 1,
        experiencePoints: 0,
        totalFocusMinutes: 0,
        happinessScore: 50,
        updatedAt: settledAt,
      ));
    });

    tearDown(() => db.close());

    /// The production path: one Drift transaction.
    Future<void> settleAtomically(String sessionId, int seconds,
        {DateTime? at}) async {
      final entry = RewardLedger(
        sessionId: sessionId,
        userId: userId,
        focusCoinsEarned: (seconds / 60).floor() * 2,
        experienceEarned: (seconds / 60).floor() * 5,
        settledAt: at ?? settledAt,
      );
      await db.settlementDao.settleAtomically(
        entry: entry,
        addedFocusSeconds: seconds,
        now: at ?? settledAt,
      );
    }

    /// The fallback path: sequential writes, no atomic settlement.
    Future<void> settleSequentially(String sessionId, int seconds) async {
      final service = RewardService(
        ledgerRepo: DriftRewardLedgerRepository(db.rewardLedgerDao),
        petRepo: petRepo,
        clock: _FixedClock(settledAt),
      );
      await service.settle(
          _session(id: sessionId, userId: userId, elapsedSeconds: seconds));
    }

    for (final path in <String, Future<void> Function(String, int)>{
      'atomic': settleAtomically,
      'sequential': settleSequentially,
    }.entries) {
      group('via the ${path.key} path', () {
        test('the first settled session records first_focus', () async {
          await path.value('s1', 300);

          final memories = await petRepo.findMemories(petId);
          expect(memories.map((m) => m.memoryType),
              contains(PetMemoryType.firstFocus));
        });

        test('a later session records no second first_focus', () async {
          await path.value('s1', 300);
          await path.value('s2', 300);

          final memories = await petRepo.findMemories(petId);
          expect(
            memories.where((m) => m.memoryType == PetMemoryType.firstFocus),
            hasLength(1),
          );
        });

        test('re-settling the same session records nothing new', () async {
          await path.value('s1', 300);
          final before = (await petRepo.findMemories(petId)).length;

          await path.value('s1', 300);

          expect((await petRepo.findMemories(petId)).length, before);
        });

        test('crossing a level records level_up', () async {
          // 25 minutes at 5 XP per minute is 125 XP, past the first boundary.
          await path.value('s1', 25 * 60);

          final memories = await petRepo.findMemories(petId);
          expect(memories.map((m) => m.memoryType),
              contains(PetMemoryType.levelUp));
        });

        test('a session inside the same level records no level_up', () async {
          await path.value('s1', 5 * 60);

          final memories = await petRepo.findMemories(petId);
          expect(memories.map((m) => m.memoryType),
              isNot(contains(PetMemoryType.levelUp)));
        });

        test('every recorded type is inside the closed vocabulary', () async {
          await path.value('s1', 25 * 60);
          await path.value('s2', 5 * 60);

          final memories = await petRepo.findMemories(petId);
          expect(memories, isNotEmpty);
          for (final memory in memories) {
            expect(PetMemoryType.all, contains(memory.memoryType));
          }
        });

        test('the memory belongs to the real pet, at the settlement time',
            () async {
          await path.value('s1', 300);

          final memory = (await petRepo.findMemories(petId))
              .firstWhere((m) => m.memoryType == PetMemoryType.firstFocus);
          expect(memory.petId, petId);
          expect(memory.happenedAt, settledAt);
          expect(memory.content, isNotEmpty);
        });
      });
    }

    test('recording a memory does not change what settlement awarded',
        () async {
      await settleAtomically('s1', 25 * 60);

      // 25 minutes: 125 XP, 50 coins, 25 focus minutes, happiness +5.
      final progress = await petRepo.findPetProgress(petId);
      expect(progress!.experiencePoints, 125);
      expect(progress.totalFocusMinutes, 25);
      expect(progress.happinessScore, 55);
      expect(GrowthLevelCurve.levelForXp(progress.experiencePoints), 2);

      final ledger = await DriftRewardLedgerRepository(db.rewardLedgerDao)
          .findBySessionId('s1');
      expect(ledger!.focusCoinsEarned, 50);
      expect(ledger.experienceEarned, 125);

      // And no inventory was touched: memory is not a reward.
      final inventory = await db.craftDao.findInventory(userId);
      expect(inventory, isEmpty);
    });
  });

  // ── Path parity, on its own databases ───────────────────────────────────
  //
  // Kept out of the group above so only one in-memory database is ever open:
  // Drift warns when two AppDatabase instances coexist, and the warning is
  // legitimate even when the executors are separate.
  group('P9 both settlement paths agree', () {
    Future<List<String>> rememberedTypes({
      required bool atomic,
      int seconds = 25 * 60,
    }) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = DriftPetRepository(database.petDao);
      // Derived from the duration the same way RewardService derives them, so
      // the two paths are handed identical facts rather than two sets that
      // happen to match at 25 minutes.
      final minutes = seconds ~/ 60;
      try {
        await repo.savePet(Pet(
          id: petId,
          userId: userId,
          characterId: 'mochi',
          species: PetSpecies.dog,
          name: 'Mochi',
          adoptedAt: settledAt,
        ));
        await repo.savePetProgress(PetProgress(
          id: 'progress-$petId',
          petId: petId,
          level: 1,
          experiencePoints: 0,
          totalFocusMinutes: 0,
          happinessScore: 50,
          updatedAt: settledAt,
        ));

        if (atomic) {
          await database.settlementDao.settleAtomically(
            entry: RewardLedger(
              sessionId: 'p1',
              userId: userId,
              focusCoinsEarned: minutes * 2,
              experienceEarned: minutes * 5,
              settledAt: settledAt,
            ),
            addedFocusSeconds: seconds,
            now: settledAt,
          );
        } else {
          await RewardService(
            ledgerRepo: DriftRewardLedgerRepository(database.rewardLedgerDao),
            petRepo: repo,
            clock: _FixedClock(settledAt),
          ).settle(_session(id: 'p1', userId: userId, elapsedSeconds: seconds));
        }

        final types = (await repo.findMemories(petId))
            .map((m) => m.memoryType)
            .toList()
          ..sort();
        return types;
      } finally {
        await database.close();
      }
    }

    test('the same inputs produce the same memories on either path', () async {
      final atomic = await rememberedTypes(atomic: true);
      final sequential = await rememberedTypes(atomic: false);

      expect(atomic, isNotEmpty);
      expect(sequential, atomic);
    });

    test('D4 a 50-minute session reaches the database on both paths', () async {
      // The rule is only real if the *real* settlement paths write it. The pure
      // tests above would pass even if neither call site passed the duration.
      for (final atomic in const [true, false]) {
        final types = await rememberedTypes(atomic: atomic, seconds: 50 * 60);
        expect(types, contains(PetMemoryType.longSession),
            reason: 'the ${atomic ? "atomic" : "sequential"} path did not '
                'record the long session');
      }
    });

    test('D4 a 25-minute session records no long_session on either path',
        () async {
      for (final atomic in const [true, false]) {
        final types = await rememberedTypes(atomic: atomic);
        expect(types, isNot(contains(PetMemoryType.longSession)),
            reason: 'the ${atomic ? "atomic" : "sequential"} path invented a '
                'long session from a short one');
      }
    });

    test('D4 and the two paths still agree on a long session', () async {
      final atomic = await rememberedTypes(atomic: true, seconds: 55 * 60);
      final sequential = await rememberedTypes(atomic: false, seconds: 55 * 60);
      expect(sequential, atomic);
      expect(atomic, contains(PetMemoryType.longSession));
    });
  });
}
