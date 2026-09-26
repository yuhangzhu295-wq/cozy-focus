import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/mochi_layered_renderer.dart';

/// The layer geometry in [MochiLayerAssets] is *measured*, not designed: it
/// comes from `assets/mochi/base/layers.json`, which
/// `tools/mochi_layers/extract_mochi_layers.py` regenerates from the approved
/// V4.1 artwork.
///
/// Until this test existed, every one of those constants was a bare literal with
/// only a comment tying it to the JSON — so a re-export could change the crop
/// and leave the renderer assembling the wrong picture, with nothing to notice
/// it. `aspect` and the pivots would show up as a subtly misaligned pet; the
/// feet inset shows up as a pet floating above the sofa it is sitting on, which
/// is the kind of thing that reads as "the art is like that" rather than as a
/// bug.
void main() {
  final json = jsonDecode(
    File('assets/mochi/base/layers.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final crop = json['character_crop'] as Map<String, dynamic>;
  final width = (crop['width'] as num).toDouble();
  final height = (crop['height'] as num).toDouble();
  final layers = json['layers'] as Map<String, dynamic>;

  /// `Alignment` is the layer image's own coordinate space: -1 at one edge, +1
  /// at the other. Derived from the measured pivot pixel rather than restated,
  /// so the two cannot agree by coincidence.
  double alignmentOf(num pivotPx, double extent) =>
      (pivotPx - extent / 2) / (extent / 2);

  group('the crop matches the measured artwork', () {
    test('aspect', () {
      expect(
        MochiLayerAssets.aspect,
        closeTo(width / height, 1e-9),
        reason: 'aspect is width / height of the character crop',
      );
      // The file's own rounded copy, kept so a mismatch between the two
      // recorded values is also visible.
      expect(MochiLayerAssets.aspect, closeTo(crop['aspect'] as double, 1e-5));
    });

    test('feet inset', () {
      final bodyBbox = (layers['body'] as Map<String, dynamic>)['bbox'] as List;
      final bodyBottom = (bodyBbox[3] as num).toDouble();

      // Two gaps stack below the paws, and both are read here rather than
      // restated:
      final letterbox = (width - height) / 2;
      final emptyRowsBelowInk = height - 1 - bodyBottom;
      final expected = (letterbox + emptyRowsBelowInk) / width;

      expect(
        MochiLayerAssets.feetInsetFraction,
        closeTo(expected, 1e-9),
        reason: 'feet sit $letterbox letterbox px + $emptyRowsBelowInk empty '
            'rows above the bottom edge of the square box',
      );

      // And the measured magnitude, so the number in the doc comment cannot
      // drift from the number in the code.
      expect(MochiLayerAssets.feetInsetFraction, closeTo(0.1722, 5e-5));
      expect(MochiLayerAssets.feetInsetFraction * 92, closeTo(15.84, 0.01));
    });

    test('every pivot the renderer pins', () {
      final pivots = json['pivots'] as Map<String, dynamic>;

      Alignment measured(String key) {
        final px = pivots[key] as List;
        return Alignment(
          alignmentOf(px[0] as num, width),
          alignmentOf(px[1] as num, height),
        );
      }

      final expected = <String, Alignment>{
        'sprout': MochiLayerAssets.sproutPivot,
        'ear_left': MochiLayerAssets.earLeftPivot,
        'ear_right': MochiLayerAssets.earRightPivot,
        'eye_left': MochiLayerAssets.eyeLeftPivot,
        'eye_right': MochiLayerAssets.eyeRightPivot,
      };

      for (final entry in expected.entries) {
        final want = measured(entry.key);
        // The Dart constants are rounded to four decimals.
        expect(entry.value.x, closeTo(want.x, 5e-5), reason: entry.key);
        expect(entry.value.y, closeTo(want.y, 5e-5), reason: entry.key);
      }

      // `headPivot` is deliberately absent: it is the neck point the head group
      // rotates about, computed for the rig rather than a measured layer pivot,
      // so there is nothing in the JSON to check it against.
    });

    test('the JSON still describes the layers the renderer loads', () {
      // Enumerated here rather than read from a list on the class, so that a
      // layer added to one side alone is a visible edit to this map.
      final byName = <String, String>{
        'body': MochiLayerAssets.body,
        'ear_left': MochiLayerAssets.earLeft,
        'ear_right': MochiLayerAssets.earRight,
        'sprout': MochiLayerAssets.sprout,
        'face': MochiLayerAssets.face,
        'eye_left': MochiLayerAssets.eyeLeft,
        'eye_right': MochiLayerAssets.eyeRight,
      };

      expect(
          byName.keys.toSet(), (json['z_order'] as List).cast<String>().toSet(),
          reason: 'the painter order and the renderer disagree about which '
              'layers exist');

      expect(
        byName.values.toSet(),
        layers.values
            .map((l) => (l as Map<String, dynamic>)['file'] as String)
            .toSet(),
        reason: 'a layer measured in the JSON is loaded from a different path',
      );
    });
  });
}
