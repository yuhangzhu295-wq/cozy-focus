import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/craft_models.dart';
import '../room/anchor_point.dart';
import '../room_presence.dart';
import 'furniture_action_resolver.dart';
import '../companion_selection.dart';
import '../pack/companion_availability_provider.dart';
import '../runtime/companion_action_availability.dart';
import '../room/furniture_catalog.dart';
import '../room/furniture_entity.dart';
import '../room/room_simulation.dart';

/// The affordance shown when the player taps a piece of furniture.
///
/// ## What changed, and why it matters
///
/// The room used to answer a tap with ownership: *"已拥有"*. Ownership is not an
/// interaction — it is a property, and telling the player about it again teaches
/// them nothing and gives them nothing to do.
///
/// This panel answers with **use**: `让 Mochi 使用`, plus the specific actions the
/// object supports and what each one does. That is the brief's
/// `Tap furniture → "让 Mochi 使用"`, and it is also where the player learns
/// what the object is *for*, which is the thing a collection card could never
/// tell them.
///
/// ## It never offers something that cannot happen
///
/// Every action listed is checked against ownership and against the furniture
/// still being placed. An action the companion cannot perform is not shown
/// greyed out — it is absent, so there are no fake buttons.
class FurnitureUsePanel extends ConsumerWidget {
  /// The placed row the player tapped.
  final RoomItem roomItem;

  /// The player-facing name of the furniture.
  final String label;

  /// Whether the player owns the furniture.
  final bool unlocked;

  /// Called when the player picks an action.
  final void Function(FurnitureAction action) onUse;

  /// Called when the player dismisses the panel.
  final VoidCallback onDismiss;

