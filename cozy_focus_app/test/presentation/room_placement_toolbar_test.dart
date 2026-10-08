// P7 Slice 2 — the placement toolbar.
//
// Slice 1 gave the controller a write path for scale, z-order and visibility.
// This is the test that the room actually reaches it: the buttons exist, they
// call the controller, and the result is visible in the layout — a bigger
// sprite, a changed draw order, a ghost instead of a disappearance.
//
// The room owns a 2s periodic simulation timer, so these tests step the clock
// explicitly with `pump(duration)` rather than `pumpAndSettle`, which would keep
// finding new frames and time out.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/core/auth/current_user.dart';
import 'package:cozy_focus_app/data/local/app_database.dart'
    hide FocusSession, Pet, CraftJob, CraftRecipe, InventoryItem, RoomItem;
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/room_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

class _TestClock implements FocusClock {
  final DateTime _now;
  _TestClock(this._now);
  @override
  DateTime now() => _now;
}

Widget _app(ProviderContainer container, Widget child) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.lightTheme, home: child),
    );

RoomItem roomItem(
  String itemId, {
  required String id,
  double x = 0.35,
  double y = 0.6,
  int zIndex = 0,
  double scale = 1.0,
  bool isVisible = true,
}) =>
    RoomItem(
      id: id,
      userId: localMvpUserId,
      itemId: itemId,
      positionX: x,
      positionY: y,
      scale: scale,
      zIndex: zIndex,
      isVisible: isVisible,
      placedAt: DateTime(2026, 10, 1, 10),
    );

InventoryItem owned(String itemId, {int quantity = 2}) => InventoryItem(
      id: 'inv-$itemId',
      userId: localMvpUserId,
      itemId: itemId,
      quantity: quantity,
      updatedAt: DateTime(2026, 10, 1, 10),
    );

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider
            .overrideWithValue(_TestClock(DateTime(2026, 10, 1, 10))),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> seedRoom(List<RoomItem> items) async {
    final repo = container.read(craftRepositoryProvider);
    for (final item in items) {
      await repo.upsertInventoryItem(owned(item.itemId));
      await repo.placeRoomItem(item);
    }
    await container.read(craftControllerProvider.notifier).loadAll();
  }

  Future<void> pumpRoom(WidgetTester tester) async {
    await tester.pumpWidget(_app(container, const RoomPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Selects a placed item, then dismisses the "use" panel so the placement
  /// toolbar is the visible one.
  ///
  /// Selecting opens the use panel first by design; the toolbar is what the
  /// player gets once they decline to have Mochi use the thing.
  Future<void> selectItem(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  CraftState craft() => container.read(craftControllerProvider);

  group('P7 toolbar — scale', () {
    testWidgets('放大 raises the persisted scale', (tester) async {
      await seedRoom([roomItem('sofa', id: 'room-sofa')]);
      await pumpRoom(tester);
      await selectItem(tester, '温馨沙发');

      expect(find.byTooltip('放大'), findsOneWidget);
      await tester.tap(find.byTooltip('放大'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(craft().roomItems.single.scale, closeTo(1.2, 1e-6));
    });

    testWidgets('缩小 lowers it, and cannot go below the floor', (tester) async {
      await seedRoom([roomItem('sofa', id: 'room-sofa')]);
      await pumpRoom(tester);
      await selectItem(tester, '温馨沙发');

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byTooltip('缩小'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
      }

      // Four taps would reach 0.2 unclamped; the controller floors it.
      expect(craft().roomItems.single.scale, CraftController.minRoomItemScale);
    });
  });

  group('P7 toolbar — z-order', () {
    testWidgets('置顶 moves the item to the end of the draw order',
        (tester) async {
      await seedRoom([
        roomItem('sofa', id: 'room-sofa', zIndex: 0),
        roomItem('desk', id: 'room-desk', x: 0.7, zIndex: 1),
      ]);
      await pumpRoom(tester);
      await selectItem(tester, '温馨沙发');

      await tester.tap(find.byTooltip('置顶'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(craft().roomItems.map((r) => r.id).toList(),
          ['room-desk', 'room-sofa']);
    });

    testWidgets('置底 moves it to the front of the draw order', (tester) async {
      await seedRoom([
        roomItem('sofa', id: 'room-sofa', zIndex: 0),
        roomItem('desk', id: 'room-desk', x: 0.7, zIndex: 1),
      ]);
      await pumpRoom(tester);
      await selectItem(tester, '窗边书桌');

      await tester.tap(find.byTooltip('置底'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(craft().roomItems.map((r) => r.id).toList(),
          ['room-desk', 'room-sofa']);
    });
  });

  group('P7 toolbar — visibility', () {
    testWidgets('隐藏 leaves a ghost rather than removing the item',
        (tester) async {
      await seedRoom([roomItem('sofa', id: 'room-sofa')]);
      await pumpRoom(tester);
      await selectItem(tester, '温馨沙发');

      expect(find.byTooltip('隐藏'), findsOneWidget);
      await tester.tap(find.byTooltip('隐藏'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(craft().roomItems.single.isVisible, isFalse);
      // The row survives, so the player can find it again and un-hide it.
      expect(craft().roomItems.length, 1);
      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.3),
        findsOneWidget,
      );
      // And the button now offers the way back.
      expect(find.byTooltip('显示'), findsOneWidget);
    });

    testWidgets('显示 brings it back to full opacity', (tester) async {
      await seedRoom([roomItem('sofa', id: 'room-sofa', isVisible: false)]);
      await pumpRoom(tester);
      await selectItem(tester, '温馨沙发');

      await tester.tap(find.byTooltip('显示'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(craft().roomItems.single.isVisible, isTrue);
      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.3),
        findsNothing,
      );
    });
  });

  group('P7 — a failed placement is surfaced', () {
    testWidgets('the stored error reaches the player as a SnackBar',
        (tester) async {
      await seedRoom(const []);
      await pumpRoom(tester);

      // Any failing write goes through the same state field; placing with no
      // stock is the one the player can actually hit.
      await container
          .read(craftControllerProvider.notifier)
          .placeItem('sofa', 0.5, 0.5);

      // Bounded rather than a fixed pair of pumps. `ref.listen` reports the
      // error on the build after the provider notifies, and under a full-suite
      // run the notification can land a frame later than a fixed 400ms covers —
      // which made this the only test in the suite that failed intermittently
      // (twice in ten full runs, never once in ten runs of this file alone).
      // The wait is what is flexible; the assertion is not.
      var frames = 0;
      while (find.byType(SnackBar).evaluate().isEmpty && frames < 20) {
        await tester.pump(const Duration(milliseconds: 100));
        frames++;
      }

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
