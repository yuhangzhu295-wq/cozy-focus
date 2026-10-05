/// What an archive is allowed to be, decided before anything is written.
///
/// ## Why this is separate from extracting
///
/// Unzipping is the only step in the import path where a mistake writes outside
/// the sandbox. So the *judgement* — is this archive safe to extract — is factored
/// out of the code that touches the disk and expressed against a plain list of
/// entries. An archive reader hands over names and sizes; this decides; the
/// extractor then only runs when the answer is yes.
///
/// That keeps the dangerous logic testable without an archive library, and it
/// means the extractor has no policy of its own to get subtly wrong.
///
/// ## The failures it exists for
///
/// A pack is a file a user obtained somewhere. The interesting cases are not
/// malformed ones — those fail on their own — but archives that are *well formed*
/// and hostile: a name that climbs out of the sandbox, a small file that expands
/// to fill the disk, a hundred thousand entries, a symlink pointing at
/// `/etc/passwd`, or the same path listed twice so the second write wins.
library;

import 'companion_pack_validator.dart';

/// One entry an archive reader found, before any of it is written.
class PackArchiveEntry {
  /// The entry's path, as the archive spells it.
  final String name;

  /// The size it will occupy once extracted.
  final int uncompressedSize;

  /// The size it occupies inside the archive, used to spot a bomb.
  final int compressedSize;

  /// Whether this is an ordinary file. A symlink, a directory or a device node
  /// is not something a pack needs.
  final bool isRegularFile;

  const PackArchiveEntry({
    required this.name,
    required this.uncompressedSize,
    required this.compressedSize,
    this.isRegularFile = true,
  });

  /// The ratio this entry expands by, or null when it cannot be computed.
  double? get expansionRatio =>
      compressedSize > 0 ? uncompressedSize / compressedSize : null;

  @override
  String toString() => 'PackArchiveEntry($name, $uncompressedSize bytes)';
}

/// The bounds an archive must fit inside.
class PackArchiveLimits {
  /// How many entries are allowed.
  final int maxEntries;

  /// The largest single extracted file.
  final int maxEntryBytes;

  /// The largest total extracted size.
  final int maxTotalBytes;

  /// The largest expansion any one entry may have.
  ///
  /// A real PNG pack compresses a few times over at most. A ratio in the
  /// hundreds is a file designed to expand, not a file that happens to compress
  /// well — and the total-size cap alone would not catch one that expands just
  /// under it.
  final double maxExpansionRatio;

  const PackArchiveLimits({
    required this.maxEntries,
    required this.maxEntryBytes,
    required this.maxTotalBytes,
    required this.maxExpansionRatio,
  });

  /// Deliberately generous for a real pack, tight for a hostile one. A full
  /// thirteen-action pack is on the order of a few hundred frames.
  static const PackArchiveLimits standard = PackArchiveLimits(
    maxEntries: 4096,
    maxEntryBytes: 8 * 1024 * 1024,
    maxTotalBytes: 128 * 1024 * 1024,
    maxExpansionRatio: 200,
  );
}

/// Decides whether an archive may be extracted.
abstract final class CompanionPackArchivePolicy {
  const CompanionPackArchivePolicy._();

  /// The only file types a companion pack contains.
  ///
  /// A pack is a manifest and PNG frames. Anything else is either a mistake or
  /// an attempt to carry something in alongside the art, and neither belongs in
  /// a pack - so the type is refused rather than ignored, because ignoring it
  /// would still mean writing it to disk.
  static const Set<String> allowedExtensions = {'.json', '.png'};

  /// The manifest's name, which must sit at the pack's root.
  static const String manifestName = 'manifest.json';

  /// Inspects [entries] and reports every reason the archive must not be
  /// extracted.
  ///
  /// Returns the same [PackValidationResult] the manifest validator returns, so
  /// an importer has one vocabulary and one place to look.
  static PackValidationResult inspect({
    required List<PackArchiveEntry> entries,
    PackArchiveLimits limits = PackArchiveLimits.standard,
  }) {
    final problems = <PackViolation>[];
    void reject(String code, String detail) =>
        problems.add(PackViolation(code, detail));

    if (entries.isEmpty) {
      reject('empty_archive', 'the archive contains no entries');
      return PackValidationResult(problems);
    }

    if (entries.length > limits.maxEntries) {
      reject(
          'too_many_entries',
          '${entries.length} entries exceeds the limit of '
              '${limits.maxEntries}');
    }

    final seen = <String>{};
    var total = 0;

    for (final entry in entries) {
      final name = entry.name;

      if (name.trim().isEmpty) {
        reject('empty_entry_name', 'an entry has no name');
        continue;
      }

      // The sandbox escape. Refused here rather than sanitised later, because a
      // path that climbs out is a statement of intent.
      final unsafe = CompanionPackValidator.unsafePathReason(name);
      if (unsafe != null) {
        reject('unsafe_entry_path', '"$name": $unsafe');
        continue;
      }

      if (!entry.isRegularFile) {
        reject('non_regular_entry',
            '"$name" is not an ordinary file; a pack needs only files');
        continue;
      }

      if (!seen.add(name)) {
        reject('duplicate_entry',
            '"$name" appears more than once, so which one wins is undefined');
      }

      if (entry.uncompressedSize < 0 || entry.compressedSize < 0) {
        reject('invalid_entry_size', '"$name" declares a negative size');
        continue;
      }

      if (entry.uncompressedSize > limits.maxEntryBytes) {
        reject(
            'entry_too_large',
            '"$name" would extract to ${entry.uncompressedSize} bytes, above '
                'the ${limits.maxEntryBytes} limit');
      }

      final ratio = entry.expansionRatio;
      if (ratio != null && ratio > limits.maxExpansionRatio) {
        reject(
            'expansion_ratio_bomb',
            '"$name" expands ${ratio.toStringAsFixed(0)}x, above the '
                '${limits.maxExpansionRatio}x limit');
      }

      total += entry.uncompressedSize;
      if (total > limits.maxTotalBytes) {
        // Reported once, because every later entry would repeat it.
        reject(
            'archive_too_large',
            'the archive would extract to more than ${limits.maxTotalBytes} '
                'bytes');
        break;
      }
    }

    // What a pack is allowed to contain.
    final manifests = <String>[];
    for (final entry in entries) {
      final name = entry.name;
      if (name.trim().isEmpty) continue; // already reported

      final lower = name.toLowerCase();
      final dot = lower.lastIndexOf('.');
      final extension = dot < 0 ? '' : lower.substring(dot);
      if (!allowedExtensions.contains(extension)) {
        reject(
            'disallowed_file_type',
            '"$name" is not one of ${allowedExtensions.join(', ')}; a pack is a '
                'manifest and PNG frames');
      }

      // At the root, by exact name. A nested `sub/manifest.json` does not match,
      // which is what makes "exactly allowed" true rather than approximate.
      if (lower == manifestName) manifests.add(name);
    }

    if (manifests.isEmpty) {
      reject('no_manifest', 'a pack must carry $manifestName at its root');
    } else if (manifests.length > 1) {
      reject(
          'duplicate_manifest',
          '$manifestName appears ${manifests.length} times, so which one is '
              'authoritative is undefined');
    }

    return PackValidationResult(problems);
  }
}
