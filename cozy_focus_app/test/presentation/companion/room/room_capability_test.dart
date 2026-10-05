import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/presentation/companion/room/anchor_point.dart';
import 'package:cozy_focus_app/presentation/companion/room/companion_vitals.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_action_resolver.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_availability.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/time_of_day.dart';

/// P35 — the room commits nothing the companion cannot perform.
///
/// ## The rule
///
/// The furniture panel was already gated, so an action the companion has no art
/// for was not *offered*. But the decision loop was not: it resolved a cause to
/// furniture and an action, and the effect of that action was applied to the
/// companion's vitals — energy restored, mood lifted — before the director ever
/// saw the committed action and quietly refused to draw it.
///
/// So the companion rested without appearing to, and the player's companion
/// recovered from something that never happened. That is the same defect as the
/// capability answer being the dog's, one layer down: a decision made about
/// behaviour by something that does not know what the companion can do.
///
/// The fix is that the decision itself carries the companion's capabilities, and
/// an action it cannot perform is not chosen at all — so there is no commitment
/// and no effect.
void main() {
  RoomItem placed(String itemId, {String? id}) => RoomItem(
        id: id ?? 'room-$itemId',
        userId: 'u',
        itemId: itemId,
        positionX: 0.4,
        positionY: 0.5,
        scale: 1.0,
        zIndex: 1,
        isVisible: true,
        placedAt: DateTime(2026, 10, 1),
      );

  InventoryItem owned(String itemId) => InventoryItem(
        id: 'inv-$itemId',
        userId: 'u',
        itemId: itemId,
        quantity: 1,
        updatedAt: DateTime(2026, 10, 1),
      );

  Map<String, AnchorPoint> anchorsFor(List<RoomItem> rows) =>
      FurnitureAnchorRegistry.build(
        placed: rows,
        owned: [for (final id in FurnitureCatalog.itemIds) owned(id)],
        eligibleItemIds: FurnitureCatalog.itemIds,
      );

  /// A companion that ships exactly [actions].
  CompanionActionAvailability ships(Set<String> actions) =>
      CompanionActionAvailability(companionId: 'test', schedulable: actions);

  /// Everything the shipped dog ships.
  final everything = CompanionActionAvailabilityResolver.resolve('dog');

  RoomDecisionInput input(
    List<RoomItem> rows, {
    required CompanionActionAvailability availability,
    bool focusPaused = false,
    bool focusRunning = false,
    TimeOfDayBand timeOfDay = TimeOfDayBand.midday,
    CompanionVitals? vitals,
    PlayerRequest? request,
  }) =>
      RoomDecisionInput(
        anchors: anchorsFor(rows),
        vitals: vitals ?? const CompanionVitals(),
        timeOfDay: timeOfDay,
        focusRunning: focusRunning,
        focusPaused: focusPaused,
        unlockedItemIds: FurnitureCatalog.itemIds,
        request: request,
        companionId: const CompanionId('test'),
        availability: availability,
      );

  group('canPerform answers in the vocabulary the room speaks', () {
    test('an action the companion ships is performable', () {
      expect(ships({'idle', 'room_sit'}).canPerform('room_sit'), isTrue);
    });

    test('an action it does not ship is not', () {
      expect(ships({'idle'}).canPerform('room_sit'), isFalse);
    });

    test('an id that is not a companion action at all is not', () {
      // Not in the vocabulary, so nothing can schedule it. False rather than an
      // exception: the question has an answer, and the answer is no.
      expect(ships({'idle'}).canPerform('not_an_action'), isFalse);
      expect(everything.canPerform('not_an_action'), isFalse);
    });
  });

  group('a companion that cannot sit is not sent to the sofa', () {
    test('the break decision has no action and no effect', () {
      final rows = [placed('sofa')];

      // The dog gets the sofa: the decision this rule is meant to keep working.
      final dog = FurnitureActionResolver.decide(
        input(rows, availability: everything, focusPaused: true),
      );
      expect(dog.companionAction, isNotNull,
          reason: 'a companion that can sit must still be sent to the sofa');
      expect(dog.effect.isNeutral, isFalse,
          reason: 'and resting must still restore it');

      // A pack that ships idle and walk only.
      final partial = FurnitureActionResolver.decide(
        input(rows, availability: ships({'idle', 'walk'}), focusPaused: true),
      );
      expect(partial.companionAction, isNull,
          reason: 'it cannot perform the sofa action, so it must not be given '
              'one');
      expect(partial.actionId, isNull);
      expect(partial.effect.isNeutral, isTrue,
          reason: 'and no effect may be applied for an action that cannot '
              'happen');
    });

    test('it falls through to the floor rather than idling at the sofa', () {
      final rows = [placed('sofa')];
      final decision = FurnitureActionResolver.decide(
        input(rows, availability: ships({'idle'}), focusPaused: true),
      );

      // Not the sofa anchor with the action stripped: standing on the sofa doing
      // nothing would be a worse answer than staying on the floor.
      expect(decision.roomItemId, isNull);
      expect(decision.cause, RoomDecisionCause.idle);
      expect(decision.effect.isNeutral, isTrue);
    });
  });

  group('the bed is not used by a companion that cannot sleep', () {
    test('a late-night decision is refused without the action', () {
      final rows = [placed('bed')];

      final dog = FurnitureActionResolver.decide(
        input(rows,
            availability: everything, timeOfDay: TimeOfDayBand.lateNight),
      );
      expect(dog.companionAction, isNotNull);

      final partial = FurnitureActionResolver.decide(
        input(rows,
            availability: ships({'idle', 'walk'}),
            timeOfDay: TimeOfDayBand.lateNight),
      );
      expect(partial.companionAction, isNull);
      expect(partial.effect.isNeutral, isTrue);
    });
  });

  group('a player request is not honoured for an action that cannot happen',
      () {
    test('the request is not the cause of the resulting decision', () {
      final sofa = placed('sofa');
      final request = PlayerRequest(
        itemId: 'sofa',
        actionId: 'sit',
        roomItemId: sofa.id,
      );

      final honoured = FurnitureActionResolver.decide(
        input([sofa], availability: everything, request: request),
      );
      expect(honoured.cause, RoomDecisionCause.playerRequest);

      final refused = FurnitureActionResolver.decide(
        input([sofa], availability: ships({'idle'}), request: request),
      );
      expect(refused.cause, isNot(RoomDecisionCause.playerRequest),
          reason: 'the request must not be honoured');
      expect(refused.companionAction, isNull);
      expect(refused.effect.isNeutral, isTrue,
          reason: 'and asking for it must not restore the companion anyway');
    });
  });

  group('the routine is subject to the same rule', () {
    test('an autonomous decision never names an action it cannot perform', () {
      // The routine is where "capability truth applies to autonomous decisions
      // too" matters most: nobody tapped anything, so there is no player
      // expectation to lean on.
      final rows = [
        placed('bed'),
        placed('sofa'),
        placed('desk'),
        placed('bookshelf'),
      ];

      for (final band in TimeOfDayBand.values) {
        for (final paused in [false, true]) {
          final decision = FurnitureActionResolver.decide(input(
            rows,
            availability: ships({'idle'}),
            timeOfDay: band,
            focusPaused: paused,
          ));
          expect(decision.companionAction, isNull,
              reason:
                  'at ${band.name}, paused=$paused, the companion was given '
                  '${decision.companionAction} and ships only idle');
          expect(decision.effect.isNeutral, isTrue,
              reason: 'and the effect of ${decision.actionId} must not be '
                  'applied');
        }
      }
    });

    test('and a companion that can do everything still gets its routine', () {
      final rows = [placed('bed'), placed('sofa'), placed('desk')];
      final seen = <String?>{};
      for (final band in TimeOfDayBand.values) {
        final decision = FurnitureActionResolver.decide(
          input(rows, availability: everything, timeOfDay: band),
        );
        seen.add(decision.companionAction);
      }
      // The guard against over-gating: the rule must not turn the room into a
      // companion that only ever idles on the floor.
      expect(seen.where((action) => action != null), isNotEmpty,
          reason: 'the dog must still use its furniture; saw $seen');
    });
  });
}
