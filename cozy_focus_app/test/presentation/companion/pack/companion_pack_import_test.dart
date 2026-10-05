import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_import.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_pack_profiles.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_packs_provider.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';

/// P32 — the import path, walked the way the app walks it.
///
/// ## Why this file exists
///
/// The pieces either side of this were already tested: the archive reader is
/// tested against hostile archives, and `hot_install_test` proves that a pack in
/// the registry becomes a usable companion. What neither covers is the seam
/// between them — that the bytes a user picked are what end up installed, and
/// that the install is what makes the companion selectable.
///
/// So these tests start from an archive built in memory, as a user's file would
/// be, and end at `companionSelectionProvider` accepting the new id. Nothing is
/// stubbed between those two points.
void main() {
  late Directory installRoot;

  setUp(() {
    installRoot = Directory.systemTemp.createTempSync('cozy_import_');
  });

  tearDown(() {
    if (installRoot.existsSync()) installRoot.deleteSync(recursive: true);
    final staging = CompanionPackImporter.stagingRootFor(installRoot);
    if (staging.existsSync()) staging.deleteSync(recursive: true);
  });

  /// A 1x1 transparent PNG. Real bytes, so a preview that draws the idle frame
  /// is drawing something decodable rather than a placeholder.
  final png = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  /// A pack manifest that passes strict validation.
  Map<String, dynamic> manifestFor(
    String id, {
    String? displayName,
    String? species,
    String idleFrameName = 'idle_000.png',
    List<String> extraIdleFrames = const ['idle_001.png'],
  }) =>
      {
        'companionId': id,
        if (displayName != null) 'displayName': displayName,
        if (species != null) 'species': species,
        'posePack': '${id}_art',
        'canvas': {'width': 512, 'height': 512},
        'groundBaseline': 458,
        'centerAnchor': 255,
        'actions': {
          'idle': {
            'frames': [
              idleFrameName,
              ...extraIdleFrames,
            ],
            'fps': 5,
            'loopMode': 'loop',
          },
        },
      };

  /// Builds a `.cozy_pet` in memory, as the exporter would.
  Uint8List archiveOf({
    required String id,
    Map<String, dynamic>? manifest,
    List<String> frameNames = const ['idle_000.png', 'idle_001.png'],
    List<String> extraEntries = const [],
    String manifestEntryName = 'manifest.json',
  }) {
    final archive = Archive();
    archive.addFile(ArchiveFile.typedData(
      manifestEntryName,
      utf8.encode(jsonEncode(manifest ?? manifestFor(id))),
    ));
    for (final name in frameNames) {
      archive.addFile(ArchiveFile.typedData(name, png));
    }
    for (final name in extraEntries) {
      archive.addFile(ArchiveFile.typedData(name, png));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      companionPackRootProvider.overrideWithValue(installRoot.path),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  Future<CompanionPackImportReport> install(
    ProviderContainer c,
    Uint8List bytes, {
    String displayName = '小豆',
    String species = 'dog',
  }) {
    final preview = CompanionPackImporter.inspect(bytes);
    return CompanionPackImporter.install(
      preview: preview,
      displayName: displayName,
      speciesId: species,
      installRoot: installRoot,
      packs: c.read(installedPacksProvider.notifier),
      builtInIds: const {'dog', 'cat', 'rabbit'},
    );
  }

  // ─────────────────────────── inspect ──────────────────────────────────────

  group('inspect', () {
    test('describes a good pack without writing anything', () {
      final preview = CompanionPackImporter.inspect(archiveOf(id: 'mimi'));

      expect(preview.ok, isTrue);
      expect(preview.packId, 'mimi');
      expect(preview.actionIds, ['idle']);
      expect(preview.frameCount, 2);
      expect(preview.canvasWidth, 512);
      expect(preview.canvasHeight, 512);
      expect(preview.idleFrame, isNotNull,
          reason: 'the preview needs something to draw');

      // Nothing was written: inspecting is not installing.
      expect(installRoot.listSync(), isEmpty);
    });

    test('reads the name and species a pack declares for itself', () {
      final preview = CompanionPackImporter.inspect(archiveOf(
        id: 'mimi',
        manifest: manifestFor('mimi', displayName: '咪咪', species: 'cat'),
      ));

      expect(preview.declaredName, '咪咪');
      expect(preview.declaredSpecies, 'cat');
      expect(preview.suggestedName, '咪咪');
    });

    test('falls back to the id when the pack declares no name', () {
      // The shipped manifests carry no displayName, because their name lives in
      // the app's own profile table. A user's pack has no profile table, so the
      // id is the honest placeholder and the user renames it at import.
      final preview = CompanionPackImporter.inspect(archiveOf(id: 'mimi'));
      expect(preview.declaredName, isNull);
      expect(preview.suggestedName, 'mimi');
    });

    test('refuses bytes that are not an archive at all', () {
      final preview = CompanionPackImporter.inspect(utf8.encode('not a zip'));

      expect(preview.ok, isFalse);
      expect(preview.read.files, isEmpty,
          reason: 'a refusal must never hand a caller files to write');
      // Measured, not assumed: `ZipDecoder` in archive 4.3.0 does not throw for
      // bytes it cannot parse — it returns an empty archive. So this arrives as
      // `empty_archive` and not as the reader's `unreadable_archive`, which is
      // why that branch is documented as unreachable rather than covered here.
      expect(preview.validation.codes, contains('empty_archive'));
    });

    test('refuses a truncated archive', () {
      final full = archiveOf(id: 'mimi');
      final preview = CompanionPackImporter.inspect(
        Uint8List.sublistView(full, 0, full.length ~/ 2),
      );

      expect(preview.ok, isFalse);
      expect(preview.read.files, isEmpty);
    });

    test('refuses a frame whose bytes are not a PNG', () {
      // The policy enforces the `.png` *extension*; nothing enforced the
      // *content*. A file renamed to look like a frame would otherwise install
      // cleanly and fail at render time, which is the worst place to find out.
      final archive = Archive();
      archive.addFile(ArchiveFile.typedData(
        'manifest.json',
        utf8.encode(jsonEncode(manifestFor('mimi'))),
      ));
      archive.addFile(ArchiveFile.typedData(
        'idle_000.png',
        Uint8List.fromList(utf8.encode('this is a text file')),
      ));
      archive.addFile(ArchiveFile.typedData('idle_001.png', png));

      final preview = CompanionPackImporter.inspect(
        Uint8List.fromList(ZipEncoder().encode(archive)),
      );

      expect(preview.ok, isFalse);
      expect(preview.validation.codes, contains('frame_not_a_png'));
    });

    test('refuses a pack whose action points at a frame it does not contain',
        () {
      final preview = CompanionPackImporter.inspect(archiveOf(
        id: 'mimi',
        manifest: manifestFor('mimi',
            idleFrameName: 'idle_000.png', extraIdleFrames: ['missing.png']),
        frameNames: const ['idle_000.png'],
      ));

      expect(preview.ok, isFalse);
      expect(preview.validation.codes, contains('missing_frame_file'));
    });

    test('refuses a manifest that is not at the pack root under its exact name',
        () {
      // The policy matches the name case-insensitively; the reader and the
      // installer look for `manifest.json` exactly. The net effect is that an
      // exact name is required, and this pins that down rather than leaving the
      // two comparisons to drift apart.
      final preview = CompanionPackImporter.inspect(
        archiveOf(id: 'mimi', manifestEntryName: 'MANIFEST.JSON'),
      );

      expect(preview.ok, isFalse);
      expect(preview.validation.codes, contains('no_manifest'));
    });

    test('refuses a pack with no idle action', () {
      final manifest = manifestFor('mimi');
      (manifest['actions'] as Map).remove('idle');
      final preview = CompanionPackImporter.inspect(
        archiveOf(id: 'mimi', manifest: manifest),
      );

      expect(preview.ok, isFalse);
      expect(preview.validation.codes, contains('no_actions'));
    });

    test('refuses a single-frame action, because a still is not an animation',
        () {
      final preview = CompanionPackImporter.inspect(archiveOf(
        id: 'mimi',
        manifest: manifestFor('mimi', extraIdleFrames: const []),
        frameNames: const ['idle_000.png'],
      ));

      expect(preview.ok, isFalse);
      expect(preview.validation.codes, contains('action_too_short'));
    });
  });

  // ─────────────────────────── install ──────────────────────────────────────

  group('install', () {
    test('installs, records, and makes the companion usable with no restart',
        () async {
      final c = container();
      expect(
        c.read(companionCatalogProvider).profiles.keys.map((id) => id.value),
        isNot(contains('mimi')),
      );

      final report = await install(c, archiveOf(id: 'mimi'));
      expect(report.status, CompanionPackImportStatus.installed);
      expect(report.pack!.packId, 'mimi');
      expect(report.pack!.displayName, '小豆');
      expect(report.pack!.species, 'dog');

      // The bytes really landed, where the runtime will read them.
      expect(
          File('${installRoot.path}/mimi/manifest.json').existsSync(), isTrue);
      expect(
          File('${installRoot.path}/mimi/idle_000.png').existsSync(), isTrue);

      await settle();

      // And the app offers it, without a restart and without manual invalidation.
      expect(
        c.read(companionCatalogProvider).profiles.keys.map((id) => id.value),
        contains('mimi'),
        reason: 'the catalog must gain the imported companion',
      );
      expect(
        await c
            .read(companionSelectionProvider.notifier)
            .select(const CompanionId('mimi')),
        isTrue,
        reason: 'an imported companion must be selectable',
      );
    });

    test('leaves no staging directory behind', () async {
      final c = container();
      await install(c, archiveOf(id: 'mimi'));

      final staging = CompanionPackImporter.stagingRootFor(installRoot);
      expect(
        staging.existsSync() ? staging.listSync() : const [],
        isEmpty,
        reason:
            'a staging directory left behind is a later run tripping over it',
      );
    });

    test('re-importing the same pack is a no-op, not a second install',
        () async {
      final c = container();
      final bytes = archiveOf(id: 'mimi');

      expect((await install(c, bytes)).status,
          CompanionPackImportStatus.installed);
      final revision = c.read(installedPacksProvider);

      final again = await install(c, bytes);
      expect(again.status, CompanionPackImportStatus.alreadyInstalled);
      expect(c.read(installedPacksProvider), revision,
          reason: 'a no-op must not tell every consumer the world changed');
    });

    test('a different pack under a taken id is a conflict, and changes nothing',
        () async {
      final c = container();
      expect((await install(c, archiveOf(id: 'mimi'))).status,
          CompanionPackImportStatus.installed);
      final original =
          File('${installRoot.path}/mimi/manifest.json').readAsStringSync();

      // Same id, different content: a different frame set, so a different pack.
      final different = archiveOf(
        id: 'mimi',
        frameNames: const ['idle_000.png', 'idle_001.png', 'idle_002.png'],
        manifest: manifestFor('mimi', extraIdleFrames: ['idle_002.png']),
      );

      final report = await install(c, different, displayName: '别的');
      expect(report.status, CompanionPackImportStatus.conflict);
      expect(
        File('${installRoot.path}/mimi/manifest.json').readAsStringSync(),
        original,
        reason: 'a conflict must not overwrite what the user already had',
      );
    });

    test('refuses a built-in id, so the shipped companion stays unambiguous',
        () async {
      final c = container();
      final report = await install(c, archiveOf(id: 'dog'));

      expect(report.status, CompanionPackImportStatus.refused);
      expect(report.validation.codes, contains('pack_id_reserved'));
      expect(Directory('${installRoot.path}/dog').existsSync(), isFalse);
    });

    test('refuses an id that could escape the pack root', () async {
      final c = container();
      final report = await install(c, archiveOf(id: '../evil'));

      expect(report.status, CompanionPackImportStatus.refused);
      expect(report.validation.codes, contains('unsafe_pack_id'));
      expect(installRoot.listSync(), isEmpty,
          reason: 'a refusal must not have written anything anywhere');
    });

    test('refuses an empty name and an unsupported species', () async {
      final c = container();

      final unnamed =
          await install(c, archiveOf(id: 'mimi'), displayName: '   ');
      expect(unnamed.status, CompanionPackImportStatus.refused);
      expect(unnamed.validation.codes, contains('empty_display_name'));

      final wrongSpecies =
          await install(c, archiveOf(id: 'mimi'), species: 'dragon');
      expect(wrongSpecies.status, CompanionPackImportStatus.refused);
      expect(wrongSpecies.validation.codes, contains('unsupported_species'));

      expect(installRoot.listSync(), isEmpty);
    });

    test('refuses an archive it could not inspect, writing nothing', () async {
      final c = container();
      final report = await install(c, Uint8List.fromList(utf8.encode('nope')));

      expect(report.status, CompanionPackImportStatus.refused);
      expect(installRoot.listSync(), isEmpty);
    });

    test('staging sits beside the pack root, so the final move is a rename',
        () {
      // A rename across filesystems fails, and a copy would leave a window in
      // which the pack is half-written. Both are avoided by staging as a sibling.
      final staging = CompanionPackImporter.stagingRootFor(installRoot);
      expect(staging.parent.path, installRoot.parent.path);
    });
  });
}
