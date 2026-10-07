import '../../domain/models/enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/pet_models.dart';
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

  Future<void> loadPetGrowth() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final petRepo = _ref.read(petRepositoryProvider);
      final userId = _ref.read(currentUserIdProvider);

      final pet = await petRepo.findPetByUser(userId);
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
