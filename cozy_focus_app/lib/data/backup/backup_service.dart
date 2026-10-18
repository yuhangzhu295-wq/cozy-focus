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

    // Refuse to start a second restore while an earlier one is unresolved.
    // SQLite serialises database writes, not filesystem writes: two restores
    // could share a journal and a `previous` directory, and one would then
    // clean up the other's evidence. The journal is the signal - it exists only
    // while a swap may be pending.
    if (packRoot != null) {
      final journalPath =
          File('${packRoot.parent.path}/.cozy_restore_journal.json');
      if (journalPath.existsSync()) {
        throw const BackupException(
          '上一次恢复还没有收尾。请先重启一次应用，让它完成或回退，再恢复备份。',
        );
      }
    }

    final tables = payload['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const BackupException('备份缺少数据表。');
    }

    // Validate every row against the live schema before deleting anything.
    //
    // Three checks, not one. A backup that names a column this build does not
    // have would fail halfway through the replacement. A null in a NOT NULL
    // column would fail the insert. And a value whose JSON type does not match
    // the column's affinity would *succeed* at write time and then explode in a
    // typed read - which is the one that reaches the user.
    final columns = <String, Map<String, _ColumnShape>>{};
    for (final table in BackupFormat.tables) {
      columns[table] = await _shapesOf(db, table);
      final rows = tables[table];
      if (rows is! List) {
        throw BackupException('备份缺少表 $table。');
      }
      if (rows.length > BackupFormat.maxRowsPerTable) {
        throw BackupException('备份的表 $table 行数超过上限，已拒绝恢复。');
      }
      for (final row in rows) {
        if (row is! Map<String, dynamic>) {
          throw BackupException('表 $table 含无效记录。');
        }
        for (final entry in row.entries) {
          final shape = columns[table]![entry.key];
          if (shape == null) {
            throw BackupException(
              '备份里的表 $table 含当前版本没有的字段 ${entry.key}，已拒绝恢复。',
            );
          }
          final value = entry.value;
          if (value == null) {
            if (shape.required) {
              throw BackupException(
                '备份的表 $table 字段 ${entry.key} 为空，但当前版本要求有值。',
              );
            }
            continue;
          }
          if (value is Map || value is List) {
            // A nested value cannot be bound to a scalar column. Name-only
            // validation used to let this through to the INSERT.
            throw BackupException(
              '备份的表 $table 字段 ${entry.key} 是嵌套结构，不是单个值。',
            );
          }
          if (!shape.accepts(value)) {
            throw BackupException(
              '备份的表 $table 字段 ${entry.key} 的类型与 ${shape.type} 列不符。',
            );
          }
        }
      }
    }

    // A table the backup carries that this build does not know must not count
    // toward the success report: it was never written.
    final known = BackupFormat.tables.toSet();
    for (final extra in tables.keys) {
      if (!known.contains(extra)) {
        throw BackupException('备份含当前版本没有的表 $extra，已拒绝恢复。');
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
    _PackSwap? swap;

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

        // The swap is inside the transaction so the database is the only
        // serialisation point: another controller's write cannot land between
        // the delete and the commit, because it queues behind this transaction.
        // The file operations are short (two renames), and a failure rolls the
        // database back and swaps the packs back in the catch.
        if (stagedPacks != null) {
          swap = await _swapPacksIn(stagedPacks, epoch);
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
            final names = cols.keys.where(row.containsKey).toList();
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
      if (swap != null) {
        final restored = await _swapPacksBack(swap!);
        if (!restored) {
          // The database rolled back but the packs did not go back with it. The
          // honest message names which half is wrong; "原数据没有改动" would be
          // false for the packs and would send the user hunting in the database.
          throw const BackupException(
            '恢复失败，没能回退。数据库已回到恢复前的状态，但伙伴包没有还原，'
            '请重启应用后再试一次。',
          );
        }
      } else if (stagedPacks != null) {
        // The transaction failed before the swap (unsettled work, a bad row, a
        // row-count mismatch), so the staging directory never became the live
        // root. Leaving it behind would accumulate garbage beside the packs.
        await _discardStaged(stagedPacks);
      }
      if (error is BackupException) rethrow;
      throw BackupException('恢复失败，原数据没有改动：$error');
    }

    if (swap != null) await _finishSwap(swap!);
    // The transaction committed and the packs are swapped. The staging
    // directory is gone (it *became* the live root), so there is nothing to
    // clean up on the success path.
    final rows = [
      for (final table in BackupFormat.tables)
        if (tables[table] is List) (tables[table] as List).length,
    ].fold<int>(0, (sum, count) => sum + count);
    return RestoreReport(
      rowsRestored: rows,
      packsRestored: stagedPacks?.fileCount ?? 0,
    );
  }

  /// Whether the journal's epoch is present in `app_settings`.
  ///
  /// Three-valued on purpose. The previous version collapsed a *read error* into
  /// "not committed", which is the one interpretation it must never have: a
  /// database that is merely locked at startup would have rolled back a
  /// completed restore.
  static Future<BackupEpochCheck> _committedEpoch(
    AppDatabase db,
    String epoch,
  ) async {
    try {
      final row = await db
          .customSelect(
            "SELECT value FROM app_settings WHERE key = 'backup_restore_epoch'",
          )
          .getSingleOrNull();
      final committed = row?.data['value'] as String?;
      return committed == epoch
          ? BackupEpochCheck.committed
          : BackupEpochCheck.notCommitted;
    } catch (_) {
      return BackupEpochCheck.unreadable;
    }
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
  ///
  /// **Every failure path preserves the journal.** It is the only record that
  /// these two halves ever disagreed; clearing it after a failed rollback would
  /// leave a live directory and a previous one and no way to tell which is
  /// which - and the "no journal" branch deletes `previous` as garbage.
  static Future<BackupRecoveryOutcome> recoverInterruptedRestore({
    required AppDatabase db,
    Directory? packRoot,
  }) async {
    if (packRoot == null) return BackupRecoveryOutcome.nothingToDo;
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
      return BackupRecoveryOutcome.nothingToDo;
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(await journal.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      // An unreadable journal cannot be acted on. Keep it: deleting it would
      // discard the only evidence that a swap may have happened.
      return BackupRecoveryOutcome.unreadableJournal;
    }

    final epoch = data['epoch'];
    if (epoch is! String) return BackupRecoveryOutcome.unreadableJournal;

    // The swap marker records which staging directory was actually renamed into
    // place. Without it a stale journal from an earlier restore - whose
    // directory has since been replaced - could validate against a live
    // directory that belongs to the user now, and the rollback would delete it.
    final stagingPath = data['staging'];
    if (stagingPath is! String || !_isOwnStagingDirectory(live, stagingPath)) {
      // The journal names a directory this app would never have created (or a
      // path outside the pack root's parent). A journal is an editable file;
      // trusting its path is a recursive delete of whatever it names.
      return BackupRecoveryOutcome.unreadableJournal;
    }
    final marker = File('${journal.path}.swapped');
    if (await marker.exists()) {
      final recorded = await marker.readAsString();
      if (recorded != stagingPath) {
        return BackupRecoveryOutcome.staleJournal;
      }
    } else if (live.existsSync() && data['hadLive'] == false) {
      // No marker and `hadLive == false`: either the crash was before the swap
      // (live must not exist) or the live root was created by something else
      // since. Both are refused rather than guessed at.
      return BackupRecoveryOutcome.staleJournal;
    }

    final epochState = await _committedEpoch(db, epoch);
    switch (epochState.matches) {
      case null:
        return BackupRecoveryOutcome.unreadableEpoch;

      case true:
        // The data committed. Keep the new packs; drop the old ones.
        if (!await _delete(previous)) {
          return BackupRecoveryOutcome.rollbackFailed;
        }
        await _clearJournal(journal);
        await _clearMarker(marker);
        return BackupRecoveryOutcome.committed;

      case false:
        // The data did not commit. Put the old packs back.
        final hadLive = data['hadLive'];
        if (hadLive == false) {
          // There was no old root, so the live one is the new staging directory
          // and must not survive the rollback. `live.exists()` is the proof the
          // swap happened; if it is absent the crash was earlier and there is
          // nothing to undo.
          if (await live.exists() && !await _delete(live)) {
            return BackupRecoveryOutcome.rollbackFailed;
          }
        } else if (await previous.exists()) {
          if (await live.exists() && !await _delete(live)) {
            return BackupRecoveryOutcome.rollbackFailed;
          }
          try {
            await previous.rename(live.path);
          } catch (_) {
            // `live` is gone and `previous` still holds the user's packs. Keep
            // the journal so the next start retries instead of treating
            // `previous` as garbage.
            return BackupRecoveryOutcome.rollbackFailed;
          }
        } else {
          // `hadLive == true` but `previous` is gone. The old root cannot be
          // put back, so the new packs are next to rolled-back data. Declaring
          // success here would be a lie; it is an unresolved state.
          return BackupRecoveryOutcome.rollbackFailed;
        }
        if (!await _delete(Directory(stagingPath))) {
          return BackupRecoveryOutcome.rollbackFailed;
        }
        await _clearJournal(journal);
        await _clearMarker(marker);
        return BackupRecoveryOutcome.rolledBack;
    }
  }

  /// Whether [path] is the staging directory this app would create for [live].
  ///
  /// Staging directories are generated here as `.cozy_restore_<microseconds>`
  /// directly under the pack root's parent. A journal must never be able to
  /// name anything else for recursive deletion.
  static bool _isOwnStagingDirectory(Directory live, String path) {
    if (path.contains('..')) return false;
    final name = p.basename(path);
    if (!name.startsWith('.cozy_restore_')) return false;
    try {
      return p.isWithin(live.parent.path, Directory(path).absolute.path);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _delete(Directory directory) async {
    if (!await directory.exists()) return true;
    try {
      await directory.delete(recursive: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _clearMarker(File marker) async {
    try {
      if (await marker.exists()) await marker.delete();
    } catch (_) {}
  }

  /// The column shapes this build expects: name -> (type, required).
  ///
  /// `PRAGMA table_info` gives `type` (an affinity word) and `notnull`. Name
  /// validation alone is not enough: SQLite applies type *affinity*, so a
  /// TEXT-typed value can be stuffed into an INTEGER column without an error,
  /// and the failure then surfaces later as a typed read throwing mid-screen.
  static Future<Map<String, _ColumnShape>> _shapesOf(
    AppDatabase db,
    String table,
  ) async {
    final rows = await db.customSelect('PRAGMA table_info("$table")').get();
    return {
      for (final row in rows)
        row.data['name'] as String: _ColumnShape(
          type: (row.data['type'] as String? ?? '').toUpperCase(),
          required: (row.data['notnull'] as int? ?? 0) == 1,
        ),
    };
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
    final marker = File('${journal.path}.swapped');

    if (await previous.exists()) {
      await previous.delete(recursive: true);
    }
    final hadLive = await live.exists();
    await _writeJournal(journal, {
      'epoch': epoch,
      'previous': previous.path,
      'staging': staged.staging.path,
      // Whether there was an old root at all. Without this, a crash on the
      // first-ever restore (no `previous`) would leave the new packs with the
      // old data, and recovery would have no way to tell.
      'hadLive': hadLive,
    });

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
    // Written only after the rename succeeded, so recovery can tell "the swap
    // happened" from "the journal was written but the swap never did".
    await _writeText(marker, staged.staging.path);
    return _PackSwap(
      live: live,
      previous: previous,
      journal: journal,
      marker: marker,
    );
  }

  /// Puts the old pack root back after the database transaction failed.
  ///
  /// Returns false when the old root cannot be restored. That is not a detail:
  /// the caller must not claim "原数据没有改动" when the packs no longer match.
  static Future<bool> _swapPacksBack(_PackSwap swap) async {
    try {
      if (await swap.live.exists()) {
        await swap.live.delete(recursive: true);
      }
      if (await swap.previous.exists()) {
        await swap.previous.rename(swap.live.path);
      } else {
        return false;
      }
    } catch (_) {
      // The journal stays until the next start, which will retry this exact
      // recovery with the same information.
      return false;
    }
    await _clearJournal(swap.journal);
    return true;
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
    await _writeText(journal, jsonEncode(data));
  }

  static Future<void> _writeText(File file, String text) async {
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(text, flush: true);
    // Rename is the atomic step: a half-written journal must never be read.
    await temp.rename(file.path);
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

/// One column's declared type affinity and whether it may be null.
class _ColumnShape {
  final String type;
  final bool required;

  const _ColumnShape({required this.type, required this.required});

  /// Whether a JSON-decoded [value] is safe to bind to this column.
  ///
  /// SQLite's affinity means `INSERT INTO t (n) VALUES ('abc')` on an INTEGER
  /// column stores 'abc' rather than failing, so the value has to be checked
  /// here or the failure surfaces later in a typed read.
  bool accepts(Object value) {
    if (type.contains('INT') || type.contains('REAL') || type == 'NUM') {
      return value is int || value is double || value is num;
    }
    if (type.contains('BOOL')) {
      return value is bool || value is int;
    }
    if (type.contains('BLOB')) {
      return value is List || value is String;
    }
    // TEXT, and the empty affinity a column with no declared type gets.
    return value is String || value is int || value is double || value is num;
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
  final File marker;

  const _PackSwap({
    required this.live,
    required this.previous,
    required this.journal,
    required this.marker,
  });
}

/// What `recoverInterruptedRestore` concluded.
///
/// Returned so `main` can tell the difference between "nothing to do" and "this
/// needs another attempt". Anything other than [nothingToDo], [committed] or
/// [rolledBack] leaves the state exactly as it was, with the journal intact.
class BackupRecoveryOutcome {
  final String state;
  const BackupRecoveryOutcome(this.state);

  static const nothingToDo = BackupRecoveryOutcome('nothing_to_do');
  static const committed = BackupRecoveryOutcome('committed');
  static const rolledBack = BackupRecoveryOutcome('rolled_back');
  static const unreadableJournal = BackupRecoveryOutcome('unreadable_journal');
  static const staleJournal = BackupRecoveryOutcome('stale_journal');
  static const unreadableEpoch = BackupRecoveryOutcome('unreadable_epoch');
  static const rollbackFailed = BackupRecoveryOutcome('rollback_failed');

  /// Whether the filesystem is in a consistent, untouched state.
  bool get isResolved =>
      this == nothingToDo || this == committed || this == rolledBack;

  @override
  String toString() => 'BackupRecoveryOutcome($state)';
}

/// Whether the journal's epoch matched the one written in the data transaction.
class BackupEpochCheck {
  final bool? matches;
  const BackupEpochCheck(this.matches);

  static const committed = BackupEpochCheck(true);
  static const notCommitted = BackupEpochCheck(false);
  static const unreadable = BackupEpochCheck(null);
}
