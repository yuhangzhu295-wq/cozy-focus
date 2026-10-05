/// The installed companion packs, as one observable thing.
///
/// ## Why this layer exists
///
/// `InstalledPackRegistry` is plain Dart with a revision counter, deliberately:
/// the rules for installing, removing and repairing a selection are testable
/// without a container. What it cannot do on its own is two things — tell the UI
/// that something changed, and remember across a restart.
///
/// The state is the registry's revision, so a watcher rebuilds exactly when the
/// contents change and not otherwise.
///
/// ## Why this is the only signal, and the only writer
///
/// The alternative is each consumer being invalidated by hand from whatever
/// performed the import, which is how a stale cache bug is born: the catalog, the
/// visual registry, the availability cache and the avatar would each have to
/// remember, and the one that forgot would render a companion that is no longer
/// installed.
///
/// The same argument applies to the record file, so persistence lives here too.
/// A caller that installs through this controller gets the disk written for it,
/// and there is no path that mutates the registry and forgets to.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'companion_pack_root.dart';
import 'installed_pack_record_store.dart';
import 'installed_pack_recovery.dart';
import 'installed_pack_registry.dart';

/// Owns the registry, publishes its revision as state, and keeps the disk in step.
class InstalledPacksController extends StateNotifier<int> {
  /// [packRoot] is where installed packs live, or null when the app has not
  /// resolved one — in which case nothing is recovered and nothing is written,
  /// which is true, and better than guessing a path.
  InstalledPacksController({Directory? packRoot})
      : _packRoot = packRoot,
        super(0);

  final Directory? _packRoot;

  final InstalledPackRegistry _registry = InstalledPackRegistry();

  /// The registry itself. Read it for contents; watch the controller for changes.
  InstalledPackRegistry get registry => _registry;

  /// The revision consumers should watch.
  int get revision => state;

  /// What the last recovery found, or null before one has run.
  ///
  /// Exposed so a caller can report the packs that were dropped or could not be
  /// described, rather than the app silently offering fewer companions than are
  /// on disk.
  InstalledPackRecoveryResult? get recovery => _recovery;
  InstalledPackRecoveryResult? _recovery;

  /// Reads what is installed from disk.
  ///
  /// Called once, when the provider is created. Synchronous because the catalog
  /// is read synchronously and a launch must not show a companion list that is
  /// briefly missing everything the user installed.
  void recover() {
    final root = _packRoot;
    if (root == null) return;
    final result = InstalledPackRecovery.scan(root);
    _recovery = result;
    final adopted = _registry.adoptAll(result.packs);
    if (adopted) state = _registry.revision;
    // Written whenever the records and the directories disagreed — a pack
    // discovered by the scan, or a record whose pack is gone. Persisting the
    // discovered set means the next start reads one small JSON file instead of
    // re-hashing every frame, and it makes the name and species the app derived
    // durable rather than re-derived each launch.
    if (adopted || result.needsRewrite) _persist();
  }

  /// Installs [pack] and publishes the change.
  PackInstallOutcome install(InstalledCompanionPack pack) {
    final outcome = _registry.install(pack);
    if (outcome == PackInstallOutcome.installed) {
      state = _registry.revision;
      _persist();
    }
    return outcome;
  }

  /// Removes [packId] and publishes the change when something was removed.
  bool remove(String packId) {
    final removed = _registry.remove(packId);
    if (removed) {
      state = _registry.revision;
      _persist();
    }
    return removed;
  }

  /// Publishes a change made directly against [registry].
  ///
  /// For the import path, which mutates the registry across several steps and
  /// reports one change per import rather than one per step. Kept explicit so the
  /// ordinary paths above cannot forget to publish.
  void publish() {
    state = _registry.revision;
    _persist();
  }

  /// The ids currently installed.
  Set<String> get installedIds => _registry.packIds;

  /// The companion ids a user may select: the built-in three, plus anything
  /// installed.
  ///
  /// One place answers this, so the selector, the catalog and the availability
  /// resolver cannot disagree about what exists.
  Set<String> selectableIds(Set<String> builtInIds) =>
      {...builtInIds, ..._registry.packIds};

  void _persist() {
    final root = _packRoot;
    if (root == null) return;
    InstalledPackRecordStore.write(root, _registry.records);
  }
}

/// The single observable signal for installed packs.
///
/// Watch this to rebuild when a pack is installed or removed. Do not add a second
/// one: a second signal is a second thing to remember to publish.
final installedPacksProvider =
    StateNotifierProvider<InstalledPacksController, int>((ref) {
  final root = ref.read(companionPackRootProvider);
  final controller = InstalledPacksController(
    packRoot: root == null ? null : Directory(root),
  );
  // Recovers before the provider is handed out, so the first reader of the
  // catalog already sees everything that is installed.
  controller.recover();
  return controller;
});
