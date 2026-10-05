/// The profiles of installed companion packs, ready for a synchronous catalog.
///
/// ## Why the loading is separated from the reading
///
/// `CompanionCatalog` is synchronous and many callers depend on that — a build
/// must not wait on disk. An installed pack's identity lives in a manifest file,
/// which is an asynchronous read. So the read happens once, when the installed
/// set changes, and this exposes the result as a plain map a build can read.
///
/// Until the read completes the map is empty, which is the honest answer: a pack
/// that has not been loaded is not yet a companion the app can offer.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../runtime/companion_id.dart';
import '../runtime/companion_profile.dart';
import 'installed_pack_registry.dart';
import 'installed_packs_provider.dart';

/// The directory installed packs live under, or null when none is known.
///
/// A plain value rather than an asynchronous lookup: the catalog is synchronous
/// and a build must not await a path. The app resolves it once at startup and
/// overrides this; until it does, nothing is installed — which is true, and is a
/// better answer than a guess.
final companionPackRootProvider = Provider<String?>((ref) => null);

/// The installed packs' profiles, keyed by companion id.
///
/// Watches the installed-pack revision and re-reads when it changes, so a pack
/// installed while the app is running appears without a restart.
class InstalledPackProfiles
    extends StateNotifier<Map<CompanionId, CompanionProfile>> {
  InstalledPackProfiles(this._ref) : super(const {}) {
    _ref.listen<int>(installedPacksProvider, (_, __) => _load());
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final root = _ref.read(companionPackRootProvider);
    final registry = _ref.read(installedPacksProvider.notifier).registry;
    if (root == null || registry.packs.isEmpty) {
      if (mounted && state.isNotEmpty) state = const {};
      return;
    }

    final profiles = <CompanionId, CompanionProfile>{};
    for (final pack in registry.packs) {
      final profile = _profileFor(root, pack);
      if (profile != null) profiles[CompanionId(pack.packId)] = profile;
    }
    // A pack whose manifest cannot be read is left out rather than faked. It is
    // still installed, and the installer's validation is what should have caught
    // a bad manifest — so reaching here means the files changed underneath us,
    // and offering the companion would mean rendering something unverified.
    if (mounted) state = profiles;
  }

  /// Reads one pack's identity from its manifest.
  CompanionProfile? _profileFor(String root, InstalledCompanionPack pack) {
    final file =
        File('$root/${pack.packId}/${InstalledPackProfiles.manifestName}');
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final posePack = json['posePack'];
      if (posePack is! String || posePack.isEmpty) return null;
      return CompanionProfile(
        id: CompanionId(pack.packId),
        displayName: pack.displayName,
        posePack: posePack,
        species: pack.species,
      );
    } catch (_) {
      return null;
    }
  }

  static const String manifestName = 'manifest.json';
}

/// The installed packs' profiles. Read synchronously; loaded asynchronously.
final installedPackProfilesProvider = StateNotifierProvider<
    InstalledPackProfiles, Map<CompanionId, CompanionProfile>>(
  (ref) => InstalledPackProfiles(ref),
);
