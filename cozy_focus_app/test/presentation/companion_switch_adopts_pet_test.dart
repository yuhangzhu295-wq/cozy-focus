import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide
        Task,
        TaskSubtask,
        TaskSchedule,
        FocusSession,
        FocusRecord,
        RestSession,
        Pet,
        PetMemory;
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/pet_models.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/growth_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';

/// The companion picker changed the label and nothing else.
///
/// ## Found by walking the picker on a device and then reading the table
///
/// Picking 小猫 changed `companionSelectionProvider` — a display preference kept
/// in a file — and the screen updated everywhere, which looks like success. The
/// `pets` table said something else: one row, `mochi_pet_id`, `species=dog`,
/// `name=Mochi`. Its `UNIQUE(user_id)` means one adopted pet per user, and
/// `pet_progress` hangs off that row, so the cat displayed Mochi's level and XP
/// because Mochi was still the only pet there was.
///
/// Confirming was `context.pop()` and nothing else.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  const userId = 'default_user';
  const petId = 'mochi_pet_id';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(_FixedClock()),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> seedAdoptedPet() async {
    final repo = container.read(petRepositoryProvider);
    await repo.savePet(Pet(
      id: petId,
      userId: userId,
      characterId: 'mochi',
      species: PetSpecies.dog,
      name: 'Mochi',
      adoptedAt: DateTime(2026, 10, 1),
    ));
    await repo.savePetProgress(PetProgress(
      id: 'progress_$petId',
      petId: petId,
      level: 3,
      experiencePoints: 240,
      totalFocusMinutes: 90,
      happinessScore: 80,
      updatedAt: DateTime(2026, 10, 6),
    ));
  }

  test('confirming a companion rewrites the adopted pet', () async {
    await seedAdoptedPet();

    await container.read(growthControllerProvider.notifier).adoptCompanion(
          characterId: 'cat',
          species: 'cat',
          name: '小猫',
        );

    final pet =
        await container.read(petRepositoryProvider).findPetByUser(userId);
    expect(pet, isNotNull);
    expect(pet!.characterId, 'cat');
    expect(pet.species, PetSpecies.cat);
    expect(pet.name, '小猫');
    expect(pet.id, petId,
        reason:
            'one pet per user, so the row is updated rather than duplicated');
  });

  test('and the progress stays with the pet, not with the companion', () async {
    await seedAdoptedPet();

    await container.read(growthControllerProvider.notifier).adoptCompanion(
          characterId: 'cat',
          species: 'cat',
          name: '小猫',
        );

    // The schema says one pet per user and `pet_progress` belongs to that pet, so
    // a change of companion is a change of form for the pet you have raised. That
    // is a model choice the schema already made; what was wrong was the screen and
    // the table disagreeing about it.
    final progress =
        await container.read(petRepositoryProvider).findPetProgress(petId);
    expect(progress!.experiencePoints, 240);
    expect(progress.level, 3);
  });

  test('the growth state the screens read shows the new identity', () async {
    await seedAdoptedPet();

    await container.read(growthControllerProvider.notifier).adoptCompanion(
          characterId: 'rabbit',
          species: 'rabbit',
          name: '小兔',
        );

    final state = container.read(growthControllerProvider);
    expect(state.pet!.name, '小兔');
    expect(state.pet!.species, PetSpecies.rabbit);
    expect(state.progress!.experiencePoints, 240,
        reason: 'the numbers follow the pet, and the pet is still yours');
  });

  test('a profile that declares no species keeps the pet\'s own', () async {
    await seedAdoptedPet();

    // `CompanionProfile.species` is nullable on purpose and nothing may infer it
    // from the id, so a profile without one must not overwrite what is stored.
    //
    // The id is one the catalog knows, because the growth controller repairs a pet
    // whose companion *no longer exists* — a leftover from a deleted pack — and an
    // id nothing declares reads as exactly that. What this test is about is the
    // null argument, so it stays out of that path.
    await container.read(growthControllerProvider.notifier).adoptCompanion(
          characterId: 'rabbit',
          species: null,
          name: '自定义伙伴',
        );

    final pet =
        await container.read(petRepositoryProvider).findPetByUser(userId);
    expect(pet!.species, PetSpecies.dog,
        reason: 'the stored species is kept rather than guessed at');
    expect(pet.characterId, 'rabbit');
    expect(pet.name, '自定义伙伴');
  });

  test('with no adopted pet there is nothing to rewrite and nothing breaks',
      () async {
    // A first launch before the pet is created. Confirming must not throw.
    await container.read(growthControllerProvider.notifier).adoptCompanion(
          characterId: 'cat',
          species: 'cat',
          name: '小猫',
        );

    expect(await container.read(petRepositoryProvider).findPetByUser(userId),
        isNull);
  });
}

class _FixedClock implements FocusClock {
  @override
  DateTime now() => DateTime(2026, 10, 7, 12);
}
