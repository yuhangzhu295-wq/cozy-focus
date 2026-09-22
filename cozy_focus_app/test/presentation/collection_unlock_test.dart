import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/core/auth/current_user.dart';
import 'package:cozy_focus_app/data/local/app_database.dart'
    hide
        Pet,
        PetMemory,
        FocusSession,
        FocusRecord,
        CraftJob,
        CraftRecipe,
        InventoryItem,
        RoomItem;
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/pet_models.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/companion/collection_unlock.dart';
import 'package:cozy_focus_app/presentation/companion/companion_avatar.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/pet_collection_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';

/// STAGE 5 / C7 — the collection unlock response.
///
/// The brief asks for a reaction driven by *real* unlocks. The hard part is not
/// the celebration; it is not celebrating on arrival, when every already-owned
/// item is visible at once.
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

InventoryItem inv(String itemId, int quantity) => InventoryItem(
      id: 'inv-$itemId',
      userId: localMvpUserId,
      itemId: itemId,
      quantity: quantity,
      updatedAt: DateTime(2026, 9, 12, 10, 0, 0),
    );

void main() {
  group('the tracker reports transitions, not states', () {
    test('a first observation is a baseline and reports nothing', () {
      final tracker = PetCollectionUnlockTracker();
      expect(tracker.hasBaseline, isFalse);

      // However much is already owned: arriving somewhere is not an unlock.
      final result = tracker.observe([
        inv('sofa', 1),
        inv('rug', 3),
        inv('lamp', 1),
      ]);

      expect(result, isNull);
      expect(tracker.hasBaseline, isTrue);
      expect(tracker.baselineSize, 3);
    });

    test('an empty first observation is still a baseline', () {
      final tracker = PetCollectionUnlockTracker();
      expect(tracker.observe(const []), isNull);
      expect(tracker.hasBaseline, isTrue);
      expect(tracker.baselineSize, 0);
    });

    test('a later 0 -> positive is an unlock', () {
      final tracker = PetCollectionUnlockTracker();
      tracker.observe([inv('sofa', 1)]);

      expect(tracker.observe([inv('sofa', 1), inv('rug', 1)]), 'rug');
    });

    test('crafting a duplicate of something already owned is not an unlock',
        () {
      final tracker = PetCollectionUnlockTracker();
      tracker.observe([inv('sofa', 1)]);

      // The user already had the sofa. Announcing it again would be noise, which
      // is why the comparison is on the owned *set* and not on quantities.
      expect(tracker.observe([inv('sofa', 2)]), isNull);
    });

    test('the same inventory observed twice reports only once', () {
      final tracker = PetCollectionUnlockTracker();
      tracker.observe(const []);

      expect(tracker.observe([inv('bed', 1)]), 'bed');
      expect(tracker.observe([inv('bed', 1)]), isNull);
      expect(tracker.observe([inv('bed', 1)]), isNull);
    });

    test('a quantity-zero row is not ownership', () {
      final tracker = PetCollectionUnlockTracker();
      tracker.observe(const []);

      expect(tracker.observe([inv('bed', 0)]), isNull);
      expect(tracker.observe([inv('bed', 1)]), 'bed');
    });

    test('several simultaneous unlocks pick the lowest id, deterministically',
        () {
      final tracker = PetCollectionUnlockTracker();
      tracker.observe(const []);

      final forward = tracker.observe([inv('rug', 1), inv('bed', 1)]);
      expect(forward, 'bed');

      // Only one reaction can be shown, so the choice must not depend on the
      // order the rows came back in.
      final other = PetCollectionUnlockTracker()..observe(const []);
      expect(other.observe([inv('bed', 1), inv('rug', 1)]), 'bed');
    });

    test('losing an item and regaining it counts again', () {
      final tracker = PetCollectionUnlockTracker();
      tracker.observe([inv('sofa', 1)]);

      expect(tracker.observe(const []), isNull);
      expect(tracker.observe([inv('sofa', 1)]), 'sofa');
    });

    test('reset makes the next observation a baseline again', () {
      final tracker = PetCollectionUnlockTracker();
      tracker.observe(const []);

      tracker.reset();
      expect(tracker.hasBaseline, isFalse);
      // The honest state is "I do not know what was already owned"; guessing
      // here is exactly the false celebration this class prevents.
      expect(tracker.observe([inv('sofa', 1), inv('rug', 1)]), isNull);
    });
  });

  group('the collection page celebrates a real unlock and only that', () {
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
      await container.read(petRepositoryProvider).savePet(Pet(
            id: 'pet_1',
            userId: localMvpUserId,
            characterId: 'mochi',
            species: PetSpecies.dog,
            name: '可可',
            adoptedAt: clock.now(),
          ));
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpWidget(_app(container, const PetCollectionPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    /// Gives the collection a real item and reloads, as a craft completion would.
    Future<void> unlock(WidgetTester tester, String itemId) async {
      await container
          .read(craftRepositoryProvider)
          .upsertInventoryItem(inv(itemId, 1));
      await container.read(craftControllerProvider.notifier).loadAll();
      await tester.pump();
    }

    /// Leaves the collection page, disposing its `State`.
    Future<void> leavePage(WidgetTester tester) async {
      await tester.pumpWidget(_app(container, const SizedBox()));
      await tester.pump();
    }

    PetVisualState? overrideOn(WidgetTester tester) => tester
        .widget<CompanionAvatar>(find.byType(CompanionAvatar))
        .visualStateOverride;

    testWidgets('arriving with a full collection celebrates nothing',
        (tester) async {
      // The guard. Every already-owned item is visible on the first frame, so a
      // naive "celebrate what is owned" implementation would fire here — and
      // would then fire on every single visit.
      await container.read(craftRepositoryProvider).upsertInventoryItem(
            inv('sofa', 1),
          );
      await container.read(craftRepositoryProvider).upsertInventoryItem(
            inv('rug', 2),
          );
      await container.read(craftControllerProvider.notifier).loadAll();

      await pumpPage(tester);

      final avatar =
          tester.widget<CompanionAvatar>(find.byType(CompanionAvatar));
      expect(avatar.visualStateOverride, isNull,
          reason: 'loading the page is not an unlock');
      expect(find.text('可可 的收藏屋 🌱'), findsOneWidget);
    });

    testWidgets('a real later unlock does celebrate', (tester) async {
      await pumpPage(tester);
      expect(
        tester
            .widget<CompanionAvatar>(find.byType(CompanionAvatar))
            .visualStateOverride,
        isNull,
      );

      await unlock(tester, 'bed');

      final avatar =
          tester.widget<CompanionAvatar>(find.byType(CompanionAvatar));
      expect(avatar.visualStateOverride, PetVisualState.celebrate);
    });

    testWidgets('the celebration names the item that unlocked', (tester) async {
      await pumpPage(tester);
      await unlock(tester, 'bed');

      // The name comes from the collection catalog, so the announcement cannot
      // name something the collection does not contain.
      expect(find.text('新收藏：治愈小床！'), findsOneWidget);
    });

    testWidgets('the celebration is a one-shot and clears itself',
        (tester) async {
      await pumpPage(tester);
      await unlock(tester, 'lamp');
      expect(
        tester
            .widget<CompanionAvatar>(find.byType(CompanionAvatar))
            .visualStateOverride,
        PetVisualState.celebrate,
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      final avatar =
          tester.widget<CompanionAvatar>(find.byType(CompanionAvatar));
      expect(avatar.visualStateOverride, isNull,
          reason:
              'the celebration must not become a state the page is stuck in');
      expect(find.text('可可 的收藏屋 🌱'), findsOneWidget);
    });

    testWidgets('the celebration reaches the pet, not just the parameter',
        (tester) async {
      // `PetAvatarWidget` reads the *controller* when one is supplied, so a
      // changed parameter alone would be silently ignored. This pins that the
      // override actually lands on the controller the pet draws from — the
      // parameter check alone would pass even if the state never arrived.
      await pumpPage(tester);
      await unlock(tester, 'cabinet');
      await tester.pump();

      final pet = tester.widget<PetAvatarWidget>(find.byType(PetAvatarWidget));
      expect(pet.controller, isNotNull);
      expect(pet.controller!.visualState, PetVisualState.celebrate,
          reason:
              'the pet reads the controller, so the override must be there');
    });

    testWidgets('rebuilding without a change does not re-celebrate',
        (tester) async {
      await pumpPage(tester);
      await unlock(tester, 'desk');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(
        tester
            .widget<CompanionAvatar>(find.byType(CompanionAvatar))
            .visualStateOverride,
        isNull,
      );

      // A reload with nothing new must not re-fire.
      await container.read(craftControllerProvider.notifier).loadAll();
      await tester.pump();

      expect(
        tester
            .widget<CompanionAvatar>(find.byType(CompanionAvatar))
            .visualStateOverride,
        isNull,
      );
    });

    testWidgets('an item outside the collection does not celebrate',
        (tester) async {
      // The tracker is fed collection ids only, so a craft output the collection
      // does not list cannot produce a collection celebration.
      await pumpPage(tester);

      await container
          .read(craftRepositoryProvider)
          .upsertInventoryItem(inv('not_a_collection_item', 1));
      await container.read(craftControllerProvider.notifier).loadAll();
      await tester.pump();

      expect(overrideOn(tester), isNull);
    });

    testWidgets('an unlock that happened while the page was closed celebrates',
        (tester) async {
      // The reachability test, and the reason the tracker lives in a provider.
      //
      // Inventory is written in exactly one place — the craft engine, when a job
      // completes — and that completion is driven by a focus-session settlement.
      // The collection page is therefore *never* mounted when a real unlock
      // happens. A page-scoped tracker would take a fresh baseline on every
      // visit and this assertion would be impossible to satisfy: the class would
      // be correct and unreachable at the same time.
      await pumpPage(tester);
      expect(overrideOn(tester), isNull);

      await leavePage(tester);
      await unlock(tester, 'bed');

      await pumpPage(tester);
      expect(overrideOn(tester), PetVisualState.celebrate);
      expect(find.text('新收藏：治愈小床！'), findsOneWidget);
    });

    testWidgets('returning with nothing new stays quiet', (tester) async {
      // The other half: surviving navigation must not mean re-celebrating.
      await pumpPage(tester);
      await leavePage(tester);
      await pumpPage(tester);

      expect(overrideOn(tester), isNull);
      expect(find.text('可可 的收藏屋 🌱'), findsOneWidget);
    });

    testWidgets('the first ever visit is a baseline even with items owned',
        (tester) async {
      // Re-asserted through the provider so the guard cannot be lost when the
      // tracker's lifetime changes: the app-level scope must not turn "arriving
      // with a full collection" into a celebration.
      await container.read(craftRepositoryProvider).upsertInventoryItem(
            inv('sofa', 1),
          );
      await container.read(craftRepositoryProvider).upsertInventoryItem(
            inv('bed', 1),
          );

      await pumpPage(tester);

      expect(overrideOn(tester), isNull,
          reason: 'the very first observation establishes the baseline');
      expect(find.textContaining('新收藏'), findsNothing);
    });
  });
}
