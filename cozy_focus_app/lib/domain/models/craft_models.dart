import 'enums.dart';

class CraftRecipe {
  final String id;
  final String name;
  final String? description;
  final int requiredMinutes;  // focus minutes needed to unlock
  final Map<String, int> ingredientCosts;  // itemId → quantity
  final String outputItemId;
  final int outputQuantity;
  final String? artworkPath;

  const CraftRecipe({
    required this.id,
    required this.name,
    this.description,
    required this.requiredMinutes,
    required this.ingredientCosts,
    required this.outputItemId,
    required this.outputQuantity,
    this.artworkPath,
  });
}

class CraftJob {
  final String id;
  final String userId;
  final String recipeId;
  final CraftJobStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final bool rewardClaimed;
  final String? sessionId;  // session that triggered this craft

  const CraftJob({
    required this.id,
    required this.userId,
    required this.recipeId,
    required this.status,
    required this.startedAt,
    this.completedAt,
    required this.rewardClaimed,
    this.sessionId,
  });
}

class InventoryItem {
  final String id;
  final String userId;
  final String itemId;     // references item definition catalog
  final int quantity;
  final DateTime updatedAt;

  const InventoryItem({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.quantity,
    required this.updatedAt,
  });
}

class RoomItem {
  final String id;
  final String userId;
  final String itemId;
  final double positionX;
  final double positionY;
  final double scale;
  final int zIndex;
  final bool isVisible;
  final DateTime placedAt;

  const RoomItem({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.positionX,
    required this.positionY,
    required this.scale,
    required this.zIndex,
    required this.isVisible,
    required this.placedAt,
  });
}
