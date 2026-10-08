import 'package:flutter/material.dart';

import '../../domain/models/task.dart';
import '../theme/app_theme.dart';

/// The colour a task category is drawn in.
///
/// One place rather than one per screen: the task list, the today plan and the
/// detail card all show the same chip, and three copies of the same mapping is
/// how 工作 ends up red on one screen and green on another. An unknown or absent
/// category gets the neutral colour rather than a made-up one, so a task whose
/// category was never set does not silently look like 其他.
Color taskCategoryColor(String? categoryId) {
  return switch (categoryId) {
    'life' => AppColors.catLife,
    'study' => AppColors.catStudy,
    'work' => AppColors.catWork,
    _ => AppColors.catOther,
  };
}

/// The icon the designs draw for a category.
///
/// The designs give each category its own mark — a house, an open book, a
/// briefcase, three dots — and every place that offers a category to pick
/// (the capture sheet, the create-task form, the today plan) draws them. Before
/// this existed, the capture sheet drew the same tag glyph four times, and
/// [TaskCategory.iconName] was declared and rendered nowhere.
///
/// Keyed on the model's own `iconName` rather than on the id, so the domain keeps
/// naming its marks and this is only the translation into Flutter's icon set. An
/// unknown name gets the neutral tag rather than a guess.
IconData taskCategoryIcon(String? categoryId) {
  return switch (taskCategoryFor(categoryId)?.iconName) {
    'home' => Icons.home_rounded,
    'book' => Icons.menu_book_rounded,
    'briefcase' => Icons.work_rounded,
    'more' => Icons.more_horiz_rounded,
    _ => Icons.sell_outlined,
  };
}

/// The category chip the designs show: a tinted pill with the category's name.
class TaskCategoryChip extends StatelessWidget {
  final String? categoryId;
  final String label;

  const TaskCategoryChip({
    super.key,
    required this.categoryId,
    required this.label,
  });

  /// Builds the chip from a stored category id, or nothing when the task has no
  /// category — an empty pill would read as a category with no name.
  static Widget? maybe(String? categoryId) {
    final category = taskCategoryFor(categoryId);
    if (category == null) return null;
    return TaskCategoryChip(
      categoryId: category.id,
      label: category.label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = taskCategoryColor(categoryId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
