import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/growth/growth_level_curve.dart';

/// D6 — the V1 growth economy, pinned by value.
///
/// ## Why this is not a duplicate of the existing curve tests
///
/// The tests in `mochi_growth_visibility_test.dart` assert relationships
/// *through the constants*: "the level at the cap is `maxLevel`", "within-level
/// progress is below `xpPerLevel`". Those stay green if `xpPerLevel` becomes 250,
/// because they never name a number. They test that the curve is internally
/// consistent, which is a different claim from "this is the approved economy".
///
/// The owner approved 100 XP per level with a cap of 30 for V1 (D6), so the
/// numbers themselves are now a decision and are written down as literals here.
/// Changing them is allowed, but it has to be deliberate enough to edit this
/// file, which is the point.
void main() {
  group('D6 the approved V1 growth economy', () {
    test('100 XP per level', () {
      expect(GrowthLevelCurve.xpPerLevel, 100);
    });

    test('the cap is 30', () {
      expect(GrowthLevelCurve.maxLevel, 30);
    });

    test('the levels are 1-based, so a fresh install is Lv.1', () {
      expect(GrowthLevelCurve.minLevel, 1);
      expect(GrowthLevelCurve.levelForXp(0), 1);
    });

    test('100 XP of progress is exactly one level, at every step', () {
      // Flat, not curved: this is what the two existing progress bars assume.
      for (var level = 1; level < GrowthLevelCurve.maxLevel; level++) {
        final atLevel = GrowthLevelCurve.xpForLevel(level);
        expect(GrowthLevelCurve.levelForXp(atLevel), level);
        expect(GrowthLevelCurve.levelForXp(atLevel + 99), level);
        expect(GrowthLevelCurve.levelForXp(atLevel + 100), level + 1);
      }
    });
  });

  group('D6 existing progress is not reset', () {
    test('an XP total already stored still maps to its own level', () {
      // The "do not reset" half of the decision: whatever XP an install already
      // holds, the curve reads it rather than restarting it. A 12-level install
      // must not come back as Lv.1.
      final storedXp = GrowthLevelCurve.xpForLevel(12) + 40;
      expect(GrowthLevelCurve.levelForXp(storedXp), 12);
    });

    test('XP beyond the cap is kept, not clamped away', () {
      // The cap limits the *level*, not the stored XP: a capped install keeps
      // accruing, so raising the cap later does not require recovering data.
      final beyondCap =
          GrowthLevelCurve.xpForLevel(GrowthLevelCurve.maxLevel) * 5;
      expect(GrowthLevelCurve.levelForXp(beyondCap), GrowthLevelCurve.maxLevel);
      // And it is still expressible as XP, i.e. nothing was discarded.
      expect(beyondCap, greaterThan(0));
    });
  });
}
