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
  Future<ExportResult> saveToGallery(
    Uint8List bytes,
    String filename,
  ) async {
    try {
      await Gal.putImageBytes(bytes, name: filename);
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

  /// Write [bytes] to a temporary PNG file and open the system share sheet.
  ///
  /// [text] is the accompanying share text (must not contain private notes).
  Future<void> shareAsImage(
    Uint8List bytes,
    String filename,
    String text,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: text,
      ),
    );
  }
}
