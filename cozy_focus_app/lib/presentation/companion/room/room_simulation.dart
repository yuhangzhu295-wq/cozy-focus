import 'dart:async';

import 'package:flutter/foundation.dart';
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
/// One decision the loop made, and what it displaced.
///
/// ## Why this exists
///
/// A player chose `sit` on the sofa and the companion was doing something else
/// two seconds later. Nothing in the state said *which* transition did that:
/// `activity` shows only the winner, and `cause` only its reason. This records
/// the loser too, so a replacement can be explained instead of guessed at.
///
/// Diagnostics, not business state. Nothing reads it but a test and a log.
class RoomDecisionTrace {
  /// Loop time when this decision was committed.
  final Duration at;

  /// Why the loop was evaluating. One of `tick`, `request`, `evaluateNow`,
  /// `arranging`, `focusPause`.
  final String via;

  /// Whether the evaluation was forced past the dwell guard.
  final bool forced;

  /// The decision that won.
  final String cause;
  final String? actionId;
  final String? anchorId;

  /// When the winner's commitment expires.
  final Duration? endsAt;

  /// What it displaced, when it displaced anything.
  final String? replacedCause;
  final String? replacedActionId;

  /// How much of the displaced commitment was still owed. Non-null and positive
  /// means an unexpired commitment was taken away — the thing P28 is about.
  final Duration? replacedRemaining;

  const RoomDecisionTrace({
    required this.at,
    required this.via,
    required this.forced,
    required this.cause,
    this.actionId,
    this.anchorId,
    this.endsAt,
    this.replacedCause,
    this.replacedActionId,
    this.replacedRemaining,
  });

  /// Whether this decision cut short a commitment that had time left on it.
  bool get preemptedLiveCommitment =>
      replacedRemaining != null && replacedRemaining! > Duration.zero;

  @override
  String toString() {
    final replaced = replacedCause == null
        ? ''
        : ' replaced=$replacedCause/${replacedActionId ?? '-'}'
            ' remaining=${replacedRemaining?.inSeconds}s';
    return 'RoomDecisionTrace($via${forced ? '/forced' : ''} '
        'at=${at.inSeconds}s -> $cause/${actionId ?? '-'} '
        'endsAt=${endsAt?.inSeconds}s$replaced)';
  }
}

class RoomSimulationController extends StateNotifier<RoomSimulationState> {
  final Ref _ref;

  /// How often the loop wakes to check whether the current commitment expired.
  ///
  /// Slow on purpose. The companion decides on the scale of seconds; waking four
  /// times a second would burn battery to discover that nothing has changed.
  static const Duration tickInterval = Duration(seconds: 2);

  /// The longest gap a single tick will credit to the loop's clock.
  ///
  /// The loop measures the time it was *running*, not the wall clock. A timer
  /// that arrives late — the app was backgrounded, the frame loop stalled, the
  /// device clock changed — must not be credited as time the player spent
  /// watching the companion. Without this bound one late tick adds more than a
  /// whole dwell, `endsAt` is already in the past, and the action the player just
  /// chose disappears on the next evaluation. That is the second half of the
  /// P28 defect, and it survived the first fix.
  ///
  /// Two intervals covers ordinary scheduling jitter while refusing any gap that
  /// means the loop was not running. It bounds the *credit*, so a genuinely
  /// backgrounded app resumes with its commitment intact and counts down from
  /// where it left off rather than having silently expired.
  static const Duration maxTickCredit = Duration(seconds: 4);

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

  /// The last decisions the loop made, newest last.
  ///
  /// Bounded, because it is diagnostics: a long session would otherwise keep
  /// every decision it ever made alive for the sake of a test that reads the
  /// tail.
  final List<RoomDecisionTrace> _trace = [];
  static const int _traceLimit = 64;

  /// The recorded decisions. Read by the P28 diagnostics test and by a debug
  /// log; nothing in the app depends on it.
  List<RoomDecisionTrace> get decisionTrace => List.unmodifiable(_trace);

