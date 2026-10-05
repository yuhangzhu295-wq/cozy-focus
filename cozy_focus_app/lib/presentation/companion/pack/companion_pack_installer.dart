/// Installs a validated pack onto disk, atomically.
///
/// ## The order, and why it is this order
///
/// 1. Write everything into a **staging** directory, never into the pack root.
/// 2. Read the manifest back **from the written bytes** and validate again.
/// 3. Only then move the staging directory into place, in one rename.
///
/// Step 2 is the one that is easy to skip and the one that matters. Everything
/// before this point validated a *description* of the pack; this validates what
/// actually landed on disk, which is what the runtime will read. The brief's rule
/// is not to trust ZIP filenames alone, and re-reading is how that is honoured.
///
/// Step 3 is a rename rather than a copy so the move is atomic within a
/// filesystem: a pack is either absent or complete, never half of both. A failure
/// anywhere before it leaves the pack root untouched, and the staging directory
/// is removed rather than left for a later run to trip over.
///
/// ## Why the roots are parameters
///
/// The caller supplies the staging and install roots, so a test can point both at
/// a temporary directory. Nothing here imports `path_provider` or touches
/// Flutter, which is what keeps this testable with real files and no binding.
library;

import 'dart:convert';
import 'dart:io';

import 'companion_pack_archive_reader.dart';
import 'companion_pack_install_plan.dart';
import 'companion_pack_validator.dart';
import 'installed_pack_registry.dart';

/// What an install attempt did.
enum CompanionPackInstallStatus {
  /// Written and moved into place.
  installed,

  /// Refused, and the pack root was not touched.
  refused,

  /// A different pack already occupies this id.
  conflict,

  /// The same pack is already installed.
  alreadyInstalled,
}

/// The outcome, with the reasons when it is not [CompanionPackInstallStatus.installed].
class CompanionPackInstallReport {
  final CompanionPackInstallStatus status;
  final PackValidationResult validation;

  /// The installed directory, when one exists.
  final String? installedPath;

  /// The metadata to record, when the install succeeded.
  final InstalledCompanionPack? pack;

  const CompanionPackInstallReport({
    required this.status,
    this.validation = const PackValidationResult([]),
    this.installedPath,
    this.pack,
  });

  bool get ok => status == CompanionPackInstallStatus.installed;

  @override
  String toString() => ok
      ? 'CompanionPackInstallReport(installed $installedPath)'
      : 'CompanionPackInstallReport(${status.name}): $validation';
}

/// Writes a read pack to disk and moves it into place.
abstract final class CompanionPackInstaller {
  const CompanionPackInstaller._();

  /// The manifest's name inside a pack. Kept in step with the archive policy,
  /// which is what refuses a pack whose manifest is not at its root.
  static const String manifestName = 'manifest.json';

