import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../companion_selection.dart';
import '../runtime/companion_id.dart';
import '../time_of_day.dart';
import '../../controllers/craft_controller.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/providers.dart';
import 'anchor_point.dart';
import 'companion_vitals.dart';
import 'furniture_action_resolver.dart';
import 'furniture_catalog.dart';
import '../room_presence.dart';

/// The companion's room simulation.
///
/// ## What it is responsible for
///
/// Running the loop the brief describes:
///
/// ```text
/// every interval:
///   evaluate  energy, time, room objects, current task
///   choose    an activity
///   commit    to it for a bounded time
/// ```
///
/// It reads the *real* business truth — placed furniture, inventory, whether a
/// focus session is running — through the same providers the pages use, so the
/// companion cannot behave as if the player owns something they do not.
///
/// ## What it is not allowed to do
///
/// It cannot write business state. There is no repository here, no session
/// controller, no craft controller it calls *into*. It reads
/// [craftControllerProvider] and [homeControllerProvider] and never mutates
/// them. Its own output is [RoomSimulationState], which is presentation.
///
/// That is the same structural guarantee the behaviour director already had, and
/// it is why this can be a stateful timer-driven loop without becoming a second
/// business state machine.
///
/// ## Why a timer at all
///
/// The brief explicitly asks for an interval loop. The alternative — recomputing
/// on every rebuild — would make the companion's commitment depend on how often
/// the widget tree happened to rebuild, which is exactly the "flash between
/// poses" failure the sprite player was written to avoid. One timer, at a low
/// frequency, with a committed dwell, is what makes an action read as a choice.
class RoomSimulationController extends StateNotifier<RoomSimulationState> {
  final Ref _ref;

  /// How often the loop wakes to check whether the current commitment expired.
  ///
  /// Slow on purpose. The companion decides on the scale of seconds; waking four
  /// times a second would burn battery to discover that nothing has changed.
  static const Duration tickInterval = Duration(seconds: 2);

  Timer? _timer;
  DateTime? _lastTick;

  /// Whether the interval loop is scheduled.
  ///
  /// The loop is deliberately **not** started in the constructor. A provider
  /// that starts a `Timer.periodic` on creation cannot be stopped by a test that
  /// only disposes the container, and the pending timer then fails the widget
  /// test at teardown — which is exactly what happened. Starting is explicit so
  /// the owner of the loop is also the owner of its teardown.
  bool _running = false;

  /// Whether the loop is currently scheduled. Idempotent [start] and [stop]
  /// make this safe to read from a lifecycle callback that may run twice.
  bool get isRunning => _running;

  /// Whether the player is rearranging the room right now.
  ///
  /// While this holds, the loop keeps the companion's vitals ticking but does
  /// not *choose* a new activity: the layout is mid-change, and a decision made
  /// now would be made against furniture that is about to move. Choosing is what
  /// pauses, not time.
  bool _arranging = false;

  /// Whether the player is arranging. Read by tests and by the page's hint.
  bool get isArranging => _arranging;

  RoomSimulationController(this._ref) : super(RoomSimulationState.initial);

  /// Starts the interval loop. Does nothing when it is already running.
  void start() {
    if (_running) return;
    _running = true;
    _lastTick = DateTime.now();
    _timer = Timer.periodic(tickInterval, (_) => _tick());
  }

