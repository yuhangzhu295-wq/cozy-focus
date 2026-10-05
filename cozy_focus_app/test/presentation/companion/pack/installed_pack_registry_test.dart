import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/pack/installed_pack_registry.dart';

/// P32 — the registry of installed packs, and the rules for changing it.
void main() {
  InstalledCompanionPack pack(
    String id, {
    String checksum = 'aaa',
    String species = 'dog',
    int version = 1,
  }) =>
      InstalledCompanionPack(
        packId: id,
        displayName: id.toUpperCase(),
        species: species,
        source: 'local_import',
        formatVersion: version,
        checksum: checksum,
        relativeDirectory: 'companion_packs/$id',
      );

  group('install', () {
    test('a new pack is installed and the revision moves', () {
      final registry = InstalledPackRegistry();
      expect(registry.revision, 0);
      expect(registry.install(pack('mimi')), PackInstallOutcome.installed);
      expect(registry.contains('mimi'), isTrue);
      expect(registry.revision, 1);
    });

    test('the same pack again is a no-op, not a write', () {
      final registry = InstalledPackRegistry()..install(pack('mimi'));
      final revision = registry.revision;
      expect(
          registry.install(pack('mimi')), PackInstallOutcome.alreadyInstalled);
      expect(registry.revision, revision,
          reason: 'nothing changed, so nothing should be notified');
    });

    test('a different pack under the same id is refused', () {
      // Overwriting silently would destroy something the user chose to keep.
      final registry = InstalledPackRegistry()..install(pack('mimi'));
      expect(registry.install(pack('mimi', checksum: 'bbb')),
          PackInstallOutcome.conflict);
      expect(registry['mimi']!.checksum, 'aaa',
          reason: 'the installed pack must survive the refusal intact');
    });
  });

  group('remove', () {
    test('removing an installed pack bumps the revision', () {
      final registry = InstalledPackRegistry()..install(pack('mimi'));
      final revision = registry.revision;
      expect(registry.remove('mimi'), isTrue);
      expect(registry.contains('mimi'), isFalse);
      expect(registry.revision, revision + 1);
    });

    test('removing something absent reports false and changes nothing', () {
      final registry = InstalledPackRegistry();
      expect(registry.remove('nobody'), isFalse);
      expect(registry.revision, 0);
    });

    test('the silent removal exists for the one caller that notifies itself',
        () {
      final registry = InstalledPackRegistry()..install(pack('mimi'));
      final revision = registry.revision;
      expect(registry.removeSilently('mimi'), isTrue);
      expect(registry.revision, revision,
          reason: 'the import path reports one change per import, not one per '
              'step');
    });
  });

  group('selection repair', () {
    SelectionRepairResult repair({
      String? selected,
      String removed = 'mimi',
      Set<String> installed = const {},
      Set<String> builtIn = const {'dog', 'cat', 'rabbit'},
      String fallback = 'dog',
    }) =>
        CompanionSelectionRepair.afterRemoval(
          selected: selected,
          removedId: removed,
          installedIds: installed,
          builtInIds: builtIn,
          defaultId: fallback,
        );

    test('removing a pack that was not selected leaves the selection alone',
        () {
      final result = repair(selected: 'dog');
      expect(result.action, SelectionRepair.unchanged);
      expect(result.selected, 'dog');
    });

    test('removing the selected pack switches to another installed one', () {
      // Closest to what the user had.
      final result = repair(selected: 'mimi', installed: {'zoe', 'mimi'});
      expect(result.action, SelectionRepair.switched);
      expect(result.selected, 'zoe');
    });

    test('with nothing else installed it switches to the default built-in', () {
      final result = repair(selected: 'mimi');
      expect(result.action, SelectionRepair.switched);
      expect(result.selected, 'dog');
    });

    test('a missing default still yields a built-in rather than nothing', () {
      final result = repair(
        selected: 'mimi',
        builtIn: {'cat', 'rabbit'},
        fallback: 'dog',
      );
      expect(result.action, SelectionRepair.switched);
      expect(result.selected, 'cat');
    });

    test('with nothing at all left the selection is cleared, not dangling', () {
      final result = repair(selected: 'mimi', builtIn: const {});
      expect(result.action, SelectionRepair.cleared);
      expect(result.selected, isNull);
    });

    test('a null selection stays null', () {
      final result = repair(selected: null);
      expect(result.action, SelectionRepair.unchanged);
      expect(result.selected, isNull);
    });
  });

  test('the registry does not expose its internal state', () {
    // A caller that could mutate it directly would bypass the revision, which is
    // the whole point of having one.
    final registry = InstalledPackRegistry()..install(pack('mimi'));
    expect(() => registry.packs.add(pack('zoe')), throwsUnsupportedError);
    // `packIds` is a copy, so mutating it cannot reach the registry either.
    registry.packIds.add('zoe');
    expect(registry.contains('zoe'), isFalse);
  });
}
