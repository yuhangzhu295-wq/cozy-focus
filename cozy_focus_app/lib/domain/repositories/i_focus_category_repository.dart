import '../models/focus_category.dart';

abstract interface class IFocusCategoryRepository {
  Future<void> save(FocusCategory category);
  Future<void> update(FocusCategory category);
  Future<List<FocusCategory>> findAll(String userId);
  Future<FocusCategory?> findById(String id);
  Future<void> archive(String id);
}
