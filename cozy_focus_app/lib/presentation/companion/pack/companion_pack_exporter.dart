/// Writes an installed pack back out as a `.cozy_pet`.
///
/// ## What goes in, and what deliberately does not
///
/// Only the pack's own validated files: its manifest and its frames. Not the
/// app's database, not the user's records, not tokens, not absolute paths, not
/// temporary files. A pack is the user's companion, and an export is them taking
/// it with them - it is not a backup of the app.
///
/// ## Why the ordering is fixed
///
/// The entries are sorted by name before encoding. A ZIP carries timestamps and
/// an encoder's ordering, so two exports of the same pack would otherwise differ
/// byte for byte and a re-import could not be compared to its source. Sorting does
/// not make the archive byte-identical - that is not required - but it makes the
/// *content* reproducible, which is what the round trip needs.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'companion_pack_archive_policy.dart';

/// The result of an export attempt.
class CompanionPackExportResult {
  final Uint8List? bytes;
  final String? refusal;

  const CompanionPackExportResult(this.bytes, this.refusal);

  bool get ok => bytes != null;

  @override
  String toString() => ok
      ? 'CompanionPackExportResult(${bytes!.length} bytes)'
      : 'CompanionPackExportResult(refused: $refusal)';
}

/// Packs an installed pack directory into a `.cozy_pet`.
abstract final class CompanionPackExporter {
  const CompanionPackExporter._();

  /// The extension a pack archive carries.
  static const String extension = '.cozy_pet';

  /// Encodes the pack in [packDirectory].
  ///
  /// Returns a refusal rather than throwing when the directory has no manifest,
  /// because exporting something that is not a pack is a caller mistake the UI
  /// should be able to report.
  static CompanionPackExportResult export({
    required String packDirectory,
    required String packId,
  }) {
    final root = Directory(packDirectory);
    if (!root.existsSync()) {
      return const CompanionPackExportResult(
          null, 'the pack directory does not exist');
    }

    final manifest =
        File('$packDirectory/${CompanionPackArchivePolicy.manifestName}');
    if (!manifest.existsSync()) {
      return const CompanionPackExportResult(
          null, 'the pack has no manifest, so it is not a pack');
    }

    // Everything under the pack directory, and nothing else. A file that has
    // appeared there since the install - a stray log, an editor's backup - is not
    // part of the pack and does not belong in an export.
    final files = <File>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File) continue;
      final name = _relativeName(root.path, entity.path);
      if (name == null) continue;
      if (!_isPackFile(name)) continue;
      files.add(entity);
    }

    if (files.isEmpty) {
      return const CompanionPackExportResult(
          null, 'the pack directory contains no pack files');
    }

    files.sort((a, b) => _relativeName(root.path, a.path)!
        .compareTo(_relativeName(root.path, b.path)!));

    final archive = Archive();
    for (final file in files) {
      final name = _relativeName(root.path, file.path)!;
      archive.addFile(ArchiveFile.typedData(name, file.readAsBytesSync()));
    }

    return CompanionPackExportResult(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      null,
    );
  }

  /// A pack is a manifest and its frames. Nothing else travels with it, which is
  /// the same rule the import policy applies in the other direction.
  static bool _isPackFile(String relativeName) {
    final lower = relativeName.toLowerCase();
    return CompanionPackArchivePolicy.allowedExtensions.any(lower.endsWith);
  }

  /// [path] relative to [root], with `/` separators, or null when it is outside.
  static String? _relativeName(String root, String path) {
    final prefix = '$root${Platform.pathSeparator}';
    if (!path.startsWith(prefix)) return null;
    return path
        .substring(prefix.length)
        .replaceAll(Platform.pathSeparator, '/');
  }
}
