import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

/// Result of a gallery-save or share-image operation.
enum ExportResult { success, permissionDenied, failed }

/// Service responsible for capturing a Flutter widget subtree as PNG bytes,
/// saving it to the system gallery, and sharing it via the system share sheet.
///
/// Uses [gal] for gallery access — MIT license, AGP-compatible, actively maintained.
/// Design: plain Dart service called imperatively from page state.
class WrappedExportService {
  const WrappedExportService();

  /// Capture the widget subtree under [key] as raw PNG bytes.
  ///
  /// [pixelRatio] defaults to 3.0 for high-DPI output.
  /// Returns null if the key has no render object attached or capture fails.
  Future<Uint8List?> captureCardAsBytes(
    GlobalKey key, {
    double pixelRatio = 3.0,
  }) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Save [bytes] as a PNG to the device gallery via [gal].
  ///
  /// Returns [ExportResult.success] only if [Gal.putImageBytes] succeeds.
  ///
  /// [name] is the base name, with or without `.png`. `gal` appends the
  /// extension itself and its own documentation says not to include one, so
  /// passing `photo.png` saved `photo.png.png` — found by saving a card on a
  /// device and reading the gallery. The extension is normalised here rather
  /// than left to each caller, because the two callers are not the only ones a
  /// later change could add, and the gallery is where it shows.
  Future<ExportResult> saveToGallery(
    Uint8List bytes,
    String name,
  ) async {
    try {
      await Gal.putImageBytes(bytes, name: baseName(name));
      return ExportResult.success;
    } on GalException catch (e) {
      if (e.type == GalExceptionType.accessDenied ||
          e.type == GalExceptionType.notEnoughSpace) {
        return ExportResult.permissionDenied;
      }
      return ExportResult.failed;
    } catch (_) {
      return ExportResult.failed;
    }
  }

  /// `cozy_focus_2026_wrapped.png` -> `cozy_focus_2026_wrapped`.
  ///
  /// A leading dot is left alone: `.hidden` is a name, not an extension.
  static String baseName(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  /// Write [bytes] to a temporary PNG file and open the system share sheet.
  ///
  /// [text] is the accompanying share text (must not contain private notes).
  /// [name] is a base name; the extension is added here, because the file this
  /// writes is the one the share sheet reads and it does need one.
  Future<void> shareAsImage(
    Uint8List bytes,
    String name,
    String text,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${baseName(name)}.png');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: text,
      ),
    );
  }
}
