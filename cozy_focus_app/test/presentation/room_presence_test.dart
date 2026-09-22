import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/core/auth/current_user.dart';
import 'package:cozy_focus_app/data/local/app_database.dart'
    hide FocusSession, Pet, CraftJob, CraftRecipe, InventoryItem, RoomItem;
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/companion/companion_avatar.dart';
import 'package:cozy_focus_app/presentation/companion/room_presence.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/room_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// STAGE 5 / C5 — the room, gated on real ownership **and** placement.
///
/// `designs/pages/09_房间.png` shows Mochi sitting on a cushion inside the room.
/// These tests pin that Mochi's seat can only ever come from furniture the user
/// actually owns and has actually put down, and that the room shows Mochi either
/// way.
class _TestClock implements FocusClock {
  final DateTime _now;
  _TestClock(this._now);
  @override
  DateTime now() => _now;
}

Widget _app(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: AppTheme.lightTheme, home: child),
  );
}

/// A placed row. `placedAt` is derived from [order] so a test can say which of
/// two items was put down later without constructing dates by hand.
RoomItem placed(
  String itemId, {
  required double x,
  required double y,
  int zIndex = 1,
  bool isVisible = true,
  String? id,
  int order = 0,
}) {
  return RoomItem(
    id: id ?? 'room-$itemId-$zIndex-$order',
    userId: localMvpUserId,
    itemId: itemId,
    positionX: x,
    positionY: y,
    scale: 1.0,
    zIndex: zIndex,
    isVisible: isVisible,
    placedAt: DateTime(2026, 9, 12, 10, 0, order),
  );
}

InventoryItem owned(String itemId, {int quantity = 1}) {
  return InventoryItem(
    id: 'inv-$itemId',
    userId: localMvpUserId,
    itemId: itemId,
    quantity: quantity,
    updatedAt: DateTime(2026, 9, 12, 10, 0, 0),
  );
}

/// Recovers the normalised point the room page anchored Mochi at.
///
/// The page places the avatar with `Positioned` inside the room canvas, so the
/// avatar's global rect has to be measured against the canvas's own origin —
/// the canvas is not at the top of the screen. Inverting the page's arithmetic
/// this way means the assertion needs no knowledge of the canvas size and
/// cannot drift with the layout.
Offset impliedPresence(WidgetTester tester) {
  final avatarFinder = find.byType(CompanionAvatar);
  final stackFinder =
      find.ancestor(of: avatarFinder, matching: find.byType(Stack)).first;

  final avatar = tester.widget<CompanionAvatar>(avatarFinder);
  final avatarTopLeft = tester.getTopLeft(avatarFinder);
  final canvasTopLeft = tester.getTopLeft(stackFinder);
  final canvas = tester.getSize(stackFinder);

  return Offset(
    (avatarTopLeft.dx - canvasTopLeft.dx + avatar.size / 2) / canvas.width,
    (avatarTopLeft.dy - canvasTopLeft.dy + avatar.size) / canvas.height,
  );
}

