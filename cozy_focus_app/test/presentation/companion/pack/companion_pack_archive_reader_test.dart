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
    test('a symlink: the model holds one, the round trip drops it', () {
      // Recorded rather than asserted green. `ZipEncoder` does not carry
      // `symbolicLink` through encode/decode, so `isSymbolicLink` comes back
      // false and a symlink cannot be built here. The policy's
      // `non_regular_entry` refusal is covered directly in the policy test with
      // `isRegularFile: false`. Whether the *reader* detects a real symlink
      // depends on the decoder, which this test cannot reach - so it is an open
      // verification item, not a pass.
      final link = entry('idle_000.png')..symbolicLink = '/etc/passwd';
      expect(link.isSymbolicLink, isTrue,
          reason: 'the model can hold one, which is what the policy is written '
              'against');
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
