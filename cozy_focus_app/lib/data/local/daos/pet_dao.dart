import 'package:drift/drift.dart';
import '../../../domain/models/pet_models.dart';
import '../../../domain/models/enums.dart';
import '../tables/pet_tables.dart';
import '../app_database.dart';

part 'pet_dao.g.dart';

@DriftAccessor(tables: [Pets, PetProgressTable, PetMemories])
class PetDao extends DatabaseAccessor<AppDatabase> with _$PetDaoMixin {
  PetDao(super.db);

  Future<void> upsertPet(Pet pet) async {
    await into(pets).insertOnConflictUpdate(
      PetsCompanion.insert(
        id: pet.id,
        userId: pet.userId,
        characterId: pet.characterId,
        species: pet.species.name,
        name: pet.name,
        adoptedAt: pet.adoptedAt,
      ),
    );
  }

  Future<Pet?> findPetByUser(String userId) async {
    final row = await (select(pets)..where((t) => t.userId.equals(userId)))
        .getSingleOrNull();
    return row == null ? null : _mapPet(row);
  }

  Future<void> upsertProgress(PetProgress progress) async {
    await into(petProgressTable).insertOnConflictUpdate(
      PetProgressTableCompanion.insert(
        id: progress.id,
        petId: progress.petId,
        level: Value(progress.level),
        experiencePoints: Value(progress.experiencePoints),
        totalFocusMinutes: Value(progress.totalFocusMinutes),
        happinessScore: Value(progress.happinessScore),
        updatedAt: progress.updatedAt,
      ),
    );
  }

  Future<PetProgress?> findProgress(String petId) async {
    final row = await (select(petProgressTable)
          ..where((t) => t.petId.equals(petId)))
        .getSingleOrNull();
    return row == null ? null : _mapProgress(row);
  }

  Future<void> addMemory(PetMemory memory) async {
    await into(petMemories).insert(
      PetMemoriesCompanion.insert(
        id: memory.id,
        petId: memory.petId,
        memoryType: memory.memoryType,
        content: memory.content,
        happenedAt: memory.happenedAt,
      ),
    );
  }

  Future<List<PetMemory>> findMemories(String petId, {int limit = 50}) async {
    final rows = await (select(petMemories)
          ..where((t) => t.petId.equals(petId))
          ..orderBy([(t) => OrderingTerm.desc(t.happenedAt)])
          ..limit(limit))
        .get();
    return rows.map(_mapMemory).toList();
  }

  Pet _mapPet(PetsData row) => Pet(
        id: row.id,
        userId: row.userId,
        characterId: row.characterId,
        species: PetSpecies.values.firstWhere((e) => e.name == row.species),
        name: row.name,
        adoptedAt: row.adoptedAt,
      );

  PetProgress _mapProgress(PetProgressTableData row) => PetProgress(
        id: row.id,
        petId: row.petId,
        level: row.level,
        experiencePoints: row.experiencePoints,
        totalFocusMinutes: row.totalFocusMinutes,
        happinessScore: row.happinessScore,
        updatedAt: row.updatedAt,
      );

  PetMemory _mapMemory(PetMemoriesData row) => PetMemory(
        id: row.id,
        petId: row.petId,
        memoryType: row.memoryType,
        content: row.content,
        happenedAt: row.happenedAt,
      );
}
