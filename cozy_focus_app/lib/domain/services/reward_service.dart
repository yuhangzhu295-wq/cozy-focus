import '../models/focus_session.dart';
import '../models/sync_models.dart';
import '../models/pet_models.dart';
import '../repositories/i_reward_ledger_repository.dart';
import '../repositories/i_pet_repository.dart';
import 'focus_clock.dart';
import 'craft_engine.dart';

/// RewardService — idempotent reward settlement keyed by session_id.
///
/// Invariant: one and only one RewardLedger entry per session_id.
/// Calling settle() twice with the same session produces no second reward.
class RewardService {
  final IRewardLedgerRepository _ledgerRepo;
  final IPetRepository _petRepo;
  final FocusClock _clock;
  final CraftEngine? _craftEngine;

  // Reward constants — adjust in a config file later.
  static const int _coinsPerMinute = 2;
  static const int _xpPerMinute = 5;

  RewardService({
    required IRewardLedgerRepository ledgerRepo,
    required IPetRepository petRepo,
    FocusClock? clock,
    CraftEngine? craftEngine,
  })  : _ledgerRepo = ledgerRepo,
        _petRepo = petRepo,
        _clock = clock ?? const SystemFocusClock(),
        _craftEngine = craftEngine;

  /// Settle reward for a completed session.
  /// Returns false (no-op) if already settled.
  Future<bool> settle(FocusSession session) async {
    // Idempotency check
    final existing = await _ledgerRepo.findBySessionId(session.id);
    if (existing != null) return false;

    final focusMinutes = (session.elapsedSeconds / 60).floor();
    final coins = focusMinutes * _coinsPerMinute;
    final xp = focusMinutes * _xpPerMinute;

    final entry = RewardLedger(
      sessionId: session.id,
      userId: session.userId,
      focusCoinsEarned: coins,
      experienceEarned: xp,
      settledAt: _clock.now(),
    );

    await _ledgerRepo.settleReward(entry);

    // Update pet XP
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
          updatedAt: _clock.now(),
        );
        await _petRepo.savePetProgress(updated);
      }
    }

    // Accumulate craft progress (best-effort: craft engine may not be present)
    if (_craftEngine != null && session.elapsedSeconds > 0) {
      await _craftEngine.accumulateProgress(
          session.userId, session.elapsedSeconds);
    }

    return true;
  }
}
