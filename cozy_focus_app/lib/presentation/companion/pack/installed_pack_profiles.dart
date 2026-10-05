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

import '../runtime/companion_action_manifest.dart';
import '../runtime/companion_frame_source.dart';
import '../runtime/companion_id.dart';
import '../runtime/companion_profile.dart';
import 'companion_pack_root.dart';
import 'installed_pack_registry.dart';
import 'installed_packs_provider.dart';

/// The installed packs' profiles, keyed by companion id.
///
/// Watches the installed-pack revision and re-reads when it changes, so a pack
/// installed while the app is running appears without a restart.
/// Everything the runtime needs about one installed pack.
///
/// Identity, the manifest a provider draws from, and where the bytes are. Kept
/// together because they come from one directory and must agree.
class InstalledPackRuntime {
  final CompanionProfile profile;
  final CompanionActionManifest manifest;
  final CompanionFrameSource frameSource;

  const InstalledPackRuntime({
    required this.profile,
    required this.manifest,
    required this.frameSource,
  });
}

class InstalledPackProfiles
    extends StateNotifier<Map<CompanionId, InstalledPackRuntime>> {
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

    final loaded = <CompanionId, InstalledPackRuntime>{};
    for (final pack in registry.packs) {
      final runtime = _runtimeFor(root, pack);
      if (runtime != null) loaded[CompanionId(pack.packId)] = runtime;
    }
    // A pack whose manifest cannot be read is left out rather than faked. It is
    // still installed, and the installer's validation is what should have caught
    // a bad manifest — so reaching here means the files changed underneath us,
    // and offering the companion would mean rendering something unverified.
    if (mounted) state = loaded;
  }

  /// Reads one pack's identity and manifest.
  InstalledPackRuntime? _runtimeFor(String root, InstalledCompanionPack pack) {
    final dir = '$root/${pack.packId}';
    final file = File('$dir/${InstalledPackProfiles.manifestName}');
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final manifest = CompanionActionManifest.fromJson(json);
      if (manifest.posePack.isEmpty) return null;
      return InstalledPackRuntime(
        profile: CompanionProfile(
          id: CompanionId(pack.packId),
          displayName: pack.displayName,
          posePack: manifest.posePack,
          species: pack.species,
        ),
        manifest: manifest,
        frameSource: CompanionFrameSource.directory(dir),
      );
    } catch (_) {
      return null;
    }
  }

  static const String manifestName = 'manifest.json';
}

/// The installed packs' profiles. Read synchronously; loaded asynchronously.
final installedPackProfilesProvider = StateNotifierProvider<
    InstalledPackProfiles, Map<CompanionId, InstalledPackRuntime>>(
  (ref) => InstalledPackProfiles(ref),
);
