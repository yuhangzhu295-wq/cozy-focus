import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/core/auth/current_user.dart';
import 'package:cozy_focus_app/data/local/app_database.dart'
    hide CraftJob, CraftRecipe, InventoryItem, RoomItem;
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_action_resolver.dart';
import 'package:cozy_focus_app/presentation/companion/room/room_simulation.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';

/// P28 — a player's furniture action must survive its committed dwell.
///
/// ## The contract
///
/// `FurnitureActionResolver._decisionFor` sets `dwell: action.minDwell` — 14
/// seconds for the sofa's `sit` — and `RoomSimulationController._evaluate`
/// returns early while `activity.endsAt > elapsedSinceStart`. So a committed
/// action is supposed to hold for its minimum dwell.
///
/// ## What the room actually did
///
/// On a device, choosing 让 Mochi 坐下 from the sofa panel showed 正在坐下 and
/// applied the effect, then reverted to the ambient action within a few seconds
/// with the companion never leaving where it stood.
///
/// ## The mechanism these tests pin
///
/// `requestAction` commits the decision **and clears the request in the same
/// state update**, so the request is a one-shot input rather than a record of
/// what the player asked for. Every `_evaluate(force: true)` skips the
/// `endsAt` guard — and a forced evaluate with `request == null` re-picks from
/// focus / pause / night / routine / idle, replacing the player's action
/// immediately.
///
/// The room page calls forced entry points for ordinary reasons: after
/// `loadAll`, after a placement property changes, after a removal, and on the
/// arranging→idle and focus-pause edges. None of those is a reason to take the
/// companion away from what the player just asked for.
///
/// These tests are written to fail against that behaviour. They are the
/// regression, not a description of the current code.
class _TestClock implements FocusClock {
  _TestClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

RoomItem _placed(String itemId, {String? id}) => RoomItem(
      id: id ?? 'room-$itemId',
      userId: localMvpUserId,
      itemId: itemId,
      positionX: 0.4,
      positionY: 0.6,
      scale: 1.0,
      zIndex: 1,
      isVisible: true,
      placedAt: DateTime(2026, 9, 12, 10),
    );

InventoryItem _owned(String itemId) => InventoryItem(
      id: 'inv-$itemId',
      userId: localMvpUserId,
      itemId: itemId,
      quantity: 1,
      updatedAt: DateTime(2026, 9, 12, 10),
    );

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider
            .overrideWithValue(_TestClock(DateTime(2026, 9, 12, 10))),
      ],
    );
    // The loop reads these two, and both load asynchronously from the database.
    // Warming them here lets those loads finish while the database is still
    // open; otherwise a pending query outlives the test and fails against a
    // closed connection, which reads as a product failure and is not one.
    container.read(homeControllerProvider);
    container.read(craftControllerProvider);
    await pumpEventQueue();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Owns and places [itemId], then loads the craft state the loop reads.
  Future<void> place(String itemId, {String? id}) async {
    await container
        .read(craftRepositoryProvider)
        .upsertInventoryItem(_owned(itemId));
    await container
        .read(craftRepositoryProvider)
        .placeRoomItem(_placed(itemId, id: id));
    await container.read(craftControllerProvider.notifier).loadAll();
  }

  /// The room simulation, with the loop deliberately not started.
  ///
  /// The timer is not what these tests are about: they call the same forced
  /// entry points the page calls, which is where the preemption happens.
  RoomSimulationController sim() =>
      container.read(roomSimulationProvider.notifier);

  RoomSimulationState state() => container.read(roomSimulationProvider);

  group('a player request holds for its committed dwell', () {
    test('the sofa sit request is accepted with the player-request cause',
        () async {
      await place('sofa');
      sim().requestAction(
        itemId: 'sofa',
        actionId: 'sit',
        roomItemId: 'room-sofa',
      );

      expect(state().cause, RoomDecisionCause.playerRequest);
      expect(state().activity.actionId, 'sit');
      expect(state().activity.companionAction, 'room_sit');
      expect(state().activity.anchorId, isNotEmpty);
    });

    test('a plain tick does not replace it before the dwell expires', () async {
      await place('sofa');
      sim().requestAction(
          itemId: 'sofa', actionId: 'sit', roomItemId: 'room-sofa');

      // The loop's own tick obeys `endsAt`. This is the path that already works,
      // and it is here so the failing cases below cannot be mistaken for "the
      // dwell is simply not implemented".
      sim().debugAdvance(const Duration(seconds: 1));

      expect(state().activity.actionId, 'sit',
          reason: 'the commitment has not expired');
      expect(state().cause, RoomDecisionCause.playerRequest);
    });

    test('evaluateNow does not replace it', () async {
      await place('sofa');
      sim().requestAction(
          itemId: 'sofa', actionId: 'sit', roomItemId: 'room-sofa');

      // The page calls this after loadAll, after a placement property changes
      // and after a removal. None of those means "stop doing what I asked".
      sim().evaluateNow();

      expect(state().activity.actionId, 'sit',
          reason: 'a rebuild-driven re-evaluation must not take the companion '
              'off the action the player chose');
      expect(state().cause, RoomDecisionCause.playerRequest);
    });

    test('leaving arrange mode does not replace it', () async {
      await place('sofa');
      // The arrange edge only re-decides while the loop is running, so the loop
      // has to be started or this test would pass by doing nothing at all.
      sim().start();
      sim().requestAction(
          itemId: 'sofa', actionId: 'sit', roomItemId: 'room-sofa');

      // The drag lifecycle: a pan starts (arranging), then ends.
      sim().setArranging(true);
      sim().setArranging(false);

      expect(state().activity.actionId, 'sit',
          reason: 'finishing a drag is not a reason to abandon the request');
    });

    test('a focus pause DOES replace it, and that is the documented rule',
        () async {
      await place('sofa');
      sim().requestAction(
          itemId: 'sofa', actionId: 'sit', roomItemId: 'room-sofa');

      sim().setFocusPaused(true);

      // P28.2 forbids *routine, idle, ambient emotion and the daily routine*
      // from replacing a live player action. A focus pause is none of those: it
      // is a real business event -- the brief's break -- and it is deliberately
      // listed as higher authority. This test exists so the precedence is
      // asserted in both directions rather than assumed.
      expect(state().cause, RoomDecisionCause.tired,
          reason: 'pausing a session sends the companion to rest, by design');
      expect(state().activity.actionId, 'rest');
    });

    test('the effect is applied once, not once per re-evaluation', () async {
      await place('sofa');
      final before = state().vitals.energy;

      sim().requestAction(
          itemId: 'sofa', actionId: 'sit', roomItemId: 'room-sofa');
      final afterRequest = state().vitals.energy;

      sim().evaluateNow();
      sim().evaluateNow();

      expect(state().vitals.energy, afterRequest,
          reason: 're-evaluating must not re-apply the effect; before=$before '
              'afterRequest=$afterRequest after=${state().vitals.energy}');
    });

    test('re-requesting the same action does not apply its effect twice',
        () async {
      // The review caught this: `request` is allowed to preempt the live
      // commitment, so a second tap of the same chip ran the decision again and
      // applied the effect again. The bed's nap is +34 energy, so one accidental
      // double tap took the companion from depleted to capped.
      await place('sofa');
      sim().requestAction(
          itemId: 'sofa', actionId: 'sit', roomItemId: 'room-sofa');
      final afterFirst = state().vitals.energy;

      sim().requestAction(
          itemId: 'sofa', actionId: 'sit', roomItemId: 'room-sofa');

      expect(state().vitals.energy, afterFirst,
          reason: 'asking again for what is already running is the same '
              'instruction, not a second one');
      expect(state().activity.actionId, 'sit');
    });

    test('once the dwell really expires the loop may choose again', () async {
      await place('sofa');
      sim().requestAction(
          itemId: 'sofa', actionId: 'sit', roomItemId: 'room-sofa');

      // Past minDwell (14s for the sofa's sit): the companion is free again.
      sim().debugAdvance(const Duration(seconds: 20));

      expect(state().activity.actionId, isNotNull,
          reason: 'the companion is still doing something after the dwell');
    });
  });

  group('a request for furniture the player cannot use is refused', () {
    test('an unowned item is not accepted', () async {
      // Placed but never owned: the resolver checks ownership before accepting.
      await container
          .read(craftRepositoryProvider)
          .placeRoomItem(_placed('sofa'));
      await container.read(craftControllerProvider.notifier).loadAll();

      sim().requestAction(
          itemId: 'sofa', actionId: 'sit', roomItemId: 'room-sofa');

      expect(state().cause, isNot(RoomDecisionCause.playerRequest),
          reason: 'a tap cannot make the companion use furniture the player '
              'does not own');
    });
  });

  group('diagnostics', () {
    test('the trace shows housekeeping no longer preempts the request',
        () async {
      // P28.1 asked for requestAt / decisionAt / endsAt / cause / actionId /
      // anchorId and the replacement reason, so the cause is *read* rather than
      // reasoned about. The trace is what named the defect: a forced
      // `evaluateNow` replaced `player_request/sit` with `routine/sit` and threw
      // away all 14 seconds still owed.
      //
      // It now also proves the fix from the same evidence: the trace still
      // records the commitment, and no housekeeping entry point takes it away.
      await place('sofa');
      sim().requestAction(
          itemId: 'sofa', actionId: 'sit', roomItemId: 'room-sofa');

      final afterRequest = state();
      expect(afterRequest.cause, RoomDecisionCause.playerRequest);
      final owed =
          afterRequest.activity.endsAt - afterRequest.elapsedSinceStart;
      expect(afterRequest.playerCommitmentItemId, 'sofa',
          reason: 'the state records whose decision this is');

      // The housekeeping entry points the room page actually calls.
      sim().evaluateNow();
      sim().setArranging(true);
      sim().setArranging(false);

      // ignore: avoid_print
      print('P28_TRACE: ${sim().decisionTrace.map((t) => '$t').join(' | ')}');

      final byHousekeeping = [
        for (final t in sim().preemptions)
          if (t.replacedCause == RoomDecisionCause.playerRequest.id &&
              !const {'request', 'focusPause'}.contains(t.via))
            t,
      ];
      expect(byHousekeeping, isEmpty,
          reason:
              'routine, idle, ambient and the daily routine may not replace '
              'a live player action: $byHousekeeping');

      expect(state().activity.actionId, 'sit');
      expect(state().cause, RoomDecisionCause.playerRequest);
      expect(state().activity.endsAt - state().elapsedSinceStart, owed,
          reason: 'and the dwell it was promised is intact, not restarted');
    });

    test('the commitment ends when its furniture is removed', () async {
      // The guard must not become "never re-decide": a sofa that has been picked
      // up cannot be sat on, so the commitment ends with it.
      await place('sofa');
      sim().requestAction(
          itemId: 'sofa', actionId: 'sit', roomItemId: 'room-sofa');
      expect(state().playerCommitmentItemId, 'sofa');

      await container.read(craftRepositoryProvider).removeRoomItem('room-sofa');
      await container.read(craftControllerProvider.notifier).loadAll();
      sim().evaluateNow();

      expect(state().playerCommitmentItemId, isNull,
          reason: 'the furniture it was committed to is gone');
      expect(state().activity.actionId, isNot('sit'),
          reason: 'and the companion is no longer claimed to be sitting on it');
    });
  });
}