  /// Stops the loop and cancels its timer. Does nothing when it is stopped.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Tells the loop whether the player is rearranging the room.
  ///
  /// Deliberately **not** part of [RoomSimulationState]: a page clears this from
  /// `dispose`, and writing provider state during teardown is what Riverpod
  /// forbids — a listener rebuilding against a defunct element is an assertion,
  /// not a warning. Keeping the flag on the controller means clearing it is a
  /// field assignment that notifies nobody.
  ///
  /// Leaving arranging re-decides immediately, against the layout as it now is.
  /// That re-decision is skipped when the loop is stopped, which is exactly the
  /// case during teardown, so a page being disposed cannot start a decision it
  /// would immediately have to abandon.
  void setArranging(bool arranging) {
    if (_arranging == arranging) return;
    _arranging = arranging;
    if (!arranging && _running && mounted) _evaluate(force: true);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  /// The player asked the companion to use a piece of furniture.
  ///
  /// Recorded as a request and applied on the next tick, so a tap cannot
  /// interrupt the loop mid-decision. The request is dropped if the furniture is
  /// gone by then — see [FurnitureActionResolver.decide].
  void requestAction({
    required String itemId,
    required String actionId,
    required String roomItemId,
  }) {
    state = state.copyWith(
      request: PlayerRequest(
        itemId: itemId,
        actionId: actionId,
        roomItemId: roomItemId,
      ),
    );
    _evaluate(force: true);
  }

  /// Clears a request the player made and then abandoned.
  void clearRequest() {
    if (state.request == null) return;
    state = state.copyWith(clearRequest: true);
  }

  /// Tells the loop whether the running session is paused.
  ///
  /// A paused session is the brief's *break*: the companion should head for the
  /// sofa rather than keep working. The room page knows this from the same
  /// source the focus page does, so it is handed in rather than re-derived here.
  void setFocusPaused(bool paused) {
    if (state.focusPaused == paused) return;
    state = state.copyWith(focusPaused: paused);
    if (paused) _evaluate(force: true);
  }

  /// Runs one decision immediately. Exposed for tests and for the moment a
  /// focus session starts, where waiting up to a tick would be visible.
  void evaluateNow() => _evaluate(force: true);

  void _tick() {
    final now = DateTime.now();
    final elapsed =
        _lastTick == null ? tickInterval : now.difference(_lastTick!);
    _lastTick = now;
    state = state.copyWith(
      vitals: state.vitals.afterElapsed(elapsed),
      elapsedSinceStart: state.elapsedSinceStart + elapsed,
    );
    _evaluate();
  }

  /// Whether the loop may choose a new activity.
  ///
  /// A player request or an explicit [evaluateNow] is *forced* and always runs;
  /// what pausing suppresses is the interval loop's own choosing. This is a pure
  /// predicate rather than an inline condition so the policy can be asserted
  /// directly, instead of being inferred from a timer that reads the wall clock.
  static bool mayChoose({required bool arranging, required bool forced}) =>
      forced || !arranging;

  /// The heart of the loop.
  void _evaluate({bool force = false}) {
    // Rearranging suppresses *choosing*, not time: the vitals tick and the
    // companion stays where it is, but it does not commit to an anchor that the
    // player is in the middle of moving.
    if (!mayChoose(arranging: _arranging, forced: force)) return;

    final committed = state.activity;
    if (!force && committed.endsAt > state.elapsedSinceStart) return;

    final craft = _ref.read(craftControllerProvider);
    final home = _ref.read(homeControllerProvider);
    final CompanionId companionId =
        state.companionId ?? _ref.read(companionSelectionProvider);

    final anchors = FurnitureAnchorRegistry.build(
      placed: craft.roomItems,
      owned: craft.inventory,
      eligibleItemIds: FurnitureCatalog.itemIds,
      surfaceFractionFor: (itemId) =>
          PetRoomPresenceResolver.seatSurfaceFraction(itemId),
    );

    final decision = FurnitureActionResolver.decide(
      RoomDecisionInput(
        anchors: anchors,
        vitals: state.vitals,
        // Read through the injected clock rather than `DateTime.now()`.
        //
        // The night rule keys off this band, so a raw clock reading made the
        // room's behaviour — and every test that renders it — depend on the
        // wall clock: the same room put the companion on the sofa at 10:00 and
        // sent it to bed at 02:00. A test that injects a daytime clock now
        // genuinely controls what the room decides.
        timeOfDay:
            TimeOfDayResolver.resolve(_ref.read(focusClockProvider).now()),
        focusRunning: home.hasActiveSession && !state.focusPaused,
        focusPaused: state.focusPaused,
        unlockedItemIds: _unlockedItemIds(craft),
        request: state.request,
        companionId: companionId,
      ),
    );

    final nextActivity = CompanionActivity(
      anchorId: decision.anchorId,
      actionId: decision.actionId,
      companionAction: decision.companionAction,
      endsAt: state.elapsedSinceStart + decision.dwell,
    );

    final applied = decision.effect.isNeutral
        ? state.vitals
        : state.vitals.copyWithEffect(decision.effect);

    state = state.copyWith(
      vitals: applied,
      activity: nextActivity,
      cause: decision.cause,
      // A request is consumed by being decided on, whether or not it was
      // honoured: leaving it set would re-apply it forever.
      clearRequest: state.request != null,
    );
  }

  /// The item ids the player actually owns.
  ///
  /// Read from the inventory rows rather than from the placed rows: owning a
  /// sofa that is still in inventory is what "unlocked" means, and the brief's
  /// *unlock changes gameplay* is about ownership, not placement.
  Set<String> _unlockedItemIds(CraftState craft) => {
        for (final item in craft.inventory)
          if (item.quantity > 0) item.itemId,
      };
}

/// The simulation's observable output.
///
/// Everything here is presentation. Nothing in this class is a business fact,
/// and no page may treat it as one.
class RoomSimulationState {
  final CompanionVitals vitals;
  final CompanionActivity activity;

