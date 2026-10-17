import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'backup_format.dart';

/// Moves a backup file in and out through the platform's own file UI.
///
/// ## Why a channel on Android
///
/// `file_selector` has no `getSaveLocation` implementation on Android, and the
/// brief asks for the system save interface with a user-chosen target. The
/// Storage Access Framework is exactly that: `ACTION_CREATE_DOCUMENT` and
/// `ACTION_OPEN_DOCUMENT` open the system picker, grant access to the one file
/// the user picked, and require no storage permission. `MainActivity` hosts the
/// two calls; this class is the Dart side.
///
/// Everywhere else the plugin's own picker is used, so a desktop build and the
/// tests do not need the channel.
abstract final class BackupFileService {
  const BackupFileService._();

  static const MethodChannel _channel = MethodChannel('cozyfocus/backup');

  /// Writes [bytes] where the user chooses. Returns the location, or null when
  /// the user cancelled.
  static Future<String?> save(
    Uint8List bytes, {
    required String suggestedName,
  }) async {
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod<String>('saveBackup', {
          'name': suggestedName,
          'bytes': bytes,
        });
      } on MissingPluginException {
        // A test host or a build without the activity: fall through rather than
        // failing the export.
      } on PlatformException catch (error) {
        throw BackupFileException('保存失败：${error.message ?? error.code}');
      }
    }

    try {
      final location = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'CozyFocus 备份',
            extensions: [BackupFormat.extension],
          ),
        ],
      );
      if (location == null) return null;
      final file = File(location.path);
      await file.writeAsBytes(bytes, flush: true);
      return location.path;
    } on UnimplementedError {
      // No save dialog on this platform: put the file somewhere the user can
      // reach and tell them the path instead of pretending it was chosen.
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$suggestedName');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }
  }

  /// Lets the user pick a backup file and returns its bytes, or null on cancel.
  static Future<Uint8List?> pick() async {
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod<Uint8List>('openBackup');
      } on MissingPluginException {
        // fall through
      } on PlatformException catch (error) {
        throw BackupFileException('读取失败：${error.message ?? error.code}');
      }
    }

    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'CozyFocus 备份',
          extensions: [BackupFormat.extension],
        ),
      ],
    );
    if (file == null) return null;
    return file.readAsBytes();
  }
}

/// A file-level failure the UI can show without a stack trace.
class BackupFileException implements Exception {
  final String message;
  const BackupFileException(this.message);

  @override
  String toString() => message;
}
