import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/mochi_layered_renderer.dart';
import 'package:cozy_focus_app/presentation/companion/room_presence.dart';

/// Where Mochi's feet land when it sits on furniture.
///
/// This is a two-part correction stacked on a single resolved point, and both
/// parts are invisible in a screenshot taken at a glance: a pet floating 15 pt
/// above a sofa reads as "that is how the art is", not as a bug. The numbers
/// that feed it come from two other files — the painter's own `Rect`s and the
/// extracted layer bbox — so they are re-read here rather than restated, and the
/// composed result is asserted rather than the individual terms.
void main() {
  final artworkSource =
      File('lib/presentation/widgets/cozy_furniture_artwork.dart')
          .readAsStringSync();

  /// The body of one painter method, so a `_cream` rect in `_sofa` cannot be
  /// confused with one in `_bed`.
  String painterMethod(String name) {
    final signature = 'void _$name(Canvas canvas) {';
    final start = artworkSource.indexOf(signature);
    expect(start, greaterThanOrEqualTo(0),
        reason: '$signature is gone, so the seat surface it defines cannot be '
            'checked — re-derive the fraction in PetRoomPresenceResolver');
    final rest = artworkSource.substring(start + signature.length);
    final next = rest.indexOf('\n  void ');
    return next < 0 ? rest : rest.substring(0, next);
  }

  /// The top edge of the painter's cushion/mattress, in the painter's own
  /// 100-unit space.
  double paintedSeatTop(String name) {
    final tops = RegExp(
      r'Rect\.fromLTWH\(\s*[\d.]+,\s*([\d.]+),\s*[\d.]+,\s*[\d.]+\s*\)'
      r'[^;]*_cream',
    )
        .allMatches(painterMethod(name))
        .map((m) => double.parse(m.group(1)!))
        .toList();

    expect(tops, isNotEmpty,
        reason: '_$name draws no `_cream` cushion, so there is no sitting '
            'surface to anchor to');
    return tops.reduce((a, b) => a < b ? a : b);
  }

  group('the seat surface is the painter\'s own cushion line', () {
    for (final entry in PetRoomPresenceResolver.seatSurfaceFractions.entries) {
      test('${entry.key}: ${entry.value}', () {
        expect(
          entry.value,
          closeTo(paintedSeatTop(entry.key) / 100, 1e-9),
          reason: '_${entry.key} draws its cushions at y = '
              '${paintedSeatTop(entry.key)} of 100',
        );
      });
    }

    test('the only seat with no line of its own is the flat one', () {
      // A positive statement, not an accident: `rug` is the one seat that lies
      // flat on the floor, so Mochi stands in the middle of it rather than on a
      // raised surface. Any other seat arriving without a surface would be an
      // oversight, and this makes it a failing test instead of a quiet default.
      final withoutSurface = PetRoomPresenceResolver.seatItemIds.difference(
          PetRoomPresenceResolver.seatSurfaceFractions.keys.toSet());
      expect(withoutSurface, {'rug'});
    });

    test('every seat the resolver accepts is one the painter can draw', () {
      for (final id in PetRoomPresenceResolver.seatItemIds) {
        // `painterMethod` fails outright if the method is gone; this also pins
        // that it draws something rather than being an empty stub.
        expect(
          painterMethod(id),
          anyOf(contains('_roundRect'), contains('canvas.draw')),
          reason: 'no _$id painter',
        );
      }
    });
  });

  group('feet land on the seat, not above it', () {
    const canvasHeight = 600.0;
    const itemScale = 1.0;
    const itemRenderedSize = 60.0 * itemScale;
    const anchorY = 0.5 * canvasHeight;
    const avatarSize = 92.0;

    test('a sofa placed at mid-canvas', () {
      const surface = 0.48;
      const cushionTop =
          anchorY - itemRenderedSize / 2 + surface * itemRenderedSize;
      expect(cushionTop, closeTo(298.8, 1e-9));

      final feetY = PetSeatPlacement.feetY(
        seatAnchorY: anchorY,
        seatRenderedSize: itemRenderedSize,
        seatSurfaceFraction: surface,
      );
      expect(feetY, closeTo(cushionTop, 1e-9));

      final top = PetSeatPlacement.boxTop(
        feetY: feetY,
        avatarSize: avatarSize,
        feetInsetFraction: MochiLayerAssets.feetInsetFraction,
      );

      // The invariant that matters: the character's *ink* bottom, not the box's
      // bottom edge, is what rests on the cushion.
      final inkFeet =
          top + avatarSize * (1 - MochiLayerAssets.feetInsetFraction);
      expect(inkFeet, closeTo(cushionTop, 1e-9));
    });

    test('the box bottom is 15.8 pt below the feet, and that is the bug', () {
      // The formula this replaced anchored the box by its bottom edge:
      // `top = anchorY - avatarSize`. Reproduced here so the size of the defect
      // is a number in the suite rather than a claim in a report.
      final surface = PetRoomPresenceResolver.seatSurfaceFraction('sofa');
      final cushionTop =
          anchorY - itemRenderedSize / 2 + surface * itemRenderedSize;

      const wrongInkFeet = (anchorY - avatarSize) +
          avatarSize * (1 - MochiLayerAssets.feetInsetFraction);

      expect(cushionTop - wrongInkFeet, closeTo(14.64, 0.01));
      expect(
        cushionTop - wrongInkFeet,
        greaterThan(avatarSize * 0.15),
        reason: 'a gap this size is visible on a 60 pt sofa, which is why it '
            'was worth correcting rather than documenting',
      );
    });

    test('a bed sits 4.8 pt above its anchor, 3.6 pt more than a sofa', () {
      final bedSurface = PetRoomPresenceResolver.seatSurfaceFraction('bed');
      final sofaSurface = PetRoomPresenceResolver.seatSurfaceFraction('sofa');

      // Both are anchored at their centre, so the *only* difference is the
      // cushion line: a bed's mattress sits 6 % of the sprite higher than a
      // sofa's cushions.
      final difference = (sofaSurface - bedSurface) * itemRenderedSize;
      expect(difference, closeTo(3.6, 1e-9));

      final bedFeet = PetSeatPlacement.feetY(
        seatAnchorY: anchorY,
        seatRenderedSize: itemRenderedSize,
        seatSurfaceFraction: bedSurface,
      );
      expect(anchorY - bedFeet, closeTo(4.8, 1e-9));
    });

    test('on the floor the resolved point is already the feet', () {
      // No seat: `seatRenderedSize` is zero, so the correction is a no-op and
      // the floor point passes through untouched.
      final feetY = PetSeatPlacement.feetY(
        seatAnchorY: PetRoomPresenceResolver.floorY * canvasHeight,
        seatRenderedSize: 0,
        seatSurfaceFraction: PetRoomPresenceResolver.defaultSeatSurfaceFraction,
      );
      expect(
          feetY, closeTo(PetRoomPresenceResolver.floorY * canvasHeight, 1e-9));
    });

    test('an unknown item falls back to the sprite centre, not to nothing', () {
      expect(
        PetRoomPresenceResolver.seatSurfaceFraction('rug'),
        PetRoomPresenceResolver.defaultSeatSurfaceFraction,
      );
      expect(
        PetRoomPresenceResolver.seatSurfaceFraction('SOFA'),
        PetRoomPresenceResolver.seatSurfaceFractions['sofa'],
        reason: 'item ids are persisted lower-cased but a caller should not '
            'have to know that',
      );
    });
  });
}
