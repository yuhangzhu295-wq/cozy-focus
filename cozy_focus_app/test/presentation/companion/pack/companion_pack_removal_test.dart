import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_removal.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_pack_registry.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_packs_provider.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import '../../../support/install_root_fixture.dart';

/// P32G — deleting a companion, in the order that keeps the app valid.
///
/// The brief's rule: if the deleted pack is selected, switch to a valid fallback
/// **first**, so `selectedCompanionId` is never dangling. These tests pin that
/// order, because doing it the other way round leaves a window in which the app
/// points at a companion that no longer exists.
class _MemoryStore implements CompanionSelectionStore {
  CompanionId? _value;

  @override
  Future<CompanionId?> read() async => _value;

  @override
  Future<void> write(CompanionId id) async => _value = id;
}

void main() {
  late Directory root;
  late InstalledPacksController packs;
  late CompanionSelection selection;
  late _MemoryStore store;

  const builtIns = {'dog', 'cat', 'rabbit'};
  const defaultId = 'dog';

  setUp(() {
    root = createIsolatedInstallRoot('cozy_pack_removal_');
    packs = InstalledPacksController();
    store = _MemoryStore();
    selection = CompanionSelection(store, selectableIds: {
      ...builtIns,
      'mimi',
      'zoe',
    });
  });

  tearDown(() {
    deleteIsolatedInstallRoot(root);
  });

  InstalledCompanionPack record(String id) => InstalledCompanionPack(
        packId: id,
        displayName: id,
        species: 'dog',
        source: 'local_import',
        formatVersion: 1,
        checksum: 'aaa',
        relativeDirectory: 'companion_packs/$id',
      );

  Future<CompanionPackRemovalReport> remove(String packId) =>
      CompanionPackRemoval.remove(
        packId: packId,
        packs: packs,
        selection: selection,
        installRoot: root,
        builtInIds: builtIns,
        defaultId: defaultId,
      );

  test('removing a pack that was not selected leaves the selection alone',
      () async {
    packs.install(record('mimi'));
    packs.install(record('zoe'));
    await selection.select(const CompanionId('zoe'));

    final report = await remove('mimi');

    expect(report.removed, isTrue);
    expect(selection.state, const CompanionId('zoe'),
        reason: 'deleting one companion must not change which one is chosen');
    expect(report.selectionAfter, isNull);
  });

  test('removing the selected pack switches to another installed one',
      () async {
    packs.install(record('mimi'));
    packs.install(record('zoe'));
    await selection.select(const CompanionId('mimi'));

    final report = await remove('mimi');

    expect(report.selectionAfter, 'zoe',
        reason: 'another installed pack is closest to what the user had');
    expect(selection.state, const CompanionId('zoe'));
    expect(await store.read(), const CompanionId('zoe'),
        reason: 'the fallback must be persisted, not only held in memory');
  });

  test('with nothing else installed it falls back to a built-in', () async {
    packs.install(record('mimi'));
    await selection.select(const CompanionId('mimi'));

    final report = await remove('mimi');

    expect(report.selectionAfter, defaultId);
    expect(selection.state, const CompanionId('dog'));
    expect(await store.read(), const CompanionId('dog'));
  });

  test('the selection is never left pointing at the removed pack', () async {
    // The whole point of the order. After the removal, the selected id must name
    // something the app can actually draw.
    packs.install(record('mimi'));
    await selection.select(const CompanionId('mimi'));

    await remove('mimi');

    expect(selection.state.value, isNot('mimi'));
    expect(
        {...builtIns, ...packs.installedIds}, contains(selection.state.value),
        reason: 'the selection must name a companion that exists');
  });

  test('removing something that is not installed reports false', () async {
    final report = await remove('nobody');
    expect(report.removed, isFalse);
    expect(selection.state, const CompanionId('dog'),
        reason: 'an untouched selection stays where it was');
  });

  test('the pack stops being installed and its files go', () async {
    final dir = Directory('${root.path}/mimi')..createSync();
    File('${dir.path}/manifest.json').writeAsStringSync('{}');
    packs.install(record('mimi'));

    await remove('mimi');

    expect(packs.installedIds, isNot(contains('mimi')));
    expect(dir.existsSync(), isFalse, reason: 'the files go with it');
  });
}
