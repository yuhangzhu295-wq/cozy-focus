import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/companion_visual_registry.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_root.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_pack_profiles.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_pack_registry.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_packs_provider.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';

/// P32E — the load-bearing test: a companion installed while the app is running
/// becomes a companion the app can use, with no restart.
///
/// ## Why this is the test that matters
///
/// Every other test in this slice proves one link. This one walks the chain the
/// way the app does — read the catalog, install a pack, read it again — and
/// asserts the companion is there. **Remove the revision observation and it
/// fails**: that is the property the brief asks for, and the reason a test that
/// only checked each link separately would not have been enough.
///
/// The negative proof was run by hand: dropping `ref.watch(installedPackProfiles
/// Provider)` from `companionCatalogProvider` makes the last test fail, because
/// the catalog is then built once and never again.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('cozy_hot_install_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// A 1x1 transparent PNG, so the provider has a real frame to resolve.
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

  /// Writes an installed pack to disk, as the installer would have.
  void writePack(String packId) {
    final dir = Directory('${root.path}/$packId')..createSync(recursive: true);
    File('${dir.path}/manifest.json').writeAsStringSync(jsonEncode({
      'companionId': packId,
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
    for (final name in const ['idle_000.png', 'idle_001.png']) {
      File('${dir.path}/$name').writeAsBytesSync(png);
    }
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

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  test('a pack installed while the app runs becomes usable, with no restart',
      () async {
    writePack('mimi');
    final c = container();

    // ── before: the app knows only the built-ins ──────────────────────────
    final before = c
        .read(companionCatalogProvider)
        .profiles
        .keys
        .map((id) => id.value)
        .toSet();
    expect(before, isNot(contains('mimi')));
    expect(
        c
            .read(companionVisualRegistryProvider)
            .providerForCompanion(const CompanionId('mimi')),
        isNull);

    // ── install, as the import path would ─────────────────────────────────
    expect(c.read(installedPacksProvider.notifier).install(record('mimi')),
        PackInstallOutcome.installed);
    await settle();

    // ── after: with no restart and no manual invalidation ─────────────────
    expect(
      c.read(companionCatalogProvider).profiles.keys.map((id) => id.value),
      contains('mimi'),
      reason: 'the catalog must gain it while the app is running',
    );

    final provider = c
        .read(companionVisualRegistryProvider)
        .providerForCompanion(const CompanionId('mimi'));
    expect(provider, isNotNull,
        reason: 'and something must know how to draw it');
    expect(provider!.posePackId, 'mimi_art');

    // The selection accepts it, which is what makes it reachable in the picker.
    final selection = c.read(companionSelectionProvider.notifier);
    expect(await selection.select(const CompanionId('mimi')), isTrue,
        reason: 'an installed companion must be selectable');
  });

  test('the installed companion resolves to its own file frames', () {
    // Deliberately not a widget pump: rendering waits on the image stream, which
    // made this test hang rather than fail. What matters here is that the pack
    // resolves to *file* frames in the pack's own directory rather than to
    // bundled assets - the drawing itself is proven by the device flow, and by
    // companion_frame_source_test for the player.
    writePack('mimi');
    final c = container();
    c.read(installedPacksProvider.notifier).install(record('mimi'));
    return settle().then((_) {
      final runtime =
          c.read(installedPackProfilesProvider)[const CompanionId('mimi')]!;
      expect(runtime.frameSource.isBundled, isFalse,
          reason: 'an installed pack must not read bundled assets');
      expect(runtime.frameSource.directory, contains('mimi'));

      final spec = runtime.manifest.specForRendering(CompanionPose.idle);
      expect(spec, isNotNull, reason: 'the pack ships idle');
      expect(spec!.frames, ['idle_000.png', 'idle_001.png']);

      // And the frames are really on disk, which is what the player will read.
      for (final frame in spec.frames) {
        expect(File('${runtime.frameSource.directory}/$frame').existsSync(),
            isTrue,
            reason: '$frame must exist where the frame source points');
      }
    });
  });

  test('an action the pack does not ship is never drawn', () async {
    // The brief's rule: missing actions are not scheduled and are not counted as
    // ready. The provider reports what it has, and draws nothing for the rest.
    writePack('mimi');
    final c = container();
    c.read(installedPacksProvider.notifier).install(record('mimi'));
    await settle();

    final provider = c
        .read(companionVisualRegistryProvider)
        .providerForCompanion(const CompanionId('mimi'))!;
    expect(provider.productionPoses, contains(CompanionPose.idle));
    expect(provider.productionPoses, isNot(contains(CompanionPose.focusRead)),
        reason: 'the pack ships idle only, so focus_read is not ready');
    expect(provider.productionPoses, isNot(contains(CompanionPose.celebrate)));
  });

  test('removing the pack takes the companion away again', () async {
    writePack('mimi');
    final c = container();
    final packs = c.read(installedPacksProvider.notifier);
    packs.install(record('mimi'));
    await settle();
    expect(
      c.read(companionCatalogProvider).profiles.keys.map((id) => id.value),
      contains('mimi'),
    );

    packs.remove('mimi');
    await settle();

    expect(
      c.read(companionCatalogProvider).profiles.keys.map((id) => id.value),
      isNot(contains('mimi')),
      reason: 'a removed pack must stop being offered, without a restart',
    );
    expect(
      c
          .read(companionVisualRegistryProvider)
          .providerForCompanion(const CompanionId('mimi')),
      isNull,
    );
  });
}
