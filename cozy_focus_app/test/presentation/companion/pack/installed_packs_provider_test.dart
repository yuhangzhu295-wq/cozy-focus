import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/pack/installed_pack_registry.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_packs_provider.dart';

/// P32E — the one signal every consumer watches.
///
/// The property under test is not "the revision is an int". It is that a change
/// publishes exactly when the contents change, because a consumer that rebuilds
/// on every mutation but a no-op is a wasted rebuild, and a mutation that does not
/// publish is a companion that stays invisible until restart.
void main() {
  InstalledCompanionPack pack(String id, {String checksum = 'aaa'}) =>
      InstalledCompanionPack(
        packId: id,
        displayName: id,
        species: 'dog',
        source: 'local_import',
        formatVersion: 1,
        checksum: checksum,
        relativeDirectory: 'companion_packs/$id',
      );

  test('a fresh controller is at revision zero with nothing installed', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(installedPacksProvider), 0);
    expect(
        container.read(installedPacksProvider.notifier).installedIds, isEmpty);
  });

  test('installing publishes, and a watcher sees it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var rebuilds = 0;
    container.listen(installedPacksProvider, (_, __) => rebuilds++);

    final outcome =
        container.read(installedPacksProvider.notifier).install(pack('mimi'));

    expect(outcome, PackInstallOutcome.installed);
    expect(rebuilds, 1, reason: 'a watcher must be told exactly once');
    expect(container.read(installedPacksProvider.notifier).installedIds,
        contains('mimi'));
  });

  test('re-installing the same pack publishes nothing', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(installedPacksProvider.notifier);
    controller.install(pack('mimi'));

    var rebuilds = 0;
    container.listen(installedPacksProvider, (_, __) => rebuilds++);
    expect(
        controller.install(pack('mimi')), PackInstallOutcome.alreadyInstalled);
    expect(rebuilds, 0, reason: 'nothing changed, so nothing should rebuild');
  });

  test('a conflicting pack publishes nothing and changes nothing', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(installedPacksProvider.notifier);
    controller.install(pack('mimi'));

    var rebuilds = 0;
    container.listen(installedPacksProvider, (_, __) => rebuilds++);
    expect(controller.install(pack('mimi', checksum: 'bbb')),
        PackInstallOutcome.conflict);
    expect(rebuilds, 0);
    expect(controller.registry['mimi']!.checksum, 'aaa');
  });

  test('removing publishes, and removing something absent does not', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(installedPacksProvider.notifier);
    controller.install(pack('mimi'));

    var rebuilds = 0;
    container.listen(installedPacksProvider, (_, __) => rebuilds++);
    expect(controller.remove('nobody'), isFalse);
    expect(rebuilds, 0);
    expect(controller.remove('mimi'), isTrue);
    expect(rebuilds, 1);
  });

  test('publish reports a change made across several steps', () {
    // The import path mutates the registry directly and reports one change per
    // import rather than one per step.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(installedPacksProvider.notifier);

    var rebuilds = 0;
    container.listen(installedPacksProvider, (_, __) => rebuilds++);
    controller.registry.install(pack('mimi'));
    expect(rebuilds, 0,
        reason: 'a direct mutation is not published on its own');
    controller.publish();
    expect(rebuilds, 1);
  });

  test('selectable ids are the built-ins plus what is installed', () {
    // One place answers this, so the selector, the catalog and the availability
    // resolver cannot disagree about what exists.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(installedPacksProvider.notifier);

    expect(controller.selectableIds(const {'dog', 'cat', 'rabbit'}),
        {'dog', 'cat', 'rabbit'});

    controller.install(pack('mimi'));
    expect(controller.selectableIds(const {'dog', 'cat', 'rabbit'}),
        {'dog', 'cat', 'rabbit', 'mimi'});
  });
}
