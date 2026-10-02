// P7 Slice 3 — edit/life separation.
//
// While the player is dragging furniture the room's loop must not choose a new
// activity: any decision taken now would be taken against a layout that is
// about to change. These tests cover the three things that can silently break —
// the page raising and clearing the pause, an explicit player request surviving
// it, and the pause never outliving the page.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/core/auth/current_user.dart';
import 'package:cozy_focus_app/data/local/app_database.dart'
    hide FocusSession, Pet, CraftJob, CraftRecipe, InventoryItem, RoomItem;
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_action_resolver.dart';
import 'package:cozy_focus_app/presentation/companion/room/room_simulation.dart';
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

void main() {
  group('the choosing policy', () {
    test('the loop may not choose while the player is arranging', () {
      expect(
        RoomSimulationController.mayChoose(arranging: true, forced: false),
        isFalse,
      );
    });

    test('an unforced choice is allowed once arranging stops', () {
      expect(
        RoomSimulationController.mayChoose(arranging: false, forced: false),
        isTrue,
      );
    });

    test('a forced choice always runs, arranging or not', () {
      // This is what keeps a tap on the furniture working mid-rearrange: the
      // pause suppresses the loop's own choosing, not the player's.
      expect(
        RoomSimulationController.mayChoose(arranging: true, forced: true),
        isTrue,
      );
    });
  });

  group('the page drives the pause', () {
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

    Future<void> seedRoom() async {
      final repo = container.read(craftRepositoryProvider);
      await repo.upsertInventoryItem(InventoryItem(
        id: 'inv-sofa',
        userId: localMvpUserId,
        itemId: 'sofa',
        quantity: 2,
        updatedAt: DateTime(2026, 10, 1, 10),
      ));
      await repo.placeRoomItem(RoomItem(
        id: 'room-sofa',
        userId: localMvpUserId,
        itemId: 'sofa',
        positionX: 0.35,
        positionY: 0.6,
        scale: 1.0,
        zIndex: 0,
        isVisible: true,
        placedAt: DateTime(2026, 10, 1, 10),
      ));
      await container.read(craftControllerProvider.notifier).loadAll();
    }

    Future<void> pumpRoom(WidgetTester tester) async {
      await tester.pumpWidget(_app(container, const RoomPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    RoomSimulationState sim() => container.read(roomSimulationProvider);

    /// The pause is controller state, not simulation state: a page clears it
    /// from `dispose`, where writing provider state is not allowed.
    RoomSimulationController notifier() =>
        container.read(roomSimulationProvider.notifier);

    testWidgets('a drag pauses the loop and lifting resumes it',
        (tester) async {
      await seedRoom();
      await pumpRoom(tester);
      expect(notifier().isArranging, isFalse);

      final gesture =
          await tester.startGesture(tester.getCenter(find.byTooltip('温馨沙发')));
      // A pan is not recognised until the pointer moves past the slop, which is
      // exactly the moment the pause has to be in place.
      await gesture.moveBy(const Offset(24, 0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(notifier().isArranging, isTrue);

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(notifier().isArranging, isFalse);
    });

    testWidgets('an explicit request is still honoured while paused',
        (tester) async {
      await seedRoom();
      await pumpRoom(tester);

      notifier().setArranging(true);
      await tester.pump();

      notifier().requestAction(
        itemId: 'sofa',
        actionId: 'sit',
        roomItemId: 'room-sofa',
      );
      await tester.pump();

      expect(sim().cause, RoomDecisionCause.playerRequest);
      expect(sim().activity.actionId, 'sit');
    });

    testWidgets('a page torn down mid-drag does not leave the loop paused',
        (tester) async {
      await seedRoom();
      await pumpRoom(tester);

      final gesture =
          await tester.startGesture(tester.getCenter(find.byTooltip('温馨沙发')));
      await gesture.moveBy(const Offset(24, 0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(notifier().isArranging, isTrue);

      // Navigate away without ever lifting the finger. The simulation is
      // app-scoped, so a pause left behind here would outlive the page.
      await tester.pumpWidget(_app(container, const SizedBox.shrink()));
      await tester.pump();
      await gesture.cancel();

      expect(notifier().isArranging, isFalse);
    });
  });
}
