import '../models/achievement.dart';

abstract interface class IAchievementRepository {
  Future<void> save(Achievement achievement);
  Future<void> update(Achievement achievement);
  Future<List<Achievement>> findAll(String userId);
  Future<Achievement?> findByKey(String userId, String achievementKey);
  Future<void> unlock(String userId, String achievementKey, DateTime unlockedAt);
}
