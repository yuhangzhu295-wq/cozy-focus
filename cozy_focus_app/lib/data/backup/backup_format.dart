import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The local backup format: one versioned JSON envelope with a checksum.
///
/// ## Why JSON and not a copy of the database file
///
/// Copying `cozy_focus.sqlite` would be smaller and faster, but it couples a
/// backup to the exact schema and to SQLite's internal state (WAL, page layout,
/// free pages). A backup that can only be read by the build that wrote it is not
/// a backup the user can keep. The envelope names its own format version and the
/// app schema version, so an older app can refuse it in words the user
/// understands instead of failing inside SQLite.
///
/// ## What the checksum covers
///
/// Everything except the checksum itself, encoded canonically: maps sorted by
/// key at every depth, lists left in order. Without canonicalisation the same
/// data would hash differently depending on the order Drift returned columns in,
/// and the check would fail on backups that are perfectly good.
abstract final class BackupFormat {
  const BackupFormat._();

  /// The marker that identifies this file as a CozyFocus backup.
  static const String format = 'cozyfocus.backup';

  /// The envelope's own version. Bumped only for a change to the envelope.
  static const int version = 1;

  /// The file extension shown in the save dialog.
  static const String extension = 'cozybackup';

  /// Refuse to parse anything larger than this before allocating a decoded
  /// string. A backup of this app is a few hundred kilobytes; 64 MB is already
  /// far beyond a real one and stops a hostile or corrupted file from becoming a
  /// memory problem before any validation runs.
  static const int maxBytes = 64 * 1024 * 1024;

  /// Caps on the pack payload, checked before decoding as well as after.
  static const int maxPackBytes = 32 * 1024 * 1024;
  static const int maxPackFiles = 2000;

  /// Settings keys that are this app's own bookkeeping, not the user's
  /// preferences. They stay in the database but never travel in a backup.
  static const Set<String> internalSettingsKeys = {'backup_restore_epoch'};

  /// The business tables a backup carries, parents before children.
  ///
  /// `sync_outbox` is deliberately absent: it holds pending writes, not user
  /// data. Restoring queued operations would replay changes the user already
  /// made in the backup's world, which is the opposite of a restore.
  static const List<String> tables = [
    'app_settings',
    'focus_categories',
    'tasks',
    'task_subtasks',
    'task_schedules',
    'focus_sessions',
    'focus_records',
    'distraction_notes',
    'rest_sessions',
    'craft_recipes',
    'craft_jobs',
    'inventory_items',
    'room_items',
    'pets',
    'pet_progress',
    'pet_memories',
    'achievements',
    'reward_ledger',
  ];

  /// Tables that must be cleared on restore but are not carried in a backup.
  ///
  /// `sync_outbox` holds pending writes. A backup must not carry them (replaying
  /// them would undo the restore), but a restore must still clear the *target's*
  /// queue - otherwise operations queued before the restore would be flushed
  /// against the restored world.
  static const List<String> clearedOnly = ['sync_outbox'];

  /// Every table the snapshot and the delete pass touch.
  static List<String> get snapshotTables => [...tables, ...clearedOnly];

  /// The reverse order, for deletes: children first, then the outbox.
  static List<String> get tablesInDeleteOrder =>
      [...clearedOnly, ...tables.reversed];
}

/// What a validated backup contains, before anything is written.
class BackupPreview {
  final DateTime? exportedAt;
  final String? appVersion;
  final int formatVersion;
  final int appSchemaVersion;
  final Map<String, int> rowCounts;
  final List<String> packIds;
  final int byteLength;

  const BackupPreview({
    required this.exportedAt,
    required this.appVersion,
    required this.formatVersion,
    required this.appSchemaVersion,
    required this.rowCounts,
    required this.packIds,
    required this.byteLength,
  });

  int get totalRows => rowCounts.values.fold(0, (sum, count) => sum + count);

  @override
  String toString() =>
      'BackupPreview(rows $totalRows, packs ${packIds.length}, '
      'schema $appSchemaVersion, ${byteLength ~/ 1024} KB)';
}

/// The result of reading a file: either a preview to confirm, or a refusal.
///
/// The payload is kept in memory and never written during validation, so a
/// corrupt or incompatible file cannot touch the database.
class BackupReadResult {
  final BackupPreview? preview;
  final String? refusal;
  final Map<String, dynamic>? payload;

  const BackupReadResult._({this.preview, this.refusal, this.payload});

  const BackupReadResult.refused(String reason) : this._(refusal: reason);

  const BackupReadResult.ok(BackupPreview preview, Map<String, dynamic> payload)
      : this._(preview: preview, payload: payload);

  bool get ok => preview != null && payload != null;
}

/// Reads, decodes and validates a backup file.
///
/// Validation is ordered cheapest-first: size, JSON, envelope, version, schema,
/// checksum, shape. Nothing here writes.
abstract final class BackupReader {
  const BackupReader._();

