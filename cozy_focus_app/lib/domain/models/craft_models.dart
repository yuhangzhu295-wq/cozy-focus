import 'enums.dart';

class CraftRecipe {
  final String id;
  final String name;
  final String? description;
  final int requiredMinutes;
  final Map<String, int> ingredientCosts;
  final String outputItemId;
  final int outputQuantity;
  final String? artworkPath;

  /// Emoji icon used when no artworkPath asset exists.
  final String icon;

  const CraftRecipe({
    required this.id,
    required this.name,
    this.description,
    required this.requiredMinutes,
    required this.ingredientCosts,
    required this.outputItemId,
    required this.outputQuantity,
    this.artworkPath,
    this.icon = '📦',
  });

  int get requiredSeconds => requiredMinutes * 60;
}

class CraftJob {
  final String id;
  final String userId;
  final String recipeId;
  final CraftJobStatus status;

  /// Accumulated focus seconds contributed to this job.
  final int progressSeconds;
  final DateTime startedAt;
  final DateTime? completedAt;
  final bool rewardClaimed;
  final String? sessionId;

  const CraftJob({
    required this.id,
    required this.userId,
    required this.recipeId,
    required this.status,
    required this.progressSeconds,
    required this.startedAt,
    this.completedAt,
    required this.rewardClaimed,
    this.sessionId,
  });

  CraftJob copyWith({
    String? id,
    String? userId,
    String? recipeId,
    CraftJobStatus? status,
    int? progressSeconds,
    DateTime? startedAt,
    DateTime? completedAt,
    bool? rewardClaimed,
    String? sessionId,
  }) {
    return CraftJob(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      recipeId: recipeId ?? this.recipeId,
      status: status ?? this.status,
      progressSeconds: progressSeconds ?? this.progressSeconds,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

class InventoryItem {
  final String id;
  final String userId;
  final String itemId;
  final int quantity;
  final DateTime updatedAt;

  const InventoryItem({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.quantity,
    required this.updatedAt,
  });

  InventoryItem copyWith({int? quantity, DateTime? updatedAt}) => InventoryItem(
        id: id,
        userId: userId,
        itemId: itemId,
        quantity: quantity ?? this.quantity,
        updatedAt: updatedAt ?? this.updatedAt,
      );
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

  RoomItem copyWith({
    double? positionX,
    double? positionY,
    double? scale,
    int? zIndex,
    bool? isVisible,
  }) =>
      RoomItem(
        id: id,
        userId: userId,
        itemId: itemId,
        positionX: positionX ?? this.positionX,
        positionY: positionY ?? this.positionY,
        scale: scale ?? this.scale,
        zIndex: zIndex ?? this.zIndex,
        isVisible: isVisible ?? this.isVisible,
        placedAt: placedAt,
      );
}
