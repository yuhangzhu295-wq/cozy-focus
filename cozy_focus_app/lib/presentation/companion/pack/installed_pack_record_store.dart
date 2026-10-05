/// The installed packs, written down so a restart does not forget them.
///
/// ## Why this file has to exist
///
/// The registry is in memory. Without a durable record, every pack a user
/// installed disappears when the app is killed: the files are still on disk, but
/// nothing knows they are there, so the catalog does not offer them and the
/// persisted selection is silently dropped as an unknown id. That is what
/// happened on the device — the pack sat in `companion_packs/`, the selection
/// file said `xiaomao`, and the app opened as Mochi.
///
/// ## Why it is not inside a pack
///
/// It sits *beside* the pack directories, at the pack root, because a pack
/// directory is exactly what gets exported. Anything inside one travels with the
/// user's `.cozy_pet`, and an install record is not part of a companion.
///
/// ## Why it is not a database table
///
/// The brief's rule: the files and their validated manifest are the asset truth,
/// and pack contents must not be copied into the database. This is metadata
/// *about* installed packs, in one small JSON file next to them, where it can be
/// inspected and where it cannot drift from the directories it describes — a
/// record whose directory is gone is dropped on load.
library;

import 'dart:convert';
import 'dart:io';

import 'installed_pack_registry.dart';

/// Reads and writes the install records at a pack root.
abstract final class InstalledPackRecordStore {
  const InstalledPackRecordStore._();

  /// The file's name, inside the pack root.
  static const String fileName = 'installed_packs.json';

  static File fileFor(Directory packRoot) => File('${packRoot.path}/$fileName');

  /// The records, or an empty list when there are none to trust.
  ///
  /// A corrupt or unreadable file yields nothing rather than throwing: losing the
  /// list means the app falls back to scanning the directories, which is a
  /// truthful degradation and not a crash.
  static List<InstalledCompanionPack> read(Directory packRoot) {
    try {
      final file = fileFor(packRoot);
      if (!file.existsSync()) return const [];
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return const [];
      final raw = decoded['packs'];
      if (raw is! List) return const [];
      return [
        for (final entry in raw)
          if (InstalledCompanionPack.fromJson(entry) case final pack?) pack,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Writes [records], or removes the file when there are none.
  ///
  /// Removing rather than leaving an empty list, so a clean app has no stray
  /// file claiming to describe nothing.
  static void write(Directory packRoot, List<InstalledCompanionPack> records) {
    try {
      final file = fileFor(packRoot);
      if (records.isEmpty) {
        if (file.existsSync()) file.deleteSync();
        return;
      }
      file.writeAsStringSync(jsonEncode({
        'version': 1,
        'packs': [for (final record in records) record.toJson()],
      }));
    } catch (_) {
      // Losing the record is survivable — the next start scans the directories —
      // and failing an install over it would not be.
    }
  }
}
