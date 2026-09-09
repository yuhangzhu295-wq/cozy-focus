// Pure unit tests for clampNormalizedPosition (room_geometry.dart)
import 'package:flutter_test/flutter_test.dart';
import 'package:cozy_focus_app/core/geometry/room_geometry.dart';

void main() {
  group('clampNormalizedPosition', () {
    // Helper: 60x60 item on 390x844 canvas (common phone)
    ({double x, double y}) c390(double rawX, double rawY) =>
        clampNormalizedPosition(
          rawX: rawX,
          rawY: rawY,
          canvasWidth: 390,
          canvasHeight: 844,
          itemWidth: 60,
          itemHeight: 60,
        );

    ({double x, double y}) c320(double rawX, double rawY) =>
        clampNormalizedPosition(
          rawX: rawX,
          rawY: rawY,
          canvasWidth: 320,
          canvasHeight: 640,
          itemWidth: 60,
          itemHeight: 60,
        );

    ({double x, double y}) c430(double rawX, double rawY) =>
        clampNormalizedPosition(
          rawX: rawX,
          rawY: rawY,
          canvasWidth: 430,
          canvasHeight: 932,
          itemWidth: 60,
          itemHeight: 60,
        );

    test('1. center (0.5, 0.5) is unchanged on 390x844', () {
      final r = c390(0.5, 0.5);
      expect(r.x, closeTo(0.5, 0.001));
      expect(r.y, closeTo(0.5, 0.001));
    });

    test('2. raw 0.0 clamped to positive min boundary on 390x844', () {
      final r = c390(0.0, 0.0);
      // halfW = 30/390 ~0.077
      expect(r.x, greaterThan(0.0));
      expect(r.y, greaterThan(0.0));
    });

    test('3. raw 1.0 clamped to below-1 max boundary on 390x844', () {
      final r = c390(1.0, 1.0);
      expect(r.x, lessThan(1.0));
      expect(r.y, lessThan(1.0));
    });

    test('4. center stable on 320x640', () {
      final r = c320(0.5, 0.5);
      expect(r.x, closeTo(0.5, 0.001));
      expect(r.y, closeTo(0.5, 0.001));
    });

    test('5. center stable on 430x932', () {
      final r = c430(0.5, 0.5);
      expect(r.x, closeTo(0.5, 0.001));
      expect(r.y, closeTo(0.5, 0.001));
    });

    test('6. extreme negative clamped to min boundary', () {
      final r = c390(-5.0, -5.0);
      expect(r.x, greaterThan(0.0));
      expect(r.y, greaterThan(0.0));
    });

    test('7. extreme positive clamped to max boundary', () {
      final r = c390(99.0, 99.0);
      expect(r.x, lessThan(1.0));
      expect(r.y, lessThan(1.0));
    });

    test('8. symmetric: minX + maxX == 1.0 on 390x844', () {
      final minR = c390(0.0, 0.5);
      final maxR = c390(1.0, 0.5);
      expect(minR.x + maxR.x, closeTo(1.0, 0.001));
    });

    test('9. output is always in [0..1] for any raw input', () {
      for (final v in [-2.0, -1.0, 0.0, 0.3, 0.5, 0.8, 1.0, 2.0]) {
        final r = c390(v, v);
        expect(r.x, inInclusiveRange(0.0, 1.0),
            reason: 'x out of range for raw=$v');
        expect(r.y, inInclusiveRange(0.0, 1.0),
            reason: 'y out of range for raw=$v');
      }
    });

    test('10. smaller canvas produces larger relative margins', () {
      // On a narrower canvas the half-item fraction is bigger
      final r320 = c320(0.0, 0.5);
      final r430 = c430(0.0, 0.5);
      // minX on 320 = 30/320 = 0.09375; minX on 430 = 30/430 ~0.070
      expect(r320.x, greaterThan(r430.x));
    });

    test('11. zero canvas dimensions returns raw value unchanged', () {
      final r = clampNormalizedPosition(
        rawX: 0.5,
        rawY: 0.5,
        canvasWidth: 0,
        canvasHeight: 0,
        itemWidth: 60,
        itemHeight: 60,
      );
      expect(r.x, equals(0.5));
      expect(r.y, equals(0.5));
    });

    // ── Scale-aware bounds ────────────────────────────────────────────────
    // Rendered size = _itemSize * scale; larger scale ⟹ smaller allowed range.

    test('12. scale=0.5 allows more room than scale=1.0', () {
      // At scale 0.5 the rendered item is 30px on a 390x844 canvas.
      final rSmall = clampNormalizedPosition(
        rawX: 0.0,
        rawY: 0.5,
        canvasWidth: 390,
        canvasHeight: 844,
        itemWidth: 60 * 0.5,
        itemHeight: 60 * 0.5,
      );
      final rNormal = clampNormalizedPosition(
        rawX: 0.0,
        rawY: 0.5,
        canvasWidth: 390,
        canvasHeight: 844,
        itemWidth: 60 * 1.0,
        itemHeight: 60 * 1.0,
      );
      // Smaller item → centre can be closer to 0.
      expect(rSmall.x, lessThan(rNormal.x));
    });

    test('13. scale=2.0 produces larger clamp margin than scale=1.0', () {
      final rBig = clampNormalizedPosition(
        rawX: 0.0,
        rawY: 0.5,
        canvasWidth: 390,
        canvasHeight: 844,
        itemWidth: 60 * 2.0,
        itemHeight: 60 * 2.0,
      );
      final rNormal = clampNormalizedPosition(
        rawX: 0.0,
        rawY: 0.5,
        canvasWidth: 390,
        canvasHeight: 844,
        itemWidth: 60 * 1.0,
        itemHeight: 60 * 1.0,
      );
      // Bigger item → centre must stay further from edge.
      expect(rBig.x, greaterThan(rNormal.x));
    });

    test('14. scale=1.5: item edges stay within canvas bounds', () {
      const canvas = 390.0;
      const itemW = 60.0 * 1.5; // 90px
      final rMin = clampNormalizedPosition(
        rawX: -1.0,
        rawY: 0.5,
        canvasWidth: canvas,
        canvasHeight: 844,
        itemWidth: itemW,
        itemHeight: itemW,
      );
      final rMax = clampNormalizedPosition(
        rawX: 2.0,
        rawY: 0.5,
        canvasWidth: canvas,
        canvasHeight: 844,
        itemWidth: itemW,
        itemHeight: itemW,
      );
      const halfNorm = (itemW / 2) / canvas;
      // Left edge = centre - halfNorm >= 0
      expect(rMin.x - halfNorm, greaterThanOrEqualTo(-0.001));
      // Right edge = centre + halfNorm <= 1
      expect(rMax.x + halfNorm, lessThanOrEqualTo(1.001));
    });

    test('15. scale=2.0 canvas 320x640: item edges within bounds', () {
      const cW = 320.0;
      const cH = 640.0;
      const itemW = 60.0 * 2.0; // 120px
      for (final raw in [-5.0, 0.0, 0.5, 1.0, 5.0]) {
        final r = clampNormalizedPosition(
          rawX: raw,
          rawY: raw,
          canvasWidth: cW,
          canvasHeight: cH,
          itemWidth: itemW,
          itemHeight: itemW,
        );
        const halfNormX = (itemW / 2) / cW;
        const halfNormY = (itemW / 2) / cH;
        expect(r.x - halfNormX, greaterThanOrEqualTo(-0.001),
            reason: 'left edge out for raw=$raw');
        expect(r.x + halfNormX, lessThanOrEqualTo(1.001),
            reason: 'right edge out for raw=$raw');
        expect(r.y - halfNormY, greaterThanOrEqualTo(-0.001),
            reason: 'top edge out for raw=$raw');
        expect(r.y + halfNormY, lessThanOrEqualTo(1.001),
            reason: 'bottom edge out for raw=$raw');
      }
    });
  });
}