  /// The decisions that cut short a commitment which still had time left.
  List<RoomDecisionTrace> get preemptions => [
        for (final t in _trace)
          if (t.preemptedLiveCommitment) t
      ];

  RoomSimulationController(this._ref) : super(RoomSimulationState.initial);

  /// Whether the decision loop narrates itself to the console.
  ///
  /// P28 left a device symptom that survived four code-level fixes: a player's
  /// 休息 gave way after about five seconds against an eighteen-second dwell,
  /// with no exception in logcat. `RoomDecisionTrace` records committed
  /// decisions but not the evaluations that *declined*, nor the raw clock gap —
  /// which is precisely the gap that leaves the five seconds unexplained. These
  /// lines make the replacement readable instead of guessed at, and `kDebugMode`
  /// keeps them out of a release build entirely.
  static void _diag(String message) {
    if (kDebugMode) debugPrint('P28TRACE|$message');
  }

  /// How much of a wall-clock gap a tick is allowed to credit.
  ///
  /// Pure so the policy can be read and tested on its own. `_tick` and
  /// [debugTickWithGap] both go through it, so changing it here changes the loop.
  /// A backwards reading is as untrustworthy as a huge one — both fall back to a
  /// single interval rather than moving the loop's clock at all.
  @visibleForTesting
  static Duration creditedFor(Duration raw) =>
      raw.isNegative || raw > maxTickCredit ? tickInterval : raw;

  /// Runs one loop tick with [raw] standing in for the wall-clock gap, applying
  /// the same credit bound `_tick` applies.
  ///
  /// Distinct from [debugAdvance], which is deliberately *raw* so a test can
  /// expire a dwell. This one exists so the bound is exercised through the path
  /// that uses it, rather than as a bare formula.
  @visibleForTesting
  void debugTickWithGap(Duration raw) {
    final elapsed = creditedFor(raw);
    state = state.copyWith(
      vitals: state.vitals.afterElapsed(elapsed),
      elapsedSinceStart: state.elapsedSinceStart + elapsed,
    );
    _evaluate(via: 'tick');
  }

  /// Advances the loop's own clock by [elapsed] and evaluates, exactly as a tick
  /// would, without waiting for the real two-second timer.
  ///
  /// Exposed for tests only, and **raw on purpose**: it bypasses [maxTickCredit]
  /// so a test can expire a dwell deliberately. Use [debugTickWithGap] to
  /// exercise the bound itself.
  @visibleForTesting
  void debugAdvance(Duration elapsed) {
    state = state.copyWith(
      vitals: state.vitals.afterElapsed(elapsed),
      elapsedSinceStart: state.elapsedSinceStart + elapsed,
    );
    _evaluate(via: 'tick');
  }

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
    if (!arranging && _running && mounted) {
      _evaluate(force: true, via: 'arranging');
    }
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
    // Asking for what the companion is already doing is not a new decision.
    //
    // `request` is allowed to preempt the live commitment — that is how the
    // player changes their mind — so without this a second tap of the same chip
    // ran the whole decision again and applied the effect a second time. The
    // bed's nap is +34 energy, so one accidental double tap took the companion
    // from depleted to capped. Re-tapping the action that is already running is
    // the same instruction, not a second one.
    final live = state.activity;
    final alreadyDoingIt = state.playerCommitmentItemId == itemId &&
        live.actionId == actionId &&
        live.endsAt > state.elapsedSinceStart;
    if (alreadyDoingIt) {
      // Acknowledge the tap without deciding again: the commitment stands, its
      // dwell is untouched, and the effect is not applied a second time. The
      // cause is set because it is true — the player did ask for this — and
      // leaving it as whatever the routine said would make the room deny a
      // request it just honoured.
      state = state.copyWith(cause: RoomDecisionCause.playerRequest);
      return;
    }

