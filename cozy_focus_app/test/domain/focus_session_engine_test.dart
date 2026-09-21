import 'package:flutter_test/flutter_test.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/focus_session.dart';
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/models/pet_models.dart';
import 'package:cozy_focus_app/domain/models/sync_models.dart';
import 'package:cozy_focus_app/domain/repositories/i_focus_session_repository.dart';
import 'package:cozy_focus_app/domain/repositories/i_focus_record_repository.dart';
import 'package:cozy_focus_app/domain/repositories/i_reward_ledger_repository.dart';
import 'package:cozy_focus_app/domain/repositories/i_pet_repository.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/domain/services/focus_session_engine.dart';
import 'package:cozy_focus_app/domain/services/reward_service.dart';

// ── In-memory stubs ──────────────────────────────────────────────────────────

class StubClock implements FocusClock {
  DateTime _now;
  StubClock(this._now);
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
}

class StubSessionRepo implements IFocusSessionRepository {
  final Map<String, FocusSession> _store = {};

  @override
  Future<void> save(FocusSession s) async => _store[s.id] = s;
  @override
  Future<void> update(FocusSession s) async => _store[s.id] = s;
  @override
  Future<FocusSession?> findById(String id) async => _store[id];
  @override
  Future<List<FocusSession>> findActive(String userId) async =>
      _store.values.where((s) => s.isActive).toList();
  @override
  Future<List<FocusSession>> findUnfinished(String userId) async =>
      _store.values.where((s) => s.isUnfinished).toList();
  @override
  Future<List<FocusSession>> findRecent(String userId,
          {int limit = 20}) async =>
      _store.values.toList();
  @override
  Future<void> delete(String id) async => _store.remove(id);
}

class StubRecordRepo implements IFocusRecordRepository {
  final List<FocusRecord> _records = [];

  @override
  Future<void> insert(FocusRecord r) async => _records.add(r);
  @override
  Future<FocusRecord?> findBySessionId(String id) async =>
      _records.where((r) => r.sessionId == id).firstOrNull;
  @override
  Future<FocusRecord?> findById(String id) async =>
      _records.where((r) => r.id == id).firstOrNull;
  @override
  Future<void> update(FocusRecord record) async {
    final idx = _records.indexWhere((r) => r.id == record.id);
    if (idx != -1) _records[idx] = record;
  }

  @override
  Future<void> deleteById(String id) async =>
      _records.removeWhere((r) => r.id == id);
  @override
  Future<List<FocusRecord>> findByDateRange(String userId,
          {required DateTime from, required DateTime to}) async =>
      _records;
  @override
  Future<int> totalSecondsForDay(String userId, DateTime date) async => 0;
  @override
  Future<Map<DateTime, int>> dailyTotals(String userId,
          {required DateTime from, required DateTime to}) async =>
      {};
}

class StubLedgerRepo implements IRewardLedgerRepository {
  final Map<String, RewardLedger> _store = {};
  @override
  Future<bool> settleReward(RewardLedger entry) async {
    if (_store.containsKey(entry.sessionId)) return false;
    _store[entry.sessionId] = entry;
    return true;
  }

  @override
  Future<RewardLedger?> findBySessionId(String id) async => _store[id];
}

class StubPetRepo implements IPetRepository {
  @override
  Future<void> savePet(Pet pet) async {}
  @override
  Future<Pet?> findPetByUser(String userId) async => null;
  @override
  Future<void> savePetProgress(PetProgress progress) async {}
  @override
  Future<PetProgress?> findPetProgress(String petId) async => null;
  @override
  Future<void> addMemory(PetMemory memory) async {}
  @override
  Future<List<PetMemory>> findMemories(String petId, {int limit = 50}) async =>
      [];
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late StubClock clock;
  late StubSessionRepo sessionRepo;
  late StubRecordRepo recordRepo;
  late StubLedgerRepo ledgerRepo;
  late StubPetRepo petRepo;
  late RewardService rewardService;
  late FocusSessionEngine engine;

  setUp(() {
    clock = StubClock(DateTime(2026, 9, 1, 10, 0, 0));
    sessionRepo = StubSessionRepo();
    recordRepo = StubRecordRepo();
    ledgerRepo = StubLedgerRepo();
    petRepo = StubPetRepo();
    rewardService = RewardService(
      ledgerRepo: ledgerRepo,
      petRepo: petRepo,
      clock: clock,
    );
    engine = FocusSessionEngine(
      sessionRepo: sessionRepo,
      recordRepo: recordRepo,
      rewardService: rewardService,
      clock: clock,
    );
  });

