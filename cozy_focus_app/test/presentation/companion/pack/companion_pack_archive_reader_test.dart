import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_archive_policy.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_archive_reader.dart';

/// P32 — reading a `.cozy_pet` without trusting it.
///
/// Every archive here is built for real, so the decode path is exercised rather
/// than mocked. The hostile ones are valid ZIPs: a reader lists them happily,
/// which is exactly why the policy has to be the thing that refuses them.
///
/// Two rules are covered by the policy test instead of here, and the reason is
/// recorded in each case rather than left as a silent gap: this encoder cannot
/// produce the input.
void main() {
  Uint8List zip(List<ArchiveFile> files) {
    final archive = Archive();
    for (final f in files) {
      archive.addFile(f);
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  ArchiveFile entry(String name, [List<int>? bytes]) => ArchiveFile.typedData(
        name,
        Uint8List.fromList(bytes ?? utf8.encode('x')),
      );

  final manifest =
      Uint8List.fromList(utf8.encode(jsonEncode({'companionId': 'mimi'})));

  ArchiveFile manifestEntry() =>
      ArchiveFile.typedData('manifest.json', manifest);

  CompanionPackReadResult read(List<ArchiveFile> files) =>
      CompanionPackArchiveReader.read(zip(files));

  test('refuses a file larger than a pack may be, before decoding it', () {
    // The limit that is applied *before* the decoder, which is the only place
    // a limit can bound what is read rather than what is written. The policy's
    // entry limits can only run once the archive has been decoded, so without
    // this the decoder is handed an arbitrary file first and asked questions
    // afterwards.
    final oversized = List<int>.filled(PackArchiveLimits.maxInputBytes + 1, 0);
    final result = CompanionPackArchiveReader.read(oversized);

    expect(result.ok, isFalse);
    expect(result.files, isEmpty,
        reason: 'a refusal must never hand a caller files to write');
    expect(result.validation.codes, contains('input_too_large'));
  });

  test('a file at the limit is still decoded', () {
    // The guard against a bound that refuses the thing it exists to allow. A
    // buffer of the maximum size that is not a ZIP is refused for *that*
    // reason, not for its size.
    final atLimit = List<int>.filled(PackArchiveLimits.maxInputBytes, 0);
    final result = CompanionPackArchiveReader.read(atLimit);

    expect(result.validation.codes, isNot(contains('input_too_large')));
  });

  test('a well-formed pack reads back its files and their bytes', () {
    final result = read([
      manifestEntry(),
      entry('idle_000.png', [1, 2, 3]),
      entry('idle_001.png', [4, 5, 6]),
    ]);

    expect(result.ok, isTrue, reason: '$result');
    expect(result.files.map((f) => f.name),
        containsAll(['manifest.json', 'idle_000.png', 'idle_001.png']));
    final png = result.files.firstWhere((f) => f.name == 'idle_000.png');
    expect(png.bytes, [1, 2, 3],
        reason: 'the reader must hand over the bytes it read, not a summary');
  });

  group('refusals, each decided before anything could be written', () {
    test('a directory escape is refused', () {
      expect(
        read([manifestEntry(), entry('../escape.png')]).validation.codes,
        contains('unsafe_entry_path'),
      );
    });

    test('an absolute path is refused', () {
      expect(
        read([manifestEntry(), entry('/absolute.png')]).validation.codes,
        contains('unsafe_entry_path'),
      );
    });

    test('a pack with no manifest is refused', () {
      expect(
          read([entry('idle_000.png'), entry('idle_001.png')]).validation.codes,
          contains('no_manifest'));
    });

    test('a file type a pack has no use for is refused', () {
      expect(read([manifestEntry(), entry('payload.exe')]).validation.codes,
          contains('disallowed_file_type'));
    });

    test('an entry count over the limit is refused', () {
      final many = [
        manifestEntry(),
        for (var i = 0; i < 40; i++) entry('f_$i.png'),
      ];
      const tight = PackArchiveLimits(
        maxEntries: 8,
        maxEntryBytes: 1 << 20,
        maxTotalBytes: 1 << 30,
        maxExpansionRatio: 200,
      );
      final result = CompanionPackArchiveReader.read(zip(many), limits: tight);
      expect(result.validation.codes, contains('too_many_entries'));
    });

    test('a single oversized entry is refused', () {
      const tight = PackArchiveLimits(
        maxEntries: 64,
        maxEntryBytes: 1024,
        maxTotalBytes: 1 << 30,
        maxExpansionRatio: 200,
      );
      final result = CompanionPackArchiveReader.read(
        zip([manifestEntry(), entry('big.png', List<int>.filled(4096, 1))]),
        limits: tight,
      );
      expect(result.validation.codes, contains('entry_too_large'));
    });
  });

  group('two rules this encoder cannot produce an input for', () {
    /// A real ZIP whose `idle_000.png` entry is a Unix symlink.
    ///
    /// `ZipEncoder` always writes an MS-DOS creator and never carries
    /// `symbolicLink` through encode/decode, so the entry is built by hand:
    /// `ArchiveFile.mode` goes out as the external attributes (`mode << 16`),
    /// and the creator byte is patched to 3 - which is the condition the decoder
    /// checks before it will read a mode as a file type at all. Without the
    /// patch the archive is an ordinary ZIP with odd attributes.
    Uint8List zipWithUnixSymlink() {
      const target = '/etc/passwd';
      final link = ArchiveFile(
        'idle_000.png',
        target.length,
        Uint8List.fromList(utf8.encode(target)),
      )..mode = 0xa1ff; // S_IFLNK | 0777

      final out = Uint8List.fromList(zip([manifestEntry(), link]));
      for (var i = 0; i + 5 < out.length; i++) {
        final isCentralHeader = out[i] == 0x50 &&
            out[i + 1] == 0x4b &&
            out[i + 2] == 0x01 &&
            out[i + 3] == 0x02;
        if (isCentralHeader) out[i + 5] = 3; // high byte of versionMadeBy: Unix
      }
      return out;
    }

    test('a symlink: the reader refuses one, built for real', () {
      // The open verification item this group used to record, closed. The
      // question was never whether the policy can refuse `isRegularFile: false`
      // - it can, and the policy test covers it - but whether the *reader* ever
      // produces that flag from a real archive.
      final bytes = zipWithUnixSymlink();

      // First that the input is what this test claims. A refusal of something
      // that was never a symlink would pass for the wrong reason, and that is
      // the failure mode a hand-built archive invites.
      final decoded = ZipDecoder().decodeBytes(bytes);
      final link = decoded.files.firstWhere((f) => f.name == 'idle_000.png');
      expect(link.isSymbolicLink, isTrue,
          reason: 'the patched archive must decode as a symlink, or the '
              'refusal below proves nothing');
      expect(link.symbolicLink, '/etc/passwd');

      final result = CompanionPackArchiveReader.read(bytes);
      expect(result.ok, isFalse);
      expect(result.files, isEmpty,
          reason: 'a refusal must never hand a caller files to write');
      expect(result.validation.codes, contains('non_regular_entry'));
    });

    test('the same archive without the patch is accepted', () {
      // The control. If the reader refused every archive, the test above would
      // pass and mean nothing; the only difference here is the creator byte and
      // the mode.
      const target = '/etc/passwd';
      final plain = ArchiveFile(
        'idle_000.png',
        target.length,
        Uint8List.fromList(utf8.encode(target)),
      );
      final result = read([manifestEntry(), plain]);

      expect(result.ok, isTrue,
          reason: 'an ordinary file of the same bytes is a fine pack entry');
    });

    test('a duplicate path: the archive model de-duplicates on add', () {
      // A real ZIP can hold two entries of the same name, and the rule exists for
      // that; this encoder cannot build one. Covered in the policy test.
      final archive = Archive()
        ..addFile(manifestEntry())
        ..addFile(entry('idle_000.png'))
        ..addFile(entry('idle_000.png'));
      expect(archive.files.length, 2,
          reason: 'the duplicate never reaches the decoder');
    });
  });

  test('a refused archive yields no files at all', () {
    // The property that matters: a refusal comes with nothing to write, so a
    // caller cannot accidentally write half of a bad pack.
    final result = read([entry('../escape.png'), entry('idle_000.png')]);
    expect(result.ok, isFalse);
    expect(result.files, isEmpty);
  });

  test('an unreadable archive is a refusal, not a thrown exception', () {
    // Truncated or garbage input is one of the things an importer has to survive,
    // and the caller's error handling should live in one place. The decoder is
    // lenient with garbage and yields an empty archive rather than throwing, so
    // either refusal is accepted here.
    final result = CompanionPackArchiveReader.read(List<int>.filled(64, 7));
    expect(result.ok, isFalse);
    expect(result.files, isEmpty);
    expect(
      result.validation.codes,
      anyOf(contains('unreadable_archive'), contains('empty_archive')),
    );
  });

  test('a truncated valid archive is refused, not partially accepted', () {
    final full = zip([
      manifestEntry(),
      entry('idle_000.png', List<int>.filled(2048, 3)),
    ]);
    final result =
        CompanionPackArchiveReader.read(full.sublist(0, full.length ~/ 2));
    expect(result.ok, isFalse, reason: 'a half archive is not a pack');
    expect(result.files, isEmpty);
  });

  test('directory entries are skipped rather than refused', () {
    // Some writers spell the tree explicitly; a pack from an ordinary tool would
    // otherwise fail on a technicality.
    final result = read([
      manifestEntry(),
      entry('frames/'),
      entry('frames/idle_000.png'),
      entry('frames/idle_001.png'),
    ]);
    expect(result.ok, isTrue, reason: '$result');
    expect(result.files.map((f) => f.name), isNot(contains('frames/')),
        reason: 'a directory is not a file to write');
  });
}
