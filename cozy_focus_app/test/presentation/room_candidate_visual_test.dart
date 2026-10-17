import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cozy_focus_app/presentation/widgets/cozy_room_handdrawn_candidate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pixel-level guards for the three defects the room candidate shipped with.
///
/// ## Why pixels and not structure
///
/// V1 (unreadable shelf), V2 (a dark diagonal band that reads as a shadow rather
/// than a wall) and V3 (a window smaller and dimmer than the shipped room's) are
/// all *appearance* defects. A widget test that asserted "a shelf is painted"
/// would have passed on the broken version: the shapes were all there, they just
/// could not be read. So each guard measures the rendered frame.
///
/// The thresholds are calibrated against the rendered candidate, not invented:
/// each constant below records the value the fixed painter produces and the
/// value the defective one produced, so a regression has to move a number rather
/// than merely change a shape.
void main() {
  const size = Size(360, 384);

  Future<_Frame> render(WidgetTester tester, Widget child) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        // Center, because the root gets tight 800x600 constraints: a bare
        // SizedBox at the root is forced to the surface size, and the guards
        // below would then sample a 800x600 frame while reasoning in 360x384.
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    late _Frame frame;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame = _Frame(
        data!.buffer.asUint8List(),
        image.width,
        image.height,
      );
      image.dispose();
    });
    return frame;
  }

  testWidgets('V2: the side wall fills the top-left instead of a dark band',
      (tester) async {
    final frame = await render(
      tester,
      const CozyRoomHandDrawn(deskLine: 0.60),
    );

    // The region the old wedge painted darkest: near the left edge, above the
    // middle of the wall. A wall plane is a mid-tone; the band that read as a
    // shadow measured well below it.
    // The top edge of the left quarter. In the fixed painter the side wall
    // reaches the frame, so this strip is wall tone. In the defective one the
    // near edge started at `deskY * 0.30`, so the strip above it was the lighter
    // back wall - that step *is* the diagonal band.
    final luma = frame.averageLuma(
      left: 0,
      top: 0,
      right: (size.width * 0.25).round(),
      bottom: 4,
    );

    // Fixed painter: 135.9. The defective wedge left the lighter back wall
    // above its near edge and measured 150.7 here; the threshold sits between
    // them, not at either value.
    expect(luma, lessThan(143),
        reason: 'the side wall has to reach the top edge, not leave a lighter '
            'back-wall strip above a diagonal seam: average luma $luma');
  });

  testWidgets(
      'V3: the window is large and bright enough to be the light source',
      (tester) async {
    final frame = await render(
      tester,
      const CozyRoomHandDrawn(deskLine: 0.60),
    );

    // The sky quadrant, left of the centre mullion and above the horizontal
    // one. Sampling the whole opening would include the frame bars and the
    // greenery and measure the window's *contents* rather than its light.
    final luma = frame.averageLuma(
      left: (size.width * 0.54).round(),
      top: (size.height * 0.13).round(),
      right: (size.width * 0.67).round(),
      bottom: (size.height * 0.20).round(),
    );
    expect(luma, greaterThan(215),
        reason: 'the window has to read as light: average luma $luma');

    // And it has to occupy a real share of the wall. Count near-white pixels in
    // the upper wall band; a small bright rectangle cannot pass.
    final bright = frame.countWhere(
      left: (size.width * 0.45).round(),
      top: (size.height * 0.05).round(),
      right: (size.width * 0.95).round(),
      bottom: (size.height * 0.40).round(),
      test: (r, g, b) => r > 225 && g > 215 && b > 185,
    );
    final area = ((size.width * 0.50) * (size.height * 0.35)).round();
    // Fixed painter: 0.563. The old 0.34 x 0.50 opening measured 0.427; the
    // threshold sits between them. This counts *area*, which is what "bigger
    // and brighter" actually changed - the sky's own luma was already high in
    // both versions, so sampling brightness alone proved nothing.
    expect(bright / area, greaterThan(0.49),
        reason:
            'the window covers ${(bright / area * 100).toStringAsFixed(1)}% '
            'of the upper-right wall; the old opening covered 42.7%');
  });

  testWidgets('V1: the shelf has readable structure, not a blurred smudge',
      (tester) async {
    final frame = await render(
      tester,
      const CozyRoomHandDrawn(deskLine: 0.60),
    );

    // Book spines are several distinct warm tones. A smudge has a smooth
    // gradient and very few distinct quantised colours; readable spines produce
    // many. Quantise to 5 bits per channel and count the occupied bins in the
    // shelf band.
    final bins = frame.distinctColorBins(
      left: 0,
      top: (size.height * 0.24).round(),
      right: (size.width * 0.28).round(),
      bottom: (size.height * 0.52).round(),
    );
    // Fixed painter: 127 bins. The 3.1-sigma version, without the backing panel
    // and with smaller spines, measured 92; the threshold sits between them.
    expect(bins, greaterThan(108),
        reason:
            'the shelf band carries $bins colour bins; a smudge carries few');
  });
}

class _Frame {
  final Uint8List rgba;
  final int width;
  final int height;

  _Frame(this.rgba, this.width, this.height);

  int _offset(int x, int y) => (y * width + x) * 4;

  double averageLuma({
    required int left,
    required int top,
    required int right,
    required int bottom,
  }) {
    var sum = 0.0;
    var count = 0;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final i = _offset(x, y);
        sum += 0.2126 * rgba[i] + 0.7152 * rgba[i + 1] + 0.0722 * rgba[i + 2];
        count++;
      }
    }
    return count == 0 ? 0 : sum / count;
  }

  int countWhere({
    required int left,
    required int top,
    required int right,
    required int bottom,
    required bool Function(int r, int g, int b) test,
  }) {
    var count = 0;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final i = _offset(x, y);
        if (test(rgba[i], rgba[i + 1], rgba[i + 2])) count++;
      }
    }
    return count;
  }

  int distinctColorBins({
    required int left,
    required int top,
    required int right,
    required int bottom,
  }) {
    final bins = <int>{};
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final i = _offset(x, y);
        bins.add((rgba[i] >> 3) << 10 |
            (rgba[i + 1] >> 3) << 5 |
            (rgba[i + 2] >> 3));
      }
    }
    return bins.length;
  }
}
