import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/craft_models.dart';
import '../controllers/craft_controller.dart';
import '../theme/app_theme.dart';

/// Screen 09C: Inventory Page (库存)
/// Shows all owned InventoryItems from real data. No fake items.
class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
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
        title: const Text('我的库存'),
        leading: BackButton(onPressed: () => context.go('/room')),
        actions: [
          TextButton(
            onPressed: () => context.go('/room'),
            child: const Text('前往房间'),
          ),
        ],
      ),
      body: craft.isLoading
          ? const Center(child: CircularProgressIndicator())
          : craft.inventory.isEmpty
              ? _buildEmptyState(context, craft)
              : _buildGrid(context, craft),
    );
  }

  Widget _buildEmptyState(BuildContext context, CraftState craft) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📦', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              '库存暂时空空如也',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '通过专注时间制作家具，\n它们会出现在这里',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.handyman_outlined),
              label: const Text('前往制作工坊'),
              onPressed: () => context.go('/craft'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, CraftState craft) {
    // Find placed counts per itemId
    final placedCounts = <String, int>{};
    for (final r in craft.roomItems) {
      placedCounts[r.itemId] = (placedCounts[r.itemId] ?? 0) + 1;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: craft.inventory.length,
      itemBuilder: (context, i) {
        final item = craft.inventory[i];
        final recipe = craft.recipes
            .where((r) => r.outputItemId == item.itemId)
            .firstOrNull;
        final placedCount = placedCounts[item.itemId] ?? 0;
        final unplaced = (item.quantity - placedCount).clamp(0, item.quantity);
        return _InventoryCell(
          item: item,
          recipe: recipe,
          placedCount: placedCount,
          unplacedCount: unplaced,
          onPlace: () => context.go('/room'),
        );
      },
    );
  }
}

class _InventoryCell extends StatelessWidget {
  final InventoryItem item;
  final CraftRecipe? recipe;
  final int placedCount;
  final int unplacedCount;
  final VoidCallback onPlace;

  const _InventoryCell({
    required this.item,
    required this.recipe,
    required this.placedCount,
    required this.unplacedCount,
    required this.onPlace,
  });

  @override
  Widget build(BuildContext context) {
    final icon = recipe?.icon ?? '📦';
    final name = recipe?.name ?? item.itemId;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'x${item.quantity}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (placedCount > 0)
            Text(
              '已摆放 $placedCount',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.primarySage,
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                textStyle: const TextStyle(fontSize: 12),
                padding: EdgeInsets.zero,
              ),
              onPressed: unplacedCount > 0 ? onPlace : null,
              child: Text(unplacedCount > 0 ? '摆放到房间' : '已全部摆放'),
            ),
          ),
        ],
      ),
    );
  }
}