  /// Installs [read] as [plan].
  ///
  /// [stagingRoot] and [installRoot] are created if absent. [existing] is the
  /// registry to consult for a collision; it is not mutated here, so a caller
  /// that installs and then fails to record cannot leave the two disagreeing.
  static Future<CompanionPackInstallReport> install({
    required CompanionPackReadResult read,
    required CompanionPackInstallPlan plan,
    required Directory stagingRoot,
    required Directory installRoot,
    required Set<String> installedIds,
    Map<String, String> installedChecksums = const {},
  }) async {
    if (!read.ok) {
      // Nothing was ever written, so there is nothing to clean up.
      return CompanionPackInstallReport(
        status: CompanionPackInstallStatus.refused,
        validation: read.validation,
      );
    }

    final target = Directory('${installRoot.path}/${plan.packId}');

    // ── collision, decided before a single byte is written ──────────────────
    if (installedIds.contains(plan.packId)) {
      final known = installedChecksums[plan.packId];
      final incoming = _checksumOf(read.files);
      return CompanionPackInstallReport(
        status: known == incoming
            ? CompanionPackInstallStatus.alreadyInstalled
            : CompanionPackInstallStatus.conflict,
      );
    }

    final staging = Directory(
      '${stagingRoot.path}/import_${DateTime.now().microsecondsSinceEpoch}',
    );
    await staging.create(recursive: true);

    try {
      // ── 1. write to staging ───────────────────────────────────────────────
      for (final file in read.files) {
        final destination = File('${staging.path}/${file.name}');
        await destination.parent.create(recursive: true);
        await destination.writeAsBytes(file.bytes, flush: true);
      }

      // ── 2. validate what actually landed ──────────────────────────────────
      final onDisk = await _relativePathsUnder(staging);
      final manifestFile = File('${staging.path}/$manifestName');
      if (!await manifestFile.exists()) {
        return _refused(staging, 'no_manifest_on_disk',
            '$manifestName is not present after writing');
      }

      final Map<String, dynamic> manifest;
      try {
        manifest = jsonDecode(await manifestFile.readAsString())
            as Map<String, dynamic>;
      } catch (error) {
        return _refused(staging, 'unreadable_manifest',
            'the manifest is not valid JSON: $error');
      }

      final validation = CompanionPackValidator.validate(
        manifest: manifest,
        availableFiles: onDisk,
        expectedId: plan.packId,
      );
      if (!validation.ok) return _refused(staging, null, null, validation);

      // ── 3. move into place, in one rename ─────────────────────────────────
      await installRoot.create(recursive: true);
      if (await target.exists()) {
        // Raced with another install. Refused rather than merged: a merge could
        // leave files from two packs under one id.
        await staging.delete(recursive: true);
        return const CompanionPackInstallReport(
          status: CompanionPackInstallStatus.conflict,
          validation: PackValidationResult([
            PackViolation(
                'target_appeared',
                'the pack directory appeared during the install; refused rather '
                    'than merged'),
          ]),
        );
      }
      await staging.rename(target.path);

      return CompanionPackInstallReport(
        status: CompanionPackInstallStatus.installed,
        installedPath: target.path,
        pack: InstalledCompanionPack(
          packId: plan.packId,
          displayName: plan.displayName,
          species: plan.species,
          source: plan.source.id,
          formatVersion: manifest['packFormatVersion'] is int
              ? manifest['packFormatVersion'] as int
              : 1,
          checksum: _checksumOf(read.files),
          relativeDirectory: plan.relativeDirectory,
        ),
      );
    } catch (error) {
      // A failure anywhere above leaves the pack root untouched, because nothing
      // was written to it. The staging directory is removed so a later run does
      // not trip over it.
      return _refused(staging, 'install_failed', '$error');
    }
  }

  /// Removes an installed pack's directory. Metadata removal is the caller's.
  static Future<bool> uninstall({
    required String packId,
    required Directory installRoot,
  }) async {
    final target = Directory('${installRoot.path}/$packId');
    if (!await target.exists()) return false;
    await target.delete(recursive: true);
    return true;
  }

  static Future<CompanionPackInstallReport> _refused(
    Directory staging,
    String? code,
    String? detail, [
    PackValidationResult? validation,
  ]) async {
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    return CompanionPackInstallReport(
      status: CompanionPackInstallStatus.refused,
      validation: validation ??
          PackValidationResult([
            if (code != null) PackViolation(code, detail ?? code),
          ]),
    );
  }

  /// Every file under [root], as paths relative to it, with `/` separators.
  static Future<Set<String>> _relativePathsUnder(Directory root) async {
    final prefix = '${root.path}${Platform.pathSeparator}';
    final result = <String>{};
    await for (final entity in root.list(recursive: true)) {
      if (entity is! File) continue;
      result.add(entity.path
          .substring(prefix.length)
          .replaceAll(Platform.pathSeparator, '/'));
    }
    return result;
  }

  /// A digest over the pack's contents.
  ///
  /// Over the *contents*, not the archive: the same pack zipped twice produces
  /// different bytes, so hashing the archive would make a re-import look like a
  /// different pack and turn an idempotent install into a conflict.
  static String _checksumOf(List<CompanionPackFile> files) {
    // Over the names *and the bytes*. An earlier version hashed only
    // `name:length`, which meant two packs whose frames differed but happened to
    // be the same size hashed alike - so a genuinely different pack would have
    // been accepted as the same one and the user's install silently ignored. The
    // test that installs a different pack under an existing id caught it.
    final sorted = [...files]..sort((a, b) => a.name.compareTo(b.name));
    var hash = 0x811c9dc5;
    void mix(int unit) => hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    for (final file in sorted) {
      for (final unit in utf8.encode(file.name)) {
        mix(unit);
      }
      for (final byte in file.bytes) {
        mix(byte);
      }
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
