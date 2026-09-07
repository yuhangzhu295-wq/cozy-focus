import 'package:drift/drift.dart';
import '../../../domain/models/sync_models.dart';
import '../tables/sync_tables.dart';
import '../app_database.dart';

part 'reward_ledger_dao.g.dart';

@DriftAccessor(tables: [RewardLedgerTable])
class RewardLedgerDao extends DatabaseAccessor<AppDatabase>
    with _$RewardLedgerDaoMixin {
  RewardLedgerDao(super.db);

  /// INSERT OR IGNORE — if session_id PK already exists, silently skips.
  /// Returns true if inserted, false if already existed.
  Future<bool> settleReward(RewardLedger entry) async {
    final rows = await (select(rewardLedgerTable)
          ..where((t) => t.sessionId.equals(entry.sessionId)))
        .get();
    if (rows.isNotEmpty) return false;

    await into(rewardLedgerTable).insert(
      RewardLedgerTableCompanion.insert(
        sessionId: entry.sessionId,
        userId: entry.userId,
        focusCoinsEarned: entry.focusCoinsEarned,
        experienceEarned: entry.experienceEarned,
        craftRecipeUnlocked: Value(entry.craftRecipeUnlocked),
        settledAt: entry.settledAt,
      ),
    );
    return true;
  }

  Future<RewardLedger?> findBySessionId(String sessionId) async {
    final row = await (select(rewardLedgerTable)
          ..where((t) => t.sessionId.equals(sessionId)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  RewardLedger _map(RewardLedgerTableData row) {
    return RewardLedger(
      sessionId: row.sessionId,
      userId: row.userId,
      focusCoinsEarned: row.focusCoinsEarned,
      experienceEarned: row.experienceEarned,
      craftRecipeUnlocked: row.craftRecipeUnlocked,
      settledAt: row.settledAt,
    );
  }
}
