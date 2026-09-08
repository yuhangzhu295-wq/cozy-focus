import 'enums.dart';

/// The pet definition — generic, supports dog/cat/rabbit/capybara.
/// Mochi is characterId="mochi", species=PetSpecies.dog.
class Pet {
  final String id;
  final String userId;
  final String characterId; // e.g. "mochi"
  final PetSpecies species;
  final String name;
  final DateTime adoptedAt;

  const Pet({
    required this.id,
    required this.userId,
    required this.characterId,
    required this.species,
    required this.name,
    required this.adoptedAt,
  });
}

class PetProgress {
  final String id;
  final String petId;
  final int level; // 1-based
  final int experiencePoints;
  final int totalFocusMinutes;
  final int happinessScore; // 0-100
  final DateTime updatedAt;

  const PetProgress({
    required this.id,
    required this.petId,
    required this.level,
    required this.experiencePoints,
    required this.totalFocusMinutes,
    required this.happinessScore,
    required this.updatedAt,
  });
}

class PetMemory {
  final String id;
  final String petId;
  final String memoryType; // e.g. "first_focus", "level_up", "long_session"
  final String content;
  final DateTime happenedAt;

  const PetMemory({
    required this.id,
    required this.petId,
    required this.memoryType,
    required this.content,
    required this.happenedAt,
  });
}
