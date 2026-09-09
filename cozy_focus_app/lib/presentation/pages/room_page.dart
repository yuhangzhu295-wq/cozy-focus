import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/craft_models.dart';
import '../controllers/craft_controller.dart';
import '../theme/app_theme.dart';

/// Screen 09: Room Decoration Page (房间)
/// Allows placing, moving, and removing inventory items in the room.
/// Positions are persisted via CraftController -> ICraftRepository.
/// No fake furniture — only items from real InventoryItems.
class RoomPage extends ConsumerStatefulWidget {
  const RoomPage({super.key});

  @override
  ConsumerState<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends ConsumerState<RoomPage> {
  String? _selectedRoomItemId;
  bool _showInventoryPanel = false;

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
        elevation: 0,
        title: const Text('Mochi 的小房间'),
        leading: BackButton(onPressed: () => context.go('/')),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: '库存',
            onPressed: () => context.go('/inventory'),
          ),
          IconButton(
            icon: const Icon(Icons.handyman_outlined),
            tooltip: '制作工坊',
            onPressed: () => context.go('/craft'),
          ),
        ],
      ),
      body: craft.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Room canvas
                Expanded(
                  child: Stack(
                    children: [
                      // Room background
                      _buildRoomBackground(),
                      // Placed items
                      ...craft.roomItems.map((item) {
                        final recipe = craft.recipes
                            .where((r) => r.outputItemId == item.itemId)
                            .firstOrNull;
                        return _PlacedItemWidget(
                          key: ValueKey(item.id),
                          roomItem: item,
                          recipe: recipe,
                          isSelected: _selectedRoomItemId == item.id,
                          onSelect: () {
                            setState(() {
                              _selectedRoomItemId =
                                  _selectedRoomItemId == item.id
                                      ? null
                                      : item.id;
                            });
                          },
                          onMove: (dx, dy) async {
                            final size = MediaQuery.of(context).size;
                            final newX = (item.positionX + dx / size.width)
                                .clamp(0.0, 1.0);
                            final newY = (item.positionY + dy / size.height)
                                .clamp(0.0, 1.0);
                            await ref
                                .read(craftControllerProvider.notifier)
                                .moveRoomItem(item.id, newX, newY);
                          },
                        );
                      }),
                      // Selection toolbar
                      if (_selectedRoomItemId != null)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _SelectionToolbar(
                            onDelete: () async {
                              await ref
                                  .read(craftControllerProvider.notifier)
                                  .removeRoomItem(_selectedRoomItemId!);
                              setState(() => _selectedRoomItemId = null);
                            },
                            onDeselect: () =>
                                setState(() => _selectedRoomItemId = null),
                          ),
                        ),
                      // Empty state
                      if (craft.roomItems.isEmpty)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🏠', style: TextStyle(fontSize: 56)),
                              const SizedBox(height: 12),
                              const Text(
                                '房间空空的，先去制作些家具吧',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.handyman_outlined),
                                label: const Text('前往制作工坊'),
                                onPressed: () => context.go('/craft'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Add furniture panel toggle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: _showInventoryPanel ? 180 : 0,
                  child: _showInventoryPanel
                      ? _InventoryPanel(
                          craft: craft,
                          onPlace: (recipe) async {
                            // Place near center with slight offset
                            final count = craft.roomItems.length;
                            final x = 0.3 + (count * 0.05).clamp(0.0, 0.4);
                            final y = 0.3 + (count * 0.05).clamp(0.0, 0.4);
                            await ref
                                .read(craftControllerProvider.notifier)
                                .placeItem(recipe.outputItemId, x, y);
                            setState(() => _showInventoryPanel = false);
                          },
                        )
                      : const SizedBox.shrink(),
                ),

                // Bottom action bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                        top: BorderSide(color: AppColors.border, width: 1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(
                            _showInventoryPanel
                                ? Icons.keyboard_arrow_down
                                : Icons.add_rounded,
                          ),
                          label: Text(_showInventoryPanel ? '收起' : '摆放家具'),
                          onPressed: () {
                            setState(() =>
                                _showInventoryPanel = !_showInventoryPanel);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.timer_outlined),
                          label: const Text('去专注'),
                          onPressed: () => context.go('/focus/setup'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRoomBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF5EFE6),
            Color(0xFFEDE6D8),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _RoomFloorPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Simple floor-perspective floor painter
class _RoomFloorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final floorPaint = Paint()
      ..color = const Color(0xFFD9CDBB).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..lineTo(size.width, size.height * 0.55)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, floorPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlacedItemWidget extends StatefulWidget {
  final RoomItem roomItem;
  final CraftRecipe? recipe;
  final bool isSelected;
  final VoidCallback onSelect;
  final void Function(double dx, double dy) onMove;

  const _PlacedItemWidget({
    required super.key,
    required this.roomItem,
    required this.recipe,
    required this.isSelected,
    required this.onSelect,
    required this.onMove,
  });

  @override
  State<_PlacedItemWidget> createState() => _PlacedItemWidgetState();
}

class _PlacedItemWidgetState extends State<_PlacedItemWidget> {
  Offset _dragStart = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final left = widget.roomItem.positionX * size.width;
    final top = widget.roomItem.positionY * size.height * 0.7;

    return Positioned(
      left: left - 30,
      top: top - 30,
      child: GestureDetector(
        onTap: widget.onSelect,
        onPanStart: (d) => _dragStart = d.globalPosition,
        onPanUpdate: (d) {
          final delta = d.globalPosition - _dragStart;
          _dragStart = d.globalPosition;
          widget.onMove(delta.dx, delta.dy);
        },
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color:
                widget.isSelected ? AppColors.primaryLight : Colors.transparent,
            border: widget.isSelected
                ? Border.all(
                    color: AppColors.primarySage,
                    width: 2,
                  )
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              widget.recipe?.icon ?? '📦',
              style: TextStyle(fontSize: widget.roomItem.scale * 32),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback onDeselect;

  const _SelectionToolbar({
    required this.onDelete,
    required this.onDeselect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.accentPeach),
            tooltip: '移除',
            onPressed: onDelete,
          ),
          IconButton(
            icon:
                const Icon(Icons.close_rounded, color: AppColors.textSecondary),
            tooltip: '取消选择',
            onPressed: onDeselect,
          ),
        ],
      ),
    );
  }
}

