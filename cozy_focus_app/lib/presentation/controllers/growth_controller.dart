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
