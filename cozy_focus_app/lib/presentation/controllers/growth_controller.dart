import '../../domain/models/enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/pet_models.dart';
import '../companion/companion_selection.dart';
import '../companion/runtime/companion_id.dart';
import 'providers.dart';

/// UI State for Growth > Mochi screen
class GrowthState {
  final Pet? pet;
  final PetProgress? progress;
  final bool isLoading;
  final String? errorMessage;

  const GrowthState({
    this.pet,
    this.progress,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get hasPet => pet != null;
  bool get hasProgress => progress != null;

  GrowthState copyWith({
    Pet? pet,
    PetProgress? progress,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GrowthState(
      pet: pet ?? this.pet,
      progress: progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class GrowthController extends StateNotifier<GrowthState> {
  final Ref _ref;

  GrowthController(this._ref) : super(const GrowthState(isLoading: true)) {
    loadPetGrowth();
  }

  /// Writes the chosen companion into the adopted pet.
  ///
  /// ## The defect this exists to fix
  ///
  /// The companion picker changed only `companionSelectionProvider`, which is a
  /// display preference stored in a file. Nothing wrote the choice to the `pets`
  /// table, which is where the pet's identity, level, XP and memories live — and
  /// whose `UNIQUE(user_id)` means one adopted pet per user.
  ///
  /// So picking 小猫 gave you a cat drawn on every screen while the database still
  /// said `species=dog, name=Mochi`, and the cat showed Mochi's level and XP
  /// because that is the only pet there is. Found by walking the picker on a
  /// device and reading the table: one row, `mochi_pet_id`, and a screen that
  /// disagreed with it everywhere.
  ///
  /// The fix keeps the model the schema already states — one pet, whose progress
  /// is its own and carries across a change of companion — and makes the database
  /// agree with the screen instead of contradicting it.
  ///
  /// [species] is the profile's declared animal, which may be null; when it is,
  /// the pet keeps the species it had. Nothing infers it from the id.
  Future<void> adoptCompanion({
    required String characterId,
    required String? species,
    required String name,
  }) async {
    final petRepo = _ref.read(petRepositoryProvider);
    final userId = _ref.read(currentUserIdProvider);
    final pet = await petRepo.findPetByUser(userId);
    if (pet == null) return;

    final resolved = species == null
        ? pet.species
        : PetSpecies.values.firstWhere(
            (value) => value.name == species,
            orElse: () => pet.species,
          );

    await petRepo.savePet(Pet(
      id: pet.id,
      userId: pet.userId,
      characterId: characterId,
      species: resolved,
      name: name,
      adoptedAt: pet.adoptedAt,
    ));
    await loadPetGrowth();
  }

  /// Makes the adopted pet agree with the selected companion.
  ///
  /// The selection and the `pets` row are two records of the same fact, so every
  /// path that changes one has to change the other. The picker's confirm does it
  /// through [adoptCompanion]; the *removal* path did not, so deleting the pack
  /// the user was using left the app drawing the fallback companion while the
  /// growth and dress pages still called it by the deleted pack's name. Found on
  /// a device: **咪咪二号 的衣橱** above a picture of Mochi, after deleting 咪咪二号.
  ///
  /// Call this from a path that changed the selection *without* adopting — the
  /// removal path is the one that does.
  ///
  /// ## Why this is not called on load
  ///
  /// Reconciling on every load would repair an install that already disagrees,
  /// which is tempting, and it is wrong: `CompanionSelection` restores from its
  /// store asynchronously and reads as the *default* until it has, so a load that
  /// ran during that window would rewrite the user's companion to the default.
  /// A silent revert on a slow start is worse than the stale name this fixes.
  /// Found while writing the first version of this, which did exactly that and
  /// made the test below fail with `Mochi` where a stored `cat` was expected.
  ///
  /// A row whose id already matches is left exactly as it is, name included: the
  /// import screen lets a pack be called anything, and rewriting that name from
  /// the catalog would be the same defect pointing the other way.
  Future<void> syncWithSelection() async {
    await _reconcileIfSettled();
    await loadPetGrowth();
  }

  /// Repairs an adopted pet whose companion no longer exists.
  ///
  /// Deliberately narrower than "make the row match the selection". A pet naming a
  /// companion the app can no longer draw is a leftover: the pack it came from was
  /// deleted, the selection has already been repaired to a fallback, and the row is
  /// the only thing still pointing at it. A pet naming a companion that *does*
  /// exist is left alone, because the two can differ for a moment while a picker
  /// adopts and rewriting one from the other would fight the adoption — the wider
  /// rule did exactly that, and three tests of the confirm path caught it.
  ///
  /// The selection must also have been read: see [CompanionSelection.restored].
  /// Before that it reads as the default, and this would repair a pet to a
  /// companion the user never chose.
  ///
  /// Returns the pet as it now stands, or null when there is none.
  Future<Pet?> _reconcileIfSettled() async {
    final petRepo = _ref.read(petRepositoryProvider);
    final userId = _ref.read(currentUserIdProvider);
    final pet = await petRepo.findPetByUser(userId);
    if (pet == null) return null;

    final selection = _ref.read(companionSelectionProvider.notifier);
    if (!selection.restored) return pet;

    final known = _ref
        .read(companionCatalogProvider)
        .companionIds
        .map((id) => id.value)
        .toSet();
    if (known.contains(pet.characterId)) return pet;

    final selected = selection.selected.value;
    if (pet.characterId == selected) return pet;

    final profile =
        _ref.read(companionCatalogProvider).profileFor(CompanionId(selected));
    final agreed = Pet(
      id: pet.id,
      userId: pet.userId,
      characterId: selected,
      // The profile's declared animal, and the stored one when it declares none:
      // nothing infers a species from an id.
      species: profile.species == null
          ? pet.species
          : PetSpecies.values.firstWhere(
              (value) => value.name == profile.species,
              orElse: () => pet.species,
            ),
      name: profile.displayName,
      adoptedAt: pet.adoptedAt,
    );
    await petRepo.savePet(agreed);
    return agreed;
  }

  Future<void> loadPetGrowth() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final petRepo = _ref.read(petRepositoryProvider);

      // Also the healing path: an install left disagreeing by an earlier build
      // repairs itself the first time the pet is loaded, now that the guard above
      // makes it safe to act on the selection.
      final pet = await _reconcileIfSettled();
      PetProgress? progress;
      if (pet != null) {
        progress = await petRepo.findPetProgress(pet.id);
      }

      state = GrowthState(
        pet: pet,
        progress: progress,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}

final growthControllerProvider =
    StateNotifierProvider.autoDispose<GrowthController, GrowthState>((ref) {
  return GrowthController(ref);
});