    state = state.copyWith(
      request: PlayerRequest(
        itemId: itemId,
        actionId: actionId,
        roomItemId: roomItemId,
      ),
    );
    _evaluate(force: true, via: 'request');
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
    if (paused) _evaluate(force: true, via: 'focusPause');
  }

  /// Runs one decision immediately. Exposed for tests and for the moment a
  /// focus session starts, where waiting up to a tick would be visible.
  void evaluateNow() => _evaluate(force: true, via: 'evaluateNow');

  void _tick() {
    final now = DateTime.now();
    final raw = _lastTick == null ? tickInterval : now.difference(_lastTick!);
    final elapsed = creditedFor(raw);
    _diag(
        'tick raw=${raw.inMilliseconds}ms credited=${elapsed.inMilliseconds}ms '
        'elapsed=${(state.elapsedSinceStart + elapsed).inMilliseconds}ms');
    _lastTick = now;
    state = state.copyWith(
      vitals: state.vitals.afterElapsed(elapsed),
      elapsedSinceStart: state.elapsedSinceStart + elapsed,
    );
    _evaluate(via: 'tick');
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
  void _evaluate({bool force = false, String via = 'tick'}) {
    // Rearranging suppresses *choosing*, not time: the vitals tick and the
    // companion stays where it is, but it does not commit to an anchor that the
    // player is in the middle of moving.
    if (!mayChoose(arranging: _arranging, forced: force)) return;

    final committed = state.activity;
    final owesDwell = committed.endsAt > state.elapsedSinceStart;

    _diag('eval via=$via force=$force owesDwell=$owesDwell '
        'committed=${committed.actionId ?? '-'} '
        'remaining=${(committed.endsAt - state.elapsedSinceStart).inMilliseconds}ms '
        'commitment=${state.playerCommitmentRoomItemId ?? '-'}');

    // The loop's own tick never interrupts a commitment.
    if (!force && owesDwell) {
      _diag('  declined: dwell holds');
      return;
    }

    final craft = _ref.read(craftControllerProvider);
    final home = _ref.read(homeControllerProvider);

    // P28.2 — a player's accepted action outranks a forced re-evaluation.
    //
    // The forced entry points are ordinary housekeeping: the page calls them
    // after `loadAll`, after a placement property changes, after a removal, when
    // a drag ends, and on the focus-pause edge. None of those is a reason to take
    // the companion off the action the player just chose — and before this they
    // did, because the one-shot `request` had already been consumed, so the
    // forced evaluation re-picked from the routine and restarted the dwell. On a
    // device that read as "I tapped the sofa and the cat went back to the
    // bookshelf two seconds later".
    //
    // It holds until the dwell expires, with two exceptions, both explicit:
    // the player making a *new* request, and a focus pause (the brief's break).
    // The furniture ceasing to be usable ends it too — that is the one thing
    // that must still invalidate it.
    if (force &&
        owesDwell &&
        state.playerCommitmentItemId != null &&
        state.playerCommitmentRoomItemId != null &&
        !_preemptingEntryPoints.contains(via) &&
        _commitmentIsStillUsable(
          craft,
          state.playerCommitmentRoomItemId!,
          state.playerCommitmentItemId!,
        )) {
      _diag('  declined: player commitment holds');
      return;
    }
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

    _diag('  commit cause=${decision.cause.id} action=${decision.actionId} '
        'anchor=${decision.anchorId} room=${decision.roomItemId} '
        'endsAt=${nextActivity.endsAt.inMilliseconds}ms');

    _record(RoomDecisionTrace(
      at: state.elapsedSinceStart,
      via: via,
      forced: force,
      cause: decision.cause.id,
      actionId: decision.actionId,
      anchorId: decision.anchorId,
      endsAt: nextActivity.endsAt,
      // Only a *commitment* can be replaced. The first decision of a session
      // displaces `CompanionActivity.idle`, which is the absence of one, and
      // recording that as a preemption would drown the real ones.
      replacedCause: committed.isBusy ? state.cause.id : null,
      replacedActionId: committed.actionId,
      replacedRemaining:
          committed.isBusy ? committed.endsAt - state.elapsedSinceStart : null,
    ));

    state = state.copyWith(
      vitals: applied,
      activity: nextActivity,
      cause: decision.cause,
      // A request is consumed by being decided on, whether or not it was
      // honoured: leaving it set would re-apply it forever.
      clearRequest: state.request != null,
      // Remember whose decision this was, so a later forced evaluation can tell
      // a player's action from the loop's own. See the guard above.
      playerCommitmentItemId: decision.cause == RoomDecisionCause.playerRequest
          ? decision.itemId
          : null,
      playerCommitmentRoomItemId:
          decision.cause == RoomDecisionCause.playerRequest
              ? decision.roomItemId
              : null,
      clearPlayerCommitment: decision.cause != RoomDecisionCause.playerRequest,
    );
  }

  /// The entry points that may end a live player commitment early.
  ///
  /// * `request` — the player changed their mind; the newest request wins.
  /// * `focusPause` — a real business event (the brief's break), documented as
  ///   higher authority than a furniture choice.
  ///
  /// Everything else that forces an evaluation is housekeeping and must not
  /// preempt. `arranging` and `evaluateNow` are the two the room page calls
  /// routinely.
  static const Set<String> _preemptingEntryPoints = {'request', 'focusPause'};

  /// Whether the furniture a player commitment was made against is still usable:
  /// owned, placed and visible.
  ///
  /// A sofa that has been picked up, hidden or sold cannot be sat on, so the
  /// commitment ends with it. This is the check that keeps the guard above from
  /// being "never re-decide".
  bool _commitmentIsStillUsable(
    CraftState craft,
    String roomItemId,
    String itemId,
  ) {
    final owned =
        craft.inventory.any((i) => i.itemId == itemId && i.quantity > 0);
    if (!owned) return false;
    // The exact row the player tapped must still be there, still be the item it
    // was, and still be visible. A second sofa of the same kind does not stand in
    // for the one that was picked up.
    return craft.roomItems
        .any((r) => r.id == roomItemId && r.itemId == itemId && r.isVisible);
  }

  void _record(RoomDecisionTrace trace) {
    _trace.add(trace);
    if (_trace.length > _traceLimit) {
      _trace.removeAt(0);
    }
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

  /// The furniture a player-requested action is committed to.
  ///
  /// Non-null while the current activity is one the *player* asked for and whose
  /// dwell has not expired. It is what lets a forced re-evaluation tell "the
  /// player chose this a moment ago" apart from "the loop chose this", which the
  /// one-shot [request] cannot: by the time a forced evaluation runs, the request
  /// has been consumed.
  ///
  /// Cleared whenever the loop commits an activity of its own.
  final String? playerCommitmentItemId;

  /// The *placed row* the commitment is against.
  ///
  /// Two sofas share an `itemId`, so validating on that alone forgives the
  /// removal of the very sofa the companion is sitting on. This is the instance.
  final String? playerCommitmentRoomItemId;

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
    this.playerCommitmentItemId,
    this.playerCommitmentRoomItemId,
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
    String? playerCommitmentItemId,
    String? playerCommitmentRoomItemId,
    bool clearPlayerCommitment = false,
    Duration? elapsedSinceStart,
    bool? focusPaused,
  }) =>
      RoomSimulationState(
        vitals: vitals ?? this.vitals,
        activity: activity ?? this.activity,
        cause: cause ?? this.cause,
        companionId: companionId ?? this.companionId,
        request: clearRequest ? null : (request ?? this.request),
        playerCommitmentItemId: clearPlayerCommitment
            ? null
            : (playerCommitmentItemId ?? this.playerCommitmentItemId),
        playerCommitmentRoomItemId: clearPlayerCommitment
            ? null
            : (playerCommitmentRoomItemId ?? this.playerCommitmentRoomItemId),
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
