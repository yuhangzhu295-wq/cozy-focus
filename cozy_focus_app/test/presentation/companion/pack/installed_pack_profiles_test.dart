import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_root.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_pack_profiles.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_pack_registry.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_packs_provider.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_manifest_data.dart';

/// P32E — an installed pack becomes a companion the catalog can offer.
///
/// The load is asynchronous because a manifest is a file, but the catalog is
/// synchronous because a build must not wait on disk. These tests pin both halves:
/// the merge is a plain map operation, and the read happens when the installed set
/// changes rather than on every build.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('cozy_pack_profiles_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Writes a pack directory with a manifest.
  void writePack(String packId, {String? posePack, String? manifest}) {
    final dir = Directory('${root.path}/$packId')..createSync(recursive: true);
    File('${dir.path}/manifest.json').writeAsStringSync(
      manifest ??
          jsonEncode({
            'companionId': packId,
            'posePack': posePack ?? packId,
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
          }),
    );
  }

  InstalledCompanionPack record(String packId) => InstalledCompanionPack(
        packId: packId,
        displayName: 'Mimi',
        species: 'dog',
        source: 'local_import',
        formatVersion: 1,
        checksum: 'aaa',
        relativeDirectory: 'companion_packs/$packId',
      );

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      companionPackRootProvider.overrideWithValue(root.path),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('the catalog merges installed profiles', () {
    test('withProfiles adds without disturbing the built-ins', () {
      final bundled = bundledCompanionCatalog();
      final before = bundled.profiles.keys.toSet();

      final merged = bundled.withProfiles({
        const CompanionId('mimi'): bundled.profiles.values.first,
      });

      expect(merged.profiles.keys, containsAll(before));
      expect(merged.profiles.length, before.length + 1);
      expect(merged.defaultProfileId, bundled.defaultProfileId,
          reason: 'the fallback must not change because a pack was installed');
    });

    test('withProfiles with nothing added returns the same catalog', () {
      final bundled = bundledCompanionCatalog();
      expect(identical(bundled.withProfiles(const {}), bundled), isTrue,
          reason: 'an empty merge must not rebuild the catalog');
    });
  });

  group('the loader reads installed packs', () {
    test('with no root configured it reports nothing installed', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      // companionPackRootProvider defaults to null.
      final profiles = c.read(installedPackProfilesProvider);
      await Future<void>.delayed(Duration.zero);
      expect(profiles, isEmpty);
      expect(c.read(installedPackProfilesProvider), isEmpty);
    });

    test('an installed pack becomes a profile with its own pose pack',
        () async {
      writePack('mimi', posePack: 'mimi_art');
      final c = container();
      c.read(installedPacksProvider.notifier).install(record('mimi'));

      // The load is asynchronous, so let it run.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final runtime =
          c.read(installedPackProfilesProvider)[const CompanionId('mimi')];
      expect(runtime, isNotNull, reason: 'the pack is installed and readable');
      expect(runtime!.profile.displayName, 'Mimi');
      expect(runtime.profile.posePack, 'mimi_art',
          reason:
              'the pose pack comes from the manifest, which is what tells the '
              'runtime which provider draws it');
      expect(runtime.profile.species, 'dog');
    });

    test('a pack whose manifest cannot be read is left out, not faked',
        () async {
      // Reaching here means the files changed underneath us - the installer's
      // validation should have caught a bad manifest. Offering the companion
      // would mean rendering something unverified.
      writePack('mimi', manifest: 'not json at all');
      final c = container();
      c.read(installedPacksProvider.notifier).install(record('mimi'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(c.read(installedPackProfilesProvider), isEmpty);
      expect(c.read(installedPacksProvider.notifier).installedIds,
          contains('mimi'),
          reason: 'it is still installed; it simply is not offered');
    });

    test('a manifest without a pose pack is left out', () async {
      writePack('mimi',
          manifest: jsonEncode({'companionId': 'mimi', 'actions': {}}));
      final c = container();
      c.read(installedPacksProvider.notifier).install(record('mimi'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(c.read(installedPackProfilesProvider), isEmpty,
          reason: 'without a pose pack nothing knows how to draw it');
    });

    test('removing a pack removes its profile', () async {
      writePack('mimi');
      final c = container();
      final packs = c.read(installedPacksProvider.notifier);
      packs.install(record('mimi'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.read(installedPackProfilesProvider), isNotEmpty);

      packs.remove('mimi');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.read(installedPackProfilesProvider), isEmpty);
    });
  });

  test('the catalog provider offers an installed pack without a restart', () {
    // The whole point of the slice, stated as one assertion: read the catalog,
    // install a pack, read it again, and the companion is there. No restart, no
    // manual invalidation.
    writePack('mimi');
    final c = container();
    expect(
      c.read(companionCatalogProvider).profiles.keys.map((id) => id.value),
      isNot(contains('mimi')),
    );

    c.read(installedPacksProvider.notifier).install(record('mimi'));

    // The profile load is asynchronous, so the catalog gains it once it lands.
    return Future<void>.delayed(const Duration(milliseconds: 50), () {
      expect(
        c.read(companionCatalogProvider).profiles.keys.map((id) => id.value),
        contains('mimi'),
        reason:
            'an installed pack must appear in the catalog while the app runs',
      );
    });
  });
}
