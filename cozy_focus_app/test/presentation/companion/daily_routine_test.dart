import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_availability.dart';
import 'package:cozy_focus_app/presentation/companion/room/anchor_point.dart';
import 'package:cozy_focus_app/presentation/companion/room/companion_vitals.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_action_resolver.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_entity.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/daily_routine.dart';
import 'package:cozy_focus_app/presentation/companion/time_of_day.dart';

RoomItem placed(String itemId, {double x = 0.4, double y = 0.5, String? id}) =>
    RoomItem(
      id: id ?? 'room-$itemId',
      userId: 'u',
      itemId: itemId,
      positionX: x,
      positionY: y,
      scale: 1.0,
      zIndex: 1,
      isVisible: true,
      placedAt: DateTime(2026, 10, 1),
    );

InventoryItem owned(String itemId, {int quantity = 1}) => InventoryItem(
      id: 'inv-$itemId',
      userId: 'u',
      itemId: itemId,
      quantity: quantity,
      updatedAt: DateTime(2026, 10, 1),
    );

Map<String, AnchorPoint> anchorsFor(List<RoomItem> placed_) =>
    FurnitureAnchorRegistry.build(
      placed: placed_,
      owned: [
        for (final id in FurnitureCatalog.itemIds) owned(id),
      ],
      eligibleItemIds: FurnitureCatalog.itemIds,
    );

/// Decides for a band, with the furniture placed and everything owned.
RoomDecision decide({
  required TimeOfDayBand band,
  required List<RoomItem> furniture,
  CompanionVitals vitals = const CompanionVitals(),
  bool focusRunning = false,
  bool focusPaused = false,
  PlayerRequest? request,
}) =>
    FurnitureActionResolver.decide(RoomDecisionInput(
      availability: _everything,
      anchors: anchorsFor(furniture),
      vitals: vitals,
      timeOfDay: band,
      unlockedItemIds: FurnitureCatalog.itemIds,
      focusRunning: focusRunning,
      focusPaused: focusPaused,
      request: request,
    ));

/// A companion that ships every action.
///
/// The subject of these tests is the room's *decision logic* — night puts it to
/// bed, a break sends it to a seat, the routine fills the empty hours — and that
/// logic is the same whichever companion is present. Stating "a companion that
/// can do all of it" keeps the capability gate out of the way here; the gate
/// itself is what `room_capability_test.dart` is about.
final _everything = CompanionActionAvailabilityResolver.resolve('dog');

