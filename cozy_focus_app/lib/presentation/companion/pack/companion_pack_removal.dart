/// Removing an installed companion pack, in the order that keeps the app valid.
///
/// ## The order, and why it is this order
///
/// If the pack being removed is the *selected* companion, the selection is
/// repaired **before** anything is removed. Doing it the other way round leaves a
/// window in which the app is pointing at a companion that no longer exists, and
/// every consumer of the selection would then have to defend against that - which
/// is the shape of bug the brief's rule exists to prevent.
///
/// Then the metadata goes, then the files. Metadata first, so a failure to delete
/// from disk cannot leave the app offering a pack whose files are gone; the pack
/// simply stops being installed, and the leftover directory is inert.
library;

import 'dart:io';

import '../companion_selection.dart';
import '../runtime/companion_id.dart';
import 'companion_pack_installer.dart';
import 'installed_pack_registry.dart';
import 'installed_packs_provider.dart';

/// What a removal did.
class CompanionPackRemovalReport {
  final bool removed;

  /// The companion selected afterwards, when the removed one had been selected.
  final String? selectionAfter;

  const CompanionPackRemovalReport(this.removed, {this.selectionAfter});

  @override
  String toString() => 'CompanionPackRemovalReport(removed: $removed'
      '${selectionAfter == null ? '' : ', selection: $selectionAfter'})';
}

/// Removes an installed pack safely.
abstract final class CompanionPackRemoval {
  const CompanionPackRemoval._();

  /// Removes [packId], repairing the selection first when it is the one selected.
  static Future<CompanionPackRemovalReport> remove({
    required String packId,
    required InstalledPacksController packs,
    required CompanionSelection selection,
    required Directory installRoot,
    required Set<String> builtInIds,
    required String defaultId,
  }) async {
    // A pack the app cannot read is not in the registry, but its directory is
    // still on disk and still occupies the id. Refusing to remove it left the user
    // with no way out: the import refuses that id and the picker does not list it,
    // so the broken install can never be cleared. Removal has to work for the
    // directories the app cannot describe, or the state is permanent.
    final onDisk = Directory('${installRoot.path}/$packId').existsSync();
    if (!packs.installedIds.contains(packId) && !onDisk) {
      return const CompanionPackRemovalReport(false);
    }

    String? selectionAfter;
    if (selection.selected.value == packId) {
      // Repaired first. `installedIds` still contains the pack here, so it is
      // excluded explicitly - handing over a set that names the pack being
      // removed would let the repair pick the companion that is going away.
      final repair = CompanionSelectionRepair.afterRemoval(
        selected: packId,
        removedId: packId,
        installedIds: packs.installedIds.where((id) => id != packId).toSet(),
        builtInIds: builtInIds,
        defaultId: defaultId,
      );
      if (repair.selected != null) {
        await selection.select(CompanionId(repair.selected!));
        selectionAfter = repair.selected;
      }
    }

    // Metadata, so the app stops offering it even if the files cannot be removed.
    packs.remove(packId);

    // Files. A failure here is reported through the return value rather than
    // thrown: the pack is already uninstalled as far as the app is concerned.
    await CompanionPackInstaller.uninstall(
      packId: packId,
      installRoot: installRoot,
    );

    return CompanionPackRemovalReport(true, selectionAfter: selectionAfter);
  }
}