  const FurnitureUsePanel({
    super.key,
    required this.roomItem,
    required this.label,
    required this.unlocked,
    required this.onUse,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entity = FurnitureCatalog.forId(roomItem.itemId);
    // Through the availability provider, not the resolver directly: the resolver
    // knows the shipped three and would answer for an installed pack with the
    // dog's capabilities, offering a chip the pack has no art to perform.
    final availability = ref.watch(companionAvailabilityProvider)(
      ref.watch(companionSelectionProvider).value,
    );
    // The panel names the companion, so it asks which one is selected. Both
    // lines used to say "Mochi", which was wrong as soon as the selected
    // companion was an imported one.
    final companionName = ref.watch(companionDisplayNameProvider);

    final offerable = entity == null
        ? const <FurnitureAction>[]
        : [
            for (final action in entity.actions)
              if (isOfferable(availability, action)) action,
          ];

    if (entity == null || !unlocked) {
      return _frame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('这件家具暂时不能让 $companionName 使用',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9A8F80))),
          ],
        ),
      );
    }

    return _frame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          if (entity.purpose.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(entity.purpose,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9A8F80))),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in offerable)
                _actionChip(action, companionName),
            ],
          ),
          if (offerable.isEmpty)
            const Text(
              '这件家具现在没有能做的动作',
              style: TextStyle(fontSize: 12, color: Color(0xFF9A8F80)),
            ),
        ],
      ),
    );
  }

  Widget _actionChip(FurnitureAction action, String companionName) {
    final effect = describeEffect(action.effect);
    return GestureDetector(
      onTap: () => onUse(action),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F6EF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCFE0C8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('让 $companionName ${action.label}',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            if (effect.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(effect,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF7E9B74))),
            ],
          ],
        ),
      ),
    );
  }

  /// Whether [action] may be offered as a player choice.
  ///
  /// P28.4: an action the companion cannot actually show is not a choice, it is
  /// a button that lies. 坐下 on the sofa and 坐一会儿 on the rug are the two
  /// that failed this: `room_sit` has no frames of its own in any pack, no
  /// `drawAliases` entry, and the rig draws it as `MochiPoseSpec(earRotation:
  /// 0.06)` — the idle pose with a fractionally turned ear. Every layer says
  /// idle, so the label promised a sit the player never saw.
  ///
  /// Adding approved art is the other way to fix it and is not an option here:
  /// inventing placeholder art is explicitly out of bounds. So the unsupported
  /// action is hidden instead, and the row reports that it has nothing to offer
  /// rather than offering something it cannot show.
  ///
  /// This is deliberately a *capability* test, not a hardcoded list: give
  /// `room_sit` real frames, or a `drawAliases` entry, and the chip comes back
  /// with no code change here.
  @visibleForTesting
  static bool isOfferable(
    CompanionActionAvailability availability,
    FurnitureAction action,
  ) {
    // The catalog is the authority on what a tap can cause. `sofa/nap` carries
    // only the `energyLow` trigger — it is something the companion does when it
    // is tired, not something the player commands — yet the panel offered it,
    // because the filter tested drawability alone. An action a tap is not
    // declared to cause is not a player choice.
    if (!action.triggers.contains(FurnitureTrigger.playerTap)) return false;

    // One question, asked in one place. `canShow` is `canSchedule` and
    // `hasOwnDrawing` together, and it is the same test the room's decision loop
    // applies before committing an action — so the chip a player can tap and the
    // action the companion may perform cannot drift apart. An action id that is
    // not a companion action at all is `false`, which is what the old macro
    // lookup was for.
    return availability.canShow(action.companionAction);
  }

  /// Renders an effect in the player's terms, or an empty string when neutral.
  ///
  /// Words rather than numbers: the player is choosing an interaction, not
  /// tuning a stat sheet, and a signed integer is not what the object *means*.
  ///
  /// ## Every phrase here has to be true
  ///
  /// P28.5: a phrase may only appear when the corresponding effect has a real,
  /// observable runtime consequence. The three meters the room shows —
  /// [CompanionVitalsBar]'s 心情 / 精力 / 专注 — are the whole of what a
  /// furniture action can currently change, so those are the only three things
  /// promised.
  ///
  /// `FurnitureEffect.knowledge` used to add 认识新事物 here. Nothing reads it:
  /// `CompanionVitals.copyWithEffect` carries mood, energy, focus and
  /// relationship, no page shows a knowledge value, and no session or craft
  /// record is written from it. The phrase promised a consequence that did not
  /// exist, so the promise was removed rather than a knowledge mechanic invented
  /// to justify it. The field stays as data for a future feature that would have
  /// to earn the sentence back.
  @visibleForTesting
  static String describeEffect(FurnitureEffect effect) {
    final parts = <String>[];
    if (effect.energy > 0) parts.add('恢复精神');
    if (effect.energy < 0) parts.add('消耗一些精力');
    if (effect.mood > 0) parts.add('心情变好');
    if (effect.focus > 0) parts.add('更专注');
    return parts.join(' · ');
  }

  Widget _frame({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6DFD2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}

/// The companion's current state, in the player's words.
///
/// The brief asks the player to feel *"I have a living companion in a room"*.
/// A living thing visibly has how it is doing; showing that is what makes the
/// object an entity rather than a picture.
class CompanionVitalsBar extends StatelessWidget {
  final RoomSimulationState simulation;

  /// The selected companion's display name.
  ///
  /// Passed in rather than read here, because this widget is stateless and the
  /// name is the one piece of identity it needs. Before this it hardcoded
  /// "Mochi", so a player who had chosen the cat or the rabbit was told that
  /// Mochi was wandering around their room.
  final String companionName;

  /// What the selected companion can actually be seen doing.
  ///
  /// The activity sentence may only name an action this says yes to; see
  /// `_activityLabel`.
  final CompanionActionAvailability availability;

  const CompanionVitalsBar({
    super.key,
    required this.simulation,
    required this.companionName,
    required this.availability,
  });

  @override
  Widget build(BuildContext context) {
    final vitals = simulation.vitals;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6DFD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_activityLabel(simulation, companionName, availability),
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _meter('心情', vitals.mood, const Color(0xFFE8A0A8)),
          const SizedBox(height: 6),
          _meter('精力', vitals.energy, const Color(0xFF9CC48E)),
          const SizedBox(height: 6),
          _meter('专注', vitals.focusLevel, const Color(0xFF8FB8D8)),
        ],
      ),
    );
  }

  /// What the companion is doing, in the player's words.
  ///
  /// [companionName] is the selected companion's name, so the sentence follows
  /// the player's choice instead of always naming Mochi.
  ///
  /// ## The sentence may only name an action the companion can be seen doing
  ///
  /// The same rule the panel applies to its chips, for the same reason: a
  /// sentence that names an action promises the player will see it. `room_sit`
  /// has no frames of its own in any pack — every layer draws idle — so a
  /// routine that rests the companion on the sofa produced "咪咪 正在坐一会儿"
  /// over a standing pet. The chip was hidden for exactly this (P28.4) and the
  /// status line kept saying it, because the two asked different questions.
  ///
  /// `canShow`, not `canPerform`: the room's *decision* deliberately allows a
  /// declared fallback so the dog can use its own sofa, and that stays. This is
  /// about what the player is told, which is the stricter question — see
  /// `CompanionActionAvailability.canShow`.
  static String _activityLabel(RoomSimulationState simulation,
      String companionName, CompanionActionAvailability availability) {
    final actionId = simulation.activity.actionId;
    if (actionId != null) {
      final entity = FurnitureCatalog.forId(
          _itemIdFromAnchor(simulation.activity.anchorId));
      final action = entity?.actionById(actionId);
      if (action != null && availability.canShow(action.companionAction)) {
        return '$companionName 正在${action.label}';
      }
    }
    return switch (simulation.cause) {
      RoomDecisionCause.focus => '$companionName 在陪你专注',
      RoomDecisionCause.night => '夜深了，$companionName 有点困',
      RoomDecisionCause.tired => '$companionName 有点累了',
      RoomDecisionCause.playerRequest => '$companionName 听你的',
      // A routine decision always carries an action, so this line is only
      // reached if the catalog lost the action the routine named. It reads as
      // the day rather than as a failure.
      RoomDecisionCause.routine => '$companionName 在过自己的小日子',
      RoomDecisionCause.idle => '$companionName 在房间里晃悠',
    };
  }

  static String _itemIdFromAnchor(String anchorId) =>
      anchorId.endsWith('_anchor')
          ? anchorId.substring(0, anchorId.length - '_anchor'.length)
          : anchorId;

  Widget _meter(String label, int value, Color color) => Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9A8F80))),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 6,
                backgroundColor: const Color(0xFFF0EBE1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 26,
            child: Text('$value',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9A8F80))),
          ),
        ],
      );
}

/// The anchor a tapped room item resolves to, or `null` when it has none.
AnchorPoint? anchorForRoomItem({
  required List<RoomItem> placed,
  required List<InventoryItem> owned,
  required String roomItemId,
}) {
  final anchors = FurnitureAnchorRegistry.build(
    placed: placed,
    owned: owned,
    eligibleItemIds: FurnitureCatalog.itemIds,
    surfaceFractionFor: PetRoomPresenceResolver.seatSurfaceFraction,
  );
  return FurnitureAnchorRegistry.forRoomItem(anchors, roomItemId);
}

/// Every action the companion can be asked to perform on [itemId].
List<FurnitureAction> usableActionsFor(String itemId) =>
    FurnitureCatalog.forId(itemId)?.actions ?? const [];