class _InventoryPanel extends StatelessWidget {
  final CraftState craft;
  final void Function(CraftRecipe recipe) onPlace;

  const _InventoryPanel({required this.craft, required this.onPlace});

  @override
  Widget build(BuildContext context) {
    // Only show items that have been crafted (in inventory)
    final placedCounts = <String, int>{};
    for (final r in craft.roomItems) {
      placedCounts[r.itemId] = (placedCounts[r.itemId] ?? 0) + 1;
    }
    final placeable = craft.inventory.where((inv) {
      final placed = placedCounts[inv.itemId] ?? 0;
      return inv.quantity > placed;
    }).toList();

    if (placeable.isEmpty) {
      return Container(
        color: AppColors.surface,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('库存中没有可摆放的家具',
                  style: TextStyle(color: AppColors.textSecondary)),
              Text('去制作工坊制作更多家具吧',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
        ),
      );
    }

    return Container(
      color: AppColors.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: placeable.length,
        itemBuilder: (context, i) {
          final inv = placeable[i];
          final recipe = craft.recipes
              .where((r) => r.outputItemId == inv.itemId)
              .firstOrNull;
          final icon = recipe?.icon ?? '📦';
          final name = recipe?.name ?? inv.itemId;
          return GestureDetector(
            onTap: () => recipe != null ? onPlace(recipe) : null,
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.backgroundWarm,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
