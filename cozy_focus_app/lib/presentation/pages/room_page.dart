import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/craft_models.dart';
import '../controllers/craft_controller.dart';
import '../theme/app_theme.dart';
import '../../core/geometry/room_geometry.dart';

/// Screen 09: Room Decoration Page (房间装饰).
///
/// Furniture positions are stored as normalised coordinates [0.0, 1.0]
/// relative to the **room canvas** (not the full screen), computed via
/// [LayoutBuilder].  During a drag only local UI state is updated; a single
/// DB persist happens on [GestureDetector.onPanEnd].
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
                // Room canvas — fills available space; LayoutBuilder provides
                // real canvas dimensions for normalised coordinate mapping.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final canvasWidth = constraints.maxWidth;
                      final canvasHeight = constraints.maxHeight;

                      return Stack(
                        children: [
                          _buildRoomBackground(),
                          ...craft.roomItems.map((item) {
                            final recipe = craft.recipes
                                .where((r) => r.outputItemId == item.itemId)
                                .firstOrNull;
                            return _PlacedItemWidget(
                              key: ValueKey(item.id),
                              roomItem: item,
                              recipe: recipe,
                              canvasWidth: canvasWidth,
                              canvasHeight: canvasHeight,
                              isSelected: _selectedRoomItemId == item.id,
                              onSelect: () {
                                setState(() {
                                  _selectedRoomItemId =
                                      _selectedRoomItemId == item.id
                                          ? null
                                          : item.id;
                                });
                              },
                              // Called once on drag-end with final normalised coords.
                              onMoveEnd: (nx, ny) async {
                                await ref
                                    .read(craftControllerProvider.notifier)
                                    .moveRoomItem(item.id, nx, ny);
                              },
                            );
                          }),
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
                          if (craft.roomItems.isEmpty)
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🏠',
                                      style: TextStyle(fontSize: 56)),
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
                      );
                    },
                  ),
                ),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: _showInventoryPanel ? 180 : 0,
                  child: _showInventoryPanel
                      ? _InventoryPanel(
                          craft: craft,
                          onPlace: (recipe) async {
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

/// Displays a single placed furniture item and handles drag interaction.
///
/// Positions are stored as normalised coords [0.0, 1.0] relative to the room
/// canvas.  During drag, a local transient offset is maintained purely in
/// widget state (no DB writes).  [onMoveEnd] is called **once** with the
/// final normalised position when the finger lifts.
class _PlacedItemWidget extends StatefulWidget {
  final RoomItem roomItem;
  final CraftRecipe? recipe;
  final bool isSelected;
  final double canvasWidth;
  final double canvasHeight;
  final VoidCallback onSelect;
  final void Function(double nx, double ny) onMoveEnd;

  const _PlacedItemWidget({
    required super.key,
    required this.roomItem,
    required this.recipe,
    required this.isSelected,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onSelect,
    required this.onMoveEnd,
  });

  @override
  State<_PlacedItemWidget> createState() => _PlacedItemWidgetState();
}

class _PlacedItemWidgetState extends State<_PlacedItemWidget> {
  // Transient drag offset in pixels (not persisted until onPanEnd).
  double _dxOffset = 0;
  double _dyOffset = 0;

  static const double _itemSize = 60.0;

  @override
  void didUpdateWidget(_PlacedItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset transient offset when the persisted position changes externally.
    if (oldWidget.roomItem.positionX != widget.roomItem.positionX ||
        oldWidget.roomItem.positionY != widget.roomItem.positionY) {
      _dxOffset = 0;
      _dyOffset = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Convert normalised coords to canvas pixels.
    final baseLeft = widget.roomItem.positionX * widget.canvasWidth;
    final baseTop = widget.roomItem.positionY * widget.canvasHeight;
    // Clamp the transient drag centre so the item stays inside canvas visually.
    final renderedSize = _itemSize * widget.roomItem.scale;
    final clampedDrag = clampNormalizedPosition(
      rawX: (baseLeft + _dxOffset) / widget.canvasWidth,
      rawY: (baseTop + _dyOffset) / widget.canvasHeight,
      canvasWidth: widget.canvasWidth,
      canvasHeight: widget.canvasHeight,
      itemWidth: renderedSize,
      itemHeight: renderedSize,
    );
    final left = clampedDrag.x * widget.canvasWidth - renderedSize / 2;
    final top  = clampedDrag.y * widget.canvasHeight - renderedSize / 2;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: widget.onSelect,
        onPanUpdate: (d) {
          // Update local UI only — no DB write here.
          setState(() {
            _dxOffset += d.delta.dx;
            _dyOffset += d.delta.dy;
          });
        },
        onPanEnd: (_) {
          // Compute final normalised position, clamped so the item stays
          // fully inside the canvas (accounts for item rendered size).
          final finalCentreX = baseLeft + _dxOffset;
          final finalCentreY = baseTop + _dyOffset;
          final clamped = clampNormalizedPosition(
            rawX: finalCentreX / widget.canvasWidth,
            rawY: finalCentreY / widget.canvasHeight,
            canvasWidth: widget.canvasWidth,
            canvasHeight: widget.canvasHeight,
            itemWidth: renderedSize,
            itemHeight: renderedSize,
          );
          // Single DB persist.
          widget.onMoveEnd(clamped.x, clamped.y);
          // Reset transient offset — the parent will rebuild with new DB coords.
          setState(() {
            _dxOffset = 0;
            _dyOffset = 0;
          });
        },
        child: Container(
          width: renderedSize,
          height: renderedSize,
          decoration: BoxDecoration(
            color:
                widget.isSelected ? AppColors.primaryLight : Colors.transparent,
            border: widget.isSelected
                ? Border.all(color: AppColors.primarySage, width: 2)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Tooltip(
              message: widget.recipe?.name ?? widget.roomItem.itemId,
              child: Text(
                widget.recipe?.icon ?? '📦',
                style: TextStyle(fontSize: widget.roomItem.scale * 32),
              ),
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
