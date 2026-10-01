/// Chooses *what the companion does*, from state, environment, interaction and
/// time.
///
/// ## The whole point of this file
///
/// The brief's complaint is that the companion "behaves like image switching".
/// The fix is that an action must have a **cause**. This is where the causes are
/// weighed:
///
/// ```text
/// IF focus mode:  desk + write
/// IF break:       sofa + rest
/// IF night:       bed + sleep
/// IF idle:        random room behaviour
/// ```
///
/// ## It resolves; it does not act
///
/// This returns a decision. It does not move the companion, does not change the
/// vitals and does not touch a sprite. The simulation loop applies the decision,
/// which keeps "what should happen" testable without a widget tree and separate
/// from "make it happen".
library;

import '../runtime/companion_id.dart';
import '../time_of_day.dart';
import 'anchor_point.dart';
import 'companion_vitals.dart';
import 'furniture_catalog.dart';
import 'furniture_entity.dart';

/// The reasons the companion might be doing something, in priority order.
///
/// The order *is* the policy. A running focus session outranks being tired,
/// because the player has explicitly asked for focus and the companion is
/// supposed to be working with them — a companion that wandered off to the sofa
/// mid-session would be reading the player's intent wrong.
enum RoomDecisionCause {
  focus('focus'),
  night('night'),
  tired('tired'),
  playerRequest('player_request'),
  idle('idle');

  final String id;
  const RoomDecisionCause(this.id);
}

/// What the companion decided to do, and why.
class RoomDecision {
  final RoomDecisionCause cause;

  /// The furniture involved, when the decision uses some.
  final String? itemId;

  /// The anchor to travel to.
  final String anchorId;

  /// The action being performed, when there is one.
  final String? actionId;

  /// The semantic companion action the sprite pipeline should present.
  final String? companionAction;

  /// What performing it does to the companion.
  final FurnitureEffect effect;

  /// How long the companion commits for.
  final Duration dwell;

  const RoomDecision({
    required this.cause,
    required this.anchorId,
    required this.dwell,
    this.itemId,
    this.actionId,
    this.companionAction,
    this.effect = FurnitureEffect.none,
  });

  bool get isBusy => actionId != null;

  @override
  String toString() => 'RoomDecision(${cause.id} '
      '${actionId ?? 'idle'} @ $anchorId for ${dwell.inSeconds}s)';
}

/// What the world looks like when the decision is made.
class RoomDecisionInput {
  /// The anchors the current placement defines.
  final Map<String, AnchorPoint> anchors;

  /// The companion's current state.
  final CompanionVitals vitals;

  /// The local hour, for the night rule.
  final TimeOfDayBand timeOfDay;

  /// Whether a real focus session is running right now.
  final bool focusRunning;

  /// Whether a real focus session exists but is paused.
  ///
  /// A paused session is a *break*, which is the brief's `IF break: sofa +
  /// rest`. It is distinct from `focusRunning == false`, where there may be no
  /// session at all.
  final bool focusPaused;

  /// Furniture the player owns, so an action cannot be chosen for something that
  /// is not unlocked.
  final Set<String> unlockedItemIds;

  /// An action the player explicitly asked for, if any.
  ///
  /// Set when the player taps a piece of furniture, and cleared once the
  /// companion has started it. It is a *request*, not a command: it is still
  /// checked against ownership and against the furniture still existing, so a
  /// tap cannot make the companion use furniture that was removed meanwhile.
  final PlayerRequest? request;

  /// The companion id, for a future per-companion weighting. Present so the
  /// decision function's signature does not have to change when it is used.
  final CompanionId companionId;

  const RoomDecisionInput({
    required this.anchors,
    required this.vitals,
    required this.timeOfDay,
    required this.unlockedItemIds,
    this.focusRunning = false,
    this.focusPaused = false,
    this.request,
    this.companionId = CompanionId.dog,
  });
}