  /// Why the current activity was chosen. Surfaced so the room can explain
  /// itself and so tests can assert the *reason* rather than only the outcome.
  final RoomDecisionCause cause;

  /// The companion being simulated.
  final CompanionId? companionId;

  /// A player request not yet consumed.
  final PlayerRequest? request;

  /// Monotonic loop time. Used for the commitment deadline, so the deadline does
  /// not depend on wall-clock jumps.
  final Duration elapsedSinceStart;

  /// Whether a real focus session is paused. Set from the outside so the loop
  /// does not have to re-derive it, and so a test can state it directly.
  final bool focusPaused;

  const RoomSimulationState({
    required this.vitals,
    required this.activity,
    required this.cause,
    this.companionId,
    this.request,
    this.elapsedSinceStart = Duration.zero,
    this.focusPaused = false,
  });

  static const RoomSimulationState initial = RoomSimulationState(
    vitals: CompanionVitals.initial,
    activity: CompanionActivity.idle,
    cause: RoomDecisionCause.idle,
  );

  /// Whether the companion is doing something deliberate.
  bool get isBusy => activity.isBusy;

  /// The semantic action the sprite player should present, if any.
  String? get companionAction => activity.companionAction;

  RoomSimulationState copyWith({
    CompanionVitals? vitals,
    CompanionActivity? activity,
    RoomDecisionCause? cause,
    CompanionId? companionId,
    PlayerRequest? request,
    bool clearRequest = false,
    Duration? elapsedSinceStart,
    bool? focusPaused,
  }) =>
      RoomSimulationState(
        vitals: vitals ?? this.vitals,
        activity: activity ?? this.activity,
        cause: cause ?? this.cause,
        companionId: companionId ?? this.companionId,
        request: clearRequest ? null : (request ?? this.request),
        elapsedSinceStart: elapsedSinceStart ?? this.elapsedSinceStart,
        focusPaused: focusPaused ?? this.focusPaused,
      );

  @override
  String toString() => 'RoomSimulationState(${cause.id} '
      '${activity.actionId ?? 'idle'} energy=${vitals.energy})';
}

/// The app's room simulation.
///
/// Scoped to the app rather than a page so a companion left alone keeps whatever
/// it was doing, and so the vitals survive navigation — the same reasoning that
/// put the collection unlock tracker on a provider.
final roomSimulationProvider =
    StateNotifierProvider<RoomSimulationController, RoomSimulationState>(
        (ref) => RoomSimulationController(ref));
