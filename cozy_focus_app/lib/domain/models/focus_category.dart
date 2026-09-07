class FocusCategory {
  final String id;
  final String userId;
  final String name;
  final int colorValue;    // ARGB integer
  final String? iconName;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FocusCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.colorValue,
    this.iconName,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });
}