void main() {
  late AppDatabase db;
  late _TestClock clock;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _TestClock(DateTime(2026, 9, 12, 10, 0, 0));
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider.overrideWithValue(clock),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('the seat is gated on real placement', () {
    test('an empty room puts Mochi on the floor', () {
      final presence = PetRoomPresenceResolver.resolve(
        placed: const [],
        owned: const [],
      );
      expect(presence.isOnSeat, isFalse);
      expect(presence.seatItemId, isNull);
      expect(presence.x, PetRoomPresenceResolver.floorX);
      expect(presence.y, PetRoomPresenceResolver.floorY);
    });

    test('a placed seat Mochi can use is used, at that item\'s position', () {
      final presence = PetRoomPresenceResolver.resolve(
        placed: [placed('rug', x: 0.3, y: 0.55)],
        owned: [owned('rug')],
      );
      expect(presence.isOnSeat, isTrue);
      expect(presence.seatItemId, 'rug');
      // The resolved point is the item's own normalised centre, so the canvas
      // can position Mochi with the arithmetic it already uses for furniture.
      expect(presence.x, 0.3);
      expect(presence.y, 0.55);
    });

    test('OWNED but not placed is not a seat', () {
      // The first half of the brief's gate. Owning a sofa is not the same as
      // having one in the room, and Mochi must not appear to sit on furniture
      // that is still in the inventory.
      final presence = PetRoomPresenceResolver.resolve(
        placed: const [],
        owned: [owned('sofa'), owned('bed'), owned('rug')],
      );
      expect(presence.isOnSeat, isFalse);
      expect(presence.seatItemId, isNull);
    });

    test('PLACED but not owned is not a seat', () {
      // The second half. `placeItem` only places from inventory today, so this
      // cannot happen through the UI — which is exactly why it is asserted: a
      // future grant path that writes a room row directly must not be able to
      // put Mochi on furniture the user never acquired.
      final presence = PetRoomPresenceResolver.resolve(
        placed: [placed('sofa', x: 0.4, y: 0.5)],
        owned: const [],
      );
      expect(presence.isOnSeat, isFalse);
    });

    test('an inventory row at quantity zero is not ownership', () {
      final presence = PetRoomPresenceResolver.resolve(
        placed: [placed('bed', x: 0.4, y: 0.5)],
        owned: [owned('bed', quantity: 0)],
      );
      expect(presence.isOnSeat, isFalse);
    });

    test('an invisible placed seat is not on the floor', () {
      final presence = PetRoomPresenceResolver.resolve(
        placed: [placed('rug', x: 0.4, y: 0.5, isVisible: false)],
        owned: [owned('rug')],
      );
      expect(presence.isOnSeat, isFalse);
    });

    test('a placed non-seat is not a seat', () {
      // The list of seat ids is positive on purpose. A bookshelf is owned and
      // placed, and Mochi still does not climb on it.
      final presence = PetRoomPresenceResolver.resolve(
        placed: [
          placed('bookshelf', x: 0.2, y: 0.3),
          placed('lamp', x: 0.8, y: 0.3),
          placed('cabinet', x: 0.6, y: 0.4),
        ],
        owned: [owned('bookshelf'), owned('lamp'), owned('cabinet')],
      );
      expect(presence.isOnSeat, isFalse);
    });

    test('a non-seat being placed does not stop a seat being used', () {
      final presence = PetRoomPresenceResolver.resolve(
        placed: [
          placed('bookshelf', x: 0.2, y: 0.3),
          placed('rug', x: 0.5, y: 0.6),
        ],
        owned: [owned('bookshelf'), owned('rug')],
      );
      expect(presence.seatItemId, 'rug');
    });
  });

  group('the choice between several seats is deterministic', () {
    test('the topmost seat wins', () {
      final presence = PetRoomPresenceResolver.resolve(
        placed: [
          placed('rug', x: 0.2, y: 0.2, zIndex: 1, order: 1),
          placed('sofa', x: 0.7, y: 0.7, zIndex: 5, order: 0),
        ],
        owned: [owned('rug'), owned('sofa')],
      );
      expect(presence.seatItemId, 'sofa');
    });

    test('at equal zIndex the newer placement wins', () {
      final presence = PetRoomPresenceResolver.resolve(
        placed: [
          placed('rug', x: 0.2, y: 0.2, zIndex: 2, order: 0),
          placed('bed', x: 0.7, y: 0.7, zIndex: 2, order: 3),
        ],
        owned: [owned('rug'), owned('bed')],
      );
      expect(presence.seatItemId, 'bed');
    });

    test('a full tie falls back to the id, so list order never decides', () {
      final a = placed('rug', x: 0.2, y: 0.2, zIndex: 1, id: 'aaa', order: 1);
      final b = placed('bed', x: 0.7, y: 0.7, zIndex: 1, id: 'bbb', order: 1);

      final forward = PetRoomPresenceResolver.resolve(
        placed: [a, b],
        owned: [owned('rug'), owned('bed')],
      );
      final reversed = PetRoomPresenceResolver.resolve(
        placed: [b, a],
        owned: [owned('bed'), owned('rug')],
      );

      expect(forward, reversed);
      expect(forward.seatItemId, 'bed');
    });

    test('the answer does not depend on the inventory order either', () {
      final a = placed('rug', x: 0.2, y: 0.2);
      final forward = PetRoomPresenceResolver.resolve(
        placed: [a],
        owned: [owned('rug'), owned('sofa')],
      );
      final reversed = PetRoomPresenceResolver.resolve(
        placed: [a],
        owned: [owned('sofa'), owned('rug')],
      );
      expect(forward, reversed);
    });

    test('presence compares by value', () {
      const a = PetRoomPresence(seatItemId: 'rug', x: 0.2, y: 0.3);
      const b = PetRoomPresence(seatItemId: 'rug', x: 0.2, y: 0.3);
      const c = PetRoomPresence(seatItemId: null, x: 0.5, y: 0.7);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toString(), contains('rug'));
      expect(c.toString(), contains('floor'));
    });
  });

  group('every seat id is a real item', () {
    test('the seat list only names items the catalog actually ships', () async {
      // If a catalog id is renamed, the seat list silently stops matching and
      // Mochi never sits down again — with nothing failing. This is the guard.
      final recipes =
          await container.read(craftRepositoryProvider).findAllRecipes();
      final shipped = recipes.map((r) => r.outputItemId).toSet();

      expect(shipped, isNotEmpty,
          reason: 'the seeded catalog should not be empty');
      for (final id in PetRoomPresenceResolver.seatItemIds) {
        expect(shipped, contains(id),
            reason: '$id is treated as a seat but is not a craftable item');
      }
    });

    test('the seat list is a small, deliberate subset', () {
      expect(PetRoomPresenceResolver.seatItemIds, isNotEmpty);
      expect(PetRoomPresenceResolver.seatItemIds.length, lessThan(8));
    });
  });

  group('the room shows Mochi', () {
    testWidgets('Mochi is in the room even when nothing is placed',
        (tester) async {
      await container.read(craftControllerProvider.notifier).loadAll();
      await tester.pumpWidget(_app(container, const RoomPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(CompanionAvatar), findsOneWidget);
    });

    testWidgets('Mochi is in the room when a seat is placed', (tester) async {
      await container.read(craftRepositoryProvider).upsertInventoryItem(
            owned('rug', quantity: 1),
          );
      await container.read(craftRepositoryProvider).placeRoomItem(
            placed('rug', x: 0.35, y: 0.6, id: 'room-rug'),
          );
      await container.read(craftControllerProvider.notifier).loadAll();

      await tester.pumpWidget(_app(container, const RoomPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(CompanionAvatar), findsOneWidget);
    });

    testWidgets('Mochi stands on the resolved seat, by its bottom edge',
        (tester) async {
      await container.read(craftRepositoryProvider).upsertInventoryItem(
            owned('rug', quantity: 1),
          );
      await container.read(craftRepositoryProvider).placeRoomItem(
            placed('rug', x: 0.35, y: 0.6, id: 'room-rug'),
          );
      await container.read(craftControllerProvider.notifier).loadAll();

      await tester.pumpWidget(_app(container, const RoomPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final implied = impliedPresence(tester);
      expect(implied.dx, closeTo(0.35, 0.01));
      expect(implied.dy, closeTo(0.6, 0.01));
    });

    testWidgets('with nothing placed Mochi uses the floor spot',
        (tester) async {
      await container.read(craftControllerProvider.notifier).loadAll();
      await tester.pumpWidget(_app(container, const RoomPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final implied = impliedPresence(tester);
      expect(implied.dx, closeTo(PetRoomPresenceResolver.floorX, 0.01));
      expect(implied.dy, closeTo(PetRoomPresenceResolver.floorY, 0.01));
    });

    testWidgets('Mochi cannot swallow a tap meant for the furniture',
        (tester) async {
      // Mochi sits *on* furniture, so it necessarily covers the item the user
      // may want to select. This is the structural half of "decorating still
      // works while Mochi is in the room".
      await container.read(craftRepositoryProvider).upsertInventoryItem(
            owned('rug', quantity: 1),
          );
      await container.read(craftRepositoryProvider).placeRoomItem(
            placed('rug', x: 0.5, y: 0.5, id: 'room-rug'),
          );
      await container.read(craftControllerProvider.notifier).loadAll();

      await tester.pumpWidget(_app(container, const RoomPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byWidgetPredicate(
          (w) => w is IgnorePointer && w.child is CompanionAvatar,
        ),
        findsOneWidget,
        reason: 'the room avatar must sit behind an IgnorePointer',
      );
    });

    testWidgets('the room pins Mochi to idle, not to a running craft job',
        (tester) async {
      // The room is where Mochi rests; the craft presentation belongs to the
      // screens that show the job. 09_房间.png shows Mochi lying down reading.
      await container.read(craftControllerProvider.notifier).loadAll();
      await tester.pumpWidget(_app(container, const RoomPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final avatar =
          tester.widget<CompanionAvatar>(find.byType(CompanionAvatar));
      expect(avatar.visualStateOverride, PetVisualState.idle);
      expect(avatar.showStateBadge, isFalse);
    });
  });
}
