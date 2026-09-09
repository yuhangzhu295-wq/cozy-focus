import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/pet_models.dart';
import '../../domain/models/enums.dart';
import 'providers.dart';
import '../../core/auth/current_user.dart';

/// State for the Home screen (01)
class HomeUIState {
  final int todayFocusSeconds;
  final int sessionCountToday;
  final Pet? pet;
  final PetProgress? petProgress;
  final bool hasActiveSession;
  final bool isLoading;

  const HomeUIState({
    this.todayFocusSeconds = 0,
    this.sessionCountToday = 0,
    this.pet,
    this.petProgress,
    this.hasActiveSession = false,
    this.isLoading = false,
  });

  int get todayMinutes => (todayFocusSeconds / 60).floor();

  HomeUIState copyWith({
    int? todayFocusSeconds,
    int? sessionCountToday,
    Pet? pet,
    PetProgress? petProgress,
    bool? hasActiveSession,
    bool? isLoading,
  }) {
    return HomeUIState(
      todayFocusSeconds: todayFocusSeconds ?? this.todayFocusSeconds,
      sessionCountToday: sessionCountToday ?? this.sessionCountToday,
      pet: pet ?? this.pet,
      petProgress: petProgress ?? this.petProgress,
      hasActiveSession: hasActiveSession ?? this.hasActiveSession,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HomeController extends StateNotifier<HomeUIState> {
  final Ref _ref;
  static String get defaultUserId => localMvpUserId;

  HomeController(this._ref) : super(const HomeUIState()) {
    loadHomeData();
  }

  Future<void> loadHomeData() async {
    state = state.copyWith(isLoading: true);

    final recordRepo = _ref.read(focusRecordRepositoryProvider);
    final petRepo = _ref.read(petRepositoryProvider);
    final sessionRepo = _ref.read(focusSessionRepositoryProvider);

    final clock = _ref.read(focusClockProvider);
    final now = clock.now();
    final todaySec = await recordRepo.totalSecondsForDay(defaultUserId, now);

    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final todayRecords = await recordRepo.findByDateRange(
      defaultUserId,
      from: dayStart,
      to: dayEnd,
    );

    // Check or initialize default Mochi dog
    var pet = await petRepo.findPetByUser(defaultUserId);
    if (pet == null) {
      pet = Pet(
        id: 'mochi_pet_id',
        userId: defaultUserId,
        species: PetSpecies.dog,
        characterId: 'mochi',
        name: 'Mochi',
        adoptedAt: now,
      );
      await petRepo.savePet(pet);
    }

    var progress = await petRepo.findPetProgress(pet.id);
    if (progress == null) {
      progress = PetProgress(
        id: 'mochi_progress_id',
        petId: pet.id,
        level: 1,
        experiencePoints: 0,
        totalFocusMinutes: 0,
        happinessScore: 100,
        updatedAt: now,
      );
      await petRepo.savePetProgress(progress);
    }

    final activeSessions = await sessionRepo.findActive(defaultUserId);

    state = state.copyWith(
      todayFocusSeconds: todaySec,
      sessionCountToday: todayRecords.length,
      pet: pet,
      petProgress: progress,
      hasActiveSession: activeSessions.isNotEmpty,
      isLoading: false,
    );
  }
}

final homeControllerProvider =
    StateNotifierProvider<HomeController, HomeUIState>((ref) {
  return HomeController(ref);
});
