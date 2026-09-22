/// Level curve — the single, centralised place where XP becomes a level.
///
/// ## Status: TEMPORARY DEFAULT MAPPING (documented, not silently invented)
///
/// `PetProgress.level` shipped as a **dead field**: it was written back
/// unchanged by both settlement paths, so it stayed at its seeded value of `1`
/// for the lifetime of every install. Nothing in `lib/` ever derived or
/// incremented it, and neither V4.1 (`docs/cozy_focus_v4_1/`) nor any product
/// contract in `outputs/ai_handoff/` defines level thresholds, a curve, a level
/// cap, or growth stages. The searches that establish this are recorded in
/// `MOCHI_GROWTH_STAGE0_AUDIT.md` §A.
///
/// The curve below is therefore a **chosen default**, not a recovered rule. It
/// is deliberately the *least surprising* option available:
///
/// - `100` XP per level is the convention the UI already assumes. Two pages
///   already draw a within-level progress bar as `experiencePoints % 100`
///   (`mochi_growth_page.dart`, `monthly_report_page.dart`) and two more render
///   `Lv.N`. Adopting any other shape would silently make those existing
///   progress bars wrong. A flat curve keeps every current surface consistent
///   while making `level` truthful for the first time.
/// - `maxLevel` exists so the curve is total and testable rather than unbounded.
///
/// It lives here, and only here, so that replacing it with a real economy is a
/// one-file change. If the owner later specifies a curve, change [_xpPerLevel]
/// or [_xpForLevelTable] and every consumer follows.
///
/// This class computes **nothing else**: it does not award XP, does not write
/// to the database, and does not know about rewards. `RewardService` remains the
/// only XP authority (`2 coins + 5 XP per whole minute`).
abstract final class GrowthLevelCurve {
  const GrowthLevelCurve._();

  /// XP required per level. Flat by design — see the class docs.
  static const int xpPerLevel = 100;

  /// Highest level the curve will report. XP beyond this is still stored and
  /// still counts for within-level progress; it just cannot raise the level.
  static const int maxLevel = 30;

  /// Lowest level. `PetProgress.level` is 1-based.
  static const int minLevel = 1;

  /// The level that [experiencePoints] earns.
  ///
  /// Monotonic and total: every `int` input (including negatives, which cannot
  /// occur but are clamped rather than trusted) returns a level in
  /// `[minLevel, maxLevel]`.
  static int levelForXp(int experiencePoints) {
    if (experiencePoints <= 0) return minLevel;
    final earned = minLevel + (experiencePoints ~/ xpPerLevel);
    return earned > maxLevel ? maxLevel : earned;
  }

  /// Total XP required to *reach* [level]. Inverse of [levelForXp] for levels
  /// in range; used by tests and by the growth page's progress bar.
  static int xpForLevel(int level) {
    final clamped = level.clamp(minLevel, maxLevel);
    return (clamped - minLevel) * xpPerLevel;
  }

  /// XP accumulated inside the current level, in `[0, xpPerLevel]`.
  ///
  /// At [maxLevel] this reports the full bar rather than a value that would
  /// imply another level exists.
  static int xpWithinLevel(int experiencePoints) {
    if (levelForXp(experiencePoints) >= maxLevel) return xpPerLevel;
    final remainder = experiencePoints % xpPerLevel;
    return remainder < 0 ? 0 : remainder;
  }

  /// Whether [experiencePoints] has reached the top of the curve.
  static bool isMaxLevel(int experiencePoints) =>
      levelForXp(experiencePoints) >= maxLevel;
}
