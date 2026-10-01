import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/craft_models.dart';
import '../room/anchor_point.dart';
import '../room_presence.dart';
import 'furniture_action_resolver.dart';
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

    if (entity == null || !unlocked) {
      return _frame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('这件家具暂时不能让 Mochi 使用',
                style: TextStyle(fontSize: 12, color: Color(0xFF9A8F80))),
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
              for (final action in entity.actions) _actionChip(action),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip(FurnitureAction action) {
    final effect = _describeEffect(action.effect);
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
            Text('让 Mochi ${action.label}',
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

  /// Renders an effect in the player's terms, or an empty string when neutral.
  ///
  /// Words rather than numbers: the player is choosing an interaction, not
  /// tuning a stat sheet, and a signed integer is not what the object *means*.
  static String _describeEffect(FurnitureEffect effect) {
    final parts = <String>[];
    if (effect.energy > 0) parts.add('恢复精神');
    if (effect.energy < 0) parts.add('消耗一些精力');
    if (effect.mood > 0) parts.add('心情变好');
    if (effect.focus > 0) parts.add('更专注');
    if (effect.knowledge.isNotEmpty) parts.add('认识新事物');
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

  const CompanionVitalsBar({super.key, required this.simulation});

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
          Text(_activityLabel(simulation),
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
  static String _activityLabel(RoomSimulationState simulation) {
    final actionId = simulation.activity.actionId;
    if (actionId != null) {
      final entity = FurnitureCatalog.forId(
          _itemIdFromAnchor(simulation.activity.anchorId));
      final action = entity?.actionById(actionId);
      if (action != null) return 'Mochi 正在${action.label}';
    }
    return switch (simulation.cause) {
      RoomDecisionCause.focus => 'Mochi 在陪你专注',
      RoomDecisionCause.night => '夜深了，Mochi 有点困',
      RoomDecisionCause.tired => 'Mochi 有点累了',
      RoomDecisionCause.playerRequest => 'Mochi 听你的',
      RoomDecisionCause.idle => 'Mochi 在房间里晃悠',
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
