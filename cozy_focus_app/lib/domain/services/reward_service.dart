import '../models/focus_session.dart';
import '../models/sync_models.dart';
import '../models/pet_models.dart';
import '../repositories/i_reward_ledger_repository.dart';
import '../repositories/i_pet_repository.dart';
import '../repositories/i_atomic_settlement.dart';
import 'focus_clock.dart';
import 'craft_engine.dart';

/// RewardService — idempotent, atomic reward settlement keyed by session_id.
///
/// Production path: [IAtomicSettlement] handles all DB reads and writes in a
/// single SQLite transaction. No state is pre-fetched outside the transaction.
///
/// Test / fallback path: sequential non-atomic writes (when [atomicSettlement]
/// is null). Idempotency is still enforced via [_ledgerRepo].
class RewardService {
  final IRewardLedgerRepository _ledgerRepo;
  final IPetRepository _petRepo;
  final FocusClock _clock;
  final CraftEngine? _craftEngine;
  final IAtomicSettlement? _atomicSettlement;

  static const int _coinsPerMinute = 2;
  static const int _xpPerMinute = 5;

  RewardService({
    required IRewardLedgerRepository ledgerRepo,
    required IPetRepository petRepo,
    FocusClock? clock,
    CraftEngine? craftEngine,
    IAtomicSettlement? atomicSettlement,
  })  : _ledgerRepo = ledgerRepo,
        _petRepo = petRepo,
        _clock = clock ?? const SystemFocusClock(),
        _craftEngine = craftEngine,
        _atomicSettlement = atomicSettlement;

  /// Settle reward for a completed [session].
  ///
  /// Returns [true] if this call performed the settlement.
  /// Returns [false] if the session was already settled (safe no-op).
  Future<bool> settle(FocusSession session) async {
    final focusMinutes = (session.elapsedSeconds / 60).floor();
    final coins = focusMinutes * _coinsPerMinute;
    final xp = focusMinutes * _xpPerMinute;
    final now = _clock.now();

    final entry = RewardLedger(
      sessionId: session.id,
      userId: session.userId,
      focusCoinsEarned: coins,
      experienceEarned: xp,
      settledAt: now,
    );

    if (_atomicSettlement != null) {
      // Production path: SettlementDao reads PetProgress, CraftJob and Recipe
      // INSIDE the transaction. We pass only primitive inputs.
      return _atomicSettlement.settleAtomically(
        entry: entry,
        addedFocusSeconds: session.elapsedSeconds,
        now: now,
      );
    }

    // ── Test / fallback path: sequential writes ──────────────────────────
    final existing = await _ledgerRepo.findBySessionId(session.id);
    if (existing != null) return false;

    await _ledgerRepo.settleReward(entry);

    final pet = await _petRepo.findPetByUser(session.userId);
    if (pet != null) {
      final progress = await _petRepo.findPetProgress(pet.id);
      if (progress != null) {
        final updated = PetProgress(
          id: progress.id,
          petId: progress.petId,
          level: progress.level,
          experiencePoints: progress.experiencePoints + xp,
          totalFocusMinutes: progress.totalFocusMinutes + focusMinutes,
          happinessScore: (progress.happinessScore + 5).clamp(0, 100),
          updatedAt: now,
        );
        await _petRepo.savePetProgress(updated);
      }
    }

    if (_craftEngine != null && session.elapsedSeconds > 0) {
      await _craftEngine.accumulateProgress(
          session.userId, session.elapsedSeconds);
    }

    return true;
  }
}
