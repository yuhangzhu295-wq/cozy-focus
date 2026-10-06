/// Reads a `.cozy_pet` archive into the files it wants written, or refuses it.
///
/// ## Where this sits
///
/// `CompanionPackArchivePolicy` decides whether an archive *may* be extracted.
/// This does the reading, and it stops one step short of the disk: it returns the
/// files it would write, so the code that touches the filesystem is a separate,
/// very small thing, and everything above it stays testable without one.
///
/// A test can build a hostile archive in memory and assert it is refused, which is
/// the property that matters and the one that is hardest to check any other way.
///
/// ## Why it does not use a convenience extractor
///
/// The brief's rule: never hand an untrusted package to an extract-all helper. The
/// decode is the only part that has to trust the reader, and everything after it —
/// path safety, entry count, sizes, symlinks, duplicates, file types, manifest
/// location — is decided by the policy before a single byte is written.
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'companion_pack_archive_policy.dart';
import 'companion_pack_validator.dart';

/// One file the archive wants written, at a path already judged safe.
class CompanionPackFile {
  /// The relative path, exactly as the archive spelled it.
  final String name;

  /// The bytes.
  final Uint8List bytes;

  const CompanionPackFile(this.name, this.bytes);

  int get length => bytes.length;

  @override
  String toString() => 'CompanionPackFile($name, ${bytes.length} bytes)';
}

/// The files to write, or the reasons there are none.
class CompanionPackReadResult {
  final List<CompanionPackFile> files;
  final PackValidationResult validation;

  const CompanionPackReadResult(this.files, this.validation);

  /// True only when the archive was refused. A valid archive with zero files
  /// cannot occur — the policy refuses an empty one — but the flag is named for
  /// the decision rather than for the list, so a reader is never misled.
  bool get ok => validation.ok;

  @override
  String toString() => ok
      ? 'CompanionPackReadResult(${files.length} files)'
      : 'CompanionPackReadResult(refused): $validation';
}

/// Decodes an archive and applies the policy to it.
abstract final class CompanionPackArchiveReader {
  const CompanionPackArchiveReader._();

  /// Reads [bytes] as a ZIP and returns what it would write, or why it will not.
  ///
  /// A decode failure is a refusal, not an exception: a truncated or malformed
  /// archive is one of the things an importer has to survive, and turning it into
  /// a violation keeps the caller's error handling in one place.
  static CompanionPackReadResult read(
    List<int> bytes, {
    PackArchiveLimits limits = PackArchiveLimits.standard,
  }) {
    // Before the decoder, not after. The policy judges entries, and entries can
    // only be judged once the archive has been decoded - so the limits below
    // bound what is written while this bounds what is read. Without it, the
    // decoder is handed an arbitrary file first and asked questions later.
    if (bytes.length > PackArchiveLimits.maxInputBytes) {
      return CompanionPackReadResult(
        const [],
        PackValidationResult([
          PackViolation(
              'input_too_large',
              'the file is ${bytes.length} bytes, above the '
                  '${PackArchiveLimits.maxInputBytes} a pack may be'),
        ]),
      );
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (error) {
      return CompanionPackReadResult(
        const [],
        PackValidationResult([
          PackViolation(
              'unreadable_archive',
              'the archive could not be read: '
                  '$error'),
        ]),
      );
    }

    // Directory entries are how some writers spell the tree; they carry no bytes
    // and are not files the pack needs. Skipped rather than refused, because a
    // pack produced by an ordinary tool would otherwise fail on a technicality.
    final entries = <PackArchiveEntry>[];
    final content = <String, Uint8List>{};
    for (final file in archive.files) {
      final name = file.name;
      if (name.endsWith('/') || name.endsWith('\\')) continue;

      final data = file.content;
      entries.add(PackArchiveEntry(
        name: name,
        uncompressedSize: data.length,
        // The reader does not expose a trustworthy compressed size, and a
        // fabricated one would make the expansion-ratio check meaningless. Zero
        // means "not known", which the policy handles by skipping the ratio and
        // still enforcing the per-entry and total byte caps.
        compressedSize: 0,
        isRegularFile: !file.isSymbolicLink,
      ));
      content[name] = data;
    }

    final verdict = CompanionPackArchivePolicy.inspect(
      entries: entries,
      limits: limits,
    );
    if (!verdict.ok) {
      return CompanionPackReadResult(const [], verdict);
    }

    return CompanionPackReadResult(
      [
        for (final entry in entries)
          CompanionPackFile(entry.name, content[entry.name]!),
      ],
      verdict,
    );
  }
}
