import '../../domain/models/pet_models.dart';
import '../../domain/repositories/i_pet_repository.dart';
import '../local/daos/pet_dao.dart';

class DriftPetRepository implements IPetRepository {
  final PetDao _dao;
  DriftPetRepository(this._dao);

  @override
  Future<void> savePet(Pet pet) => _dao.upsertPet(pet);

  @override
  Future<Pet?> findPetByUser(String userId) => _dao.findPetByUser(userId);

  @override
  Future<void> savePetProgress(PetProgress progress) =>
      _dao.upsertProgress(progress);

  @override
  Future<PetProgress?> findPetProgress(String petId) =>
      _dao.findProgress(petId);

  @override
  Future<void> addMemory(PetMemory memory) => _dao.addMemory(memory);

  @override
  Future<List<PetMemory>> findMemories(String petId, {int limit = 50}) =>
      _dao.findMemories(petId, limit: limit);
}
