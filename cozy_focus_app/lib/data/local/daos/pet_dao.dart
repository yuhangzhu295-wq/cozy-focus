import 'package:drift/drift.dart';
import '../../../domain/models/pet_models.dart' as domain;
import '../../../domain/models/enums.dart';
import '../tables/pet_tables.dart';
import '../app_database.dart' hide Pet, PetMemory;

part 'pet_dao.g.dart';

@DriftAccessor(tables: [Pets, PetProgressTable, PetMemories])
class PetDao extends DatabaseAccessor<AppDatabase> with _$PetDaoMixin {
  PetDao(super.db);

  Future<void> upsertPet(domain.Pet pet) async {
    await into(pets).insertOnConflictUpdate(
      PetsCompanion(
        id: Value(pet.id),
        userId: Value(pet.userId),
        characterId: Value(pet.characterId),
        species: Value(pet.species.name),
        name: Value(pet.name),
        adoptedAt: Value(pet.adoptedAt),
      ),
    );
  }

  Future<domain.Pet?> findPetByUser(String userId) async {
    final row = await (select(pets)..where((t) => t.userId.equals(userId)))
        .getSingleOrNull();
    return row == null ? null : _mapPet(row);
  }

  Future<void> upsertProgress(domain.PetProgress progress) async {
    await into(petProgressTable).insertOnConflictUpdate(
      PetProgressTableCompanion(
        id: Value(progress.id),
        petId: Value(progress.petId),
        level: Value(progress.level),
        experiencePoints: Value(progress.experiencePoints),
        totalFocusMinutes: Value(progress.totalFocusMinutes),
        happinessScore: Value(progress.happinessScore),
        updatedAt: Value(progress.updatedAt),
      ),
    );
  }

  Future<domain.PetProgress?> findProgress(String petId) async {
    final row = await (select(petProgressTable)
          ..where((t) => t.petId.equals(petId)))
        .getSingleOrNull();
    return row == null ? null : _mapProgress(row);
  }

  Future<void> addMemory(domain.PetMemory memory) async {
    await into(petMemories).insert(
      PetMemoriesCompanion(
        id: Value(memory.id),
        petId: Value(memory.petId),
        memoryType: Value(memory.memoryType),
        content: Value(memory.content),
        happenedAt: Value(memory.happenedAt),
      ),
    );
  }

  Future<List<domain.PetMemory>> findMemories(String petId,
      {int limit = 50}) async {
    final rows = await (select(petMemories)
          ..where((t) => t.petId.equals(petId))
          ..orderBy([(t) => OrderingTerm.desc(t.happenedAt)])
          ..limit(limit))
        .get();
    return rows.map(_mapMemory).toList();
  }

  domain.Pet _mapPet(dynamic row) => domain.Pet(
        id: row.id as String,
        userId: row.userId as String,
        characterId: row.characterId as String,
        species: PetSpecies.values
            .firstWhere((e) => e.name == (row.species as String)),
        name: row.name as String,
        adoptedAt: row.adoptedAt as DateTime,
      );

  domain.PetProgress _mapProgress(PetProgressTableData row) =>
      domain.PetProgress(
        id: row.id,
        petId: row.petId,
        level: row.level,
        experiencePoints: row.experiencePoints,
        totalFocusMinutes: row.totalFocusMinutes,
        happinessScore: row.happinessScore,
        updatedAt: row.updatedAt,
      );

  domain.PetMemory _mapMemory(dynamic row) => domain.PetMemory(
        id: row.id as String,
        petId: row.petId as String,
        memoryType: row.memoryType as String,
        content: row.content as String,
        happenedAt: row.happenedAt as DateTime,
      );
}
