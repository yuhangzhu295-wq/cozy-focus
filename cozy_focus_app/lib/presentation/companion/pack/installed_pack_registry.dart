/// The one place that knows which companion packs a user has installed.
///
/// ## Why a registry rather than a database table
///
/// The brief is explicit: the files and their validated manifest are the asset
/// truth, and the sprite manifest should not be copied into a database unless
/// required. So this holds *metadata about* installed packs — where each one
/// lives, what version it is, what it hashes to — and never the pack's contents.
/// A reader that wants an action list reads the manifest on disk.
///
/// ## Why the revision counter
///
/// Installing or deleting a pack has to become visible to the catalog, the visual
/// registry, the availability resolver and the selection list. The alternative to
/// a single signal is each of those being invalidated by hand from the page that
/// performed the import, which is how a stale cache bug is born. One counter,
/// bumped on every mutation, is something consumers can watch.
///
/// Plain Dart on purpose: no Riverpod, no Flutter. That keeps the rules testable
/// without a container, and leaves the wiring to the runtime phase.
library;

/// What is recorded about one installed pack.
///
/// Metadata only. The manifest on disk is the authority for what the pack
/// contains; this is what the app needs in order to *find* it and to tell one
/// version from another.
class InstalledCompanionPack {
  /// The id the companion is known by, and the name of its directory.
  final String packId;

  final String displayName;
  final String species;

  /// How it arrived. Recorded, never consulted by the runtime.
  final String source;

  /// The pack format version the manifest declared.
  final int formatVersion;

  /// A digest over the pack's contents, used to tell a re-import from an update.
  final String checksum;

  /// The directory, relative to the app's private storage root.
  final String relativeDirectory;

  const InstalledCompanionPack({
    required this.packId,
    required this.displayName,
    required this.species,
    required this.source,
    required this.formatVersion,
    required this.checksum,
    required this.relativeDirectory,
  });

  @override
  String toString() =>
      'InstalledCompanionPack($packId, $species, v$formatVersion)';
}

/// The outcome of trying to install over an existing id.
enum PackInstallOutcome {
  /// Nothing was there.
  installed,

  /// The same pack is already installed. Not an error, and not a write.
  alreadyInstalled,

  /// A different pack is installed under this id. Refused: overwriting silently
  /// would destroy something the user chose to keep.
  conflict,
}

/// Which companion should be selected once a pack has been removed.
enum SelectionRepair {
  /// The selection was not the removed pack; leave it alone.
  unchanged,

  /// The selection pointed at the removed pack; it now points at [SelectionRepairResult.selected].
  switched,

  /// The selection pointed at the removed pack and there is nothing valid left
  /// to switch to. The caller must treat this as "no companion selected" rather
  /// than keeping a dangling id.
  cleared,
}

/// The result of repairing a selection.
class SelectionRepairResult {
  final SelectionRepair action;
  final String? selected;

  const SelectionRepairResult(this.action, this.selected);
}

/// The installed companion packs, and the rules for changing them.
class InstalledPackRegistry {
  final Map<String, InstalledCompanionPack> _packs = {};

  /// Bumped on every mutation. Consumers watch this to know their view is stale.
  int _revision = 0;

  int get revision => _revision;

  List<InstalledCompanionPack> get packs => List.unmodifiable(_packs.values);

  Set<String> get packIds => _packs.keys.toSet();

  bool contains(String packId) => _packs.containsKey(packId);

  InstalledCompanionPack? operator [](String packId) => _packs[packId];

  /// Installs [pack], or explains why it will not.
  ///
  /// Installing over an id that holds a *different* pack is refused rather than
  /// overwritten. The brief's rule is that an installed pack is never silently
  /// replaced: same id and same checksum is a no-op, same id and different
  /// content is a conflict the user has to resolve deliberately.
  PackInstallOutcome install(InstalledCompanionPack pack) {
    final existing = _packs[pack.packId];
    if (existing != null) {
      if (existing.checksum == pack.checksum) {
        return PackInstallOutcome.alreadyInstalled;
      }
      return PackInstallOutcome.conflict;
    }
    _packs[pack.packId] = pack;
    _revision++;
    return PackInstallOutcome.installed;
  }

  /// Removes [packId]. Returns true when something was removed.
  ///
  /// The caller removes the files; this only forgets the metadata, so a failure
  /// to delete from disk cannot leave the registry claiming a pack that is gone.
  bool remove(String packId) {
    if (_packs.remove(packId) == null) return false;
    _revision++;
    return true;
  }

  /// Forgets [packId] without bumping the revision.
  ///
  /// For the one caller that has already told its consumers something changed:
  /// the import path, which reports a single change per import rather than one
  /// per step. Kept separate from [remove] so the ordinary case cannot forget to
  /// notify.
  bool removeSilently(String packId) => _packs.remove(packId) != null;
}

/// Repairs a companion selection after a pack is removed.
///
/// The rule the brief states: deleting the selected companion must first switch
/// to a valid fallback, so `selectedCompanionId` is never left dangling.
abstract final class CompanionSelectionRepair {
  const CompanionSelectionRepair._();

  /// What [selected] should become now that [removedId] is gone.
  ///
  /// [builtInIds] are always available, so a fallback exists as long as the app
  /// ships one — which is why [defaultId] is a parameter rather than a guess.
  static SelectionRepairResult afterRemoval({
    required String? selected,
    required String removedId,
    required Set<String> installedIds,
    required Set<String> builtInIds,
    required String defaultId,
  }) {
    if (selected != removedId) {
      return SelectionRepairResult(SelectionRepair.unchanged, selected);
    }

    // Prefer another installed pack, then a built-in, then the default. A
    // remaining installed pack is the closest thing to what the user had.
    // Exclude the removed id: the caller may hand over the set it had *before*
    // the removal, and picking the pack that is gone would leave the selection
    // dangling in exactly the case this function exists to prevent.
    final remainingInstalled =
        installedIds.where((id) => id != removedId).toList()..sort();
    if (remainingInstalled.isNotEmpty) {
      return SelectionRepairResult(
          SelectionRepair.switched, remainingInstalled.first);
    }

    final remainingBuiltIn = builtInIds.toList()..sort();
    if (remainingBuiltIn.contains(defaultId)) {
      return SelectionRepairResult(SelectionRepair.switched, defaultId);
    }
    if (remainingBuiltIn.isNotEmpty) {
      return SelectionRepairResult(
          SelectionRepair.switched, remainingBuiltIn.first);
    }

    // Nothing left. Better to have no companion than a dangling id that every
    // consumer would then have to defend against.
    return const SelectionRepairResult(SelectionRepair.cleared, null);
  }
}