/// A player's explicit request to use a piece of furniture.
class PlayerRequest {
  final String itemId;
  final String actionId;
  final String roomItemId;

  const PlayerRequest({
    required this.itemId,
    required this.actionId,
    required this.roomItemId,
  });

  @override
  String toString() => 'PlayerRequest($itemId/$actionId @ $roomItemId)';
}

/// Picks the companion's next action.
abstract final class FurnitureActionResolver {
  const FurnitureActionResolver._();

  /// The anchors that satisfy [role], in a stable order.
  static List<AnchorPoint> anchorsForRole(
    Map<String, AnchorPoint> anchors,
    String role,
  ) {
    final matches = <AnchorPoint>[
      for (final anchor in anchors.values)
        if (_roleOf(anchor.itemId) == role) anchor,
    ];
    matches.sort((a, b) => a.roomItemId.compareTo(b.roomItemId));
    return matches;
  }

  /// The interaction-point role a furniture id declares, or `null`.
  static String? _roleOf(String itemId) {
    final entity = FurnitureCatalog.forId(itemId);
    if (entity == null || entity.interactionPoints.isEmpty) return null;
    return entity.interactionPoints.first;
  }

  /// Decides what the companion should do next.
  ///
  /// The order of the branches *is* the priority, and each one is the brief's
  /// own rule. When a branch has furniture to use, it uses it; when it does not,
  /// it falls through to the next branch rather than idling, so a player who
  /// owns only a rug still sees the companion live in the room.
  static RoomDecision decide(RoomDecisionInput input) {
    final request = input.request;
    if (request != null) {
      final requested = _forRequest(input, request);
      if (requested != null) return requested;
    }

    if (input.focusRunning) {
      final decision = _focusDecision(input);
      if (decision != null) return decision;
    }

    if (input.focusPaused) {
      final decision = _breakDecision(input);
      if (decision != null) return decision;
    }

    if (input.timeOfDay == TimeOfDayBand.lateNight || input.vitals.isTired) {
      final decision = _restDecision(input);
      if (decision != null) return decision;
    }

    return _idleDecision(input);
  }

  /// The player asked for a specific action. Honoured only if the furniture is
  /// still placed, still owned, and the action is still defined.
  static RoomDecision? _forRequest(
    RoomDecisionInput input,
    PlayerRequest request,
  ) {
    if (!input.unlockedItemIds.contains(request.itemId)) return null;
    final anchor = FurnitureAnchorRegistry.forRoomItem(
      input.anchors,
      request.roomItemId,
    );
    if (anchor == null) return null;
    final entity = FurnitureCatalog.forId(request.itemId);
    final action = entity?.actionById(request.actionId);
    if (entity == null || action == null) return null;

    return _decisionFor(
      cause: RoomDecisionCause.playerRequest,
      anchor: anchor,
      action: action,
    );
  }

  /// `IF focus mode: desk + write`.
  static RoomDecision? _focusDecision(RoomDecisionInput input) {
    final deskAnchors = anchorsForRole(input.anchors, 'work');
    for (final anchor in deskAnchors) {
      final entity = FurnitureCatalog.forId(anchor.itemId);
      if (entity == null) continue;
      if (!input.unlockedItemIds.contains(anchor.itemId)) continue;
      final action = entity.actionFor(
        FurnitureTrigger.focusRunning,
        unlocked: true,
      );
      if (action == null) continue;
      return _decisionFor(
        cause: RoomDecisionCause.focus,
        anchor: anchor,
        action: action,
      );
    }
    return null;
  }

  /// `IF break: sofa + rest`.
  static RoomDecision? _breakDecision(RoomDecisionInput input) {
    final seatAnchors = anchorsForRole(input.anchors, 'seat');
    for (final anchor in seatAnchors) {
      final entity = FurnitureCatalog.forId(anchor.itemId);
      if (entity == null) continue;
      if (!input.unlockedItemIds.contains(anchor.itemId)) continue;
      final action = entity.actionById('rest') ?? entity.actionById('sit');
      if (action == null) continue;
      return _decisionFor(
        cause: RoomDecisionCause.tired,
        anchor: anchor,
        action: action,
      );
    }
    return null;
  }

