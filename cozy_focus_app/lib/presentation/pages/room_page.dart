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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mochi 的小房间'),
            Text('把专注过的时间，留在这里',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.normal)),
          ],
        ),
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
                  height: _showInventoryPanel ? 220 : 0,
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
        painter: _RoomScenePainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RoomScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wall = Paint()..color = const Color(0xFFF7F0E5);
    canvas.drawRect(Offset.zero & size, wall);
    final sunlight = Paint()
      ..color = const Color(0xFFFFE7A9).withValues(alpha: 0.28);
    final beam = Path()
      ..moveTo(size.width * .12, 0)
      ..lineTo(size.width * .43, 0)
      ..lineTo(size.width * .66, size.height * .64)
      ..lineTo(size.width * .34, size.height * .64)
      ..close();
    canvas.drawPath(beam, sunlight);
    final windowPaint = Paint()..color = const Color(0xFFBFE0D6);
    final window = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .1, size.height * .1, size.width * .28,
            size.height * .27),
        const Radius.circular(12));
    canvas.drawRRect(window, windowPaint);
    final frame = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(size.width * .24, size.height * .1),
        Offset(size.width * .24, size.height * .37), frame);
    canvas.drawLine(Offset(size.width * .1, size.height * .235),
        Offset(size.width * .38, size.height * .235), frame);
    final floorPaint = Paint()..color = const Color(0xFFDCCBB6);
    final floor = Path()
      ..moveTo(0, size.height * .64)
      ..lineTo(size.width, size.height * .64)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(floor, floorPaint);
    final line = Paint()
      ..color = const Color(0xFFCAB79D).withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 1; i < 7; i++) {
      final y = size.height * .64 + i * size.height * .06;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
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
    final top = clampedDrag.y * widget.canvasHeight - renderedSize / 2;

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
              child: _RoomArtwork(
                  recipe: widget.recipe, size: widget.roomItem.scale * 54),
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
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Icon(Icons.home_work_outlined,
                  size: 16, color: AppColors.primarySage),
              SizedBox(width: 6),
              Text('选择家具摆放',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary))
            ]),
          ),
          Expanded(
              child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            itemCount: placeable.length,
            itemBuilder: (context, i) {
              final inv = placeable[i];
              final recipe = craft.recipes
                  .where((r) => r.outputItemId == inv.itemId)
                  .firstOrNull;
              final icon = recipe?.icon ?? '□';
              final name = recipe?.name ?? inv.itemId;
              return GestureDetector(
                onTap: () => recipe != null ? onPlace(recipe) : null,
                child: Container(
                  width: 104,
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
                      SizedBox(
                          width: 44,
                          height: 44,
                          child: recipe?.artworkPath == null
                              ? Text(icon,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 28))
                              : Image.asset(recipe!.artworkPath!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Text(icon,
                                      style: const TextStyle(fontSize: 28)))),
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
          )),
        ],
      ),
    );
  }
}

class _RoomArtwork extends StatelessWidget {
  final CraftRecipe? recipe;
  final double size;
  const _RoomArtwork({required this.recipe, required this.size});

  @override
  Widget build(BuildContext context) {
    if (recipe?.artworkPath != null && recipe!.artworkPath!.isNotEmpty) {
      return Image.asset(recipe!.artworkPath!,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallback());
    }
    return _fallback();
  }

  Widget _fallback() =>
      Text(recipe?.icon ?? '□', style: TextStyle(fontSize: size * .62));
}
