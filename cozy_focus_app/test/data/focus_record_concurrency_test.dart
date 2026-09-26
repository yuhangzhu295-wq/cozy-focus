import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide
        FocusSession,
        Pet,
        CraftJob,
        CraftRecipe,
        InventoryItem,
        RoomItem,
        FocusRecord;
import 'package:cozy_focus_app/data/repositories/drift_focus_record_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_focus_session_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_pet_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_reward_ledger_repository.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/models/focus_session.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/domain/services/focus_session_engine.dart';
import 'package:cozy_focus_app/domain/services/reward_service.dart';

class _FixedClock implements FocusClock {
  final DateTime v = DateTime(2026, 9, 25, 10, 0, 0);
  @override
  DateTime now() => v;
}

void main() {
  group('P0: FocusRecord sessionId concurrency and idempotency', () {
    test(
        'concurrent recoverAbandonedSessions on one finishing session produces exactly 1 record',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final clock = _FixedClock();
      final sessions = DriftFocusSessionRepository(db.focusSessionDao);
      final records = DriftFocusRecordRepository(db.focusRecordDao);
      final ledger = DriftRewardLedgerRepository(db.rewardLedgerDao);
      final pets = DriftPetRepository(db.petDao);
      final engine = FocusSessionEngine(
        sessionRepo: sessions,
        recordRepo: records,
        rewardService: RewardService(
          ledgerRepo: ledger,
          petRepo: pets,
          clock: clock,
          atomicSettlement: db.settlementDao,
        ),
        clock: clock,
      );

      await sessions.save(FocusSession(
        id: 'sess_concurrent_p0',
        userId: 'default_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
        startAt: clock.now().subtract(const Duration(minutes: 25)),
        pauseIntervals: const [],
        endAt: clock.now(),
        status: FocusSessionStatus.finishing,
        timezoneOffsetMinutes: 0,
      ));

      // Fire multiple concurrent recoveries
      await Future.wait([
        engine.recoverAbandonedSessions('default_user'),
        engine.recoverAbandonedSessions('default_user'),
        engine.recoverAbandonedSessions('default_user'),
      ]);

      final allRecords = await records.findByDateRange(
        'default_user',
        from: clock.now().subtract(const Duration(days: 1)),
        to: clock.now().add(const Duration(days: 1)),
      );

      expect(allRecords.length, 1);
      expect(allRecords.first.sessionId, 'sess_concurrent_p0');
      expect(allRecords.first.durationSeconds, 1500);

      final ledgerEntry = await ledger.findBySessionId('sess_concurrent_p0');
      expect(ledgerEntry, isNotNull);

      await db.close();
    });

    test(
        'DAO insert is idempotent when inserting identical sessionId with different record id',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final records = DriftFocusRecordRepository(db.focusRecordDao);
      final now = DateTime(2026, 9, 25, 10, 0, 0);

      final r1 = FocusRecord(
        id: 'rec_1',
        sessionId: 'sess_1',
        userId: 'user_1',
        durationSeconds: 1500,
        startAt: now.subtract(const Duration(minutes: 25)),
        endAt: now,
        recordedAt: now,
        isCountedForReward: true,
      );

      final r2 = FocusRecord(
        id: 'rec_2',
        sessionId: 'sess_1',
        userId: 'user_1',
        durationSeconds: 1500,
        startAt: now.subtract(const Duration(minutes: 25)),
        endAt: now,
        recordedAt: now,
        isCountedForReward: true,
      );

      await records.insert(r1);
      await records
          .insert(r2); // should not throw, should ignore conflict on sessionId

      final found = await records.findBySessionId('sess_1');
      expect(found, isNotNull);
      expect(found!.id, 'rec_1');

      await db.close();
    });
  });
}
