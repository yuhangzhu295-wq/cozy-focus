import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_archive_policy.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_archive_reader.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_zip_directory.dart';

/// P40 — refusing a compression bomb before the decoder is handed it.
///
/// ## The gap this closes
///
/// A bomb is small on disk and enormous in memory, and the memory is spent by
/// `decodeBytes`. Every entry limit in the policy therefore ran *after* the cost
/// had been paid, which for a bomb is the wrong way round.
///
/// A ZIP's central directory states each entry's uncompressed size without
/// decompressing anything, so the limits can now be applied to the claim before
/// the memory is spent. These tests prove three things: the directory is read
/// correctly, a bomb is refused, and — the one that actually matters — the
/// refusal comes from the *directory* rather than from the entries, which is what
/// distinguishes "refused before decoding" from "refused after".
void main() {
  Uint8List packBytes({required int filler, String name = 'a.png'}) {
    final archive = Archive();
    archive.addFile(ArchiveFile.typedData(
      'manifest.json',
      utf8.encode('{"companionId":"mimi"}'),
    ));
    archive.addFile(ArchiveFile.typedData(name, Uint8List(filler)));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Rewrites the central directory's declared uncompressed size for the entry
  /// named [name].
  ///
  /// This is how a bomb is *simulated* cheaply: rather than actually building
  /// something that expands to gigabytes, the directory is made to say so. It
  /// also exercises the property the reader documents — the declared sizes are
  /// treated as a claim, used only to decide whether to spend memory.
  Uint8List withDeclaredSize(Uint8List bytes, String name, int declared) {
    final copy = Uint8List.fromList(bytes);
    final nameBytes = utf8.encode(name);
    // Find the central directory entry: its signature, then the name at +46.
    for (var at = 0; at + 46 + nameBytes.length <= copy.length; at++) {
      if (copy[at] != 0x50 ||
          copy[at + 1] != 0x4B ||
          copy[at + 2] != 0x01 ||
          copy[at + 3] != 0x02) {
        continue;
      }
      var matches = true;
      for (var i = 0; i < nameBytes.length; i++) {
        if (copy[at + 46 + i] != nameBytes[i]) {
          matches = false;
          break;
        }
      }
      if (!matches) continue;
      copy[at + 24] = declared & 0xFF;
      copy[at + 25] = (declared >> 8) & 0xFF;
      copy[at + 26] = (declared >> 16) & 0xFF;
      copy[at + 27] = (declared >> 24) & 0xFF;
      return copy;
    }
    fail('no central directory entry named $name');
  }

  group('the directory is read without decompressing', () {
    test('it lists every entry with its declared sizes', () {
      final directory = CompanionPackZipDirectory.read(packBytes(filler: 64));

      expect(directory, isNotNull);
      expect(directory!.entries.map((e) => e.name),
          containsAll(['manifest.json', 'a.png']));
      // 64 zero bytes compress to almost nothing, so the ratio is large - which
      // is exactly the signal a bomb gives.
      final a = directory.entries.firstWhere((e) => e.name == 'a.png');
      expect(a.uncompressedSize, 64);
      expect(a.compressedSize, greaterThan(0));
    });

    test('an unreadable directory is null rather than a guess', () {
      // Null is a normal answer: the reader then proceeds exactly as it did
      // before, so a parsing gap here cannot make things worse.
      expect(CompanionPackZipDirectory.read(utf8.encode('not a zip')), isNull);
      expect(CompanionPackZipDirectory.read(Uint8List(4)), isNull);
    });
  });

  group('a bomb is refused before the decoder sees it', () {
    test('a declared total above the cap is refused', () {
      // The directory claims the entry expands to 500 MB. The real entry is 64
      // bytes, so this refusal can only have come from the directory.
      final bytes =
          withDeclaredSize(packBytes(filler: 64), 'a.png', 500 * 1024 * 1024);

      final result = CompanionPackArchiveReader.read(
        bytes,
        limits: const PackArchiveLimits(
          maxEntries: 4096,
          maxEntryBytes: 1024 * 1024 * 1024,
          maxTotalBytes: 128 * 1024 * 1024,
          maxExpansionRatio: 1000000,
        ),
      );

      expect(result.ok, isFalse);
      expect(result.files, isEmpty);
      // By ratio, because claiming 500 MB inside a 64-byte entry is also a
      // fantastic expansion. Either code proves the same thing: the number came
      // from the directory, since the real archive is 64 bytes and decodes fine.
      expect(result.validation.codes, contains('expansion_ratio_bomb'));

      // The discriminator that makes this a proof rather than an assertion: the
      // *same bytes* decode cleanly when the limits are permissive, so the
      // refusal above cannot have come from the entries. It came from the
      // directory, before the decoder ran.
      final permissive = CompanionPackArchiveReader.read(
        bytes,
        limits: const PackArchiveLimits(
          maxEntries: 4096,
          maxEntryBytes: 1024 * 1024 * 1024,
          maxTotalBytes: 1024 * 1024 * 1024,
          maxExpansionRatio: 1000000000,
        ),
      );
      expect(permissive.ok, isTrue,
          reason:
              'the archive itself is fine; only its declared size is a lie');
    });

    test('a declared expansion ratio above the cap is refused', () {
      // 64 bytes of zeros compress to a handful, so the honest ratio is already
      // large; a tight limit turns that into the bomb refusal.
      final result = CompanionPackArchiveReader.read(
        packBytes(filler: 4096),
        limits: const PackArchiveLimits(
          maxEntries: 4096,
          maxEntryBytes: 1024 * 1024,
          maxTotalBytes: 1024 * 1024,
          maxExpansionRatio: 2,
        ),
      );

      expect(result.ok, isFalse);
      expect(result.validation.codes, contains('expansion_ratio_bomb'),
          reason: 'the ratio rule is inert after decoding, so this is the '
              'directory speaking');
    });

    test('an ordinary pack is still read', () {
      // The guard against a pre-flight that refuses real packs. A PNG-like
      // payload with a normal ratio passes the directory check and is decoded.
      final archive = Archive();
      archive.addFile(ArchiveFile.typedData(
        'manifest.json',
        utf8.encode(jsonEncode({'companionId': 'mimi'})),
      ));
      // Incompressible content, so the ratio is about 1.
      final noise = Uint8List.fromList(
          List<int>.generate(4096, (i) => (i * 2654435761) & 0xFF));
      archive.addFile(ArchiveFile.typedData('idle_000.png', noise));

      final result = CompanionPackArchiveReader.read(
          Uint8List.fromList(ZipEncoder().encode(archive)));

      expect(result.ok, isTrue, reason: '${result.validation}');
      expect(result.files.map((f) => f.name), contains('idle_000.png'));
    });
  });
}
