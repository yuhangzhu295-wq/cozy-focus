import '../models/pet_models.dart';

abstract interface class IPetRepository {
  Future<void> savePet(Pet pet);
  Future<Pet?> findPetByUser(String userId);

  Future<void> savePetProgress(PetProgress progress);
  Future<PetProgress?> findPetProgress(String petId);

  Future<void> addMemory(PetMemory memory);
  Future<List<PetMemory>> findMemories(String petId, {int limit = 50});
}
