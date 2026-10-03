/// What a piece of furniture *is*, and what can be done with it.
///
/// ## The change this models
///
/// The brief names the problem: *"Furniture currently behaves like collection
/// cards."* A card is a picture with an ownership flag. A card cannot be used,
/// cannot change anything, and cannot change what the companion does.
///
/// A [FurnitureEntity] is the other thing: it declares what the object is, what
/// the player gets from having it, how the companion uses it, and what that use
/// *does*. Unlocking a sofa then adds a behaviour — `sit` — that did not exist
/// before, which is the acceptance test the card model could never pass.
///
/// ## It is data
///
/// Nothing here branches on a furniture id. The catalog is a table of these, the
/// resolvers read the table, and adding a fifth piece of furniture is a row plus
/// its sprite — no page, no resolver and no switch is edited.
library;

/// The kind of object, used for interaction-point roles and for presentation.
///
/// This is deliberately coarse. It is not a proxy for identity — the id is —
/// it is what tells the anchor registry which *role* an interaction point plays.
enum FurnitureType {
  /// Something to sit or lie on: sofa, bed, rug.
  seating('seating'),

  /// A surface to work at: desk.
  workSurface('work_surface'),

  /// Somewhere things are kept and read: bookshelf.
  storage('storage');

  final String id;
  const FurnitureType(this.id);
}

/// Why a furniture action becomes available.
///
/// The brief requires every companion action to be caused by *state +
/// environment + player interaction + time*. These are the vocabulary for that:
/// each trigger names one of those causes, so an action's availability is
/// data rather than an `if` in a page.
enum FurnitureTrigger {
  /// The player tapped this furniture.
  playerTap('player_tap'),

  /// A real focus session is running.
  focusRunning('focus_running'),

  /// A real focus session exists but is paused.
  focusPaused('focus_paused'),

  /// The companion's energy is below the threshold.
  energyLow('energy_low'),

  /// The companion's energy is high enough to work.
  energyHigh('energy_high'),

  /// It is night where the player is.
  night('night'),

  /// The daily routine picked this, because of the time of day.
  ///
  /// Distinct from [idle], and the difference is the whole point of the daily
  /// routine: `idle` means *nothing else is claiming the companion*, while
  /// `routine` means *the companion's day says it is time for this*. An action
  /// may carry both — the routine chooses it when its band calls for it, and
  /// the idle walk still falls back to it at any hour.
  ///
  /// Carrying this trigger is what makes an action **eligible to be scheduled**.
  /// `daily_routine_test.dart` asserts that every action named by the routine
  /// table actually carries it, so a step cannot point at behaviour that has not
  /// agreed to be part of the day.
  routine('routine'),

  /// Nothing else is claiming the companion.
  idle('idle');

  final String id;
  const FurnitureTrigger(this.id);

  static FurnitureTrigger? fromId(String? id) {
    for (final trigger in FurnitureTrigger.values) {
      if (trigger.id == id) return trigger;
    }
    return null;
  }
}

/// What using a piece of furniture does to the companion.
///
/// ## Why this cannot touch the economy
///
/// These adjust [CompanionVitals] — the companion's own mood, energy, focus and
/// relationship with the player. They are *not* XP, coins, focus records,
/// inventory or craft progress, and nothing here can reach any of those: the
/// class has no vocabulary for them, and the simulation that applies an effect
/// has no repository to write through.
///
/// That distinction is the whole reason this is safe to add. The existing rule
/// that *animation may never write business state* still holds exactly; this
/// introduces a second, companion-local state that is presentation.
class FurnitureEffect {
  /// Change to energy, clamped to `0…100` after application.
  final int energy;

  /// Change to mood, clamped to `0…100`.
  final int mood;

  /// Change to focus level, clamped to `0…100`.
  final int focus;

  /// Change to the relationship with the player, clamped to `0…100`.
  final int relationship;

  /// Collection item ids this action reveals progress toward, if any.
  ///
  /// Reading at a bookshelf advances *knowledge*, which the brief lists as this
  /// object's purpose. Kept as ids rather than a number so the presentation can
  /// name what was learned without inventing a currency.
  final List<String> knowledge;

  const FurnitureEffect({
    this.energy = 0,
    this.mood = 0,
    this.focus = 0,
    this.relationship = 0,
    this.knowledge = const [],
  });

  /// The neutral effect, for actions that are pure behaviour.
  static const FurnitureEffect none = FurnitureEffect();

  bool get isNeutral =>
      energy == 0 &&
      mood == 0 &&
      focus == 0 &&
      relationship == 0 &&
      knowledge.isEmpty;

