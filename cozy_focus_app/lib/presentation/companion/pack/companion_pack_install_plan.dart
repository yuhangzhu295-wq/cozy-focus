/// Where an installed companion pack lives, and what is recorded about it.
///
/// The last decision before the filesystem is touched. The manifest validator
/// answers "is this pack coherent" and the archive policy answers "is it safe to
/// extract"; this answers "may it be installed here, and under what name".
///
/// It is pure for the same reason those two are: the rules that refuse an install
/// are worth testing without a disk, and the code that writes files should have
/// no rules of its own.
library;

import 'companion_pack_validator.dart';

/// How a pack came to be in the app.
///
/// Recorded, never consulted by the runtime. The architecture rule is that a
/// companion's origin must not change how it behaves, so this is metadata an
/// importer keeps and the player never reads.
enum CompanionPackSource {
  builtIn('built_in'),
  localImport('local_import'),
  localCompile('local_compile'),
  cloudGenerated('cloud_generated');

  final String id;
  const CompanionPackSource(this.id);

  static CompanionPackSource? fromId(String? id) {
    for (final s in CompanionPackSource.values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// What an installer would do, once it has been allowed to.
class CompanionPackInstallPlan {
  /// The id the companion will be known by, and the directory it will occupy.
  final String packId;
  final String displayName;
  final String species;
  final CompanionPackSource source;

  /// The directory, relative to the app's private storage root.
  final String relativeDirectory;

  const CompanionPackInstallPlan({
    required this.packId,
    required this.displayName,
    required this.species,
    required this.source,
    required this.relativeDirectory,
  });
}

/// A plan, or the reasons there is not one.
class CompanionPackInstallDecision {
  final CompanionPackInstallPlan? plan;
  final PackValidationResult validation;

  const CompanionPackInstallDecision(this.plan, this.validation);

  bool get ok => plan != null && validation.ok;
}

/// Decides whether a validated pack may be installed, and where.
abstract final class CompanionPackInstallRules {
  const CompanionPackInstallRules._();

  /// The directory installed packs live under, inside app-private storage.
  static const String root = 'companion_packs';

  /// The species a companion may declare.
  static const List<String> species = ['dog', 'cat', 'rabbit'];

  /// Plans the install, or explains why not.
  static CompanionPackInstallDecision plan({
    required Map<String, dynamic> manifest,
    required String displayName,
    required String speciesId,
    required CompanionPackSource source,
    required Set<String> builtInIds,
    required Set<String> installedIds,
  }) {
    final problems = <PackViolation>[];
    void reject(String code, String detail) =>
        problems.add(PackViolation(code, detail));

    final id = manifest['companionId'];
    if (id is! String || !isSafePackId(id)) {
      reject('unsafe_pack_id',
          'companionId "$id" is not usable as a directory name');
      return CompanionPackInstallDecision(null, PackValidationResult(problems));
    }

    // A user pack may not take a built-in's identity. Two companions answering
    // to `dog` would make the persisted selection ambiguous, and the built-in is
    // the one the app promises to ship.
    if (builtInIds.contains(id)) {
      reject('pack_id_reserved',
          '"$id" is a built-in companion id, so a pack cannot claim it');
    }

    if (installedIds.contains(id)) {
      reject(
          'pack_already_installed',
          '"$id" is already installed; replace it deliberately rather than '
              'shadowing it');
    }

    if (!species.contains(speciesId)) {
      reject('unsupported_species',
          '"$speciesId" is not one of ${species.join(', ')}');
    }

    if (displayName.trim().isEmpty) {
      reject('empty_display_name', 'a companion needs a name to show');
    }

    if (problems.isNotEmpty) {
      return CompanionPackInstallDecision(null, PackValidationResult(problems));
    }

    return CompanionPackInstallDecision(
      CompanionPackInstallPlan(
        packId: id,
        displayName: displayName.trim(),
        species: speciesId,
        source: source,
        relativeDirectory: '$root/$id',
      ),
      const PackValidationResult([]),
    );
  }

  /// Whether [id] can be a directory name inside the pack root.
  ///
  /// Deliberately strict: lowercase letters, digits, dash and underscore only.
  /// An id reaches the filesystem, so anything that could mean something to a
  /// path — a separator, a dot, a space, a colon — is refused rather than
  /// escaped, and `..` cannot be spelled at all.
  static bool isSafePackId(String id) =>
      RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(id);
}
