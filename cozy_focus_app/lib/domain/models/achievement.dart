import 'enums.dart';

class Achievement {
  final String id;
  final String userId;
  final String achievementKey; // unique slug, e.g. "first_session"
  final AchievementType type;
  final String title;
  final String? description;
  final int threshold; // target value (count/minutes/days)
  final int currentValue;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final DateTime createdAt;

  const Achievement({
    required this.id,
    required this.userId,
    required this.achievementKey,
    required this.type,
    required this.title,
    this.description,
    required this.threshold,
    required this.currentValue,
    required this.isUnlocked,
    this.unlockedAt,
    required this.createdAt,
  });
}
