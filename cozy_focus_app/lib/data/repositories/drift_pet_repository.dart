import '../../domain/models/pet_models.dart' as domain;
import '../../domain/repositories/i_pet_repository.dart';
import '../local/daos/pet_dao.dart';

class DriftPetRepository implements IPetRepository {
  final PetDao _dao;
  DriftPetRepository(this._dao);

  @override
  Future<void> savePet(domain.Pet pet) => _dao.upsertPet(pet);

  @override
  Future<domain.Pet?> findPetByUser(String userId) => _dao.findPetByUser(userId);

  @override
  Future<void> savePetProgress(domain.PetProgress progress) =>
      _dao.upsertProgress(progress);

  @override
  Future<domain.PetProgress?> findPetProgress(String petId) =>
      _dao.findProgress(petId);

  @override
  Future<void> addMemory(domain.PetMemory memory) => _dao.addMemory(memory);

  @override
  Future<List<domain.PetMemory>> findMemories(String petId, {int limit = 50}) =>
      _dao.findMemories(petId, limit: limit);
}