  group('FocusSessionEngine state transitions', () {
    test('start → status is running, persisted in repo', () async {
      final session = await engine.start(
        userId: 'u1',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
      );
      expect(session.status, equals(FocusSessionStatus.running));
      final fromRepo = await sessionRepo.findById(session.id);
      expect(fromRepo, isNotNull);
    });

    test('start → pause → status is paused', () async {
      await engine.start(
          userId: 'u1', plannedSeconds: 1500, mode: FocusMode.focus);
      clock.advance(const Duration(minutes: 10));
      final paused = await engine.pause();
      expect(paused.status, equals(FocusSessionStatus.paused));
      expect(paused.pauseIntervals.length, equals(1));
      expect(paused.pauseIntervals.last.pauseEnd, isNull);
    });

    test('pause → resume closes pause interval', () async {
      await engine.start(
          userId: 'u1', plannedSeconds: 1500, mode: FocusMode.focus);
      clock.advance(const Duration(minutes: 10));
      await engine.pause();
      clock.advance(const Duration(minutes: 5));
      final resumed = await engine.resume();
      expect(resumed.status, equals(FocusSessionStatus.running));
      expect(resumed.pauseIntervals.last.pauseEnd, isNotNull);
    });

    test('elapsed excludes pause duration', () async {
      await engine.start(
          userId: 'u1', plannedSeconds: 1500, mode: FocusMode.focus);
      clock.advance(const Duration(minutes: 10));
      await engine.pause();
      clock.advance(const Duration(minutes: 5));
      await engine.resume();
      clock.advance(const Duration(minutes: 15));
      final completed = await engine.complete();
      // elapsed = 10 + 15 = 25min = 1500s, pause 5min excluded
      expect(completed.elapsedSeconds, equals(1500));
    });

    test('complete → save writes FocusRecord', () async {
      await engine.start(
          userId: 'u1', plannedSeconds: 1500, mode: FocusMode.focus);
      clock.advance(const Duration(minutes: 25));
      await engine.complete();
      final saved = await engine.save();
      expect(saved.status, equals(FocusSessionStatus.saved));
      final record = await recordRepo.findBySessionId(saved.id);
      expect(record, isNotNull);
      expect(record!.durationSeconds, greaterThan(0));
    });

    test('cancel clears current session', () async {
      final s = await engine.start(
          userId: 'u1', plannedSeconds: 1500, mode: FocusMode.focus);
      await engine.cancel();
      expect(engine.currentSession, isNull);
      final fromRepo = await sessionRepo.findById(s.id);
      expect(fromRepo?.status, equals(FocusSessionStatus.cancelled));
    });

    test('second start while active throws StateError', () async {
      await engine.start(
          userId: 'u1', plannedSeconds: 1500, mode: FocusMode.focus);
      expect(
        () => engine.start(
            userId: 'u1', plannedSeconds: 1500, mode: FocusMode.focus),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Reward idempotency', () {
    test('settle twice with same session_id → second returns false', () async {
      final session = FocusSession(
        id: 'idem-test',
        userId: 'u1',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
        startAt: clock.now().subtract(const Duration(minutes: 25)),
        pauseIntervals: const [],
        endAt: clock.now(),
        status: FocusSessionStatus.finishing,
        timezoneOffsetMinutes: 480,
      );
      final first = await rewardService.settle(session);
      final second = await rewardService.settle(session);
      expect(first, isTrue);
      expect(second, isFalse);
    });
  });

  // Regression: a session parked in `finishing` by complete() used to be
  // unreachable once the save page was abandoned — findActive never returned it,
  // isActive was false for it, and save() needs the in-memory session. The
  // FocusRecord was never written and the focus time was lost silently.
  group('Abandoned (finishing) session recovery', () {
    /// A "restarted app": a new engine over the same persisted stores.
    FocusSessionEngine restartedEngine() => FocusSessionEngine(
          sessionRepo: sessionRepo,
          recordRepo: recordRepo,
          rewardService: rewardService,
          clock: clock,
        );

    Future<FocusSession> completeWithoutSaving() async {
      final session = await engine.start(
          userId: 'u1', plannedSeconds: 1500, mode: FocusMode.focus);
      clock.advance(const Duration(minutes: 25));
      await engine.complete();
      expect(engine.currentSession?.status, FocusSessionStatus.finishing);
      expect(await recordRepo.findBySessionId(session.id), isNull,
          reason: 'finishing alone must not write a record');
      return session;
    }

    test('recovery persists the record a fresh engine could not reach before',
        () async {
      final session = await completeWithoutSaving();

      final recovered = await restartedEngine().recoverAbandonedSessions('u1');

      expect(recovered.length, 1);
      expect(recovered.single.id, session.id);
      expect(recovered.single.status, FocusSessionStatus.completed);

      final record = await recordRepo.findBySessionId(session.id);
      expect(record, isNotNull);
      expect(record!.durationSeconds, 1500);
      expect(record.taskName, session.taskName);
      expect(record.isCountedForReward, isTrue);

      final fromRepo = await sessionRepo.findById(session.id);
      expect(fromRepo?.status, FocusSessionStatus.completed);
    });

    test('restore() recovers it, settles the reward, and resumes nothing',
        () async {
      final session = await completeWithoutSaving();

      final restored = await restartedEngine().restore('u1');

      expect(restored, isNull,
          reason: 'the session is over; there is nothing to resume');
      expect(await recordRepo.findBySessionId(session.id), isNotNull);
      expect(await ledgerRepo.findBySessionId(session.id), isNotNull,
          reason: 'the reward must be settled by recovery too');
    });

    test('recovery is idempotent across repeated passes', () async {
      final session = await completeWithoutSaving();
      final e = restartedEngine();

      expect((await e.recoverAbandonedSessions('u1')).length, 1);
      expect((await e.recoverAbandonedSessions('u1')), isEmpty,
          reason: 'the session is completed now, so nothing is left to drain');

      // save() on a recovered session must not write a second record either.
      expect(await recordRepo.findBySessionId(session.id), isNotNull);
    });

    test('a session still open on the save page is never pre-empted', () async {
      final session = await completeWithoutSaving();

      // Same engine that still holds the session in memory: the user is on the
      // save page, so recovery must leave their pending edit alone.
      final recovered = await engine.recoverAbandonedSessions('u1');

      expect(recovered, isEmpty);
      expect(await recordRepo.findBySessionId(session.id), isNull);
    });

    test('a live running session is resumed, not finalized', () async {
      final running = await engine.start(
          userId: 'u1', plannedSeconds: 1500, mode: FocusMode.focus);
      clock.advance(const Duration(minutes: 10));

      final restored = await restartedEngine().restore('u1');

      expect(restored, isNotNull);
      expect(restored!.id, running.id);
      expect(restored.status, FocusSessionStatus.restored);
      expect(await recordRepo.findBySessionId(running.id), isNull,
          reason: 'a session that never ended must not produce a record');
    });
  });
}
