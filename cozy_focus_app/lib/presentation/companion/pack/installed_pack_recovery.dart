/// What is actually installed, decided from the disk rather than from memory.
///
/// ## Why a cold start needs its own answer
///
/// The registry is rebuilt from nothing on every launch, so "what is installed"
/// has to be re-derived. Two sources disagree in useful ways and neither is
/// enough alone:
///
/// - **The install records** know the things only the user could say — the name
///   they typed, the species they chose, and how the pack arrived. None of that
///   is in the pack, by design: the format leaves the name and species optional
///   because a shipped pack gets them from the app's own profile table.
/// - **The directories** are the truth about what is really there. A record
///   whose pack has been deleted is a record for nothing, and a directory the
///   records have never heard of is a pack someone put there.
///
/// So the records are the starting point and the directories are the check:
/// every record is kept only if its pack is still on disk, and every directory
/// the records miss is read from its own manifest. That way a hand-copied pack
/// still appears, and a deleted one still disappears.
library;

import 'dart:convert';
import 'dart:io';

import 'companion_pack_install_plan.dart';
import 'companion_pack_installer.dart';
import 'companion_pack_archive_reader.dart';
import 'installed_pack_record_store.dart';
import 'installed_pack_registry.dart';

/// The result of looking at a pack root.
class InstalledPackRecoveryResult {
  final List<InstalledCompanionPack> packs;

  /// Records whose pack directory was gone. Dropped, and reported so the caller
  /// can rewrite the records rather than leaving them to be re-checked forever.
  final List<String> droppedRecordIds;

  /// Directories that looked like packs but could not be described, with why.
  ///
  /// Reported rather than silently ignored: a pack the user copied in by hand and
  /// that the app will not offer is exactly the case where silence is the worst
  /// answer.
  final Map<String, String> unreadableDirectories;

  const InstalledPackRecoveryResult({
    required this.packs,
    this.droppedRecordIds = const [],
    this.unreadableDirectories = const {},
  });

  bool get needsRewrite => droppedRecordIds.isNotEmpty;

  @override
  String toString() => 'InstalledPackRecoveryResult(${packs.length} packs, '
      '${droppedRecordIds.length} dropped, '
      '${unreadableDirectories.length} unreadable)';
}

/// Rebuilds the installed set from a pack root.
abstract final class InstalledPackRecovery {
  const InstalledPackRecovery._();

  static const String manifestName = CompanionPackInstaller.manifestName;

  /// The packs under [packRoot].
  ///
  /// Synchronous on purpose: it runs once at startup, before the first frame
  /// that reads the catalog, and making it asynchronous would only add a window
  /// in which the app offers fewer companions than it has.
  static InstalledPackRecoveryResult scan(Directory packRoot) {
    if (!packRoot.existsSync()) {
      return const InstalledPackRecoveryResult(packs: []);
    }

    final recorded = {
      for (final record in InstalledPackRecordStore.read(packRoot))
        record.packId: record,
    };

    final packs = <InstalledCompanionPack>[];
    final dropped = <String>[];
    final unreadable = <String, String>{};

    // ── the directories are the truth about what is there ────────────────────
    for (final entity in packRoot.listSync()) {
      if (entity is! Directory) continue; // the record file lives here too
      final packId = entity.path.split(Platform.pathSeparator).last;

      // A directory whose name is not a usable pack id was not installed by this
      // app, and its name would reach the filesystem as a path segment.
      if (!CompanionPackInstallRules.isSafePackId(packId)) {
        unreadable[packId] = 'the directory name is not a usable pack id';
        continue;
      }

      final manifest = _readManifest(entity);
      if (manifest == null) {
        unreadable[packId] = 'no readable $manifestName';
        continue;
      }

      // A directory whose manifest names a different companion is two answers to
      // one question, and offering it would register one id while rendering
      // another.
      final declaredId = manifest['companionId'];
      if (declaredId != packId) {
        unreadable[packId] =
            'the manifest says "$declaredId", which is not this directory';
        continue;
      }

      final record = recorded[packId];
      final species = record?.species ?? _declaredSpecies(manifest);
      if (species == null) {
        // Neither the record nor the pack says what animal this is, and nothing
        // may infer it from the id. Skipped rather than guessed: a companion
        // whose species is invented would move like something it is not.
        unreadable[packId] = 'no record and the pack declares no species';
        continue;
      }

      packs.add(InstalledCompanionPack(
        packId: packId,
        displayName: record?.displayName ?? _declaredName(manifest) ?? packId,
        species: species,
        // A recovered pack's origin is not knowable: the source is install
        // metadata and nothing reads it, so it is not worth a second store that
        // could drift. Recorded honestly as unknown rather than assumed to be an
        // import.
        source: record?.source ?? 'unknown',
        formatVersion:
            record?.formatVersion ?? _declaredFormatVersion(manifest),
        checksum: record?.checksum ?? _checksumOf(entity),
        relativeDirectory: '${CompanionPackInstallRules.root}/$packId',
      ));
    }

    // ── a record for a pack that is gone is a record for nothing ─────────────
    final present = {for (final pack in packs) pack.packId};
    for (final id in recorded.keys) {
      if (!present.contains(id)) dropped.add(id);
    }

    packs.sort((a, b) => a.packId.compareTo(b.packId));
    return InstalledPackRecoveryResult(
      packs: packs,
      droppedRecordIds: dropped..sort(),
      unreadableDirectories: unreadable,
    );
  }

  static Map<String, dynamic>? _readManifest(Directory packDirectory) {
    try {
      final file = File('${packDirectory.path}/$manifestName');
      if (!file.existsSync()) return null;
      final decoded = jsonDecode(file.readAsStringSync());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static String? _declaredName(Map<String, dynamic> manifest) {
    final name = manifest['displayName'];
    return name is String && name.trim().isNotEmpty ? name.trim() : null;
  }

  static String? _declaredSpecies(Map<String, dynamic> manifest) {
    final species = manifest['species'];
    if (species is! String) return null;
    return CompanionPackInstallRules.species.contains(species) ? species : null;
  }

  static int _declaredFormatVersion(Map<String, dynamic> manifest) {
    final version = manifest['packFormatVersion'];
    return version is int ? version : 1;
  }

  /// The digest of a pack that has no record, computed from its files.
  ///
  /// Only for the hand-copied case. A recorded pack keeps the checksum taken at
  /// install time, so a normal start reads one small JSON file and no frames.
  static String _checksumOf(Directory packDirectory) {
    final files = <CompanionPackFile>[];
    final prefix = '${packDirectory.path}${Platform.pathSeparator}';
    for (final entity in packDirectory.listSync(recursive: true)) {
      if (entity is! File) continue;
      final name = entity.path
          .substring(prefix.length)
          .replaceAll(Platform.pathSeparator, '/');
      files.add(CompanionPackFile(name, entity.readAsBytesSync()));
    }
    return CompanionPackInstaller.checksumOf(files);
  }
}
