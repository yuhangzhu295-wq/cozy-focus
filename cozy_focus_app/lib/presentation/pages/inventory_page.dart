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
  _InventoryView _view = _InventoryView.all;

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
      backgroundColor: AppColors.backgroundWarm,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundWarm,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('房间装修'),
            Text(
              '把专注过的时间，留在这里',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        leading: BackButton(onPressed: () => context.go('/room')),
        actions: [
          IconButton(
            tooltip: '前往房间',
            onPressed: () => context.go('/room'),
            icon: const Icon(Icons.meeting_room_outlined),
          ),
        ],
      ),
      body: craft.isLoading
          ? const Center(child: CircularProgressIndicator())
          : craft.inventory.isEmpty
              ? _buildEmptyState(context, craft)
              : _buildContent(context, craft),
    );
  }

  Widget _buildContent(BuildContext context, CraftState craft) {
    final placedCounts = _placedCounts(craft);
    final ownedCount =
        craft.inventory.fold<int>(0, (total, item) => total + item.quantity);
    final placedCount = craft.roomItems.length;
    final availableCount = craft.inventory.fold<int>(0, (total, item) {
      final placed = placedCounts[item.itemId] ?? 0;
      return total + (item.quantity - placed).clamp(0, item.quantity);
    });
    final visibleItems = craft.inventory.where((item) {
      final placed = placedCounts[item.itemId] ?? 0;
      final available = (item.quantity - placed).clamp(0, item.quantity);
      return switch (_view) {
        _InventoryView.all => true,
        _InventoryView.available => available > 0,
        _InventoryView.placed => placed > 0,
      };
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 390 ? 1 : 2;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRoomContext(
                ownedCount: ownedCount,
                placedCount: placedCount,
                availableCount: availableCount,
              ),
              const SizedBox(height: 20),
              _buildViewSelector(
                allCount: craft.inventory.length,
                availableCount: availableCount,
                placedCount: placedCount,
              ),
              const SizedBox(height: 12),
              if (visibleItems.isEmpty)
                _buildFilteredEmpty(context)
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: columns == 1 ? 1.65 : 0.78,
                  ),
                  itemCount: visibleItems.length,
                  itemBuilder: (context, i) {
                    final item = visibleItems[i];
                    final recipe = craft.recipes
                        .where((r) => r.outputItemId == item.itemId)
                        .firstOrNull;
                    final placed = placedCounts[item.itemId] ?? 0;
                    final unplaced =
                        (item.quantity - placed).clamp(0, item.quantity);
                    return _InventoryCell(
                      item: item,
                      recipe: recipe,
                      placedCount: placed,
                      unplacedCount: unplaced,
                      onPlace: () => context.go('/room'),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Map<String, int> _placedCounts(CraftState craft) {
    final placedCounts = <String, int>{};
    for (final roomItem in craft.roomItems) {
      placedCounts[roomItem.itemId] = (placedCounts[roomItem.itemId] ?? 0) + 1;
    }
    return placedCounts;
  }

  Widget _buildRoomContext({
    required int ownedCount,
    required int placedCount,
    required int availableCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.home_work_outlined,
                  color: AppColors.primarySage,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mochi 的小房间',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '选择一件家具，回到房间安排它的位置',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              _RoomMetric(
                icon: Icons.inventory_2_outlined,
                value: '$ownedCount',
                label: '拥有件数',
              ),
              _RoomMetric(
                icon: Icons.home_outlined,
                value: '$placedCount',
                label: '房间中',
              ),
              _RoomMetric(
                icon: Icons.add_home_work_outlined,
                value: '$availableCount',
                label: '可摆放',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewSelector({
    required int allCount,
    required int availableCount,
    required int placedCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '家具状态',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildViewChip(
                view: _InventoryView.all,
                label: '全部',
                count: allCount,
              ),
              const SizedBox(width: 8),
              _buildViewChip(
                view: _InventoryView.available,
                label: '可摆放',
                count: availableCount,
              ),
              const SizedBox(width: 8),
              _buildViewChip(
                view: _InventoryView.placed,
                label: '已摆放',
                count: placedCount,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViewChip({
    required _InventoryView view,
    required String label,
    required int count,
  }) {
    return ChoiceChip(
      avatar: Icon(
        view == _InventoryView.all
            ? Icons.grid_view_rounded
            : view == _InventoryView.available
                ? Icons.add_home_work_outlined
                : Icons.check_circle_outline,
        size: 16,
        color: _view == view ? AppColors.primaryDark : AppColors.textSecondary,
      ),
      label: Text('$label $count'),
      selected: _view == view,
      selectedColor: AppColors.primaryLight,
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: _view == view ? AppColors.primarySage : AppColors.border,
      ),
      onSelected: (_) => setState(() => _view = view),
    );
  }

  Widget _buildFilteredEmpty(BuildContext context) {
    final isPlaced = _view == _InventoryView.placed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            isPlaced ? Icons.home_outlined : Icons.checkroom_outlined,
            size: 40,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            isPlaced ? '还没有摆放家具' : '目前没有可摆放的家具',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isPlaced ? '选择“可摆放”查看还在库存中的家具' : '所有家具都已经在房间里了',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, CraftState craft) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                  color: AppColors.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.weekend_outlined,
                  size: 48, color: AppColors.primarySage),
            ),
            const SizedBox(height: 16),
            const Text(
              '房间还在等第一件家具',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '通过专注时间制作家具，\n让小窝一点点变得温暖',
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
}

enum _InventoryView { all, available, placed }

class _RoomMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _RoomMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.primarySage),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
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
    final status = placedCount == 0
        ? '尚未摆放'
        : unplacedCount == 0
            ? '已全部摆放'
            : '已摆放 $placedCount · 可摆放 $unplacedCount';

    return Container(
      padding: const EdgeInsets.all(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.backgroundWarm,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(
                child: _InventoryArtwork(recipe: recipe, icon: icon),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  '拥有 x${item.quantity}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (placedCount > 0)
                const Icon(
                  Icons.check_circle,
                  size: 14,
                  color: AppColors.primarySage,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: unplacedCount > 0
                  ? AppColors.primarySage
                  : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                textStyle: const TextStyle(fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Icons.add_home_work_outlined, size: 16),
              onPressed: unplacedCount > 0 ? onPlace : null,
              label: Text(unplacedCount > 0 ? '摆放到房间' : '已全部摆放'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryArtwork extends StatelessWidget {
  final CraftRecipe? recipe;
  final String icon;

  const _InventoryArtwork({required this.recipe, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (recipe?.artworkPath != null && recipe!.artworkPath!.isNotEmpty) {
      return Image.asset(
        recipe!.artworkPath!,
        width: 76,
        height: 76,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Text(icon, style: const TextStyle(fontSize: 42));
}
