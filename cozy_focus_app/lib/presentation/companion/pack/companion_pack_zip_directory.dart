/// What a ZIP's central directory says, read without decompressing anything.
///
/// ## Why this exists
///
/// The archive package's `decodeBytes` and `decodeStream` both expand the whole
/// archive in memory before returning, and it exposes no way to read a ZIP's
/// directory on its own. So every entry limit in `CompanionPackArchivePolicy` —
/// the total byte cap, the per-entry cap, the expansion ratio — was applied
/// *after* the memory had already been spent. The limits bounded what was
/// written and nothing bounded what was read, which for a compression bomb is
/// the wrong way round: the bomb is small on disk and enormous in memory, and
/// the memory is spent at decode time.
///
/// A ZIP's **central directory** is a table at the end of the file that states,
/// for every entry, its compressed and uncompressed size. Reading it costs a few
/// hundred bytes of parsing and no decompression at all, which is exactly what is
/// needed to refuse a bomb before the decoder is handed it.
///
/// ## What this is not
///
/// It is **not** a replacement for the policy or the decoder, and it does not
/// extract anything. It is an additive pre-flight: it can refuse early, and it
/// cannot cause a file to be accepted that the policy would have refused. If it
/// cannot parse the directory — ZIP64, a spanned archive, a truncated tail — it
/// returns null and the reader proceeds exactly as it did before, so the worst
/// case of a bug here is the behaviour that shipped yesterday.
///
/// It also deliberately does not trust the numbers. They are a claim made by the
/// archive, used only to decide whether to spend memory on it; the entries are
/// still validated against their real bytes afterwards.
library;

/// One entry, as the central directory describes it.
class CompanionPackZipEntry {
  final String name;
  final int compressedSize;
  final int uncompressedSize;

  const CompanionPackZipEntry({
    required this.name,
    required this.compressedSize,
    required this.uncompressedSize,
  });

  /// How many times this entry claims to expand, or null when it claims to be
  /// empty on disk — a ratio against zero is not a number.
  double? get expansionRatio =>
      compressedSize <= 0 ? null : uncompressedSize / compressedSize;
}

/// A ZIP's declared contents, or nothing when the directory cannot be read.
class CompanionPackZipDirectory {
  final List<CompanionPackZipEntry> entries;

  const CompanionPackZipDirectory(this.entries);

  int get totalUncompressedBytes =>
      entries.fold(0, (sum, e) => sum + e.uncompressedSize);

  int get totalCompressedBytes =>
      entries.fold(0, (sum, e) => sum + e.compressedSize);

  /// The largest expansion any single entry claims, or null when none claims one.
  double? get worstExpansionRatio {
    double? worst;
    for (final entry in entries) {
      final ratio = entry.expansionRatio;
      if (ratio == null) continue;
      if (worst == null || ratio > worst) worst = ratio;
    }
    return worst;
  }

  /// Reads the central directory of [bytes], or null when it cannot be trusted.
  ///
  /// Null is a normal answer, not a failure: an archive whose directory this
  /// cannot parse is one the decoder will handle the way it always has.
  static CompanionPackZipDirectory? read(List<int> bytes) {
    final eocd = _findEndOfCentralDirectory(bytes);
    if (eocd == null) return null;

    final entryCount = _u16(bytes, eocd + 10);
    final directorySize = _u32(bytes, eocd + 12);
    final directoryOffset = _u32(bytes, eocd + 16);
    if (directoryOffset == null || directorySize == null) return null;
    if (directoryOffset + directorySize > bytes.length) return null;

    // ZIP64 spells these as 0xFFFF / 0xFFFFFFFF and keeps the real values in an
    // extra field this does not parse. Refusing to guess is the honest answer:
    // the reader falls back to the decoder, which handles it.
    if (entryCount == 0xFFFF ||
        directorySize == 0xFFFFFFFF ||
        directoryOffset == 0xFFFFFFFF) {
      return null;
    }

    final entries = <CompanionPackZipEntry>[];
    var cursor = directoryOffset;
    for (var i = 0; i < entryCount; i++) {
      if (cursor + 46 > bytes.length) return null;
      if (_u32(bytes, cursor) != 0x02014b50) return null;

      final compressed = _u32(bytes, cursor + 20);
      final uncompressed = _u32(bytes, cursor + 24);
      final nameLength = _u16(bytes, cursor + 28);
      final extraLength = _u16(bytes, cursor + 30);
      final commentLength = _u16(bytes, cursor + 32);
      if (compressed == null || uncompressed == null) return null;

      final nameStart = cursor + 46;
      if (nameStart + nameLength > bytes.length) return null;
      final name = String.fromCharCodes(
        bytes.sublist(nameStart, nameStart + nameLength),
      );

      entries.add(CompanionPackZipEntry(
        name: name,
        compressedSize: compressed,
        uncompressedSize: uncompressed,
      ));

      cursor = nameStart + nameLength + extraLength + commentLength;
    }

    return CompanionPackZipDirectory(entries);
  }

  /// The offset of the end-of-central-directory record, or null.
  ///
  /// Scanned backwards, because it sits at the end and may be followed by a
  /// comment of up to 65,535 bytes. The scan is bounded by that, so a file with
  /// no directory costs a fixed few kilobytes of reading and not a pass over the
  /// whole thing.
  static int? _findEndOfCentralDirectory(List<int> bytes) {
    if (bytes.length < 22) return null;
    final lowest = bytes.length - 22 - 0xFFFF;
    final from = lowest < 0 ? 0 : lowest;
    for (var at = bytes.length - 22; at >= from; at--) {
      if (_u32(bytes, at) == 0x06054b50) return at;
    }
    return null;
  }

  static int _u16(List<int> bytes, int at) =>
      (bytes[at] & 0xFF) | ((bytes[at + 1] & 0xFF) << 8);

  static int? _u32(List<int> bytes, int at) {
    if (at + 4 > bytes.length) return null;
    return ((bytes[at] & 0xFF) |
            ((bytes[at + 1] & 0xFF) << 8) |
            ((bytes[at + 2] & 0xFF) << 16) |
            ((bytes[at + 3] & 0xFF) << 24)) &
        0xFFFFFFFF;
  }
}
