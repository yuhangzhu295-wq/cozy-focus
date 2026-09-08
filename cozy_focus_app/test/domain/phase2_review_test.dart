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

// ---------------------------------------------------------------------------
// In-memory stubs
// ---------------------------------------------------------------------------

class _StubClock implements FocusClock {
  DateTime _now;
  _StubClock(this._now);
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
}

class _StubSessionRepo implements IFocusSessionRepository {
  final Map<String, FocusSession> _store = {};
  @override Future<void> save(FocusSession s) async => _store[s.id] = s;
  @override Future<void> update(FocusSession s) async => _store[s.id] = s;
  @override Future<FocusSession?> findById(String id) async => _store[id];
  @override Future<List<FocusSession>> findActive(String userId) async =>
      _store.values.where((s) => s.isActive).toList();
  @override Future<List<FocusSession>> findRecent(String userId,
      {int limit = 20}) async => _store.values.toList();
  @override Future<void> delete(String id) async => _store.remove(id);
}

class _StubRecordRepo implements IFocusRecordRepository {
  final List<FocusRecord> _records = [];
  @override Future<void> insert(FocusRecord r) async => _records.add(r);
  @override Future<FocusRecord?> findBySessionId(String id) async =>
      _records.where((r) => r.sessionId == id).firstOrNull;
  @override Future<List<FocusRecord>> findByDateRange(String userId,
      {required DateTime from, required DateTime to}) async => _records;
  @override Future<int> totalSecondsForDay(String userId, DateTime date) async => 0;
  @override Future<Map<DateTime, int>> dailyTotals(String userId,
      {required DateTime from, required DateTime to}) async => {};
}

class _StubLedgerRepo implements IRewardLedgerRepository {
  final Map<String, RewardLedger> _store = {};
  RewardLedger? lastEntry;
  @override Future<bool> settleReward(RewardLedger entry) async {
    if (_store.containsKey(entry.sessionId)) return false;
    _store[entry.sessionId] = entry;
    lastEntry = entry;
    return true;
  }
  @override Future<RewardLedger?> findBySessionId(String id) async => _store[id];
}

class _StubPetRepo implements IPetRepository {
  @override Future<void> savePet(Pet pet) async {}
  @override Future<Pet?> findPetByUser(String userId) async => null;
  @override Future<void> savePetProgress(PetProgress progress) async {}
  @override Future<PetProgress?> findPetProgress(String petId) async => null;
  @override Future<void> addMemory(PetMemory memory) async {}
  @override Future<List<PetMemory>> findMemories(String petId,
      {int limit = 50}) async => [];
}

