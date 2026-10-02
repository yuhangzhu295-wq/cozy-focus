import 'dart:io';
import 'dart:typed_data';

/// A decoded PNG, or the reason it could not be decoded.
///
/// ## Why this is hand-written
///
/// The anchor contract cannot be checked from the manifest: a manifest can
/// *declare* `groundBaseline: 919` while every frame has its feet at 500. The
/// only honest check measures the pixels. The project has no image dependency,
/// and adding one to the app for a test would be a release-size cost for a
/// build-time question, so this decodes the narrow format the pipeline actually
/// produces.
///
/// ## What it supports
///
/// 8-bit, non-interlaced PNG in colour types 0 (grey), 2 (RGB), 4 (grey+alpha)
/// and 6 (RGBA) — which is what `tools/productionise.py` writes. Anything else
/// throws a [PngFormatException] naming the field, so an unsupported file is a
/// loud failure rather than a silent pass.
class PngImage {
  final int width;
  final int height;

  /// RGBA8 pixels, `width * height * 4` bytes, row-major from the top-left.
  final Uint8List rgba;

  const PngImage({
    required this.width,
    required this.height,
    required this.rgba,
  });

  /// The bounding box of pixels whose alpha is above [alphaThreshold].
  ///
  /// Returns `null` when nothing is visible — an empty frame, which is a defect
  /// the caller should report rather than treat as a tiny character.
  PixelBounds? alphaBounds({int alphaThreshold = 8}) {
    var minX = width, maxX = -1, minY = height, maxY = -1;
    for (var y = 0; y < height; y++) {
      final row = y * width * 4;
      for (var x = 0; x < width; x++) {
        if (rgba[row + x * 4 + 3] > alphaThreshold) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return null;
    return PixelBounds(
      left: minX,
      top: minY,
      right: maxX,
      bottom: maxY,
    );
  }
}

/// A measured rectangle in canvas pixels.
class PixelBounds {
  final int left;
  final int top;
  final int right;
  final int bottom;

  const PixelBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// The horizontal centre of the visible art.
  double get centerX => (left + right) / 2;

  /// The y of the lowest visible pixel — where the feet meet the ground.
  int get groundY => bottom;

  int get visibleWidth => right - left + 1;
  int get visibleHeight => bottom - top + 1;

  @override
  String toString() => 'PixelBounds($left,$top - $right,$bottom)';
}

/// Thrown when a PNG is outside the format this probe understands.
class PngFormatException implements Exception {
  final String message;
  const PngFormatException(this.message);
  @override
  String toString() => 'PngFormatException: $message';
}

/// The `(width, height)` from a PNG's IHDR, without decoding pixels.
///
/// Cheap enough to run over every frame in the pack, which is what the canvas
/// assertion does.
({int width, int height}) pngSize(Uint8List bytes) {
  if (bytes.length < 33) {
    throw const PngFormatException('file is too short to be a PNG');
  }
  final data = ByteData.sublistView(bytes);
  final width = data.getUint32(16);
  final height = data.getUint32(20);
  return (width: width, height: height);
}

/// Decodes [bytes] into RGBA8.
PngImage decodePng(Uint8List bytes) {
  if (bytes.length < 33 ||
      bytes[0] != 0x89 ||
      bytes[1] != 0x50 ||
      bytes[2] != 0x4E ||
      bytes[3] != 0x47) {
    throw const PngFormatException('not a PNG (bad signature)');
  }

  final data = ByteData.sublistView(bytes);
  final width = data.getUint32(16);
  final height = data.getUint32(20);
  final bitDepth = bytes[24];
  final colorType = bytes[25];
  final interlace = bytes[28];

  if (bitDepth != 8) {
    throw PngFormatException('unsupported bit depth $bitDepth (only 8)');
  }
  if (interlace != 0) {
    throw const PngFormatException('interlaced PNGs are not supported');
  }

  final channels = switch (colorType) {
    0 => 1, // grey
    2 => 3, // RGB
    4 => 2, // grey + alpha
    6 => 4, // RGBA
    _ => throw PngFormatException(
        'unsupported colour type $colorType (0, 2, 4, 6 only)'),
  };

  // Walk the chunks collecting IDAT.
  final idat = BytesBuilder(copy: false);
  var offset = 8;
  while (offset + 8 <= bytes.length) {
    final length = data.getUint32(offset);
    final type = String.fromCharCodes(bytes, offset + 4, offset + 8);
    final bodyStart = offset + 8;
    if (type == 'IDAT') {
      idat.add(Uint8List.sublistView(bytes, bodyStart, bodyStart + length));
    } else if (type == 'IEND') {
      break;
    }
    offset = bodyStart + length + 4; // + CRC
  }

  final raw = Uint8List.fromList(zlib.decode(idat.takeBytes()));
  final stride = width * channels;
  if (raw.length < height * (stride + 1)) {
    throw const PngFormatException('IDAT is shorter than the header claims');
  }

  final rgba = Uint8List(width * height * 4);
  final line = Uint8List(stride);
  final previous = Uint8List(stride);
  var cursor = 0;

  for (var y = 0; y < height; y++) {
    final filter = raw[cursor++];
    line.setRange(0, stride, raw, cursor);
    cursor += stride;

    switch (filter) {
      case 0: // none
        break;
      case 1: // sub
        for (var i = channels; i < stride; i++) {
          line[i] = (line[i] + line[i - channels]) & 0xFF;
        }
      case 2: // up
        for (var i = 0; i < stride; i++) {
          line[i] = (line[i] + previous[i]) & 0xFF;
        }
      case 3: // average
        for (var i = 0; i < stride; i++) {
          final a = i >= channels ? line[i - channels] : 0;
          line[i] = (line[i] + ((a + previous[i]) >> 1)) & 0xFF;
        }
      case 4: // paeth
        for (var i = 0; i < stride; i++) {
          final a = i >= channels ? line[i - channels] : 0;
          final b = previous[i];
          final c = i >= channels ? previous[i - channels] : 0;
          final p = a + b - c;
          final pa = (p - a).abs();
          final pb = (p - b).abs();
          final pc = (p - c).abs();
          final pr = (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c);
          line[i] = (line[i] + pr) & 0xFF;
        }
      default:
        throw PngFormatException('unknown scanline filter $filter');
    }

    // Expand to RGBA.
    for (var x = 0; x < width; x++) {
      final src = x * channels;
      final dst = (y * width + x) * 4;
      switch (colorType) {
        case 0:
          final g = line[src];
          rgba[dst] = g;
          rgba[dst + 1] = g;
          rgba[dst + 2] = g;
          rgba[dst + 3] = 255;
        case 2:
          rgba[dst] = line[src];
          rgba[dst + 1] = line[src + 1];
          rgba[dst + 2] = line[src + 2];
          rgba[dst + 3] = 255;
        case 4:
          final g = line[src];
          rgba[dst] = g;
          rgba[dst + 1] = g;
          rgba[dst + 2] = g;
          rgba[dst + 3] = line[src + 1];
        case 6:
          rgba[dst] = line[src];
          rgba[dst + 1] = line[src + 1];
          rgba[dst + 2] = line[src + 2];
          rgba[dst + 3] = line[src + 3];
      }
    }
    previous.setRange(0, stride, line);
  }

  return PngImage(width: width, height: height, rgba: rgba);
}

/// Decodes the PNG at [path].
PngImage decodePngFile(String path) => decodePng(File(path).readAsBytesSync());