  static BackupReadResult read(Uint8List bytes, {required int currentSchema}) {
    if (bytes.isEmpty) {
      return const BackupReadResult.refused('文件是空的。');
    }
    if (bytes.length > BackupFormat.maxBytes) {
      return const BackupReadResult.refused(
        '文件超过 ${BackupFormat.maxBytes ~/ (1024 * 1024)} MB，'
        '这不是本应用能产生的备份。',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      return const BackupReadResult.refused('文件不是有效的备份（无法解析）。');
    }
    if (decoded is! Map<String, dynamic>) {
      return const BackupReadResult.refused('文件结构不是备份格式。');
    }

    if (decoded['format'] != BackupFormat.format) {
      return const BackupReadResult.refused('这不是 CozyFocus 的备份文件。');
    }

    final formatVersion = decoded['formatVersion'];
    if (formatVersion is! int) {
      return const BackupReadResult.refused('备份缺少格式版本。');
    }
    if (formatVersion > BackupFormat.version) {
      return BackupReadResult.refused(
        '备份格式版本 $formatVersion 比当前应用支持的 '
        '${BackupFormat.version} 更新，请先更新应用。',
      );
    }
    if (formatVersion < 1) {
      return const BackupReadResult.refused('备份格式版本无效。');
    }

    final schema = decoded['appSchemaVersion'];
    if (schema is! int) {
      return const BackupReadResult.refused('备份缺少数据库版本。');
    }
    if (schema != currentSchema) {
      return BackupReadResult.refused(
        '备份来自数据库版本 $schema，当前是 $currentSchema。'
        'V1 不支持跨版本恢复，以免写坏数据。',
      );
    }

    final checksum = decoded['checksum'];
    if (checksum is! String) {
      return const BackupReadResult.refused('备份缺少完整性校验值。');
    }
    final payload = Map<String, dynamic>.from(decoded)..remove('checksum');
    final actual =
        sha256.convert(utf8.encode(canonicalJson(payload))).toString();
    if (actual != checksum) {
      return const BackupReadResult.refused(
        '完整性校验失败：文件已损坏或被修改。原数据没有改动。',
      );
    }

    final rawTables = payload['tables'];
    if (rawTables is! Map<String, dynamic>) {
      return const BackupReadResult.refused('备份缺少数据表。');
    }
    final counts = <String, int>{};
    for (final table in BackupFormat.tables) {
      final rows = rawTables[table];
      if (rows is! List) {
        return BackupReadResult.refused('备份缺少表 $table。');
      }
      for (final row in rows) {
        if (row is! Map<String, dynamic>) {
          return BackupReadResult.refused('表 $table 含无效记录。');
        }
      }
      counts[table] = rows.length;
    }

    // Packs are an optional map of `ids` (for the preview) and `files`
    // (relative path -> base64). An older or hand-written file may omit the key
    // entirely; a malformed one is refused rather than half-restored.
    final rawPacks = payload['packs'];
    final packIds = <String>[];
    if (rawPacks != null) {
      if (rawPacks is! Map<String, dynamic>) {
        return const BackupReadResult.refused('备份的伙伴包清单无效。');
      }
      final ids = rawPacks['ids'];
      if (ids is! List || ids.any((id) => id is! String)) {
        return const BackupReadResult.refused('备份的伙伴包清单无效。');
      }
      packIds.addAll(ids.cast<String>());

      final files = rawPacks['files'];
      if (files is! Map<String, dynamic>) {
        return const BackupReadResult.refused('备份的伙伴包文件清单无效。');
      }
      if (files.length > BackupFormat.maxPackFiles) {
        return const BackupReadResult.refused('备份的伙伴包文件数量超过上限。');
      }
      for (final entry in files.entries) {
        if (entry.value is! String || !isSafePackPath(entry.key)) {
          return const BackupReadResult.refused(
            '备份含不安全的伙伴包文件路径。',
          );
        }
      }
    }

    final exportedAtRaw = payload['exportedAt'];
    DateTime? exportedAt;
    if (exportedAtRaw is String) {
      exportedAt = DateTime.tryParse(exportedAtRaw);
    }

    return BackupReadResult.ok(
      BackupPreview(
        exportedAt: exportedAt,
        appVersion: payload['appVersion'] as String?,
        formatVersion: formatVersion,
        appSchemaVersion: schema,
        rowCounts: counts,
        packIds: packIds,
        byteLength: bytes.length,
      ),
      payload,
    );
  }
}

/// Encodes [value] with every map's keys sorted.
///
/// `jsonEncode` preserves insertion order, and Drift's column order is not part
/// of any contract. Sorting is what makes the checksum depend on the data rather
/// than on how it happened to be read.
String canonicalJson(Object? value) {
  final buffer = StringBuffer();
  void write(Object? node) {
    if (node is Map) {
      final keys = node.keys.map((k) => k.toString()).toList()..sort();
      buffer.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) buffer.write(',');
        buffer.write(jsonEncode(keys[i]));
        buffer.write(':');
        write(node[keys[i]]);
      }
      buffer.write('}');
    } else if (node is List) {
      buffer.write('[');
      for (var i = 0; i < node.length; i++) {
        if (i > 0) buffer.write(',');
        write(node[i]);
      }
      buffer.write(']');
    } else {
      buffer.write(jsonEncode(node));
    }
  }

  write(value);
  return buffer.toString();
}

/// Builds the checksum for [payload], which must not already contain one.
String checksumFor(Map<String, dynamic> payload) =>
    sha256.convert(utf8.encode(canonicalJson(payload))).toString();

/// Whether [path] is a relative path that cannot escape the pack root.
///
/// Strict on purpose, and on every platform: a backup written on Linux can be
/// restored on Windows, where `\` is a separator too. A check that only split
/// on `/` accepted `pack\..\..\target`, and the staging writer then created the
/// file outside the root. A checksum does not help here - whoever wrote the
/// file can compute a matching one - so the path itself has to be safe.
bool isSafePackPath(String path) {
  if (path.isEmpty) return false;
  if (path.contains(r'\')) return false;
  if (path.startsWith('/') || path.startsWith('.')) return false;
  if (RegExp(r'^[A-Za-z]:').hasMatch(path)) return false;
  for (final part in path.split('/')) {
    if (part.isEmpty || part == '.' || part == '..') return false;
    if (part.contains(':')) return false;
  }
  return true;
}
