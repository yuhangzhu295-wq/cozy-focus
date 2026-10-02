import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/craft_models.dart';
import '../../domain/models/enums.dart';
import '../companion/animation/animation_state.dart';
import '../companion/animation/locomotion_controller.dart';
import '../companion/companion_avatar.dart';
import '../companion/companion_selection.dart';
import '../companion/mochi_layered_renderer.dart';
import '../companion/room_presence.dart';
import '../companion/room/anchor_point.dart';
import '../companion/room/companion_placement.dart';
import '../companion/room/furniture_catalog.dart';
import '../companion/room/furniture_use_panel.dart';
import '../companion/room/room_simulation.dart';
import '../controllers/craft_controller.dart';
import '../controllers/focus_session_controller.dart';
import '../theme/app_theme.dart';
import '../../core/geometry/room_geometry.dart';
import '../widgets/cozy_furniture_artwork.dart';
import '../widgets/growth_sub_nav.dart';

/// Rendered size of a placed furniture sprite at `scale == 1`.
///
/// Shared by [_PlacedItemWidget], which draws an item at this size, and
/// `_buildMochi`, which needs it to find the item's sitting surface — one fact,
/// one place, so the two cannot drift apart.
const double _kFurnitureItemSize = 60.0;

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

class _RoomPageState extends ConsumerState<RoomPage>
    with SingleTickerProviderStateMixin {
  String? _selectedRoomItemId;
  bool _showInventoryPanel = false;

  /// The furniture the player asked the companion to use, awaiting their
  /// choice of action.
  ///
  /// Held in UI state rather than in the simulation: the panel is a question,
  /// and a question is not part of the companion's state.
  RoomItem? _useTarget;

  /// Where the companion is between anchors.
  ///
  /// Replaces `AnimatedPositioned`, which moved a box with a tween and left the
  /// sprite showing one still image the whole way. This produces a gait as well
  /// as a position, so the walk frames have something to select on.
  final LocomotionController _locomotion = LocomotionController();

  /// The anchor the current trip set off from, so the drawn box can be
  /// interpolated between two real placements rather than between two numbers.
  AnchorPoint? _travelFrom;

  /// Drives [_locomotion] while a trip is under way, and only then.
  ///
  /// A ticker rather than a periodic timer: travel is short and bounded, and it
  /// must be smooth while it lasts. It is created per trip and disposed on
  /// arrival, so a settled companion asks the engine for no frames at all.
  Ticker? _travelTicker;

  /// The simulation's anchor, so travel starts on a real decision rather than
  /// on a rebuild.
  ProviderSubscription<RoomSimulationState>? _simulationSubscription;

  /// Whether the room's real placement has been loaded at least once.
  ///
  /// The companion is not drawn before this. `CraftState` starts with
  /// `isLoading == false` and empty lists, so without the flag the first frame
  /// would place the companion on the *floor* and the next would animate it
  /// across the room to the seat the player actually owns — a slide that looks
  /// like a bug and that leaves the settled position unreadable.
  bool _dataReady = false;

  RoomSimulationController? get _sim => _simulator;

  /// The simulation loop this page started.
  ///
  /// Held directly rather than looked up through `ref` in [dispose]. A test may
  /// dispose the provider container before the widget tree is finalized, and
  /// `ref.read` on a disposed container throws — which would leave the timer
  /// running and fail teardown with "A Timer is still pending". Capturing the
  /// instance means teardown never depends on the container still being alive.
  RoomSimulationController? _simulator;

  @override
  void initState() {
    super.initState();
    _simulator = ref.read(roomSimulationProvider.notifier);
    Future.microtask(() async {
      await ref.read(craftControllerProvider.notifier).loadAll();
      // Once the real placement is known, give the companion a chance to
      // decide rather than waiting up to a tick to look alive.
      if (!mounted) return;
      _sim?.evaluateNow();
      if (!mounted) return;

      // Record where the companion first appears, and place it there without
      // travelling. This is the "first placement snaps" rule, and it has to run
      // here rather than on the first anchor *change*: the opening decision is
      // often the floor, so the first change is usually the real journey to a
      // seat — snapping on that change would swallow exactly the walk this
      // phase exists to produce.
      final opening = _anchorFor(
            _anchorsFor(ref.read(craftControllerProvider)),
            ref.read(roomSimulationProvider).activity.anchorId,
          ) ??
          floorAnchor;
      _travelFrom = opening;
      _locomotion.snapTo(opening);

      setState(() => _dataReady = true);
    });
    // The loop starts here rather than in the provider so it is bounded by the
    // page that shows it: a room nobody is looking at does not need to tick, and
    // a test that unmounts the page has nothing left running.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _simulator?.start();
    });

    // Travel begins on a real decision, not during build. Detecting the anchor
    // change here also removes the old `_lastAnchorId` write that used to happen
    // inside `_buildCompanion`, which was a build-time side effect.
    _simulationSubscription = ref.listenManual<RoomSimulationState>(
      roomSimulationProvider,
      (previous, next) {
        if (previous?.activity.anchorId == next.activity.anchorId) return;
        _onAnchorChanged(next.activity.anchorId);
      },
    );
  }

  @override
  void dispose() {
    // Stopping here is what makes teardown clean: a periodic timer that outlives
    // the widget tree fails the test framework's own invariant.
    _simulator?.stop();
    _simulationSubscription?.close();
    _travelTicker?.dispose();
    super.dispose();
  }

  /// The anchors the current placement defines.
  Map<String, AnchorPoint> _anchorsFor(CraftState craft) =>
      FurnitureAnchorRegistry.build(
        placed: craft.roomItems,
        owned: craft.inventory,
        eligibleItemIds: FurnitureCatalog.itemIds,
        surfaceFractionFor: PetRoomPresenceResolver.seatSurfaceFraction,
      );

  /// Starts the companion walking to [anchorId], or places it there.
  ///
  /// The first placement snaps: the companion appears where the simulation says
  /// it is rather than walking in from the floor every time the room opens. A
  /// later change of anchor is a real journey and is walked.
  void _onAnchorChanged(String anchorId) {
    final craft = ref.read(craftControllerProvider);
    final anchors = _anchorsFor(craft);
    final anchor = _anchorFor(anchors, anchorId) ?? floorAnchor;
    final from = _travelFrom;

    if (from == null) {
      _locomotion.snapTo(anchor);
      _travelFrom = anchor;
      return;
    }

    if (!_locomotion.startTravel(from: from, to: anchor)) return;
    _travelFrom = from;
    _startTravelTicker();
  }

  void _startTravelTicker() {
    _travelTicker?.dispose();
    _travelTicker = createTicker((elapsed) {
      final arrived = _locomotion.advanceTo(elapsed);
      if (mounted) setState(() {});
      if (arrived) {
        _travelTicker?.dispose();
        _travelTicker = null;
      }
    })
      ..start();
  }

  @override
  Widget build(BuildContext context) {
    final companionName = ref.watch(companionDisplayNameProvider);
    final craft = ref.watch(craftControllerProvider);
    final simulation = ref.watch(roomSimulationProvider);
    final session = ref.watch(focusSessionControllerProvider);
    final isPaused = session.session?.status == FocusSessionStatus.paused;

    // A paused session is the brief's *break*: the companion heads for the sofa
    // instead of continuing to work. The room reads the same session truth the
    // focus page does, and pushing it in after the frame avoids a
    // rebuild-during-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sim?.setFocusPaused(isPaused);
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundWarm,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundWarm,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$companionName 的小房间'),
            const Text('把专注过的时间，留在这里',
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
                const GrowthSubNav(active: GrowthSection.room),
                CompanionVitalsBar(simulation: simulation),
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
                                  _useTarget = item;
                                });
                              },
                              onMoveEnd: (nx, ny) async {
                                await ref
                                    .read(craftControllerProvider.notifier)
                                    .moveRoomItem(item.id, nx, ny);
                                // The anchors move with their furniture, so the
                                // companion re-decides against the new layout
                                // rather than standing where the item used to be.
                                if (mounted) _sim?.evaluateNow();
                              },
                            );
                          }),
                          if (_dataReady)
                            _buildCompanion(
                              craft: craft,
                              simulation: simulation,
                              canvasWidth: canvasWidth,
                              canvasHeight: canvasHeight,
                            ),
                          if (_useTarget != null)
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: FurnitureUsePanel(
                                roomItem: _useTarget!,
                                label: _labelFor(craft, _useTarget!),
                                unlocked: _owns(craft, _useTarget!.itemId),
                                onDismiss: () =>
                                    setState(() => _useTarget = null),
                                onUse: (action) {
                                  _sim?.requestAction(
                                    itemId: _useTarget!.itemId,
                                    actionId: action.id,
                                    roomItemId: _useTarget!.id,
                                  );
                                  setState(() {
                                    _useTarget = null;
                                    _selectedRoomItemId = null;
                                  });
                                },
                              ),
                            ),
                          if (_selectedRoomItemId != null && _useTarget == null)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: _SelectionToolbar(
                                onDelete: () async {
                                  await ref
                                      .read(craftControllerProvider.notifier)
                                      .removeRoomItem(_selectedRoomItemId!);
                                  if (mounted) _sim?.evaluateNow();
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
                                  const CozyFurnitureArtwork(
                                    itemId: 'room',
                                    size: 86,
                                  ),
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
                            // New furniture means a new anchor and possibly a
                            // new behaviour, which is the acceptance test
                            // *unlock changes gameplay*.
                            if (mounted) _sim?.evaluateNow();
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

  /// Whether the player owns [itemId].
  static bool _owns(CraftState craft, String itemId) {
    for (final item in craft.inventory) {
      if (item.itemId == itemId && item.quantity > 0) return true;
    }
    return false;
  }

  /// The player-facing name of a placed item.
  static String _labelFor(CraftState craft, RoomItem item) {
    for (final recipe in craft.recipes) {
      if (recipe.outputItemId == item.itemId) return recipe.name;
    }
    return FurnitureCatalog.forId(item.itemId)?.label ?? item.itemId;
  }

  /// Places the companion where the simulation says it is.
  ///
  /// The position is not "the topmost seat" any more: it is wherever the chosen
  /// action happens, which the simulation decided from vitals, time, placement
  /// and the player's request. This widget only turns that anchor into pixels.
  Widget _buildCompanion({
    required CraftState craft,
    required RoomSimulationState simulation,
    required double canvasWidth,
    required double canvasHeight,
  }) {
    final anchors = _anchorsFor(craft);
    final anchor =
        _anchorFor(anchors, simulation.activity.anchorId) ?? floorAnchor;

    const size = 92.0;
    final box = CompanionPlacement.boxFor(
      anchor: anchor,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      avatarSize: size,
      feetInsetFraction: MochiLayerAssets.feetInsetFraction,
    );

    // The companion is drawn between the anchor it set off from and the one it
    // is heading to, at the progress the locomotion controller reports.
    //
    // This replaces `AnimatedPositioned`, which interpolated the same two
    // numbers with a tween but could not say *that the character was walking*:
    // the sprite showed one still image for the whole trip. The interpolation is
    // the same; what is new is that it is now driven by a controller the
    // animation layer can read a gait and a facing from.
    final from = _travelFrom;
    final progress = _locomotion.progress;
    final drawn = from == null || progress >= 1.0
        ? box
        : _lerpBox(
            CompanionPlacement.boxFor(
              anchor: from,
              canvasWidth: canvasWidth,
              canvasHeight: canvasHeight,
              avatarSize: size,
              feetInsetFraction: MochiLayerAssets.feetInsetFraction,
            ),
            box,
            progress,
          );

    return Positioned(
      left: drawn.left,
      top: drawn.top,
      child: IgnorePointer(
        child: CompanionAvatar(
          size: size,
          // While the companion is travelling, what it *draws* is the walk,
          // which is the whole point of this phase: the position is no longer a
          // tween over a still image. The behaviour is untouched — the director
          // still believes the companion is on its way to the anchor below — so
          // the badge and the semantics keep telling the truth.
          //
          // Until the walk frames ship, `specForAction` finds no `walk` sequence
          // and the provider falls back to the pose's own drawing: the pipeline
          // is ready and the art is honestly missing, which the asset gate
          // reports as `walk 0/6`.
          animationState: _locomotion.isTravelling ? AnimationState.walk : null,
          // The anchor's role picks the posture the sprite pipeline presents;
          // the simulation chose *which* anchor, so the two cannot disagree.
          roomAnchor: _anchorRoleFor(anchor.itemId),
          showStateBadge: false,
        ),
      ),
    );
  }

  /// The box between [from] and [to] at [t].
  ///
  /// Interpolates the *placement* rather than the anchor, so the seat-surface
  /// correction is applied at each end and the feet do not dip as the companion
  /// crosses between a floor anchor and a cushion.
  static CompanionBox _lerpBox(CompanionBox from, CompanionBox to, double t) =>
      CompanionBox(
        left: from.left + (to.left - from.left) * t,
        top: from.top + (to.top - from.top) * t,
        size: to.size,
      );

  static AnchorPoint? _anchorFor(
    Map<String, AnchorPoint> anchors,
    String anchorId,
  ) {
    for (final anchor in anchors.values) {
      if (anchor.id == anchorId) return anchor;
    }
    return null;
  }

  /// The interaction-point role an item declares, for the renderer's posture.
  static String? _anchorRoleFor(String itemId) {
    final entity = FurnitureCatalog.forId(itemId);
    if (entity == null || entity.interactionPoints.isEmpty) return null;
    return entity.interactionPoints.first;
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
    final renderedSize = _kFurnitureItemSize * widget.roomItem.scale;
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
                              ? CozyFurnitureArtwork(
                                  itemId: inv.itemId,
                                  size: 42,
                                )
                              : Image.asset(
                                  recipe!.artworkPath!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      CozyFurnitureArtwork(
                                    itemId: inv.itemId,
                                    size: 42,
                                  ),
                                )),
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

  Widget _fallback() => CozyFurnitureArtwork(
        itemId: recipe?.outputItemId ?? recipe?.id ?? '',
        size: size,
      );
}
