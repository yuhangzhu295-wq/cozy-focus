import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

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
  static const int maxPackBytes = 32 * 1024 * 1024;
  static const int maxPackFiles = 2000;

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
      tables[table] = [for (final row in rows) row.data];
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
      if (relative == null || !_safeRelative(relative)) continue;
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

  /// Whether a session is live right now.
  ///
  /// A restore while the timer runs would replace the row the engine is holding,
  /// and the engine would then write a second, orphaned session when it
  /// finishes. Refusing is the only honest option: the user can stop first.
  static Future<bool> hasLiveSession(AppDatabase db) async {
    final placeholders =
        List.filled(kLiveSessionStatusNames.length, '?').join(',');
    final rows = await db.customSelect(
      'SELECT COUNT(*) AS c FROM focus_sessions '
      'WHERE status IN ($placeholders)',
      variables: [
        for (final name in kLiveSessionStatusNames) Variable<String>(name),
      ],
    ).getSingle();
    return (rows.data['c'] as int? ?? 0) > 0;
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
    if (await hasLiveSession(db)) {
      throw const BackupException(
        '正在专注中，不能恢复备份。请先结束或暂停并保存当前专注。',
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

    // Write the pack files into a staging directory first. Nothing in the live
    // pack root is touched until the database replacement has committed.
    final stagedPacks = await _stagePacks(packRoot, payload['packs']);

    // A snapshot for the one failure the database transaction cannot roll back
    // on its own: a pack swap that fails *after* the commit.
    final snapshot = <String, List<Map<String, dynamic>>>{};
    for (final table in BackupFormat.tables) {
      final rows =
          await db.customSelect('SELECT * FROM "$table" ORDER BY rowid').get();
      snapshot[table] = [for (final row in rows) row.data];
    }

    var committed = false;
    try {
      await db.transaction(() async {
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
      });
      committed = true;
    } catch (error) {
      await _discardStaged(stagedPacks);
      if (error is BackupException) rethrow;
      throw BackupException('恢复失败，原数据没有改动：$error');
    }

    // The database is committed. Swap the packs. If this fails, put the
    // database back from the snapshot so the two halves stay consistent.
    try {
      final packsRestored = await _commitPacks(stagedPacks);
      final rows = (tables.values)
          .whereType<List>()
          .fold<int>(0, (sum, list) => sum + list.length);
      return RestoreReport(rowsRestored: rows, packsRestored: packsRestored);
    } catch (error) {
      if (committed) {
        await _applySnapshot(db, snapshot);
      }
      throw BackupException('恢复伙伴包失败，已回退数据：$error');
    }
  }

  static Future<List<String>> _columnsOf(AppDatabase db, String table) async {
    final rows = await db.customSelect('PRAGMA table_info("$table")').get();
    return [for (final row in rows) row.data['name'] as String];
  }

  static Future<void> _applySnapshot(
    AppDatabase db,
    Map<String, List<Map<String, dynamic>>> snapshot,
  ) async {
    await db.transaction(() async {
      for (final table in BackupFormat.tablesInDeleteOrder) {
        await db.customStatement('DELETE FROM "$table"');
      }
      for (final table in BackupFormat.tables) {
        for (final row in snapshot[table] ?? const <Map<String, dynamic>>[]) {
          final names = row.keys.toList();
          if (names.isEmpty) continue;
          await db.customStatement(
            'INSERT INTO "$table" '
            '(${names.map((n) => '"$n"').join(',')}) '
            'VALUES (${List.filled(names.length, '?').join(',')})',
            [for (final name in names) row[name]],
          );
        }
      }
    });
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

    final parent = root.parent;
    final staging = Directory(
      '${parent.path}/.cozy_restore_${DateTime.now().microsecondsSinceEpoch}',
    );
    await staging.create(recursive: true);

    var bytes = 0;
    try {
      for (final entry in files.entries) {
        final relative = entry.key;
        if (!_safeRelative(relative)) {
          throw BackupException('备份含不安全的文件路径：$relative');
        }
        final encoded = entry.value;
        if (encoded is! String) {
          throw const BackupException('备份的伙伴包文件无效。');
        }
        final data = base64Decode(encoded);
        bytes += data.length;
        if (bytes > maxPackBytes) {
          throw const BackupException('备份的伙伴包超过大小上限，已拒绝恢复。');
        }
        final target = File('${staging.path}/$relative');
        await target.parent.create(recursive: true);
        await target.writeAsBytes(data, flush: true);
      }
    } catch (_) {
      await _discardStaged(_StagedPacks(staging, root, 0));
      rethrow;
    }

    return _StagedPacks(staging, root, files.length);
  }

  /// Replaces the live pack root with the staged one.
  ///
  /// Two renames, so the window where the root is missing is as short as the
  /// filesystem allows. The old root is deleted only after the new one is in
  /// place.
  static Future<int> _commitPacks(_StagedPacks? staged) async {
    if (staged == null) return 0;
    final live = staged.liveRoot;
    final previous = Directory('${live.parent.path}/.cozy_restore_previous');
    if (await previous.exists()) {
      await previous.delete(recursive: true);
    }
    if (await live.exists()) {
      await live.rename(previous.path);
    }
    try {
      await staged.staging.rename(live.path);
    } catch (_) {
      // Put the old root back before rethrowing.
      if (await previous.exists()) {
        await previous.rename(live.path);
      }
      rethrow;
    }
    if (await previous.exists()) {
      await previous.delete(recursive: true);
    }
    return staged.fileCount;
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

  static bool _safeRelative(String path) {
    if (path.isEmpty) return false;
    if (path.startsWith('/') || path.startsWith(r'\')) return false;
    if (RegExp(r'^[A-Za-z]:').hasMatch(path)) return false;
    for (final part in path.split('/')) {
      if (part == '..' || part.isEmpty) return false;
    }
    return true;
  }
}

class _StagedPacks {
  final Directory staging;
  final Directory liveRoot;
  final int fileCount;

  const _StagedPacks(this.staging, this.liveRoot, this.fileCount);
}
