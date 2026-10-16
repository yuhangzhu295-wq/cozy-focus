import '../growth/growth_level_curve.dart';
import '../models/pet_models.dart';

/// Decides which memories a settlement earns.
///
/// ## Why this is a pure function and not a call site
///
/// Settlement runs on two paths — the atomic one inside
/// `SettlementDao.settleAtomically` and the sequential fallback in
/// `RewardService`. If each decided for itself what was memorable, they would
/// eventually disagree, and the disagreement would be invisible: the same user
/// would hold different memories depending on which path happened to run. The
/// codebase already carries that lesson for `level` (see the note in both
/// paths about deriving it), so the decision lives here once and both callers
/// only insert what it returns.
///
/// ## It decides; it does not write
///
/// Nothing here touches a repository. It takes the facts a settlement already
/// established and returns the rows that follow from them, which keeps the
/// rules testable without a database and keeps the writing where the
/// transaction is.
abstract final class CompanionMemory {
  /// How long one focus session has to run to be remembered.
  ///
  /// **A product decision, not a derived number** (D4, owner-approved: 50
  /// minutes). The other two rules needed no threshold — "the first" is the first
  /// row, and the level rule is the existing curve — which is why `long_session`
  /// stayed unshipped while those two shipped. It now has one.
  ///
  /// It measures *sustained focus*: the seconds the session actually ran, which
  /// is the same number settlement uses to award coins and XP. So a memory can
  /// never describe a session the ledger disagrees with.
  static const int longSessionThreshold = 50 * 60;

  /// The memories earned by one settlement.
  ///
  /// [settledCount] is the user's total settled sessions **including** the one
  /// being settled, so `1` means this was the first — no threshold is involved,
  /// because "the first" is not a number anyone has to choose.
  ///
  /// A level rise is detected by comparing [GrowthLevelCurve.levelForXp] before
  /// and after, so the threshold is the existing curve rather than a constant
  /// invented here.
  ///
  /// [sessionSeconds] is how long the session being settled actually ran, which
  /// is the fact [longSessionThreshold] is compared against.
  static List<PetMemory> earnedBy({
    required String petId,
    required int settledCount,
    required int previousXp,
    required int newXp,
    required DateTime at,
    required int sessionSeconds,
  }) {
    final memories = <PetMemory>[];

    if (settledCount == 1) {
      memories.add(PetMemory(
        id: _idFor(petId, PetMemoryType.firstFocus, at),
        petId: petId,
        memoryType: PetMemoryType.firstFocus,
        content: '第一次和你一起专注',
        happenedAt: at,
      ));
    }

    final previousLevel = GrowthLevelCurve.levelForXp(previousXp);
    final newLevel = GrowthLevelCurve.levelForXp(newXp);
    if (newLevel > previousLevel) {
      memories.add(PetMemory(
        id: _idFor(petId, PetMemoryType.levelUp, at),
        petId: petId,
        memoryType: PetMemoryType.levelUp,
        content: '成长到 Lv.$newLevel',
        happenedAt: at,
      ));
    }

    // A long session. The content names the actual minutes rather than the
    // threshold, so a 90-minute session does not read as "50 minutes".
    if (sessionSeconds >= longSessionThreshold) {
      memories.add(PetMemory(
        id: _idFor(petId, PetMemoryType.longSession, at),
        petId: petId,
        memoryType: PetMemoryType.longSession,
        content: '陪你专注了 ${sessionSeconds ~/ 60} 分钟',
        happenedAt: at,
      ));
    }

    return memories;
  }

  /// A stable id for one memory.
  ///
  /// Derived from the pet, the type and the moment rather than generated
  /// randomly, so two settlements that earn the same memory at the same
  /// microsecond collapse onto one row instead of producing two.
  static String _idFor(String petId, String type, DateTime at) =>
      'mem_${petId}_${type}_${at.microsecondsSinceEpoch}';
}
