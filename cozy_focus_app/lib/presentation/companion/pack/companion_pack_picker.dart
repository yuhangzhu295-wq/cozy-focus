/// How the app asks the user for a `.cozy_pet` file, and how it hands one back.
///
/// ## Why these are interfaces
///
/// Both ends of the import flow are platform calls: one opens a system document
/// picker, the other opens a system share sheet. Neither can run in a widget
/// test, and neither is where the interesting behaviour is. Putting them behind
/// an interface means the flow — inspect, preview, refuse, install — is tested
/// against a fake that returns bytes, and the platform code is a thin adapter
/// with nothing to get wrong.
library;

import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'companion_pack_exporter.dart';

/// A file the user chose, already read into memory.
///
/// The bytes rather than a path, because the archive reader takes bytes and the
/// Android picker may hand back a content URI that has no usable path. Reading
/// once, here, keeps the rest of the flow free of the platform's file model.
class PickedCompanionPack {
  /// The name the file had, for error messages and for the export round trip.
  final String fileName;

  final Uint8List bytes;

  const PickedCompanionPack(this.fileName, this.bytes);

  @override
  String toString() => 'PickedCompanionPack($fileName, ${bytes.length} bytes)';
}

/// Asks the user for a pack file. Returns null when they cancel.
abstract class CompanionPackPicker {
  Future<PickedCompanionPack?> pick();
}

/// Delivers an exported pack somewhere the user can keep it.
abstract class CompanionPackSink {
  Future<void> deliver({required String fileName, required Uint8List bytes});
}

/// The real picker: the platform's document picker, filtered to `.cozy_pet`.
class FileSelectorCompanionPackPicker implements CompanionPackPicker {
  const FileSelectorCompanionPackPicker();

  /// The extension a pack carries, taken from the exporter so the filter and the
  /// writer cannot disagree about what a pack is called.
  static const String extension = 'cozy_pet';

  /// The group the picker filters by.
  ///
  /// Extensions *and* MIME types, because the platforms disagree: a desktop
  /// picker matches on the extension, while Android resolves extensions to MIME
  /// types and would otherwise show nothing for a type it has never heard of. A
  /// `.cozy_pet` is a ZIP, so the ZIP types are declared as well — a picker that
  /// greys the file out is a worse failure than one that shows a few extra files
  /// the validator will refuse anyway.
  static const XTypeGroup packTypeGroup = XTypeGroup(
    label: 'Cozy Pet Pack',
    extensions: [extension],
    mimeTypes: ['application/zip', 'application/octet-stream'],
  );

  @override
  Future<PickedCompanionPack?> pick() async {
    final file = await openFile(acceptedTypeGroups: const [packTypeGroup]);
    if (file == null) return null;
    return PickedCompanionPack(file.name, await file.readAsBytes());
  }
}

/// The real sink: the system share sheet, so the user chooses where it goes.
///
/// A share sheet rather than writing to a fixed directory, because the app has
/// no business deciding where a user's file should live, and on Android 10+ the
/// app cannot write to shared storage without a permission it should not ask for.
class ShareCompanionPackSink implements CompanionPackSink {
  const ShareCompanionPackSink();

  @override
  Future<void> deliver({
    required String fileName,
    required Uint8List bytes,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            name: fileName,
            mimeType: 'application/zip',
          ),
        ],
        fileNameOverrides: [fileName],
      ),
    );
  }
}

/// The picker the app uses. Overridden in tests.
final companionPackPickerProvider = Provider<CompanionPackPicker>(
  (ref) => const FileSelectorCompanionPackPicker(),
);

/// The sink the app uses. Overridden in tests.
final companionPackSinkProvider = Provider<CompanionPackSink>(
  (ref) => const ShareCompanionPackSink(),
);

/// The file name an exported pack is offered under.
///
/// The companion id rather than the display name: an id is already constrained
/// to `[a-z0-9_-]`, so it cannot carry a separator, a space or a colon into a
/// file name, and it is stable across a rename.
String companionPackExportFileName(String packId) =>
    '$packId${CompanionPackExporter.extension}';
