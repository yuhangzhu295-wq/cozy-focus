import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/pet_models.dart';
import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/mochi_growth_page.dart';

/// The happiness card addresses the companion by its **selected** name.
///
/// ## Found by switching companions on the device
///
/// Walking the companion picker on a fresh device: `成长 → 伙伴 → 小猫 → 确定`
/// changed the page header, the pet hero and the semantics label to 小猫, and the
/// happiness card still read **「保持专注与陪伴，让小狗保持快乐满满的状态吧！」**.
/// The species word was typed into the string, so the one card whose entire
/// subject is the companion was the only one still talking about a dog.
///
/// Six other call sites already read companionDisplayNameProvider — the empty
/// state in this same file, the furniture panel, and four focus pages. This card
/// was the exception, which is why a per-card test is the right place to pin it:
/// the provider exists and works, so the only thing that can regress is someone
/// typing a species into the copy again.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  Future<void> seedPet({int happiness = 92}) async {
    final petRepo = container.read(petRepositoryProvider);
    await petRepo.savePet(Pet(
      id: 'pet_mochi_1',
      userId: 'default_user',
      characterId: 'mochi',
      species: PetSpecies.dog,
      name: 'Mochi',
      adoptedAt: DateTime(2026, 10, 1),
    ));
    await petRepo.savePetProgress(PetProgress(
      id: 'prog_mochi_1',
      petId: 'pet_mochi_1',
      level: 3,
      experiencePoints: 245,
      totalFocusMinutes: 120,
      happinessScore: happiness,
      updatedAt: DateTime(2026, 10, 1),
    ));
  }

  /// Builds the page with the selection already set, and waits for it to settle.
  ///
  /// The provider restores asynchronously *and* rebuilds when the installed packs
  /// finish loading, so a single pump is not enough — reading the copy of the card
  /// before that finishes reads the default companion instead.
  ///
  /// The wait has to sit inside runAsync. A widget test runs on the fake clock, so
  /// `await Future.delayed` never advances until something pumps, and the first
  /// version of this test hung before its first print for exactly that reason.
  Future<void> pumpWithSelection(WidgetTester tester, String selected,
      {String? displayName}) async {
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue('default_user'),
      companionSelectionStoreProvider.overrideWithValue(
          InMemoryCompanionSelectionStore(CompanionId(selected))),
      // Only set when a test wants a name the catalog does not carry, so the
      // card is proven to read the provider rather than a baked-in string.
      if (displayName != null)
        companionDisplayNameProvider.overrideWithValue(displayName),
    ]);
    addTearDown(container.dispose);

    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        if (container.read(companionSelectionProvider).value == selected) break;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    expect(container.read(companionSelectionProvider).value, selected,
        reason: 'the harness could not settle the selection on "$selected", '
            'so this test would be asserting the default companion');

    await seedPet();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.light(useMaterial3: false),
          home: const MochiGrowthPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // The card sits below the fold at the test default, and a text that is not
    // scrolled to still matches find.text — so no scroll is needed for the
    // assertion, only for the screenshot-free runs.
  }

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  testWidgets('the dog selection says the dog, as it always did',
      (tester) async {
    await pumpWithSelection(tester, 'dog');

    expect(find.text('保持专注与陪伴，让Mochi保持快乐满满的状态吧！'), findsOneWidget);
    // The word that used to be hard-coded must not come back.
    expect(find.textContaining('小狗'), findsNothing);
  });

  testWidgets('the cat selection says the cat, not a dog', (tester) async {
    // The device state that found it: the switcher ran, the page followed, and
    // this card did not.
    await pumpWithSelection(tester, 'cat');

    expect(find.text('保持专注与陪伴，让小猫保持快乐满满的状态吧！'), findsOneWidget);
    expect(find.textContaining('小狗'), findsNothing);
  });

  testWidgets('the rabbit selection says the rabbit', (tester) async {
    await pumpWithSelection(tester, 'rabbit');

    expect(find.text('保持专注与陪伴，让小兔保持快乐满满的状态吧！'), findsOneWidget);
    expect(find.textContaining('小狗'), findsNothing);
  });

  testWidgets('the copy follows the provider, not a name baked into the widget',
      (tester) async {
    // The control for the three above, and the only one that proves the card is
    // reading the provider rather than carrying a fourth hard-coded string. A
    // built-in companion passing proves *that* companion was handled; injecting a
    // name no catalog entry uses proves the text comes from wherever the rest of
    // the app gets it.
    await pumpWithSelection(tester, 'dog', displayName: '豆豆龙');

    expect(find.text('保持专注与陪伴，让豆豆龙保持快乐满满的状态吧！'), findsOneWidget);
    // And the dog's own name is not still sitting in the copy next to it.
    expect(find.textContaining('Mochi保持快乐满满'), findsNothing);
  });
}
