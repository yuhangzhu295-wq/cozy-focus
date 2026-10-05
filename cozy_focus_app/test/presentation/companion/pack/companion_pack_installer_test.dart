import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_archive_reader.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_install_plan.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_installer.dart';

/// P32 — installing onto disk, atomically.
///
/// Real files in a temporary directory rather than a mocked filesystem, because
/// the properties under test are about what is on disk: that a refusal leaves the
/// pack root untouched, that staging is not abandoned, and that the move is a
/// rename rather than a merge.
void main() {
  late Directory root;
  late Directory staging;
  late Directory installed;

  setUp(() {
    root = Directory.systemTemp.createTempSync('cozy_pack_install_');
    staging = Directory('${root.path}/staging')..createSync();
    installed = Directory('${root.path}/packs')..createSync();
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Uint8List zip(List<ArchiveFile> files) {
    final archive = Archive();
    for (final f in files) {
      archive.addFile(f);
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  ArchiveFile entry(String name, [List<int>? bytes]) =>
      ArchiveFile.typedData(name, Uint8List.fromList(bytes ?? [120]));

  /// A manifest that passes the strict validator.
  Uint8List goodManifest() => Uint8List.fromList(utf8.encode(jsonEncode({
        'companionId': 'mimi',
        'canvasWidth': 512,
        'canvasHeight': 512,
        'groundBaseline': 458,
        'centerAnchor': 255,
        'actions': {
          'idle': {
            'frames': ['idle_000.png', 'idle_001.png'],
            'fps': 5,
            'loopMode': 'loop',
          },
        },
      })));

  CompanionPackReadResult readGoodPack() =>
      CompanionPackArchiveReader.read(zip([
        ArchiveFile.typedData('manifest.json', goodManifest()),
        entry('idle_000.png', [1, 2, 3]),
        entry('idle_001.png', [4, 5, 6]),
      ]));

  CompanionPackInstallPlan planFor(String id) => CompanionPackInstallRules.plan(
        manifest: {'companionId': id},
        displayName: 'Mimi',
        speciesId: 'dog',
        source: CompanionPackSource.localImport,
        builtInIds: const {'dog', 'cat', 'rabbit'},
        installedIds: const {},
      ).plan!;

  Future<CompanionPackInstallReport> install(
    CompanionPackReadResult read, {
    String id = 'mimi',
    Set<String> already = const {},
    Map<String, String> checksums = const {},
  }) =>
      CompanionPackInstaller.install(
        read: read,
        plan: planFor(id),
        stagingRoot: staging,
        installRoot: installed,
        installedIds: already,
        installedChecksums: checksums,
      );

  test('a valid pack lands, and staging is not left behind', () async {
    final report = await install(readGoodPack());

    expect(report.ok, isTrue, reason: '$report');
    final target = Directory('${installed.path}/mimi');
    expect(target.existsSync(), isTrue);
    expect(File('${target.path}/manifest.json').existsSync(), isTrue);
    expect(File('${target.path}/idle_000.png').readAsBytesSync(), [1, 2, 3],
        reason: 'the bytes must survive the write');
    expect(staging.listSync(), isEmpty,
        reason:
            'an abandoned staging directory is litter a later run trips on');
    expect(report.pack!.packId, 'mimi');
    expect(report.pack!.relativeDirectory, 'companion_packs/mimi');
  });

  test('a refused read installs nothing and writes nothing', () async {
    final bad = CompanionPackArchiveReader.read(zip([
      entry('../escape.png'),
      entry('idle_000.png'),
    ]));
    final report = await install(bad);

    expect(report.status, CompanionPackInstallStatus.refused);
    expect(installed.listSync(), isEmpty);
    expect(staging.listSync(), isEmpty);
  });

  test('a manifest that fails validation on disk is refused', () async {
    // The read passed the policy; the manifest itself is bad. This is the case
    // that only exists because the manifest is re-validated against what was
    // actually written.
    final badManifest = Uint8List.fromList(utf8.encode(jsonEncode({
      'companionId': 'mimi',
      // No canvas, no anchors, and an idle with a single frame.
      'actions': {
        'idle': {
          'frames': ['idle_000.png'],
          'fps': 5,
          'loopMode': 'loop',
        },
      },
    })));
    final read = CompanionPackArchiveReader.read(zip([
      ArchiveFile.typedData('manifest.json', badManifest),
      entry('idle_000.png', [1, 2, 3]),
    ]));
    expect(read.ok, isTrue, reason: 'the archive itself is well formed');

    final report = await install(read);

    expect(report.status, CompanionPackInstallStatus.refused);
    expect(report.validation.codes, contains('missing_canvas'));
    expect(installed.listSync(), isEmpty,
        reason: 'the pack root must be untouched by a refused install');
    expect(staging.listSync(), isEmpty,
        reason: 'and the staging directory must not be abandoned');
  });

  test('a pack referencing a frame it does not contain is refused on disk',
      () async {
    // The manifest names three frames but the archive carries two, so the
    // mismatch is only visible against what was written.
    final manifest = Uint8List.fromList(utf8.encode(jsonEncode({
      'companionId': 'mimi',
      'canvasWidth': 512,
      'canvasHeight': 512,
      'groundBaseline': 458,
      'centerAnchor': 255,
      'actions': {
        'idle': {
          'frames': ['idle_000.png', 'idle_999.png'],
          'fps': 5,
          'loopMode': 'loop',
        },
      },
    })));
    final read = CompanionPackArchiveReader.read(zip([
      ArchiveFile.typedData('manifest.json', manifest),
      entry('idle_000.png', [1, 2, 3]),
    ]));

    final report = await install(read);
    expect(report.status, CompanionPackInstallStatus.refused);
    expect(report.validation.codes, contains('missing_frame_file'));
    expect(installed.listSync(), isEmpty);
  });

  group('collision', () {
    test('the same pack already installed is not written again', () async {
      final first = await install(readGoodPack());
      expect(first.ok, isTrue);

      final again = await install(
        readGoodPack(),
        already: {'mimi'},
        checksums: {'mimi': first.pack!.checksum},
      );
      expect(again.status, CompanionPackInstallStatus.alreadyInstalled);
    });

    test('a different pack under the same id is refused, not overwritten',
        () async {
      final first = await install(readGoodPack());
      expect(first.ok, isTrue);
      final before =
          File('${installed.path}/mimi/idle_000.png').readAsBytesSync();

      final other = CompanionPackArchiveReader.read(zip([
        ArchiveFile.typedData('manifest.json', goodManifest()),
        entry('idle_000.png', [9, 9, 9]),
        entry('idle_001.png', [8, 8, 8]),
      ]));
      final report = await install(
        other,
        already: {'mimi'},
        checksums: {'mimi': first.pack!.checksum},
      );

      expect(report.status, CompanionPackInstallStatus.conflict);
      expect(
          File('${installed.path}/mimi/idle_000.png').readAsBytesSync(), before,
          reason: 'the installed pack must survive the refusal intact');
    });

    test('a plan whose id collides with a built-in is never reached', () {
      // The install rules refuse it before a plan exists, so the installer
      // cannot be handed one.
      final decision = CompanionPackInstallRules.plan(
        manifest: {'companionId': 'dog'},
        displayName: 'Dog',
        speciesId: 'dog',
        source: CompanionPackSource.localImport,
        builtInIds: const {'dog', 'cat', 'rabbit'},
        installedIds: const {},
      );
      expect(decision.ok, isFalse);
      expect(decision.validation.codes, contains('pack_id_reserved'));
    });
  });

  test('uninstall removes the directory', () async {
    await install(readGoodPack());
    expect(Directory('${installed.path}/mimi').existsSync(), isTrue);

    expect(
        await CompanionPackInstaller.uninstall(
            packId: 'mimi', installRoot: installed),
        isTrue);
    expect(Directory('${installed.path}/mimi').existsSync(), isFalse);
  });

  test('uninstalling something absent reports false', () async {
    expect(
        await CompanionPackInstaller.uninstall(
            packId: 'nobody', installRoot: installed),
        isFalse);
  });

  test('the checksum is over the contents, so the same pack re-imports alike',
      () async {
    // Zipping the same pack twice produces different bytes. Hashing the archive
    // would make a re-import look like a different pack and turn an idempotent
    // install into a conflict.
    // Same id, because the manifest declares `mimi` and the validator rightly
    // refuses it under any other name - a pack registering under one id and
    // rendering from another is the case that check exists for.
    final first = await install(readGoodPack());
    await CompanionPackInstaller.uninstall(
        packId: 'mimi', installRoot: installed);
    final second = await install(readGoodPack());
    expect(second.pack!.checksum, first.pack!.checksum,
        reason: 'the same contents must hash the same across installs, even '
            'though the archive bytes differ each time it is zipped');
  });
}
