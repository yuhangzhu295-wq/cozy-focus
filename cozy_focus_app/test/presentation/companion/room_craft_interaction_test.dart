import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/presentation/companion/room_interaction.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_behavior_director.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/random_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../companion/runtime/catalog_test_support.dart';

RoomItem placedItem(
  String itemId, {
  String? id,
  bool visible = true,
  int zIndex = 0,
  int placedAtMinute = 0,
}) =>
    RoomItem(
      id: id ?? 'row-$itemId-$zIndex-$placedAtMinute',
      userId: 'u',
      itemId: itemId,
      positionX: 0.5,
      positionY: 0.5,
      scale: 1.0,
      zIndex: zIndex,
      isVisible: visible,
      placedAt: DateTime(2026, 1, 1).add(Duration(minutes: placedAtMinute)),
    );

InventoryItem ownedItem(String itemId, {int quantity = 1}) => InventoryItem(
      id: 'inv-$itemId',
      userId: 'u',
      itemId: itemId,
      quantity: quantity,
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  final catalog = loadShippedCatalog();

  RoomInteractionTarget? resolve({
    List<RoomItem> placed = const [],
    List<InventoryItem> owned = const [],
  }) =>
      RoomInteractionResolver.resolve(
        catalog: catalog,
        placed: placed,
        owned: owned,
      );

  group('room recipes mirror docs/06', () {
    test('each furniture item maps to its declared behaviour', () {
      for (final entry in {
        'sofa': 'seat',
        'bed': 'lie',
        'bookshelf': 'front',
        'desk': 'work',
      }.entries) {
        final target = resolve(
          placed: [placedItem(entry.key)],
          owned: [ownedItem(entry.key)],
        );
        expect(target, isNotNull, reason: entry.key);
        expect(target!.anchor, entry.value, reason: entry.key);
        expect(target.itemId, entry.key);
      }
    });

    test(
        'the rug is a seat, so a cushion-less catalog still has somewhere to sit',
        () {
      final target = resolve(
        placed: [placedItem('rug')],
        owned: [ownedItem('rug')],
      );
      expect(target!.anchor, 'seat');
    });

    test('an item with no recipe is never chosen', () {
      // A wall decoration must not silently become something the companion
      // climbs on.
      expect(
        resolve(placed: [placedItem('lamp')], owned: [ownedItem('lamp')]),
        isNull,
      );
    });
  });

  group('the owned && placed && visible gate', () {
    test('placed but not owned is refused', () {
      expect(resolve(placed: [placedItem('sofa')]), isNull);
    });

    test('owned with zero stock is refused', () {
      expect(
        resolve(
          placed: [placedItem('sofa')],
          owned: [ownedItem('sofa', quantity: 0)],
        ),
        isNull,
      );
    });

    test('placed but hidden is refused', () {
      expect(
        resolve(
          placed: [placedItem('sofa', visible: false)],
          owned: [ownedItem('sofa')],
        ),
        isNull,
      );
    });

    test('owned and visible but not placed is refused', () {
      // Not placed means it is not in the placed list at all.
      expect(resolve(owned: [ownedItem('sofa')]), isNull);
    });

    test('all three together are accepted', () {
      final target = resolve(
        placed: [placedItem('sofa')],
        owned: [ownedItem('sofa')],
      );
      expect(target, isNotNull);
      expect(target!.itemId, 'sofa');
    });
  });

  group('selection among several eligible items', () {
    test('the topmost z-index wins', () {
      final target = resolve(
        placed: [
          placedItem('sofa', zIndex: 1),
          placedItem('bed', zIndex: 5),
        ],
        owned: [ownedItem('sofa'), ownedItem('bed')],
      );
      expect(target!.itemId, 'bed');
    });

    test('at equal z-index the newer placement wins', () {
      final target = resolve(
        placed: [
          placedItem('sofa', zIndex: 2, placedAtMinute: 10),
          placedItem('bed', zIndex: 2, placedAtMinute: 20),
        ],
        owned: [ownedItem('sofa'), ownedItem('bed')],
      );
      expect(target!.itemId, 'bed');
    });

    test('a hidden topmost item does not block a visible one', () {
      final target = resolve(
        placed: [
          placedItem('bed', zIndex: 9, visible: false),
          placedItem('sofa', zIndex: 1),
        ],
        owned: [ownedItem('sofa'), ownedItem('bed')],
      );
      expect(target!.itemId, 'sofa');
    });
  });

  group('the anchor drives the behaviour through the director', () {
    CompanionBehaviorDirector directorFor(String? anchor, {int seed = 3}) =>
        CompanionBehaviorDirector(
          catalog: catalog,
          context: CompanionContext(
            companionId: CompanionId.dog,
            baseContext: CompanionBaseContext.room,
            roomAnchor: anchor,
          ),
          random: SeededRandomSource(seed),
        );

    test('a seat anchor sits', () {
      expect(directorFor('seat').currentMacroBehavior!.id, 'room_sit');
    });

    test('a lie anchor sleeps', () {
      expect(directorFor('lie').currentMacroBehavior!.id, 'room_sleep');
    });

    test('a front anchor reads', () {
      expect(directorFor('front').currentMacroBehavior!.id, 'room_read');
    });

    test('a work anchor works', () {
      expect(directorFor('work').currentMacroBehavior!.id, 'room_work');
    });

    test('no anchor falls back to the room ambient behaviour', () {
      final director = directorFor(null);
      expect(
        ['room_relax', 'idle'],
        contains(director.currentMacroBehavior!.id),
      );
    });

    test('an unknown anchor still schedules rather than freezing', () {
      final director = directorFor('nowhere');
      expect(director.currentMacroBehavior, isNotNull);
    });
  });

  group('presentation never rewrites business coordinates', () {
    test('the resolver returns an anchor and a row id, never a position', () {
      final item = placedItem('sofa');
      final target = resolve(placed: [item], owned: [ownedItem('sofa')]);

      // The placed row keeps its own position; the resolver only names which
      // anchor and which row it chose.
      expect(target!.roomItemId, item.id);
      expect(item.positionX, 0.5);
      expect(item.positionY, 0.5);
    });
  });

  group('craft behaviour is gated on a real job', () {
    test('no craft job means no craft behaviour', () {
      final director = CompanionBehaviorDirector(
        catalog: catalog,
        context: const CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.craft,
          // craftProgress is null: no real CraftJob.
        ),
        random: SeededRandomSource(1),
      );
      for (var ms = 0; ms <= 60000; ms += 1000) {
        director.advanceTo(Duration(milliseconds: ms));
        expect(
          director.currentMacroBehavior,
          isNot(CompanionMacroBehavior.craftWork),
          reason: 'craft behaviour played at ${ms}ms without a job',
        );
      }
    });

    test('a real job does allow craft behaviour', () {
      final director = CompanionBehaviorDirector(
        catalog: catalog,
        context: const CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.craft,
          craftProgress: 0.3,
        ),
        random: SeededRandomSource(1),
      );
      expect(director.currentMacroBehavior, CompanionMacroBehavior.craftWork);
    });

    test('the director cannot advance craft — it holds no progress writer', () {
      // Structural: the director's only output is a presentation intent, which
      // has no craft field a caller could mistake for a mutation. Advancing it
      // for a simulated hour leaves the craft progress it was given unchanged.
      const progress = 0.3;
      final director = CompanionBehaviorDirector(
        catalog: catalog,
        context: const CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.craft,
          craftProgress: progress,
        ),
        random: SeededRandomSource(2),
      );
      for (var ms = 0; ms <= 3600000; ms += 5000) {
        director.advanceTo(Duration(milliseconds: ms));
      }
      expect(director.intent.craftProgress, progress);
    });
  });
}
