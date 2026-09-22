import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/craft_models.dart';

/// The collection's unlock tracker, scoped to the app rather than to a page.
///
/// **The baseline has to outlive a page instance, or the celebration is
/// unreachable.** Inventory is written in exactly one place — the craft engine,
/// when a job completes — and that completion is driven by
/// `RewardService.accumulateProgress` during a focus-session settlement. In
/// other words the inventory changes while the *focus* flow is on screen, never
/// while the collection page is mounted.
///
/// A tracker owned by the page's `State` therefore establishes a fresh baseline
/// on every visit, and the transition it exists to report can never be observed:
/// the class would be correct and dead at the same time. Holding it here means
/// the baseline survives navigation, so the next visit after a real craft
/// completion is a genuine `0 → positive` and the first visit still reports
/// nothing.
final petCollectionUnlockTrackerProvider =
    Provider<PetCollectionUnlockTracker>((ref) => PetCollectionUnlockTracker());

/// Detects collection items that have **just become owned**.
///
/// ## Where the reaction comes from
///
/// The brief asks for a collection unlock response driven by *real* unlocks.
/// The only ownership truth in the app is the Drift `inventory` table, so this
/// watches that and nothing else. There is no synthetic "you unlocked something"
/// event to accidentally trust, and no reward path that could be mistaken for
/// one.
///
/// ## The trap this exists to avoid
///
/// The obvious implementation — "celebrate for every owned item I can see" —
/// fires on the first frame of every visit, because on load *everything* already
/// owned is visible at once. A user with a full collection would be greeted by a
/// celebration every time they opened the page, and the celebration would mean
/// nothing.
///
/// So the first observation is a **baseline**: it records what is already owned
/// and reports nothing. Only a transition observed *after* that baseline counts.
/// `collection_unlock_test.dart` pins both halves — no reaction on load, and a
/// reaction on a real later change.
///
/// ## What counts as an unlock
///
/// Only `0 → positive`. Crafting a second copy of something already owned
/// (`1 → 2`) is not an unlock: the user already had it, and announcing it again
/// would be noise. The quantity is deliberately not part of the comparison for
/// that reason.
class PetCollectionUnlockTracker {
  Set<String>? _baseline;

  /// Whether a baseline has been established yet.
  ///
  /// Before this is true the tracker reports nothing by design.
  bool get hasBaseline => _baseline != null;

  /// How many distinct items the baseline recorded.
  int get baselineSize => _baseline?.length ?? 0;

  /// Feeds the current ownership truth and reports an unlock, if one happened.
  ///
  /// Call this from a provider listener rather than from `build` — it is a
  /// stateful observation, and running it during a build would make the answer
  /// depend on how many times the frame happened to rebuild.
  ///
  /// The first call establishes the baseline and returns `null` **always**,
  /// however much is owned.
  ///
  /// When several items unlock between two observations, the lowest item id is
  /// reported. Only one reaction can be shown, and picking by id means the
  /// answer does not depend on the order the rows came back in.
  String? observe(Iterable<InventoryItem> inventory) {
    final owned = <String>{
      for (final item in inventory)
        if (item.quantity > 0) item.itemId,
    };

    final baseline = _baseline;
    if (baseline == null) {
      _baseline = owned;
      return null;
    }

    _baseline = owned;

    final unlocked = owned.difference(baseline).toList()..sort();
    if (unlocked.isEmpty) return null;
    return unlocked.first;
  }

  /// Forgets the baseline, so the next [observe] is treated as a first load.
  ///
  /// Used when the tracked inventory belongs to a different user: the honest
  /// state is "I do not know what was already owned", and guessing would produce
  /// the false celebration this class exists to prevent.
  ///
  /// Note that *navigating away and back must not call this* — that is exactly
  /// the mistake that makes the celebration unreachable. See the provider above.
  void reset() {
    _baseline = null;
  }
}