void main() {
  group('the day has a shape', () {
    test('the same room behaves differently in the morning and the evening',
        () {
      // The headline: before the routine, 05:00 and 21:00 were identical. This
      // is the assertion that would have failed against the old resolver.
      final furniture = [placed('bookshelf'), placed('sofa')];

      final morning = decide(
        band: TimeOfDayBand.morning,
        furniture: furniture,
      );
      final evening = decide(
        band: TimeOfDayBand.evening,
        furniture: furniture,
      );

      expect(morning.cause, RoomDecisionCause.routine);
      expect(evening.cause, RoomDecisionCause.routine);
      expect(morning.companionAction, isNot(evening.companionAction),
          reason: 'the companion must not behave the same at 07:00 and 21:00');
    });

    test('the morning starts with reading', () {
      final decision = decide(
        band: TimeOfDayBand.morning,
        furniture: [placed('bookshelf'), placed('sofa')],
      );
      expect(decision.cause, RoomDecisionCause.routine);
      expect(decision.itemId, 'bookshelf');
      expect(decision.companionAction, 'focus_read');
    });

    test('the middle of the day is spent making something', () {
      final decision = decide(
        band: TimeOfDayBand.midday,
        furniture: [placed('desk'), placed('bookshelf')],
      );
      expect(decision.cause, RoomDecisionCause.routine);
      expect(decision.itemId, 'desk');
      expect(decision.companionAction, 'craft_work');
    });

    test('the afternoon goes looking for something to read', () {
      final decision = decide(
        band: TimeOfDayBand.afternoon,
        furniture: [placed('bookshelf'), placed('desk')],
      );
      expect(decision.cause, RoomDecisionCause.routine);
      expect(decision.itemId, 'bookshelf');
      expect(decision.companionAction, 'focus_think');
    });

    test('the evening winds down on the sofa', () {
      final decision = decide(
        band: TimeOfDayBand.evening,
        furniture: [placed('sofa'), placed('desk')],
      );
      expect(decision.cause, RoomDecisionCause.routine);
      expect(decision.itemId, 'sofa');
      expect(decision.companionAction, 'room_sit');
    });

    test('a rug satisfies a seat step when there is no sofa', () {
      // Steps name a *role*, not a furniture id, so the routine survives a
      // player who owns less. A rug-only room still gets an evening.
      final decision = decide(
        band: TimeOfDayBand.evening,
        furniture: [placed('rug'), placed('desk')],
      );
      expect(decision.cause, RoomDecisionCause.routine);
      expect(decision.itemId, 'rug');
      expect(decision.companionAction, 'room_sit');
    });
  });

  group('the routine outranks only idling', () {
    test('late night is still the night rule, not the routine', () {
      // lateNight is deliberately unscheduled: the night rule owns bedtime, and
      // two answers to "when does it sleep" would be two sources of truth.
      final decision = decide(
        band: TimeOfDayBand.lateNight,
        furniture: [placed('bed'), placed('bookshelf')],
      );
      expect(decision.cause, RoomDecisionCause.night);
      expect(decision.companionAction, 'sleep');
    });

    test('a running focus session beats the routine', () {
      final decision = decide(
        band: TimeOfDayBand.evening,
        furniture: [placed('desk'), placed('sofa')],
        focusRunning: true,
      );
      expect(decision.cause, RoomDecisionCause.focus);
      expect(decision.companionAction, 'focus_write');
    });

    test('a player request beats the routine', () {
      final decision = decide(
        band: TimeOfDayBand.morning,
        furniture: [placed('bookshelf'), placed('sofa')],
        request: const PlayerRequest(
          itemId: 'sofa',
          actionId: 'sit',
          roomItemId: 'room-sofa',
        ),
      );
      expect(decision.cause, RoomDecisionCause.playerRequest);
      expect(decision.itemId, 'sofa');
    });

    test('a tired companion beats the routine', () {
      final decision = decide(
        band: TimeOfDayBand.midday,
        furniture: [placed('sofa'), placed('desk')],
        vitals: const CompanionVitals(energy: 12),
      );
      expect(decision.cause, RoomDecisionCause.tired);
      expect(decision.itemId, 'sofa');
    });

    test('a paused session is a break, not a routine', () {
      final decision = decide(
        band: TimeOfDayBand.morning,
        furniture: [placed('sofa'), placed('bookshelf')],
        focusPaused: true,
      );
      expect(decision.cause, RoomDecisionCause.tired);
      expect(decision.companionAction, 'pause_rest');
    });

    test('with nothing to use the routine falls through to idling', () {
      // A bed alone cannot satisfy any daytime step, so the companion is
      // merely in the room rather than pretending to use something.
      final decision = decide(
        band: TimeOfDayBand.morning,
        furniture: [placed('bed')],
      );
      expect(decision.cause, RoomDecisionCause.idle);
      expect(decision.isBusy, isFalse);
      expect(decision.anchorId, floorAnchor.id);
    });
  });

  group('the routine cannot name behaviour that never opted in', () {
    test('every shipped step resolves to a real catalog action', () {
      for (final band in DailyRoutine.shipped.scheduledBands) {
        for (final step in DailyRoutine.shipped.stepsFor(band)) {
          final label = '${wireIdFor(band)} $step';
          final candidates = FurnitureCatalog.withInteractionPoint(step.role);
          expect(candidates, isNotEmpty,
              reason: '$label names a role no furniture defines');

          final action = candidates
              .map((entity) => entity.actionById(step.action))
              .whereType<FurnitureAction>()
              .toList();
          expect(action, isNotEmpty,
              reason: '$label names an action no ${step.role} furniture has');
        }
      }
    });

    test('every step action carries the routine trigger', () {
      // This is the invariant that keeps the catalog authoritative. A step
      // naming behaviour that never opted in is a data error, and the resolver
      // drops it — so it would silently make that band fall back to idling.
      for (final band in DailyRoutine.shipped.scheduledBands) {
        for (final step in DailyRoutine.shipped.stepsFor(band)) {
          final label = '${wireIdFor(band)} $step';
          final capable = FurnitureCatalog.withInteractionPoint(step.role).any(
            (entity) =>
                entity.actionById(step.action)?.isAvailableOn(
                      FurnitureTrigger.routine,
                    ) ??
                false,
          );
          expect(capable, isTrue,
              reason:
                  '$label: the action must declare FurnitureTrigger.routine '
                  'or the routine cannot reach it');
        }
      }
    });

    test('a step the catalog has not opted into is dropped, not honoured', () {
      // Inject a routine that names an action with no routine trigger. The
      // resolver must ignore it rather than use it, which is what makes the
      // catalog — not the routine table — the gate.
      const smuggled = DailyRoutine({
        TimeOfDayBand.morning: [
          // `nap` is a sofa action, but it is not routine-capable.
          DailyRoutineStep(role: 'seat', action: 'nap', label: '打盹'),
        ],
      });
      final decision = FurnitureActionResolver.decide(RoomDecisionInput(
        availability: _everything,
        anchors: anchorsFor([placed('sofa')]),
        vitals: const CompanionVitals(),
        timeOfDay: TimeOfDayBand.morning,
        unlockedItemIds: FurnitureCatalog.itemIds,
        routine: smuggled,
      ));
      expect(decision.cause, isNot(RoomDecisionCause.routine));
      expect(decision.companionAction, isNot('sleep'));
    });

    test('a band with no routine at all is simply absent', () {
      const empty = DailyRoutine({});
      final decision = FurnitureActionResolver.decide(RoomDecisionInput(
        availability: _everything,
        anchors: anchorsFor([placed('bookshelf')]),
        vitals: const CompanionVitals(),
        timeOfDay: TimeOfDayBand.morning,
        unlockedItemIds: FurnitureCatalog.itemIds,
        routine: empty,
      ));
      expect(decision.cause, RoomDecisionCause.idle);
    });
  });

  group('the routine is presentation-only', () {
    test('neither the domain nor the data layer references it', () {
      // The same guard the time-of-day bands carry, for the same reason: a
      // routine that can reach XP, coins or a settlement is a business rule
      // wearing a presentation costume. This fails if it ever tries.
      const tokens = [
        'DailyRoutine',
        'DailyRoutineStep',
        'daily_routine.dart',
      ];
      final offenders = <String>[];

      for (final root in ['lib/domain', 'lib/data']) {
        final directory = Directory(root);
        expect(directory.existsSync(), isTrue,
            reason: '$root must exist for this guard to mean anything');
        for (final entity in directory.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final text = entity.readAsStringSync();
          for (final token in tokens) {
            if (text.contains(token)) offenders.add('${entity.path} -> $token');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'the daily routine is presentation-only; it must not reach '
              'XP, coins, happiness, settlements or streaks');
    });
  });
}
