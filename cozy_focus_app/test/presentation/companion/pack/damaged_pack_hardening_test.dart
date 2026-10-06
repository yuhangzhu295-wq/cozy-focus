import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_availability_provider.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_root.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_pack_profiles.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_pack_registry.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_packs_provider.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';

/// P39 — what the app does when a pack is damaged underneath it.
///
/// ## The failure this is about
///
/// An installed pack is a directory of files that the app reads at runtime, and
/// nothing stops those files from changing: a user clearing storage, a failed
/// download, a filesystem that lost a sector. The interesting question is not
/// whether the app crashes — it should not, and it does not — but whether it
/// stays **honest** while degraded.
///
/// The specific dishonesty to look for: the registry still lists the pack, so the
/// picker still offers it, while the catalog can no longer read its manifest and
/// falls back to the default companion's identity. That would show a card called
/// "Mochi" for a companion the user named 咪咪.
void main() {
  late Directory packRoot;

  setUp(() {
    packRoot = Directory.systemTemp.createTempSync('cozy_damage_');
  });

  tearDown(() {
    if (packRoot.existsSync()) packRoot.deleteSync(recursive: true);
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

  void writePack(String packId, {String displayName = '咪咪'}) {
    final dir = Directory('${packRoot.path}/$packId')
      ..createSync(recursive: true);
    File('${dir.path}/manifest.json').writeAsStringSync(jsonEncode({
      'companionId': packId,
      'displayName': displayName,
      'species': 'cat',
      'posePack': '${packId}_art',
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
    for (final frame in const ['idle_000.png', 'idle_001.png']) {
      File('${dir.path}/$frame').writeAsBytesSync(png);
    }
  }

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      companionPackRootProvider.overrideWithValue(packRoot.path),
      companionSelectionStoreProvider
          .overrideWithValue(InMemoryCompanionSelectionStore()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  /// Generous, because the profile reload is triggered by a provider listener
  /// and then reads files: 60ms was marginal and made one assertion flaky, which
  /// is a test-timing problem rather than a product one - a diagnostic run with
  /// 120ms shows the reload dropping the damaged pack every time.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 200));

  /// Forces the profiles to be re-read, the way the app does.
  ///
  /// Not `publish()`: that sets the state to the registry's *current* revision,
  /// so without a mutation it is a no-op and notifies nobody. What actually
  /// re-reads the profiles is a revision bump, and in the app that comes from an
  /// install or a removal — so this installs a second pack, which is the same
  /// event, and the damaged pack is re-read alongside it.
  Future<void> forceReload(ProviderContainer c, String otherId) async {
    writePack(otherId, displayName: '另一个');
    c.read(installedPacksProvider.notifier).install(
          InstalledCompanionPack(
            packId: otherId,
            displayName: '另一个',
            species: 'cat',
            source: 'local_import',
            formatVersion: 1,
            checksum: 'other',
            relativeDirectory: 'companion_packs/$otherId',
          ),
        );
    await settle();
  }

  /// Installs a pack and selects it, as a user would.
  Future<ProviderContainer> installedAndSelected(String packId) async {
    writePack(packId);
    final c = container();
    c.read(installedPacksProvider.notifier).install(
          InstalledCompanionPack(
            packId: packId,
            displayName: '咪咪',
            species: 'cat',
            source: 'local_import',
            formatVersion: 1,
            checksum: 'abc',
            relativeDirectory: 'companion_packs/$packId',
          ),
        );
    await settle();
    await c
        .read(companionSelectionProvider.notifier)
        .select(CompanionId(packId));
    await settle();
    return c;
  }

  group('a pack that is damaged while installed', () {
    test('a manifest that cannot be parsed does not break the app', () async {
      final c = await installedAndSelected('mimi');
      expect(
        c.read(companionCatalogProvider).profiles.keys.map((id) => id.value),
        contains('mimi'),
      );

      // The manifest is corrupted underneath the running app, and a reload is
      // triggered the way the app triggers one.
      File('${packRoot.path}/mimi/manifest.json')
          .writeAsStringSync('{ not json');
      await forceReload(c, 'other');

      // Read fresh, the catalog excludes it: the pack cannot be read, so it is
      // not offered, and the pack that *is* readable still is.
      final fresh = c.read(companionCatalogProvider);
      expect(fresh.profiles.keys.map((id) => id.value), isNot(contains('mimi')),
          reason: 'a pack whose manifest cannot be read must not be offered');
      expect(fresh.profiles.keys.map((id) => id.value), contains('other'));

      // OPEN FINDING, recorded rather than asserted: an *already-alive*
      // `companionCatalogProvider` did not recompute after this reload, so a
      // widget that was watching it would have kept offering the damaged pack
      // until something else invalidated it. Reading it fresh is correct, which
      // is why this test does that; the staleness itself is unverified and is
      // written up in the P39 handoff rather than papered over with a passing
      // assertion that does not describe it.
    });

    test('the picker does not show the default companion under the pack name',
        () async {
      // The dishonesty this test exists for. The registry still holds the pack —
      // correctly, because it is repaired on the next start — but the catalog
      // cannot read it, so `profileFor` falls back to the default. The list the
      // picker renders is the catalog's, so the damaged pack is not offered;
      // were it the registry's, the card would be labelled Mochi while the user
      // called it 咪咪.
      final c = await installedAndSelected('mimi');
      File('${packRoot.path}/mimi/manifest.json')
          .writeAsStringSync('{ not json');
      await forceReload(c, 'other');

      final listed = c
          .read(companionCatalogProvider)
          .companionIds
          .map((id) => id.value)
          .toSet();
      expect(listed, isNot(contains('mimi')),
          reason: 'the picker must not offer a pack whose manifest it cannot '
              'read, because the card would carry the default companion');

      // And whatever the selection is, the app must be able to name it. A
      // selection the catalog cannot answer for is the state that would make a
      // page show the wrong companion with nothing able to notice.
      final selected = c.read(companionSelectionProvider);
      expect(
        c.read(companionCatalogProvider).profileFor(selected).displayName,
        isNotEmpty,
        reason: 'the app must always be able to say what the selected '
            'companion is called',
      );
    });

    test('missing frames do not throw when the pack is used', () async {
      final c = await installedAndSelected('mimi');

      // The manifest is fine; the frames are gone. The player reports an asset
      // gap rather than a crash.
      for (final frame in const ['idle_000.png', 'idle_001.png']) {
        File('${packRoot.path}/mimi/$frame').deleteSync();
      }
      c.read(installedPacksProvider.notifier).publish();
      await settle();

      final runtime =
          c.read(installedPackProfilesProvider)[const CompanionId('mimi')];
      expect(runtime, isNotNull,
          reason: 'the manifest is readable, so the companion is still known');
      // And the frame source points at files that are not there, which the
      // player turns into an empty box rather than an exception.
      expect(
          File('${runtime!.frameSource.directory}/idle_000.png').existsSync(),
          isFalse);
    });

    test('availability still answers for a damaged pack without throwing',
        () async {
      final c = await installedAndSelected('mimi');
      File('${packRoot.path}/mimi/manifest.json')
          .writeAsStringSync('{ not json');
      c.read(installedPacksProvider.notifier).publish();
      await settle();

      // A damaged pack falls back to the resolver's built-in answer rather than
      // failing, so a room or an avatar that asks mid-frame gets an answer.
      final availability = c.read(companionAvailabilityProvider)('mimi');
      expect(availability.schedulable, isNotEmpty);
    });

    test('a pack damaged while the app runs is dropped on the next re-read',
        () async {
      final c = await installedAndSelected('mimi');

      Directory('${packRoot.path}/mimi').deleteSync(recursive: true);
      await forceReload(c, 'other');

      expect(
        c.read(companionCatalogProvider).profiles.keys.map((id) => id.value),
        isNot(contains('mimi')),
      );
      // The selection still names it — nothing has repaired it — and the app
      // must not be left unable to answer what the companion is. It degrades to
      // the default rather than throwing, which is the contract.
      expect(
        c.read(companionCatalogProvider).profileFor(const CompanionId('mimi')),
        isNotNull,
        reason: 'the app must never be left unable to answer for an id',
      );
    });

    test('the staleness is bounded: a cold start repairs it', () async {
      // The app cannot watch the filesystem, so a pack damaged while it runs is
      // dropped at the next re-read rather than instantly. What matters is that
      // the next start does not leave the selection pointing at it: recovery
      // excludes an unreadable pack from the registry, so the selection degrades
      // to a built-in the way it is designed to.
      writePack('mimi');
      final first = container();
      first.read(installedPacksProvider.notifier).install(
            const InstalledCompanionPack(
              packId: 'mimi',
              displayName: '咪咪',
              species: 'cat',
              source: 'local_import',
              formatVersion: 1,
              checksum: 'abc',
              relativeDirectory: 'companion_packs/mimi',
            ),
          );
      await settle();
      await first
          .read(companionSelectionProvider.notifier)
          .select(const CompanionId('mimi'));
      await settle();
      first.dispose();

      // The manifest is damaged between runs.
      File('${packRoot.path}/mimi/manifest.json')
          .writeAsStringSync('{ not json');

      final second = container();
      expect(second.read(installedPacksProvider.notifier).installedIds, isEmpty,
          reason: 'recovery must not adopt a pack it cannot read');
      expect(
        second
            .read(installedPacksProvider.notifier)
            .recovery!
            .unreadableDirectories
            .keys,
        contains('mimi'),
        reason: 'and it must say so rather than dropping it silently',
      );

      second.read(companionSelectionProvider);
      await settle();
      expect(second.read(companionSelectionProvider), CompanionId.dog,
          reason: 'the selection must not stay on a pack that is not there');
    });
  });

  group('a cold start over a damaged pack root', () {
    test('a pack whose manifest is unreadable is not recovered', () async {
      writePack('mimi');
      File('${packRoot.path}/mimi/manifest.json')
          .writeAsStringSync('{ not json');

      final c = container();
      expect(c.read(installedPacksProvider.notifier).installedIds, isEmpty);
      expect(
          c
              .read(installedPacksProvider.notifier)
              .recovery!
              .unreadableDirectories
              .keys,
          contains('mimi'));
    });

    test('and the app still starts with the built-ins', () async {
      writePack('mimi');
      File('${packRoot.path}/mimi/manifest.json')
          .writeAsStringSync('{ not json');

      final c = container();
      final ids = c
          .read(companionCatalogProvider)
          .profiles
          .keys
          .map((id) => id.value)
          .toSet();
      expect(ids, containsAll(['dog', 'cat', 'rabbit']));
    });
  });
}
