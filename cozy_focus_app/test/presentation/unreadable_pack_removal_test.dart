import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_removal.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_packs_provider.dart';
import '../support/install_root_fixture.dart';

/// A pack the app could not read held its id and could not be removed.
///
/// ## Found by walking the import on a device
///
/// A leftover `companion_packs/mimi` with frames but no `manifest.json` — from an
/// earlier partial install — produced a dead end:
///
/// * recovery marked it unreadable and skipped it, so it was **not** in the
///   registry and **not** in the picker;
/// * the import's installer refuses when the target directory already exists
///   (`target_appeared`, correctly — it will not merge two packs under one id);
/// * the import page rendered that refusal as 已经有一个同名的伙伴了，先去伙伴列表把它删掉;
/// * and `CompanionPackRemoval` refused it too, because the guard was
///   `packs.installedIds.contains(packId)` and the registry had never heard of it.
///
/// So the user was told to delete something from a list it was not in, and no code
/// path would delete it. Reading the state out of the app's own `unreadable` map
/// and the filesystem is what made the mechanism clear; the screenshots alone
/// looked like a duplicate-name refusal.
void main() {
  late Directory root;
  late InstalledPacksController packs;
  late ProviderContainer container;

  setUp(() {
    // The pack root is the directory the packs live in — the same value
    // `companionPackRootProvider` resolves on a device, which is the app's
    // `companion_packs` directory, not its parent.
    root = createIsolatedInstallRoot('cozy_pack_removal_');
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  tearDown(() {
    deleteIsolatedInstallRoot(root);
  });

  /// A directory with frames but no manifest — the state that caused the dead end.
  void seedUnreadablePack(String packId) {
    final dir = Directory('${root.path}/$packId')..createSync(recursive: true);
    File('${dir.path}/idle_000.png').writeAsBytesSync([1, 2, 3]);
  }

  InstalledPacksController controllerFor() {
    packs = InstalledPacksController(packRoot: root)..recover();
    return packs;
  }

  CompanionSelection selectionFor(InstalledPacksController packs) =>
      CompanionSelection(
        InMemoryCompanionSelectionStore(),
        selectableIds: packs.selectableIds(const {'dog', 'cat', 'rabbit'}),
      );

  test('recovery reports the directory it cannot read', () {
    seedUnreadablePack('mimi');
    final packs = controllerFor();

    expect(packs.unreadableDirectories.keys, contains('mimi'));
    expect(packs.unreadableDirectories['mimi'], contains('manifest'));
    expect(packs.installedIds, isEmpty,
        reason: 'nothing readable was installed, so nothing is selectable');
  });

  test('and it can be removed, which is what clears the dead end', () async {
    seedUnreadablePack('mimi');
    final packs = controllerFor();

    final report = await CompanionPackRemoval.remove(
      packId: 'mimi',
      packs: packs,
      selection: selectionFor(packs),
      installRoot: root,
      builtInIds: const {'dog', 'cat', 'rabbit'},
      defaultId: 'dog',
    );

    expect(report.removed, isTrue,
        reason:
            'the id has to be freeable or the import can never use it again');
    expect(Directory('${root.path}/mimi').existsSync(), isFalse,
        reason: 'and the files have to go, or the next import hits '
            'target_appeared again');
  });

  test('after removing it the id can be taken by a real pack', () async {
    seedUnreadablePack('mimi');
    final packs = controllerFor();
    await CompanionPackRemoval.remove(
      packId: 'mimi',
      packs: packs,
      selection: selectionFor(packs),
      installRoot: root,
      builtInIds: const {'dog', 'cat', 'rabbit'},
      defaultId: 'dog',
    );

    // What the installer checks before it writes: the target must not exist.
    expect(Directory('${root.path}/mimi').existsSync(), isFalse);
    // And a re-scan stops reporting it.
    packs.rescan();
    expect(packs.unreadableDirectories, isEmpty);
  });

  test('a pack that is neither installed nor on disk is still refused',
      () async {
    final packs = controllerFor();

    final report = await CompanionPackRemoval.remove(
      packId: 'never_existed',
      packs: packs,
      selection: selectionFor(packs),
      installRoot: root,
      builtInIds: const {'dog', 'cat', 'rabbit'},
      defaultId: 'dog',
    );

    expect(report.removed, isFalse,
        reason: 'the relaxed guard must not turn into "remove anything"');
  });

  test('removing an unreadable pack does not touch the selection', () async {
    seedUnreadablePack('mimi');
    final packs = controllerFor();
    final selection = selectionFor(packs);
    await selection.select(const CompanionId('rabbit'));

    await CompanionPackRemoval.remove(
      packId: 'mimi',
      packs: packs,
      selection: selection,
      installRoot: root,
      builtInIds: const {'dog', 'cat', 'rabbit'},
      defaultId: 'dog',
    );

    expect(selection.selected.value, 'rabbit',
        reason: 'the pack being removed was not the one selected, so nothing '
            'about the selection changes');
  });

  test('a directory whose name is not a safe pack id is reported, not offered',
      () {
    // These reach the filesystem as a path segment, so they are reported as
    // unreadable but the picker filters them out of the delete list — deleting by
    // a name like this is not something to offer.
    Directory('${root.path}/bad name').createSync(recursive: true);
    final packs = controllerFor();

    expect(packs.unreadableDirectories.keys, contains('bad name'));
  });
}
