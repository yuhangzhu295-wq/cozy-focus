import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'runtime/companion_catalog.dart';
import 'runtime/companion_id.dart';
import 'runtime/companion_manifest_data.dart';
import 'pack/installed_packs_provider.dart';
import 'pack/installed_pack_profiles.dart';

/// Persistence for the one piece of state the companion picker owns.
///
/// ## Why this is not a business table
///
/// Which companion the user is looking at is a **presentation preference**. It
/// changes nothing about XP, sessions, rewards, craft or inventory — the shared
/// `PetProgress` is untouched by it, and every companion reads the same progress.
///
/// Storing it in the business schema would therefore make it look like business
/// truth and would invite exactly the per-companion economy the spec forbids. So
/// it lives in its own small file, and the interface is deliberately two methods
/// wide: the runtime can only ever read or write one id.
abstract class CompanionSelectionStore {
  /// The stored selection, or `null` when nothing has been chosen yet.
  Future<CompanionId?> read();

  /// Persists [id].
  Future<void> write(CompanionId id);
}

/// A store that keeps the selection in memory only.
///
/// Used by tests, and as the fallback when the file system is unavailable — in
/// which case the app still works and simply does not remember the choice across
/// restarts, which is a truthful degradation rather than a crash.
class InMemoryCompanionSelectionStore implements CompanionSelectionStore {
  CompanionId? _id;

  InMemoryCompanionSelectionStore([this._id]);

  @override
  Future<CompanionId?> read() async => _id;

  @override
  Future<void> write(CompanionId id) async => _id = id;
}

/// A store backed by a single JSON file in the app's documents directory.
class FileCompanionSelectionStore implements CompanionSelectionStore {
  static const String fileName = 'companion_selection.json';
  static const String _key = 'selectedCompanionId';

  final Directory? directoryOverride;

  FileCompanionSelectionStore({this.directoryOverride});

  Future<File> _file() async {
    final dir = directoryOverride ?? await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, fileName));
  }

  @override
  Future<CompanionId?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final raw = decoded[_key];
      if (raw is! String) return null;
      return CompanionId(raw);
    } catch (_) {
      // A corrupt or unreadable preference file must never break the app. The
      // caller falls back to the default companion.
      return null;
    }
  }

  @override
  Future<void> write(CompanionId id) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode({_key: id.value}));
    } catch (_) {
      // Losing the preference is acceptable; losing the session is not.
    }
  }
}

/// The store the app uses. Overridden in tests.
final companionSelectionStoreProvider = Provider<CompanionSelectionStore>(
  (ref) => FileCompanionSelectionStore(),
);

/// The currently selected companion.
///
/// Defaults to the shipped default companion, and resolves an unknown stored id
/// to that same default — so a selection that no longer exists (a companion
/// removed in a later build, or a hand-edited file) degrades safely instead of
/// leaving the user with no companion at all.
class CompanionSelection extends StateNotifier<CompanionId> {
  final CompanionSelectionStore _store;

  /// The companion ids this app may select: the built-in profiles plus anything
  /// installed.
  ///
  /// Passed in rather than read from the static built-in table, because that
  /// table cannot know about a pack the user installed a moment ago — and a
  /// selection that refuses a companion the app can render is exactly the bug
  /// this exists to prevent.
  final Set<String> _selectable;

  CompanionSelection(this._store, {Set<String>? selectableIds})
      : _selectable = selectableIds ??
            CompanionManifestData.profiles.keys.map((id) => id.value).toSet(),
        super(CompanionManifestData.defaultProfileId) {
    _restore();
  }

  /// The companion currently selected.
  ///
  /// Public because the removal path has to ask whether the pack it is about to
  /// delete is the one in use, and `state` is protected to everything outside a
  /// subclass.
  CompanionId get selected => state;

  Future<void> _restore() async {
    final stored = await _store.read();
    // Set on every path, including the ones that keep the default: "there is
    // nothing stored" and "there is something unknown stored" are both answers,
    // and a reader waiting on this needs either of them.
    if (stored == null) {
      _restored = true;
      return;
    }
    // The catalog is the authority on what exists; an unknown id is ignored
    // rather than trusted.
    if (!_isKnown(stored)) {
      _restored = true;
      return;
    }
    if (mounted) state = stored;
    _restored = true;
  }

  bool _isKnown(CompanionId id) => _selectable.contains(id.value);

  bool _restored = false;

  /// Whether the stored selection has been read yet.
  ///
  /// False until [_restore] finishes, and `state` reads as the default until then.
  /// Anything that *writes* based on the selection has to wait for this, or a slow
  /// start would be read as "the user chose the default" — which is how a
  /// reconciliation of the adopted pet would silently revert a user's companion.
  /// Found while writing that reconciliation: a stored `cat` came back as `Mochi`.
  bool get restored => _restored;

  /// Selects [id], persisting it. An unknown id is refused rather than stored.
  Future<bool> select(CompanionId id) async {
    if (!_isKnown(id)) return false;
    if (state == id) return true;
    state = id;
    await _store.write(id);
    return true;
  }
}

final companionSelectionProvider =
    StateNotifierProvider<CompanionSelection, CompanionId>((ref) {
  // Watch the installed set so a pack installed while the app is running becomes
  // selectable without a restart. Rebuilding recreates the notifier, which
  // re-reads the persisted selection.
  ref.watch(installedPacksProvider);
  return CompanionSelection(
    ref.watch(companionSelectionStoreProvider),
    selectableIds: ref.read(installedPacksProvider.notifier).selectableIds(
          CompanionManifestData.profiles.keys.map((id) => id.value).toSet(),
        ),
  );
});

/// The catalog the presentation layer reads.
///
/// A provider rather than a direct call, so a test can substitute a catalog and
/// assert that pages follow the *data* — including a companion this build has
/// never heard of.
final companionCatalogProvider = Provider<CompanionCatalog>((ref) {
  // Watch the installed profiles, so a pack installed while the app is running
  // appears in the catalog without a restart. The recipes are shared, so an
  // installed companion behaves through the same data as a built-in one.
  final installed = ref.watch(installedPackProfilesProvider);
  return bundledCompanionCatalog().withProfiles({
    for (final entry in installed.entries) entry.key: entry.value.profile,
  });
});

/// The selected companion's display name.
///
/// Every page that names the companion in copy reads this instead of writing
/// "Mochi", so choosing the cat does not leave the app calling it Mochi. The name
/// is catalog data, so a new companion is named correctly with no page edit.
final companionDisplayNameProvider = Provider<String>((ref) {
  final catalog = ref.watch(companionCatalogProvider);
  return catalog.profileFor(ref.watch(companionSelectionProvider)).displayName;
});
