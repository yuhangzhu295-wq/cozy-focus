import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/craft_models.dart';
import '../controllers/craft_controller.dart';
import '../theme/app_theme.dart';

/// Screen 09A: Craft Workshop List (制作工坊列表)
/// Shows all recipes grouped: InProgress / Available / Completed (in inventory).
/// No fake progress — all data from CraftEngine + ICraftRepository.
class CraftListPage extends ConsumerStatefulWidget {
  const CraftListPage({super.key});

  @override
  ConsumerState<CraftListPage> createState() => _CraftListPageState();
}

class _CraftListPageState extends ConsumerState<CraftListPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(craftControllerProvider.notifier).loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final craft = ref.watch(craftControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('制作工坊'),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: craft.isLoading
          ? const Center(child: CircularProgressIndicator())
          : craft.recipes.isEmpty
              ? _buildEmptyState()
              : _buildList(craft),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📦', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('暂无制作配方', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildList(CraftState craft) {
    final inProgressRecipes = craft.activeJob != null
        ? craft.recipes.where((r) => r.id == craft.activeJob!.recipeId).toList()
        : <CraftRecipe>[];

    final completedItemIds = craft.inventory.map((i) => i.itemId).toSet();

    final availableRecipes = craft.recipes
        .where((r) =>
            r.id != (craft.activeJob?.recipeId) &&
            !completedItemIds.contains(r.outputItemId))
        .toList();

    final completedRecipes = craft.recipes
        .where((r) => completedItemIds.contains(r.outputItemId))
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (inProgressRecipes.isNotEmpty) ...[
          _sectionHeader('制作中', AppColors.accentPeach),
          const SizedBox(height: 8),
          ...inProgressRecipes.map((r) => _RecipeCard(
                recipe: r,
                activeJob: craft.activeJob,
                inventoryItem: null,
              )),
          const SizedBox(height: 16),
        ],
        if (availableRecipes.isNotEmpty) ...[
          _sectionHeader('可制作', AppColors.primarySage),
          const SizedBox(height: 8),
          ...availableRecipes.map((r) => _RecipeCard(
                recipe: r,
                activeJob: craft.activeJob,
                inventoryItem: null,
              )),
          const SizedBox(height: 16),
        ],
        if (completedRecipes.isNotEmpty) ...[
          _sectionHeader('已获得', AppColors.textSecondary),
          const SizedBox(height: 8),
          ...completedRecipes.map((r) {
            final inv = craft.inventory
                .where((i) => i.itemId == r.outputItemId)
                .firstOrNull;
            return _RecipeCard(
              recipe: r,
              activeJob: null,
              inventoryItem: inv,
            );
          }),
        ],
      ],
    );
  }

  Widget _sectionHeader(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RecipeCard extends ConsumerWidget {
  final CraftRecipe recipe;
  final CraftJob? activeJob;
  final InventoryItem? inventoryItem;

  const _RecipeCard({
    required this.recipe,
    required this.activeJob,
    required this.inventoryItem,
  });

  bool get _isActive => activeJob != null && activeJob!.recipeId == recipe.id;
  bool get _isCompleted => inventoryItem != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    double? progress;
    if (_isActive && activeJob != null) {
      final req = recipe.requiredSeconds;
      progress =
          req > 0 ? (activeJob!.progressSeconds / req).clamp(0.0, 1.0) : 0.0;
    }

    return GestureDetector(
      onTap: () => context.push('/craft/detail/${recipe.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: _isActive
                ? AppColors.accentPeach.withValues(alpha: 0.6)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(recipe.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '需要专注 ${recipe.requiredMinutes} 分钟',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
            if (_isActive && progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceMuted,
                  color: AppColors.accentPeach,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(activeJob!.progressSeconds / 60).floor()} / ${recipe.requiredMinutes} min',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    if (_isCompleted) {
      return _chip('已获得', AppColors.primaryLight, AppColors.primaryDark);
    }
    if (_isActive) {
      return _chip('制作中', AppColors.accentPeachLight, AppColors.accentPeach);
    }
    return _chip('可制作', AppColors.surfaceMuted, AppColors.textSecondary);
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
