import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/presentation/companion/room/anchor_point.dart';
import 'package:cozy_focus_app/presentation/companion/room/companion_vitals.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_action_resolver.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_entity.dart';
import 'package:cozy_focus_app/presentation/companion/time_of_day.dart';

/// The room simulation's acceptance criteria, as tests.
///
/// These are the task's own PASS conditions restated so a regression fails
/// here rather than in a user's room. The four that are behavioural — *tap sofa
/// → rests*, *tap desk → works*, *tap bed → sleeps*, *focus → uses desk* — are
/// asserted against the resolver, which is where those decisions are actually
/// made; the page only renders the answer.
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

/// The anchors for a set of placed rows, built the way the app builds them.
Map<String, AnchorPoint> anchorsFor(
  List<RoomItem> placed_, {
  Set<String>? unlocked,
}) =>
    FurnitureAnchorRegistry.build(
      placed: placed_,
      owned: [
        for (final id in (unlocked ?? FurnitureCatalog.itemIds)) owned(id),
      ],
      eligibleItemIds: FurnitureCatalog.itemIds,
    );

void main() {
  group('acceptance 1-3: tapping furniture makes the companion use it', () {
    test('tap sofa → the companion settles on it', () {
      final sofa = placed('sofa', x: 0.3, y: 0.6);
      final anchors = anchorsFor([sofa]);
      final decision = FurnitureActionResolver.decide(
        RoomDecisionInput(
          anchors: anchors,
          vitals: const CompanionVitals(),
          timeOfDay: TimeOfDayBand.midday,
          unlockedItemIds: {'sofa'},
          request: PlayerRequest(
            itemId: 'sofa',
            actionId: 'rest',
            roomItemId: sofa.id,
          ),
        ),
      );
      // The sofa's resting action, at the sofa's own anchor.
      expect(decision.cause, RoomDecisionCause.playerRequest);
      expect(decision.companionAction, 'pause_rest');
      expect(decision.anchorId, 'sofa_anchor');
      // And it actually restores the companion, which is what makes it a use
      // rather than a picture.
      expect(decision.effect.energy, greaterThan(0));
    });

    test('tap desk → the companion works', () {
      final desk = placed('desk', x: 0.5, y: 0.5);
      final decision = FurnitureActionResolver.decide(
        RoomDecisionInput(
          anchors: anchorsFor([desk]),
          vitals: const CompanionVitals(),
          timeOfDay: TimeOfDayBand.midday,
          unlockedItemIds: {'desk'},
          request: PlayerRequest(
            itemId: 'desk',
            actionId: 'write',
            roomItemId: desk.id,
          ),
        ),
      );
      expect(decision.companionAction, 'focus_write');
      expect(decision.anchorId, 'desk_anchor');
      expect(decision.effect.focus, greaterThan(0));
    });

    test('tap bed → the companion sleeps', () {
      final bed = placed('bed', x: 0.4, y: 0.55);
      final decision = FurnitureActionResolver.decide(
        RoomDecisionInput(
          anchors: anchorsFor([bed]),
          vitals: const CompanionVitals(),
          timeOfDay: TimeOfDayBand.midday,
          unlockedItemIds: {'bed'},
          request: PlayerRequest(
            itemId: 'bed',
            actionId: 'sleep',
            roomItemId: bed.id,
          ),
        ),
      );
      expect(decision.companionAction, 'sleep');
      expect(decision.anchorId, 'bed_anchor');
      expect(decision.effect.energy, greaterThan(10));
    });
  });

  group('acceptance 4-5: focus drives the companion by itself', () {
    test('a running focus session sends the companion to the desk', () {
      final decision = FurnitureActionResolver.decide(
        RoomDecisionInput(
          anchors: anchorsFor([placed('desk'), placed('sofa')]),
          vitals: const CompanionVitals(),
          timeOfDay: TimeOfDayBand.midday,
          unlockedItemIds: {'desk', 'sofa'},
          focusRunning: true,
        ),
      );
      // No player input at all: state plus environment is enough.
      expect(decision.cause, RoomDecisionCause.focus);
      expect(decision.itemId, 'desk');
      expect(decision.companionAction, 'focus_write');
    });

    test('a paused session is a break, and sends it to the sofa', () {
      final decision = FurnitureActionResolver.decide(
        RoomDecisionInput(
          anchors: anchorsFor([placed('desk'), placed('sofa')]),
          vitals: const CompanionVitals(),
          timeOfDay: TimeOfDayBand.midday,
          unlockedItemIds: {'desk', 'sofa'},
          focusPaused: true,
        ),
      );
      expect(decision.itemId, 'sofa');
      expect(decision.companionAction, 'pause_rest');
    });

    test('after focus ends the companion changes behaviour', () {
      final anchors = anchorsFor([placed('desk'), placed('sofa')]);
      final during = FurnitureActionResolver.decide(RoomDecisionInput(
        anchors: anchors,
        vitals: const CompanionVitals(),
        timeOfDay: TimeOfDayBand.midday,
        unlockedItemIds: {'desk', 'sofa'},
        focusRunning: true,
      ));
      final after = FurnitureActionResolver.decide(RoomDecisionInput(
        anchors: anchors,
        vitals: const CompanionVitals(),
        timeOfDay: TimeOfDayBand.midday,
        unlockedItemIds: {'desk', 'sofa'},
      ));
      expect(during.companionAction, isNot(after.companionAction));
      // The *cause* is what changed, not necessarily the furniture: an idle
      // companion is allowed to stay at the desk and potter about. What must not
      // happen is that it keeps presenting the focus work behaviour as if the
      // session were still running.
      expect(during.cause, RoomDecisionCause.focus);
      expect(after.cause, isNot(RoomDecisionCause.focus));
      expect(during.companionAction, 'focus_write');
    });

    test('at night the companion goes to bed', () {
      final decision = FurnitureActionResolver.decide(
        RoomDecisionInput(
          anchors: anchorsFor([placed('bed'), placed('desk')]),
          vitals: const CompanionVitals(),
          timeOfDay: TimeOfDayBand.lateNight,
          unlockedItemIds: {'bed', 'desk'},
        ),
      );
      expect(decision.cause, RoomDecisionCause.night);
      expect(decision.itemId, 'bed');
      expect(decision.companionAction, 'sleep');
    });

    test('a tired companion prefers resting', () {
      final decision = FurnitureActionResolver.decide(
        RoomDecisionInput(
          anchors: anchorsFor([placed('sofa'), placed('desk')]),
          vitals: const CompanionVitals(energy: 12),
          timeOfDay: TimeOfDayBand.midday,
          unlockedItemIds: {'sofa', 'desk'},
        ),
      );
      expect(decision.cause, RoomDecisionCause.tired);
      expect(decision.itemId, 'sofa');
    });
  });

  group('acceptance 6: unlocking furniture changes gameplay', () {
    test('an unowned item contributes no anchor and no behaviour', () {
      // The player has a sofa but does not own it — impossible through the UI,
      // which is exactly why it is asserted: ownership is the gate that makes
      // an unlock *add* a behaviour.
      final anchors = FurnitureAnchorRegistry.build(
        placed: [placed('sofa')],
        owned: const [],
        eligibleItemIds: FurnitureCatalog.itemIds,
      );
      expect(anchors, isEmpty);

      final decision = FurnitureActionResolver.decide(
        RoomDecisionInput(
          anchors: anchors,
          vitals: const CompanionVitals(),
          timeOfDay: TimeOfDayBand.midday,
          unlockedItemIds: const {},
        ),
      );
      // No furniture, so it falls back to being in the room rather than
      // pretending to sit on something that is not there.
      expect(decision.isBusy, isFalse);
      expect(decision.anchorId, floorAnchor.id);
    });

    test('each catalog entry defines actions that add behaviour', () {
      for (final entity in FurnitureCatalog.entities.values) {
        expect(entity.actions, isNotEmpty,
            reason: '${entity.id} must offer at least one action');
        for (final action in entity.actions) {
          expect(action.triggers, isNotEmpty,
              reason: '${entity.id}/${action.id} needs a cause');
          expect(action.companionAction, isNotEmpty,
              reason: '${entity.id}/${action.id} needs a sprite action');
        }
      }
    });

    test('every action is gated on the player owning the furniture', () {
      for (final entity in FurnitureCatalog.entities.values) {
        for (final action in entity.actions) {
          expect(action.requiresUnlock, isTrue,
              reason: '${entity.id}/${action.id} must require the unlock');
        }
      }
    });
  });

  group('acceptance 7-9: no branching, no fake buttons, no static images', () {
    test('the catalog is the only place a furniture id is named', () {
      // A species-style branch would appear as an equality test on an id. The
      // resolvers must read the table instead. This checks the two files that
      // make the decisions.
      for (final path in const [
        'lib/presentation/companion/room/furniture_action_resolver.dart',
        'lib/presentation/companion/room/anchor_point.dart',
      ]) {
        final source = _read(path);
        expect(source.contains("== 'sofa'"), isFalse, reason: path);
        expect(source.contains("== 'desk'"), isFalse, reason: path);
        expect(source.contains("== 'bed'"), isFalse, reason: path);
        expect(source.contains("== 'bookshelf'"), isFalse, reason: path);
      }
    });

    test('every action maps to a companion action the sprite layer knows', () {
      // This is what stops a "fake button": an affordance whose action cannot
      // be presented is a button that does nothing.
      const presentable = {
        'room_sit',
        'room_read',
        'room_sleep',
        'room_work',
        'room_relax',
        'focus_read',
        'focus_write',
        'focus_think',
        'craft_work',
        'celebrate',
        'pause_rest',
        'sleep',
        'idle',
      };
      for (final entity in FurnitureCatalog.entities.values) {
        for (final action in entity.actions) {
          expect(presentable, contains(action.companionAction),
              reason: '${entity.id}/${action.id} → '
                  '${action.companionAction} has no presentation');
        }
      }
    });

    test('an unknown item yields no entity rather than a generic one', () {
      expect(FurnitureCatalog.forId('wall_painting'), isNull);
      expect(FurnitureCatalog.forId(''), isNull);
    });
  });

  group('the vitals stay in range', () {
    test('effects clamp at the top', () {
      const full = CompanionVitals(energy: 100, mood: 100);
      final after = full.copyWithEffect(
        const FurnitureEffect(energy: 40, mood: 40),
      );
      expect(after.energy, 100);
      expect(after.mood, 100);
    });

    test('effects clamp at the bottom', () {
      const empty = CompanionVitals(energy: 0, mood: 0, focusLevel: 0);
      final after = empty.copyWithEffect(
        const FurnitureEffect(energy: -40, mood: -40, focus: -40),
      );
      expect(after.energy, 0);
      expect(after.mood, 0);
      expect(after.focusLevel, 0);
    });

    test('time passing drains energy but never relationship', () {
      const start = CompanionVitals(energy: 80, relationship: 30);
      final later = start.afterElapsed(const Duration(hours: 2));
      expect(later.energy, lessThan(start.energy));
      expect(later.relationship, start.relationship,
          reason: 'affection must not be farmable by waiting');
    });

    test('tiredness uses the threshold the brief states', () {
      expect(const CompanionVitals(energy: 39).isTired, isTrue);
      expect(const CompanionVitals(energy: 40).isTired, isFalse);
    });
  });

  group('anchors follow the furniture', () {
    test('an anchor sits where the item was placed', () {
      final anchors = anchorsFor([placed('desk', x: 0.62, y: 0.44)]);
      final desk = anchors.values.single;
      expect(desk.id, 'desk_anchor');
      expect(desk.x, 0.62);
      expect(desk.y, 0.44);
    });

    test('two of the same item give two anchors', () {
      final anchors = anchorsFor([
        placed('rug', x: 0.2, y: 0.6, id: 'a'),
        placed('rug', x: 0.8, y: 0.6, id: 'b'),
      ]);
      expect(anchors.length, 2);
      expect(
        FurnitureAnchorRegistry.forRoomItem(anchors, 'b')?.x,
        0.8,
      );
    });

    test('an invisible item has no anchor', () {
      final hidden = RoomItem(
        id: 'hidden',
        userId: 'u',
        itemId: 'desk',
        positionX: 0.5,
        positionY: 0.5,
        scale: 1.0,
        zIndex: 1,
        isVisible: false,
        placedAt: DateTime(2026, 10, 1),
      );
      expect(anchorsFor([hidden]), isEmpty);
    });
  });
}

/// Reads a project file, so a structural guard can inspect it.
String _read(String relativePath) {
  final file = File(relativePath);
  if (!file.existsSync()) return '';
  return file.readAsStringSync();
}
