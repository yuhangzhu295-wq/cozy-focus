/// The installed companion packs, as one observable thing.
///
/// ## Why this layer exists
///
/// `InstalledPackRegistry` is plain Dart with a revision counter, deliberately:
/// the rules for installing, removing and repairing a selection are testable
/// without a container. What it cannot do on its own is tell the UI that
/// something changed.
///
/// This is that signal, and it is deliberately the **only** one. The alternative
/// is each consumer being invalidated by hand from whatever performed the import,
/// which is how a stale cache bug is born: the catalog, the visual registry, the
/// availability cache and the avatar would each have to remember, and the one that
/// forgot would render a companion that is no longer installed.
///
/// The state is the registry's revision, so a watcher rebuilds exactly when the
/// contents change and not otherwise.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'installed_pack_registry.dart';

/// Owns the registry and publishes its revision as state.
class InstalledPacksController extends StateNotifier<int> {
  InstalledPacksController() : super(0);

  final InstalledPackRegistry _registry = InstalledPackRegistry();

  /// The registry itself. Read it for contents; watch the controller for changes.
  InstalledPackRegistry get registry => _registry;

  /// The revision consumers should watch.
  int get revision => state;

  /// Installs [pack] and publishes the change.
  PackInstallOutcome install(InstalledCompanionPack pack) {
    final outcome = _registry.install(pack);
    if (outcome == PackInstallOutcome.installed) {
      state = _registry.revision;
    }
    return outcome;
  }

  /// Removes [packId] and publishes the change when something was removed.
  bool remove(String packId) {
    final removed = _registry.remove(packId);
    if (removed) state = _registry.revision;
    return removed;
  }

  /// Publishes a change made directly against [registry].
  ///
  /// For the import path, which mutates the registry across several steps and
  /// reports one change per import rather than one per step. Kept explicit so the
  /// ordinary paths above cannot forget to publish.
  void publish() => state = _registry.revision;

  /// The ids currently installed.
  Set<String> get installedIds => _registry.packIds;

  /// The companion ids a user may select: the built-in three, plus anything
  /// installed.
  ///
  /// One place answers this, so the selector, the catalog and the availability
  /// resolver cannot disagree about what exists.
  Set<String> selectableIds(Set<String> builtInIds) =>
      {...builtInIds, ..._registry.packIds};
}

/// The single observable signal for installed packs.
///
/// Watch this to rebuild when a pack is installed or removed. Do not add a second
/// one: a second signal is a second thing to remember to publish.
final installedPacksProvider =
    StateNotifierProvider<InstalledPacksController, int>(
        (ref) => InstalledPacksController());
