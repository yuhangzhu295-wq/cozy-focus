import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_install_plan.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_root.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_pack_record_store.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_pack_recovery.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_pack_registry.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_packs_provider.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';

/// P32 — what is installed, after the app has been killed and reopened.
///
/// ## The bug these exist for
///
/// The registry is in memory, so on a cold start it was empty while the pack
/// directories were still on disk. The app therefore offered only the built-in
/// three, and the persisted selection — which said `xiaomao` and was written
/// correctly — was discarded as an unknown id and silently replaced by the
/// default. On the device that read as "the companion I just installed went
/// back to Mochi", with nothing in the log.
///
/// Every hot-install test passed throughout, because a hot install never asks
/// the disk what is already there.
void main() {
  late Directory docs;
  late Directory packRoot;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('cozy_cold_start_');
    packRoot = Directory('${docs.path}/${CompanionPackInstallRules.root}')
      ..createSync(recursive: true);
  });

  tearDown(() {
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  final png = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ];

  /// A pack on disk, as the installer would have left it.
  void writePack(
    String directoryName, {
    String? companionId,
    String? displayName,
    String? species,
  }) {
    final dir = Directory('${packRoot.path}/$directoryName')
      ..createSync(recursive: true);
    File('${dir.path}/manifest.json').writeAsStringSync(jsonEncode({
      'companionId': companionId ?? directoryName,
      if (displayName != null) 'displayName': displayName,
      if (species != null) 'species': species,
      'posePack': '${directoryName}_art',
      'canvas': {'width': 512, 'height': 512},
      'groundBaseline': 458,
      'centerAnchor': 255,
      'actions': {
        'idle': {
          'frames': ['idle_000.png', 'idle_001.png'],
          'fps': 5,
          'loopMode': 'loop',
        },
      },
    }));
    for (final name in const ['idle_000.png', 'idle_001.png']) {
      File('${dir.path}/$name').writeAsBytesSync(png);
    }
  }

  /// A container as a fresh launch would build it: file-backed selection store,
  /// the real pack root, nothing carried over in memory.
  ProviderContainer launch() {
    final c = ProviderContainer(overrides: [
      companionPackRootProvider.overrideWithValue(packRoot.path),
      companionSelectionStoreProvider.overrideWithValue(
        FileCompanionSelectionStore(directoryOverride: docs),
      ),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  InstalledCompanionPack record(String packId, {String checksum = 'aaa'}) =>
      InstalledCompanionPack(
        packId: packId,
        displayName: '小豆',
        species: 'cat',
        source: 'local_import',
        formatVersion: 1,
        checksum: checksum,
        relativeDirectory: '${CompanionPackInstallRules.root}/$packId',
      );

  group('a cold start', () {
    test('finds an installed pack and restores the selection to it', () async {
      writePack('xiaomao');
      final first = launch();
      first.read(installedPacksProvider.notifier).install(record('xiaomao'));
      expect(
        await first
            .read(companionSelectionProvider.notifier)
            .select(const CompanionId('xiaomao')),
        isTrue,
      );
      await settle();
      first.dispose();

      // ── the app is killed and reopened ────────────────────────────────────
      final second = launch();
      // Providers are lazy, so the selection's asynchronous restore only starts
      // when something first reads it. Read it, then let the file read land.
      second.read(companionSelectionProvider);
      await settle();

      expect(
        second
            .read(companionCatalogProvider)
            .profiles
            .keys
            .map((id) => id.value),
        contains('xiaomao'),
        reason: 'a pack installed before the restart must still be offered',
      );
      expect(
        second.read(companionSelectionProvider),
        const CompanionId('xiaomao'),
        reason: 'the stored selection must survive, not fall back to Mochi',
      );
    });

    test('offers nothing when the root does not exist yet', () {
      final fresh = Directory('${docs.path}/never_created');
      final result = InstalledPackRecovery.scan(fresh);
      expect(result.packs, isEmpty);
    });

    test('drops a record whose pack is gone, and rewrites the records', () {
      writePack('xiaomao');
      final c = launch();
      c.read(installedPacksProvider.notifier).install(record('xiaomao'));
      expect(InstalledPackRecordStore.fileFor(packRoot).existsSync(), isTrue);

      // The directory disappears between runs — a user clearing files, or a
      // failed delete from an earlier version.
      Directory('${packRoot.path}/xiaomao').deleteSync(recursive: true);

      final second = launch();
      expect(
          second.read(installedPacksProvider.notifier).installedIds, isEmpty);
      expect(
        InstalledPackRecordStore.fileFor(packRoot).existsSync(),
        isFalse,
        reason: 'a record for nothing should not be left to re-check forever',
      );
    });

    test('reads a pack the records have never heard of', () {
      // Copied in by hand, with the name and species in its own manifest.
      writePack('handmade', displayName: '手作', species: 'dog');

      final result = InstalledPackRecovery.scan(packRoot);

      expect(result.packs, hasLength(1));
      expect(result.packs.single.packId, 'handmade');
      expect(result.packs.single.displayName, '手作');
      expect(result.packs.single.species, 'dog');
      expect(result.packs.single.source, 'unknown',
          reason: 'how it arrived is not knowable from the pack');
      expect(result.packs.single.checksum, isNotEmpty,
          reason: 'without a record the digest has to be computed');
    });

    test('refuses a pack it cannot classify, and says so', () {
      // No record and no declared species. Nothing may infer the animal from the
      // id, so the companion is not offered rather than invented.
      writePack('mystery');

      final result = InstalledPackRecovery.scan(packRoot);

      expect(result.packs, isEmpty);
      expect(result.unreadableDirectories.keys, contains('mystery'));
    });

    test('ignores a directory whose name is not a usable pack id', () {
      // `.hidden` and an uppercase name are both creatable and both outside the
      // id grammar, so neither could have been produced by an install.
      writePack('.hidden', displayName: 'x', species: 'dog');
      writePack('Fine-But-Uppercase', displayName: 'x', species: 'dog');

      final result = InstalledPackRecovery.scan(packRoot);

      expect(result.packs, isEmpty);
      expect(result.unreadableDirectories.keys,
          containsAll(['.hidden', 'Fine-But-Uppercase']));
    });

    test('ignores a directory whose manifest names another companion', () {
      // Two answers to one question: registering it would put the companion in
      // the list under one id and render it from another.
      writePack('xiaomao', companionId: 'someoneelse');

      final result = InstalledPackRecovery.scan(packRoot);

      expect(result.packs, isEmpty);
      expect(result.unreadableDirectories.keys, contains('xiaomao'));
    });

    test('a record keeps the name and species the user chose', () {
      // The pack declares neither — the format leaves both optional — so without
      // the record the user's answers would be lost on restart.
      writePack('xiaomao');
      final first = launch();
      first.read(installedPacksProvider.notifier).install(
            const InstalledCompanionPack(
              packId: 'xiaomao',
              displayName: '小豆',
              species: 'cat',
              source: 'local_import',
              formatVersion: 1,
              checksum: 'aaa',
              relativeDirectory: 'companion_packs/xiaomao',
            ),
          );
      first.dispose();

      final recovered = InstalledPackRecovery.scan(packRoot).packs.single;
      expect(recovered.displayName, '小豆');
      expect(recovered.species, 'cat');
      expect(recovered.source, 'local_import');
    });
  });

  group('the record file', () {
    test('is written on install and rewritten on removal', () {
      writePack('xiaomao');
      writePack('doudou');
      final c = launch();
      final packs = c.read(installedPacksProvider.notifier);

      packs.install(record('xiaomao'));
      packs.install(record('doudou'));
      expect(
        InstalledPackRecordStore.read(packRoot).map((r) => r.packId).toList(),
        ['doudou', 'xiaomao'],
      );

      packs.remove('xiaomao');
      expect(
        InstalledPackRecordStore.read(packRoot).map((r) => r.packId).toList(),
        ['doudou'],
      );

      packs.remove('doudou');
      expect(
        InstalledPackRecordStore.fileFor(packRoot).existsSync(),
        isFalse,
        reason: 'an empty install record is not a record',
      );
    });

    test('survives being corrupt', () {
      writePack('xiaomao', displayName: '小豆', species: 'cat');
      InstalledPackRecordStore.fileFor(packRoot)
          .writeAsStringSync('{ this is not json');

      // The directory scan is the fallback, so a corrupt record costs nothing
      // but the name the user typed.
      final result = InstalledPackRecovery.scan(packRoot);
      expect(result.packs.single.packId, 'xiaomao');
      expect(result.packs.single.displayName, '小豆');
    });

    test('does not travel with an exported pack', () {
      // It sits beside the pack directories, never inside one: a pack directory
      // is exactly what gets exported.
      writePack('xiaomao');
      final c = launch();
      c.read(installedPacksProvider.notifier).install(record('xiaomao'));

      final insidePack = Directory('${packRoot.path}/xiaomao')
          .listSync()
          .map((e) => e.path.split(Platform.pathSeparator).last)
          .toList();
      expect(insidePack, isNot(contains(InstalledPackRecordStore.fileName)));
    });
  });

  group('adopting a recovered set', () {
    // These use a bare controller rather than the provider, because the provider
    // recovers on creation: its registry is never empty, so it could not show
    // what adopting a set for the first time does.
    test('publishes once for a whole recovered set', () {
      writePack('xiaomao', displayName: '小豆', species: 'cat');
      writePack('doudou', displayName: '豆豆', species: 'dog');
      final controller = InstalledPacksController(packRoot: packRoot);
      addTearDown(controller.dispose);
      expect(controller.revision, 0);

      controller.recover();

      expect(controller.installedIds, {'xiaomao', 'doudou'});
      expect(controller.revision, 1,
          reason: 'a startup is one change, not one per pack');
    });

    test('does not publish again when nothing changed', () {
      writePack('xiaomao', displayName: '小豆', species: 'cat');
      final controller = InstalledPacksController(packRoot: packRoot);
      addTearDown(controller.dispose);
      controller.recover();
      final revision = controller.revision;

      // A second scan of the same directory must not tell every consumer the
      // world changed.
      controller.recover();

      expect(controller.revision, revision);
      expect(
          controller.registry.adoptAll(
            InstalledPackRecovery.scan(packRoot).packs,
          ),
          isFalse);
    });

    test('publishes when the set really did change', () {
      writePack('xiaomao', displayName: '小豆', species: 'cat');
      final controller = InstalledPacksController(packRoot: packRoot);
      addTearDown(controller.dispose);
      controller.recover();
      final revision = controller.revision;

      writePack('doudou', displayName: '豆豆', species: 'dog');
      controller.recover();

      expect(controller.revision, revision + 1);
      expect(controller.installedIds, {'xiaomao', 'doudou'});
    });
  });
}
