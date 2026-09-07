import '../../domain/models/sync_models.dart';
import '../../domain/repositories/i_reward_ledger_repository.dart';
import '../local/daos/reward_ledger_dao.dart';

class DriftRewardLedgerRepository implements IRewardLedgerRepository {
  final RewardLedgerDao _dao;
  DriftRewardLedgerRepository(this._dao);

  @override
  Future<bool> settleReward(RewardLedger entry) => _dao.settleReward(entry);

  @override
  Future<RewardLedger?> findBySessionId(String sessionId) =>
      _dao.findBySessionId(sessionId);
}
