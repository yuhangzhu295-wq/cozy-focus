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

/// How much one tap of 放大 / 缩小 changes a placed item's scale.
///
/// The controller clamps the result, so this step never needs to know the
/// bounds — it can stay a plain nudge.
const double _kScaleStep = 0.2;

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
    // Then clear any pause a drag left behind. The simulation is app-scoped, so
    // a page disposed mid-drag would otherwise leave the companion unable to
    // choose anything ever again. The loop is already stopped, so this cannot
    // start a decision the teardown would have to abandon.
    _simulator?.setArranging(false);
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
    // The ticker starts immediately: the pet's position and its animation run
    // on the same wall clock, so a `stand_up` transition and the first metres
    // of travel overlap naturally rather than being serialised here.
    _startTravelTicker();
  }

  /// Receives the animation controller's state changes, for diagnostics and for
  /// coordinating any future effect that needs to know when a transition ends.
  void _onCompanionAnimationChanged(AnimationState state) {
    // Tracked for diagnostics; the movement ticker is already running and the
    // animation controller handles the visual transitions independently.
  }

  /// The travel ticker, created once and then started and stopped.
  ///
  /// `SingleTickerProviderStateMixin` permits exactly one ticker for the lifetime
  /// of the state, and `createTicker` **throws** on a second call. The previous
  /// code disposed and re-created on every journey, so the second piece of
  /// furniture the companion walked to threw — and it threw inside the
  /// simulation's own tick, because the anchor-change listener runs from
  /// `_evaluate`. Reproduced in logcat on the Pixel 7 emulator:
  ///
  /// ```
  /// SingleTickerProviderStateMixin.createTicker (ticker_provider.dart:201)
  ///   _RoomPageState._startTravelTicker (room_page.dart:210)
  ///   _RoomPageState._onAnchorChanged (room_page.dart:198)
  ///   RoomSimulationController._evaluate (room_simulation.dart:413)
  ///   RoomSimulationController._tick (room_simulation.dart:303)
  /// ```
  ///
  /// A Ticker restarts from zero, which is exactly what
  /// `LocomotionController.startTravel` expects, so one instance is enough.
  void _startTravelTicker() {
    final ticker = _travelTicker ??= createTicker(_onTravelTick);
    if (!ticker.isActive) ticker.start();
  }

  void _onTravelTick(Duration elapsed) {
    final arrived = _locomotion.advanceTo(elapsed);
    if (mounted) setState(() {});
    if (arrived) _travelTicker?.stop();
  }

  /// Applies a placement change and then lets the companion re-decide.
  ///
  /// Re-deciding is what makes the change visible in behaviour rather than only
  /// in the layout: a resize moves the seat's surface line, and hiding an item
  /// removes its anchor entirely, so the companion must not stay committed to a
  /// spot that no longer exists. This mirrors what a move already does.
  Future<void> _applyPlacement(
    Future<void> Function(CraftController) change,
  ) async {
    await change(ref.read(craftControllerProvider.notifier));
    if (!mounted) return;
    _sim?.evaluateNow();
  }

  @override
  Widget build(BuildContext context) {
    final companionName = ref.watch(companionDisplayNameProvider);
    final craft = ref.watch(craftControllerProvider);
    final simulation = ref.watch(roomSimulationProvider);
    final session = ref.watch(focusSessionControllerProvider);
    final isPaused = session.session?.status == FocusSessionStatus.paused;

    // The selected row, so the toolbar can act on *this* item rather than on
    // "the selection" as an id the callbacks would have to look up again.
    final selectedRoomItem =
        craft.roomItems.where((r) => r.id == _selectedRoomItemId).firstOrNull;

    // A failed placement (no stock left, say) used to be stored in the state and
    // never shown, which read as a dead button. Surfacing it here is the whole
    // fix: the controller keeps owning *why* it failed, the page only reports it.
    ref.listen<String?>(
      craftControllerProvider.select((s) => s.error),
      (previous, next) {
        if (next == null || next == previous) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next)));
      },
    );

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
                CompanionVitalsBar(
                  simulation: simulation,
                  companionName: companionName,
                ),
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
                                if (!mounted) return;
                                // Leaving arranging re-decides against the new
                                // layout, so the companion heads for where the
                                // furniture now is rather than where it was.
                                _sim?.setArranging(false);
                              },
                              onDragStart: () => _sim?.setArranging(true),
                              onDragCancel: () => _sim?.setArranging(false),
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
                          if (selectedRoomItem != null && _useTarget == null)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: _SelectionToolbar(
                                item: selectedRoomItem,
                                onScaleDown: () => _applyPlacement(
                                  (n) => n.setRoomItemScale(selectedRoomItem.id,
                                      selectedRoomItem.scale - _kScaleStep),
                                ),
                                onScaleUp: () => _applyPlacement(
                                  (n) => n.setRoomItemScale(selectedRoomItem.id,
                                      selectedRoomItem.scale + _kScaleStep),
                                ),
                                onBringToFront: () => _applyPlacement(
                                  (n) => n.bringRoomItemToFront(
                                      selectedRoomItem.id),
                                ),
                                onSendToBack: () => _applyPlacement(
                                  (n) =>
                                      n.sendRoomItemToBack(selectedRoomItem.id),
                                ),
                                onToggleVisibility: () => _applyPlacement(
                                  (n) => n.setRoomItemVisible(
                                      selectedRoomItem.id,
                                      !selectedRoomItem.isVisible),
                                ),
                                onDelete: () async {
                                  await ref
                                      .read(craftControllerProvider.notifier)
                                      .removeRoomItem(selectedRoomItem.id);
                                  if (mounted) _sim?.evaluateNow();
                                  setState(() => _selectedRoomItemId = null);
                                },
                                onDeselect: () =>
                                    setState(() => _selectedRoomItemId = null),
                              ),
                            ),
                          if (craft.roomItems.isEmpty)
                            // Above the middle, not in it: the companion stands in
                            // the lower part of the room, and a centred block put
                            // this button underneath its head — the call to action
                            // was drawn under the pet and its label was half
                            // hidden. Found by walking the app on a device.
                            Align(
                              alignment: const Alignment(0, -0.5),
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
          // The page says *that* it is travelling and nothing more. Which
          // drawings that becomes — `stand_up → walk` on the way out,
          // `sit_down → the behaviour's pose` on arrival — is the animation
          // controller's decision, so no page names an animation state.
          travelling: _locomotion.isTravelling,
          onAnimationStateChanged: _onCompanionAnimationChanged,
          // The room is the one place with real vitals, so it is the one place
          // that supplies them. Passed through, never interpreted here.
          vitals: simulation.vitals.toPresentationVitals(),
          // The anchor's role places the companion and selects the ambient
          // recipe when nothing more specific is known.
          roomAnchor: _anchorRoleFor(anchor.itemId),
          // ...but the simulation's committed action is what the companion is
          // actually doing, and it is the same action the furniture panel names
          // to the player. Passing it is what stops the room saying one thing
          // and drawing another. Null while the companion is only travelling or
          // idling at the floor anchor, which leaves the anchor in charge.
          companionAction: simulation.companionAction,
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

  /// A drag began, so the room can pause the companion's decisions.
  final VoidCallback onDragStart;

  /// A drag ended without a position being committed, so the pause can lift.
  final VoidCallback onDragCancel;

  const _PlacedItemWidget({
    required super.key,
    required this.roomItem,
    required this.recipe,
    required this.isSelected,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onSelect,
    required this.onMoveEnd,
    required this.onDragStart,
    required this.onDragCancel,
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
        // The pause starts on the gesture rather than on the first movement, so
        // there is no window in which the companion can commit to the item the
        // player has already grabbed.
        onPanStart: (_) => widget.onDragStart(),
        onPanCancel: widget.onDragCancel,
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
          child: Opacity(
            // A hidden item is still *here*: it keeps its row, its position and
            // its z-order, and only the companion ignores it. Drawing it as a
            // faint ghost is what keeps it reachable — an item the player could
            // not see would be an item they could never un-hide.
            opacity: widget.roomItem.isVisible ? 1.0 : 0.3,
            child: Center(
              child: Tooltip(
                message: widget.recipe?.name ?? widget.roomItem.itemId,
                child: _RoomArtwork(
                    recipe: widget.recipe, size: widget.roomItem.scale * 54),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The controls for the selected furniture.
///
/// Two rows because the placement controls (resize, layer, hide) joined the
/// original remove/deselect pair; a single row would have run off the canvas on
/// a narrow phone. Every button is a plain callback — the toolbar knows nothing
/// about the database, and the page it is embedded in owns the writes.
class _SelectionToolbar extends StatelessWidget {
  /// The selected row, so the buttons can reflect its current state.
  final RoomItem item;

  final VoidCallback onDelete;
  final VoidCallback onDeselect;
  final VoidCallback onScaleDown;
  final VoidCallback onScaleUp;
  final VoidCallback onBringToFront;
  final VoidCallback onSendToBack;
  final VoidCallback onToggleVisibility;

  const _SelectionToolbar({
    required this.item,
    required this.onDelete,
    required this.onDeselect,
    required this.onScaleDown,
    required this.onScaleUp,
    required this.onBringToFront,
    required this.onSendToBack,
    required this.onToggleVisibility,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _button(
                icon: Icons.zoom_out_rounded,
                tooltip: '缩小',
                onPressed: onScaleDown,
              ),
              _button(
                icon: Icons.zoom_in_rounded,
                tooltip: '放大',
                onPressed: onScaleUp,
              ),
              _button(
                icon: Icons.flip_to_back_rounded,
                tooltip: '置底',
                onPressed: onSendToBack,
              ),
              _button(
                icon: Icons.flip_to_front_rounded,
                tooltip: '置顶',
                onPressed: onBringToFront,
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The icon shows the action, not the state: a visible item offers
              // "hide". The tooltip carries the same word so the two cannot
              // disagree.
              _button(
                icon: item.isVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                tooltip: item.isVisible ? '隐藏' : '显示',
                onPressed: onToggleVisibility,
              ),
              _button(
                icon: Icons.delete_outline_rounded,
                color: AppColors.accentPeach,
                tooltip: '移除',
                onPressed: onDelete,
              ),
              _button(
                icon: Icons.close_rounded,
                color: AppColors.textSecondary,
                tooltip: '取消选择',
                onPressed: onDeselect,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _button({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) =>
      IconButton(
        icon: Icon(icon, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
      );
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