  @override
  String toString() => 'FurnitureEffect(e$energy m$mood f$focus '
      'r$relationship${knowledge.isEmpty ? '' : ' k=${knowledge.length}'})';
}

/// One thing that can be done with a piece of furniture.
///
/// The brief's sofa example maps onto this directly:
///
/// ```text
/// Interaction: sit / rest / nap
/// Trigger:     energy < 40 or player taps sofa
/// Effect:      energy +10, mood +5
/// Animation:   go sofa anchor, play sit animation
/// ```
///
/// — three [FurnitureAction]s, each with its own [triggers], [effect] and
/// [companionAction].
class FurnitureAction {
  /// The action id, e.g. `sit`.
  final String id;

  /// What the player sees on the affordance, e.g. `坐下休息`.
  final String label;

  /// The **semantic companion action** this performs, e.g. `room_sit`.
  ///
  /// This is the join to the sprite pipeline: the value must resolve in the
  /// companion's action manifest, so the frame sequence that plays is whatever
  /// that companion ships for this action. Nothing here names a frame.
  final String companionAction;

  /// When this action is available. Never empty — an action with no trigger
  /// could never be chosen.
  final List<FurnitureTrigger> triggers;

  /// What it does to the companion.
  final FurnitureEffect effect;

  /// Whether the action only exists once the item is unlocked.
  ///
  /// This is the acceptance criterion `furniture unlock changes gameplay`:
  /// an action with this set is unreachable until the player owns the furniture,
  /// so acquiring the sofa genuinely adds a behaviour rather than a picture.
  final bool requiresUnlock;

  /// How long the companion commits to this action before re-evaluating.
  ///
  /// Bounded on both ends so a malformed value cannot produce a companion that
  /// never moves or one that twitches between actions every frame.
  final Duration minDwell;
  final Duration maxDwell;

  const FurnitureAction({
    required this.id,
    required this.label,
    required this.companionAction,
    required this.triggers,
    this.effect = FurnitureEffect.none,
    this.requiresUnlock = true,
    this.minDwell = const Duration(seconds: 12),
    this.maxDwell = const Duration(seconds: 26),
  });

  bool isAvailableOn(FurnitureTrigger trigger) => triggers.contains(trigger);

  @override
  String toString() => 'FurnitureAction($id → $companionAction via '
      '${triggers.map((t) => t.id).join('|')})';
}

/// A piece of furniture the companion can live with.
class FurnitureEntity {
  /// The item id, e.g. `sofa`. Matches `RoomItem.itemId` and
  /// `CraftRecipe.outputItemId`.
  final String id;

  /// What kind of object it is.
  final FurnitureType type;

  /// The player-facing name.
  final String label;

  /// Why the player wants it, in one line. Shown on the affordance, so the
  /// player learns the object's purpose from the object.
  final String purpose;

  /// The interaction-point roles this furniture offers, e.g. `['seat']`.
  ///
  /// A role is what the anchor registry keys on; the anchor's *coordinates* come
  /// from where the player actually put the item, never from here.
  final List<String> interactionPoints;

  /// The business predicates that must hold, mirroring the recipe manifest:
  /// `owned`, `placed`, `visible`.
  final List<String> requiredConditions;

  /// What can be done with it. Never empty.
  final List<FurnitureAction> actions;

  /// The behaviour shown when the companion is merely near this furniture and
  /// nothing else applies, if any.
  final String? ambientAction;

  const FurnitureEntity({
    required this.id,
    required this.type,
    required this.label,
    this.purpose = '',
    this.interactionPoints = const [],
    this.requiredConditions = const ['owned', 'placed', 'visible'],
    required this.actions,
    this.ambientAction,
  });

  /// The action with [actionId], or `null`.
  FurnitureAction? actionById(String actionId) {
    for (final action in actions) {
      if (action.id == actionId) return action;
    }
    return null;
  }

  /// Every action available from [trigger].
  List<FurnitureAction> actionsFor(FurnitureTrigger trigger) => [
        for (final a in actions)
          if (a.isAvailableOn(trigger)) a
      ];

  /// The first action that is both triggered by [trigger] and unlocked for a
  /// player with [unlocked].
  FurnitureAction? actionFor(
    FurnitureTrigger trigger, {
    required bool unlocked,
  }) {
    for (final action in actions) {
      if (!action.isAvailableOn(trigger)) continue;
      if (action.requiresUnlock && !unlocked) continue;
      return action;
    }
    return null;
  }

  @override
  String toString() =>
      'FurnitureEntity($id ${type.id} ${actions.length} actions)';
}