FocusSessionEngine _makeEngine({
  required _StubClock clock,
  required _StubSessionRepo sessionRepo,
  required _StubRecordRepo recordRepo,
  required _StubLedgerRepo ledgerRepo,
}) {
  final rewardService = RewardService(
    ledgerRepo: ledgerRepo,
    petRepo: _StubPetRepo(),
    clock: clock,
  );
  return FocusSessionEngine(
    sessionRepo: sessionRepo,
    recordRepo: recordRepo,
    rewardService: rewardService,
    clock: clock,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const userId = 'test-user';
  late _StubClock clock;
  late _StubSessionRepo sessionRepo;
  late _StubRecordRepo recordRepo;
  late _StubLedgerRepo ledgerRepo;
  late FocusSessionEngine engine;

  setUp(() {
    clock = _StubClock(DateTime(2026, 9, 8, 10, 0, 0));
    sessionRepo = _StubSessionRepo();
    recordRepo = _StubRecordRepo();
    ledgerRepo = _StubLedgerRepo();
    engine = _makeEngine(
        clock: clock,
        sessionRepo: sessionRepo,
        recordRepo: recordRepo,
        ledgerRepo: ledgerRepo);
  });

  group('Issue 10 - Phase 2 Review correctness tests', () {
    // -- taskName -----------------------------------------------------------------

    test('taskName persisted on FocusSession via start()', () async {
      await engine.start(
          userId: userId,
          plannedSeconds: 1500,
          mode: FocusMode.focus,
          taskName: 'write arch doc',
          categoryId: 'work');
      expect(sessionRepo._store.values.first.taskName, equals('write arch doc'));
    });

    test('taskName denormalized onto FocusRecord after save()', () async {
      await engine.start(
          userId: userId,
          plannedSeconds: 1500,
          mode: FocusMode.focus,
          taskName: 'write unit tests');
      clock.advance(const Duration(minutes: 25));
      await engine.complete();
      await engine.save(taskName: 'write unit tests', note: null);
      expect(recordRepo._records.first.taskName, equals('write unit tests'));
    });

    test('taskName override on save() replaces session taskName on FocusRecord',
        () async {
      await engine.start(
          userId: userId,
          plannedSeconds: 1500,
          mode: FocusMode.focus,
          taskName: 'original name');
      clock.advance(const Duration(minutes: 10));
      await engine.complete();
      await engine.save(taskName: 'edited name', note: null);
      expect(recordRepo._records.first.taskName, equals('edited name'));
    });

    // -- categoryId ---------------------------------------------------------------

    test('category override on save() lands on FocusRecord', () async {
      await engine.start(
          userId: userId,
          plannedSeconds: 1500,
          mode: FocusMode.focus,
          categoryId: 'original-cat');
      clock.advance(const Duration(minutes: 15));
      await engine.complete();
      await engine.save(categoryId: 'new-cat', note: null);
      expect(recordRepo._records.first.categoryId, equals('new-cat'));
    });

    // -- mood ---------------------------------------------------------------------

    test('mood stored as structured field, not concatenated into note', () async {
      await engine.start(
          userId: userId, plannedSeconds: 1500, mode: FocusMode.focus);
      clock.advance(const Duration(minutes: 20));
      await engine.complete();
      await engine.save(mood: 'happy', note: 'great session');
      final record = recordRepo._records.first;
      expect(record.mood, equals('happy'),
          reason: 'mood must be a dedicated FocusRecord field');
      expect(record.note, equals('great session'),
          reason: 'note must not be modified by mood');
      expect(record.note, isNot(contains('happy')),
          reason: 'mood must NOT be concatenated into note');
    });

    // -- clock consistency -------------------------------------------------------

    test('elapsedSecondsAt(clock.now()) matches FocusRecord.durationSeconds',
        () async {
      await engine.start(
          userId: userId, plannedSeconds: 1500, mode: FocusMode.focus);
      clock.advance(const Duration(minutes: 25));
      // Capture elapsed BEFORE complete() sets endAt — same clock state
      final elapsedBeforeSave =
          engine.currentSession!.elapsedSecondsAt(clock.now());
      await engine.complete();
      await engine.save(note: null);
      expect(recordRepo._records.first.durationSeconds, equals(elapsedBeforeSave),
          reason:
              'FocusRecord.durationSeconds must equal elapsedSecondsAt(clock.now()) '
              'computed from the injected clock, not DateTime.now()');
    });

    // -- reward consistency ------------------------------------------------------

    test('reward coins based on same elapsed as FocusRecord duration', () async {
      await engine.start(
          userId: userId, plannedSeconds: 1500, mode: FocusMode.focus);
      clock.advance(const Duration(minutes: 25)); // 1500 s
      await engine.complete();
      await engine.save(note: null);

      final record = recordRepo._records.first;
      final ledger = ledgerRepo.lastEntry;
      expect(ledger, isNotNull);
      // RewardService uses focusMinutes = (elapsedSeconds / 60).floor()
      // and record.durationSeconds comes from the same clock-injected elapsed.
      // So coins = (record.durationSeconds / 60).floor() * 2
      final expectedCoins = (record.durationSeconds / 60).floor() * 2;
      expect(ledger!.focusCoinsEarned, equals(expectedCoins),
          reason: 'Reward coins must be derived from the same elapsed source as FocusRecord');
    });

    // -- idempotency -------------------------------------------------------------

    test('reward settlement idempotent - second settle rejected', () async {
      await engine.start(
          userId: userId, plannedSeconds: 1500, mode: FocusMode.focus);
      clock.advance(const Duration(minutes: 20));
      await engine.complete();
      final sessionId = sessionRepo._store.values.first.id;
      await engine.save(note: null);

      // Simulate a second settle attempt (e.g. UI bug / double-tap)
      final secondSettle = await ledgerRepo.settleReward(RewardLedger(
          sessionId: sessionId,
          userId: userId,
          focusCoinsEarned: 999,
          experienceEarned: 999,
          settledAt: clock.now()));
      expect(secondSettle, isFalse,
          reason: 'Duplicate settle for same sessionId must be rejected');
    });

    // -- app restart -------------------------------------------------------------

    test('app restart: new engine restores session with taskName intact', () async {
      await engine.start(
          userId: userId,
          plannedSeconds: 1500,
          mode: FocusMode.focus,
          taskName: 'persisted task');
      clock.advance(const Duration(minutes: 15));

      // Simulate app killed: create fresh engine with same repos
      final engine2 = _makeEngine(
          clock: clock,
          sessionRepo: sessionRepo,
          recordRepo: recordRepo,
          ledgerRepo: ledgerRepo);
      await engine2.restore(userId);

      expect(engine2.currentSession, isNotNull,
          reason: 'Restored engine must find the active session');
      expect(engine2.currentSession!.status,
          equals(FocusSessionStatus.restored));
      expect(engine2.currentSession!.taskName, equals('persisted task'),
          reason: 'taskName must survive process restart via Drift');

      clock.advance(const Duration(minutes: 5));
      await engine2.complete();
      await engine2.save(note: 'restored note');

      expect(recordRepo._records.first.taskName, equals('persisted task'));
      expect(recordRepo._records.first.durationSeconds, greaterThan(0));
    });

    // -- no fake craft items -----------------------------------------------------

    test('no craft/room/inventory items created by engine.save()', () async {
      await engine.start(
          userId: userId, plannedSeconds: 1500, mode: FocusMode.focus);
      clock.advance(const Duration(minutes: 25));
      await engine.complete();
      await engine.save(note: null);

      // After save: exactly 1 FocusRecord and 1 RewardLedger entry.
      // Phase 4 craft items must NOT be auto-created.
      expect(recordRepo._records.length, equals(1),
          reason: 'Exactly one FocusRecord after save()');
      expect(ledgerRepo._store.length, equals(1),
          reason: 'Exactly one RewardLedger entry after save()');
    });
  });
}