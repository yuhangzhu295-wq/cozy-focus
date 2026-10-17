import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../domain/models/enums.dart';
import '../local/app_database.dart';
import 'backup_format.dart';

/// A refusal the UI can show as-is.
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

/// What a completed restore did.
class RestoreReport {
  final int rowsRestored;
  final int packsRestored;

  const RestoreReport({
    required this.rowsRestored,
    required this.packsRestored,
  });

  @override
  String toString() =>
      'RestoreReport($rowsRestored rows, $packsRestored pack files)';
}

/// Reads and writes the whole local dataset.
///
/// ## The one rule
///
/// **Nothing is deleted until a complete, checksum-verified replacement is in
/// hand, and the replacement is applied inside a transaction.** A corrupt file,
/// a wrong version or a failure halfway through leaves the current data exactly
/// as it was.
///
/// ## What it deliberately does not do
///
/// No merge. V1 replaces the dataset wholesale after an explicit confirmation,
/// because merging two histories would have to decide which of two focus
/// sessions is the real one, and guessing that is how a user loses hours.
abstract final class BackupService {
  const BackupService._();

  /// Matches `version:` in `pubspec.yaml`. Written into the file so a future
  /// reader can tell which build produced it; it is not used for validation.
  static const String appVersion = '1.0.0+1';

  /// A cap on the pack payload. Built-in packs are bundled assets and are not
  /// part of the user's data; only packs under the writable root are exported.
  /// A handful of PNG frames is small, and 32 MB stops a pathological directory
  /// from becoming an unbounded backup before any allocation happens.
  static const int maxPackBytes = BackupFormat.maxPackBytes;
  static const int maxPackFiles = BackupFormat.maxPackFiles;

  // ── export ──────────────────────────────────────────────────────────────

  /// Serialises the database and the writable pack root.
  static Future<Uint8List> export({
    required AppDatabase db,
    Directory? packRoot,
    DateTime? now,
  }) async {
    final tables = <String, dynamic>{};
    for (final table in BackupFormat.tables) {
      final rows =
          await db.customSelect('SELECT * FROM "$table" ORDER BY rowid').get();
      tables[table] = [
        for (final row in rows)
          if (table != 'app_settings' ||
              !BackupFormat.internalSettingsKeys.contains(row.data['key']))
            row.data,
      ];
    }

    final packs = _exportPacks(packRoot);

    final payload = <String, dynamic>{
      'format': BackupFormat.format,
      'formatVersion': BackupFormat.version,
      'appSchemaVersion': db.schemaVersion,
      'appVersion': appVersion,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'tables': tables,
      'packs': packs,
    };
    payload['checksum'] = checksumFor(payload);

    return Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  }