  /// `IF night: bed + sleep`, and the tired case.
  ///
  /// The bed is preferred when the hour says night; otherwise the lowest-energy
  /// restoring action available is chosen, which is what makes a tired companion
  /// lie down on a rug if that is all the player owns.
  static RoomDecision? _restDecision(RoomDecisionInput input) {
    final lieAnchors = anchorsForRole(input.anchors, 'lie');
    final isNight = input.timeOfDay == TimeOfDayBand.lateNight;
    for (final anchor in lieAnchors) {
      final entity = FurnitureCatalog.forId(anchor.itemId);
      if (entity == null) continue;
      if (!input.unlockedItemIds.contains(anchor.itemId)) continue;
      final action = entity.actionFor(
        isNight ? FurnitureTrigger.night : FurnitureTrigger.energyLow,
        unlocked: true,
      );
      if (action == null) continue;
      return _decisionFor(
        cause: isNight ? RoomDecisionCause.night : RoomDecisionCause.tired,
        anchor: anchor,
        action: action,
      );
    }

    // No bed. Take the most restorative seat action instead, so a tired
    // companion still visibly rests rather than standing about.
    final seatAnchors = anchorsForRole(input.anchors, 'seat');
    FurnitureAction? best;
    AnchorPoint? bestAnchor;
    for (final anchor in seatAnchors) {
      if (!input.unlockedItemIds.contains(anchor.itemId)) continue;
      final entity = FurnitureCatalog.forId(anchor.itemId);
      if (entity == null) continue;
      for (final action in entity.actions) {
        if (action.effect.energy <= 0) continue;
        if (best == null || action.effect.energy > best.effect.energy) {
          best = action;
          bestAnchor = anchor;
        }
      }
    }
    if (best != null && bestAnchor != null) {
      return _decisionFor(
        cause: isNight ? RoomDecisionCause.night : RoomDecisionCause.tired,
        anchor: bestAnchor,
        action: best,
      );
    }
    return null;
  }

  /// `IF idle: random room behavior`.
  ///
  /// Deliberately deterministic: it walks the anchors in id order and takes the
  /// first unlocked idle action. A random pick here would make the companion
  /// untestable for no gain — the *variety* the brief wants comes from the
  /// dwell expiring and the decision being re-made, not from the pick itself.
  static RoomDecision _idleDecision(RoomDecisionInput input) {
    final anchors = input.anchors.values.toList()
      ..sort((a, b) => a.roomItemId.compareTo(b.roomItemId));
    for (final anchor in anchors) {
      if (!input.unlockedItemIds.contains(anchor.itemId)) continue;
      final entity = FurnitureCatalog.forId(anchor.itemId);
      if (entity == null) continue;
      final action = entity.actionFor(
        FurnitureTrigger.idle,
        unlocked: true,
      );
      if (action == null) continue;
      return _decisionFor(
        cause: RoomDecisionCause.idle,
        anchor: anchor,
        action: action,
      );
    }
    return RoomDecision(
      cause: RoomDecisionCause.idle,
      anchorId: floorAnchor.id,
      dwell: input.vitals.isTired
          ? const Duration(seconds: 20)
          : const Duration(seconds: 12),
    );
  }

  static RoomDecision _decisionFor({
    required RoomDecisionCause cause,
    required AnchorPoint anchor,
    required FurnitureAction action,
  }) =>
      RoomDecision(
        cause: cause,
        itemId: anchor.itemId,
        anchorId: anchor.id,
        actionId: action.id,
        companionAction: action.companionAction,
        effect: action.effect,
        dwell: action.minDwell,
      );
}
