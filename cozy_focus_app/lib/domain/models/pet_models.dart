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
  final String memoryType;
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

/// The memories the companion can hold.
///
/// ## Why this is a closed set
///
/// [PetMemory.memoryType] is a `String` column, so without a definition here a
/// typo would be stored happily and read back as a distinct type — the producer
/// would write `first_focus` and the reader would look for `firstFocus` and find
/// nothing, with no error anywhere.
///
/// The set is deliberately short. A memory system that records everything
/// remembers nothing, so a type is added only when the moment it marks is
/// genuinely worth recalling — and only when the fact is already settled, so
/// recording it cannot change what happened.
abstract final class PetMemoryType {
  /// The companion's first completed focus session. "The first" needs no
  /// threshold: it is the first row in the ledger.
  static const String firstFocus = 'first_focus';

  /// The companion's level rose. The threshold is the existing level curve, not
  /// a number chosen here.
  static const String levelUp = 'level_up';

  /// Every type the application is allowed to write.
  ///
  /// Used by tests to assert that nothing invents a type outside this list.
  static const Set<String> all = {firstFocus, levelUp};
}