  static Map<String, dynamic> _exportPacks(Directory? root) {
    if (root == null || !root.existsSync()) {
      return {'ids': <String>[], 'files': <String, String>{}};
    }

    final files = <String, String>{};
    var bytes = 0;
    final ids = <String>{};

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File) continue;
      final relative = _relativeName(root.path, entity.path);
      if (relative == null || !isSafePackPath(relative)) continue;
      final length = entity.lengthSync();
      bytes += length;
      if (bytes > maxPackBytes || files.length >= maxPackFiles) {
        throw const BackupException(
          '伙伴包文件过多或过大，无法写入备份。请移除不需要的伙伴包后重试。',
        );
      }
      files[relative] = base64Encode(entity.readAsBytesSync());
      final first = relative.split('/').first;
      if (first != 'installed_packs.json' && !first.contains('.')) {
        ids.add(first);
      }
    }

    return {'ids': ids.toList()..sort(), 'files': files};
  }

  // ── restore ─────────────────────────────────────────────────────────────

  /// Whether anything would lose work if the dataset were replaced now.
  ///
  /// Three states qualify, and the first version only checked two of them:
  ///
  /// * a **live** focus session (`running`, `paused`) — the engine holds its
  ///   row and would write a second, orphaned session when it finishes;
  /// * an **unfinished** session (`finishing`) — it ended but was never saved,
  ///   so its focus time exists only in that row;
  /// * a **running rest** — replacing the row would lose a rest the user is
  ///   still in.
  ///
  /// Refusing is the only honest option: the user can stop first.
  static Future<bool> hasUnsettledWork(AppDatabase db) async {
    final statuses = <String>{
      ...kLiveSessionStatusNames,
      ...kUnfinishedSessionStatusNames,
    }.toList();
    final placeholders = List.filled(statuses.length, '?').join(',');
    final focus = await db.customSelect(
      'SELECT COUNT(*) AS c FROM focus_sessions '
      'WHERE status IN ($placeholders)',
      variables: [for (final name in statuses) Variable<String>(name)],
    ).getSingle();
    final rest = await db
        .customSelect(
          "SELECT COUNT(*) AS c FROM rest_sessions WHERE status = 'running'",
        )
        .getSingle();
    return (focus.data['c'] as int? ?? 0) > 0 ||
        (rest.data['c'] as int? ?? 0) > 0;
  }

  /// Applies a validated backup, replacing the current dataset.
  ///
  /// The caller must have shown [BackupPreview] and received an explicit
  /// confirmation. This method re-checks the two things that can change between
  /// preview and apply: a session becoming live, and the row shape no longer
  /// matching the schema.
  static Future<RestoreReport> restore({
    required AppDatabase db,
    required Map<String, dynamic> payload,
    Directory? packRoot,
  }) async {
    if (await hasUnsettledWork(db)) {
      throw const BackupException(
        '还有未结束的专注或休息。请先保存当前专注、结束休息，再恢复备份。',
      );
    }

    final tables = payload['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const BackupException('备份缺少数据表。');
    }

    // Validate every table's columns against the live schema before deleting
    // anything. A backup that names a column this build does not have would
    // otherwise fail halfway through the replacement.
    final columns = <String, List<String>>{};
    for (final table in BackupFormat.tables) {
      columns[table] = await _columnsOf(db, table);
      final rows = tables[table];
      if (rows is! List) {
        throw BackupException('备份缺少表 $table。');
      }
      for (final row in rows) {
        if (row is! Map<String, dynamic>) {
          throw BackupException('表 $table 含无效记录。');
        }
        for (final key in row.keys) {
          if (!columns[table]!.contains(key)) {
            throw BackupException(
              '备份里的表 $table 含当前版本没有的字段 $key，已拒绝恢复。',
            );
          }
        }
      }
    }

    // Stage the packs, swap them into place, then commit the database.
    //
    // The database transaction is the only atomic step here; a directory rename
    // is not. The order is chosen so every failure has a recovery path:
    //
    //   stage -> journal -> swap -> DB transaction -> cleanup
    //
    // * a swap failure restores the old root before anything else changes;
    // * a DB failure swaps the old root back;
    // * a process death at any point is resolved on the next start by
    //   [recoverInterruptedRestore], using the epoch written into `app_settings`
    //   *inside* the same transaction as the data.
    //
    // The previous version committed the database first and kept an in-memory
    // snapshot for a pack failure. That could not survive a process death, and
    // re-applying the snapshot would also have deleted anything another
    // controller wrote between the snapshot and the rollback.
    final stagedPacks = await _stagePacks(packRoot, payload['packs']);
    final epoch = const Uuid().v4();
    final swap =
        stagedPacks == null ? null : await _swapPacksIn(stagedPacks, epoch);

    try {
      await db.transaction(() async {
        // Re-check inside the transaction. The first check happened before
        // column validation and pack staging - a session can start in that
        // window, and deleting its row under the engine is exactly the loss
        // this refuses.
        if (await hasUnsettledWork(db)) {
          throw const BackupException(
            '恢复开始前出现了未结束的专注或休息，已取消，原数据没有改动。',
          );
        }
        for (final table in BackupFormat.tablesInDeleteOrder) {
          await db.customStatement('DELETE FROM "$table"');
        }
        for (final table in BackupFormat.tables) {
          final rows = tables[table] as List;
          final cols = columns[table]!;
          for (final raw in rows) {
            final row = raw as Map<String, dynamic>;
            // Only columns the row actually carries. A future schema may add a
            // column with a default; omitting it lets the default apply instead
            // of writing null into a NOT NULL column.
            final names = cols.where(row.containsKey).toList();
            if (names.isEmpty) continue;
            final sql = 'INSERT INTO "$table" '
                '(${names.map((n) => '"$n"').join(',')}) '
                'VALUES (${List.filled(names.length, '?').join(',')})';
            await db.customStatement(
              sql,
              [for (final name in names) row[name]],
            );
          }
        }

        // Verify the counts before the transaction commits. A mismatch means
        // something rejected rows silently, which is a failure, not a success
        // with fewer rows.
        for (final table in BackupFormat.tables) {
          final expected = (tables[table] as List).length;
          final actual = await db
              .customSelect('SELECT COUNT(*) AS c FROM "$table"')
              .getSingle();
          if ((actual.data['c'] as int? ?? 0) != expected) {
            throw BackupException(
              '恢复 $table 时写入的行数不符（期望 $expected），已回滚。',
            );
          }
        }

        // The commit marker. It is in this transaction, so it cannot claim a
        // commit that did not happen, and a later start can tell whether the
        // packs it is looking at belong to the data it is looking at.
        await db.customStatement(
          'INSERT OR REPLACE INTO app_settings (key, value) '
          "VALUES ('backup_restore_epoch', ?)",
          [epoch],
        );
      });
    } catch (error) {
      if (swap != null) await _swapPacksBack(swap);
      if (error is BackupException) rethrow;
      throw BackupException('恢复失败，原数据没有改动：$error');
    }

    if (swap != null) await _finishSwap(swap);
    final rows = (tables.values)
        .whereType<List>()
        .fold<int>(0, (sum, list) => sum + list.length);
    return RestoreReport(
      rowsRestored: rows,
      packsRestored: stagedPacks?.fileCount ?? 0,
    );
  }

  /// Finishes or rolls back a restore that a previous process did not complete.
  ///
  /// Called once at startup, before the app opens its own database connection.
  /// The journal is written before the pack swap; the epoch is written in the
  /// database transaction. Comparing the two is enough to decide which half is
  /// the truth:
  ///
  /// * epoch present -> the data committed, so the new packs are the right ones;
  /// * epoch absent  -> the data rolled back, so the old packs must come back.
  static Future<void> recoverInterruptedRestore({
    required AppDatabase db,
    Directory? packRoot,
  }) async {
    if (packRoot == null) return;
    final live = packRoot;
    final journal = File('${live.parent.path}/.cozy_restore_journal.json');
    final previous = Directory('${live.parent.path}/.cozy_restore_previous');

    if (!journal.existsSync()) {
      // No journal means no restore was in flight. A leftover previous
      // directory is the residue of a restore whose cleanup failed; the new
      // state is already committed, so the residue is garbage.
      try {
        if (await previous.exists()) await previous.delete(recursive: true);
      } catch (_) {}
      return;
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(await journal.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      await _clearJournal(journal);
      return;
    }

    final epoch = data['epoch'];
    String? committed;
    try {
      final row = await db
          .customSelect(
            "SELECT value FROM app_settings WHERE key = 'backup_restore_epoch'",
          )
          .getSingleOrNull();
      committed = row?.data['value'] as String?;
    } catch (_) {
      committed = null;
    }

    if (epoch is String && epoch == committed) {
      // The data committed. Keep the new packs; drop the old ones.
      try {
        if (await previous.exists()) await previous.delete(recursive: true);
      } catch (_) {}
    } else {
      // The data did not commit. Put the old packs back - but only if there is
      // an old root to put back. A crash before the first rename leaves `live`
      // untouched, and deleting it here would destroy the user's packs.
      try {
        if (await previous.exists()) {
          if (await live.exists()) await live.delete(recursive: true);
          await previous.rename(live.path);
        }
      } catch (_) {}
      final stagingPath = data['staging'];
      if (stagingPath is String) {
        try {
          final staging = Directory(stagingPath);
          if (await staging.exists()) await staging.delete(recursive: true);
        } catch (_) {}
      }
    }
    await _clearJournal(journal);
  }

  static Future<List<String>> _columnsOf(AppDatabase db, String table) async {
    final rows = await db.customSelect('PRAGMA table_info("$table")').get();
    return [for (final row in rows) row.data['name'] as String];
  }

  // ── packs ───────────────────────────────────────────────────────────────

  /// A staged replacement, or null when the backup carried no pack root.
  static Future<_StagedPacks?> _stagePacks(
    Directory? root,
    Object? raw,
  ) async {
    if (root == null || raw is! Map<String, dynamic>) return null;
    final files = raw['files'];
    if (files is! Map<String, dynamic>) return null;
    if (files.length > maxPackFiles) {
      throw const BackupException('备份的伙伴包文件数量超过上限，已拒绝恢复。');
    }

    final parent = root.parent;
    final staging = Directory(
      '${parent.path}/.cozy_restore_${DateTime.now().microsecondsSinceEpoch}',
    );
    await staging.create(recursive: true);
    final stagingRoot = staging.absolute.path;

    var bytes = 0;
    try {
      for (final entry in files.entries) {
        final relative = entry.key;
        if (!isSafePackPath(relative)) {
          throw BackupException('备份含不安全的文件路径：$relative');
        }
        final encoded = entry.value;
        if (encoded is! String) {
          throw const BackupException('备份的伙伴包文件无效。');
        }
        // Check the *decoded* size before decoding. Base64 is 4 chars per 3
        // bytes, so the estimate is exact enough to refuse a bomb before it is
        // allocated.
        final estimated = (encoded.length ~/ 4) * 3;
        if (bytes + estimated > maxPackBytes) {
          throw const BackupException('备份的伙伴包超过大小上限，已拒绝恢复。');
        }
        final data = base64Decode(encoded);
        bytes += data.length;
        if (bytes > maxPackBytes) {
          throw const BackupException('备份的伙伴包超过大小上限，已拒绝恢复。');
        }
        final target = File('${staging.path}/$relative');
        // Defence in depth: after canonicalisation the target must still be
        // strictly inside the staging root, whatever the path string said.
        // `isWithin` normalises separators, which a string prefix does not:
        // Dart can return `C:\a/b` from `absolute.path` on Windows.
        if (!p.isWithin(stagingRoot, target.absolute.path)) {
          throw BackupException('备份的文件路径逃出了暂存目录：$relative');
        }
        await target.parent.create(recursive: true);
        await target.writeAsBytes(data, flush: true);
      }
    } catch (_) {
      await _discardStaged(_StagedPacks(staging, root, 0));
      rethrow;
    }

    return _StagedPacks(staging, root, files.length);
  }

  /// Writes the journal, then swaps the staged root into place.
  ///
  /// The journal is written *before* the first rename, so a process death
  /// between the two renames is still recoverable: the old root is in
  /// `previous`, the new one in `staging`, and the journal names both.
  static Future<_PackSwap> _swapPacksIn(
    _StagedPacks staged,
    String epoch,
  ) async {
    final live = staged.liveRoot;
    final previous = Directory('${live.parent.path}/.cozy_restore_previous');
    final journal = File('${live.parent.path}/.cozy_restore_journal.json');

    if (await previous.exists()) {
      await previous.delete(recursive: true);
    }
    await _writeJournal(journal, {
      'epoch': epoch,
      'previous': previous.path,
      'staging': staged.staging.path,
    });

    final hadLive = await live.exists();
    if (hadLive) {
      await live.rename(previous.path);
    }
    try {
      await staged.staging.rename(live.path);
    } catch (_) {
      if (hadLive && await previous.exists()) {
        await previous.rename(live.path);
      }
      await _clearJournal(journal);
      rethrow;
    }
    return _PackSwap(live: live, previous: previous, journal: journal);
  }

  /// Puts the old pack root back after the database transaction failed.
  static Future<void> _swapPacksBack(_PackSwap swap) async {
    try {
      if (await swap.live.exists()) {
        await swap.live.delete(recursive: true);
      }
      if (await swap.previous.exists()) {
        await swap.previous.rename(swap.live.path);
      }
    } catch (_) {
      // The journal stays until the next start, which will retry this exact
      // recovery with the same information.
      return;
    }
    await _clearJournal(swap.journal);
  }

  /// Committed: the old root and the journal are garbage.
  static Future<void> _finishSwap(_PackSwap swap) async {
    try {
      if (await swap.previous.exists()) {
        await swap.previous.delete(recursive: true);
      }
    } catch (_) {
      // A leftover previous directory is harmless; the next start removes it.
    }
    await _clearJournal(swap.journal);
  }

  static Future<void> _writeJournal(
    File journal,
    Map<String, dynamic> data,
  ) async {
    final temp = File('${journal.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    // Rename is the atomic step: a half-written journal must never be read.
    await temp.rename(journal.path);
  }

  static Future<void> _clearJournal(File journal) async {
    try {
      if (await journal.exists()) await journal.delete();
    } catch (_) {}
  }

  static Future<void> _discardStaged(_StagedPacks? staged) async {
    if (staged == null) return;
    if (await staged.staging.exists()) {
      await staged.staging.delete(recursive: true);
    }
  }

  static String? _relativeName(String root, String path) {
    final normalisedRoot = root.replaceAll(r'\', '/');
    final normalised = path.replaceAll(r'\', '/');
    if (!normalised.startsWith('$normalisedRoot/')) return null;
    return normalised.substring(normalisedRoot.length + 1);
  }
}

class _StagedPacks {
  final Directory staging;
  final Directory liveRoot;
  final int fileCount;

  const _StagedPacks(this.staging, this.liveRoot, this.fileCount);
}

class _PackSwap {
  final Directory live;
  final Directory previous;
  final File journal;

  const _PackSwap({
    required this.live,
    required this.previous,
    required this.journal,
  });
}
