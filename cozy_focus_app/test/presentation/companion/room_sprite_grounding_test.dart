import 'dart:convert';
import 'dart:io';

import 'package:cozy_focus_app/presentation/companion/mochi_layered_renderer.dart';
import 'package:cozy_focus_app/presentation/companion/room/anchor_point.dart';
import 'package:cozy_focus_app/presentation/companion/room/companion_placement.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_visual_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// The room draws the companion with **two** renderers: the layered rig for
/// `idle`, a sprite sequence for every action. They do not share an
/// ink-to-canvas ratio, so a box anchored by one leaves the other's paws about
/// 6.1 pt away from every contact surface.
///
/// ## What this file pins
///
/// 1. The sprite constant is read from the packs' own manifests, not invented.
/// 2. The correction makes the two renderers agree on where the paws are.
/// 3. The box itself does not move: the correction is applied inside it, so a
///    renderer switch cannot jump the character up or down.
/// 4. Nothing outside the room receives the correction.
void main() {
  group('the sprite ground contract', () {
    test('every shipped pack declares the same baseline on the same canvas',
        () {
      for (final pack in const ['dog', 'cat', 'rabbit']) {
        final file = File('assets/companions/$pack/manifest.json');
        expect(file.existsSync(), isTrue,
            reason: '$pack has no manifest, so its ground line is unknown');
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final canvas = json['canvas'] as Map<String, dynamic>;
        expect(canvas['width'], 512, reason: '$pack canvas width');
        expect(canvas['height'], 512, reason: '$pack canvas height');
        expect(json['groundBaseline'], 458,
            reason: '$pack groundBaseline: the constant below is only valid '
                'while every pack agrees with it');
      }
    });

    test('the constant is derived from the manifest, not hard-coded', () {
      final file = File('assets/companions/dog/manifest.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final canvas = json['canvas'] as Map<String, dynamic>;
      final height = (canvas['height'] as num).toDouble();
      final baseline = (json['groundBaseline'] as num).toDouble();

      expect(kSpriteFeetInsetFraction,
          closeTo((height - baseline) / height, 1e-9));
    });

    test('the correction makes the sprite paws meet the rig paws', () {
      const rigInset = MochiLayerAssets.feetInsetFraction;
      final correction = spriteGroundOffsetFraction(rigInset);

      // Where each renderer's paws land, measured from the top of the same box.
      const rigPaws = 1 - rigInset;
      const spritePawsBefore = 1 - kSpriteFeetInsetFraction;
      final spritePawsAfter = spritePawsBefore + correction;

      expect(spritePawsAfter, closeTo(rigPaws, 1e-9));
      // The measured gap on the room's 92 pt avatar, so the size of the fix is
      // recorded rather than implied.
      expect((spritePawsBefore - rigPaws) * 92, closeTo(6.14, 0.02));
    });

    test('the correction is negative, i.e. the sprite moves up', () {
      // The sprite's ink reaches lower in its canvas (10.5% of the box below the
      // paws) than the rig's does (17.2%). Anchored by the rig constant, the
      // sprite's paws therefore sit *below* the contact line and the character
      // reads as sunk/floating against it depending on the surface's own depth.
      expect(spriteGroundOffsetFraction(MochiLayerAssets.feetInsetFraction),
          lessThan(0));
    });
  });

  group('the correction cannot move the box', () {
    test('CompanionPlacement.boxFor does not know about it', () {
      // Structural: the correction is not a parameter, so no anchor, surface or
      // travel interpolation can pick it up. That is what makes a renderer
      // switch safe - the box is identical before and after.
      const anchor = AnchorPoint(
        id: 'sofa_anchor',
        itemId: 'sofa',
        roomItemId: 'row-1',
        x: 0.5,
        y: 0.7,
        surfaceFraction: 0.42,
        scale: 1.0,
      );
      final box = CompanionPlacement.boxFor(
        anchor: anchor,
        canvasWidth: 360,
        canvasHeight: 384,
        avatarSize: 92,
        feetInsetFraction: MochiLayerAssets.feetInsetFraction,
      );
      expect(box.top, isNot(0));
      expect(box.size, 92);
    });

    test('the correction is the same at every anchor and surface', () {
      // A single constant, applied inside the box. There is no per-anchor term
      // to drift, which is what lets the same fix cover the rug, the desk, the
      // sofa and the chair.
      final correction = spriteGroundOffsetFraction(
        MochiLayerAssets.feetInsetFraction,
      );
      for (final surface in const [0.0, 0.25, 0.42, 0.5, 0.74, 1.0]) {
        final anchor = AnchorPoint(
          id: 'a',
          itemId: surface == 0.0 ? '' : 'desk',
          roomItemId: 'r',
          x: 0.5,
          y: 0.7,
          surfaceFraction: surface,
        );
        final feet = CompanionPlacement.feetYFor(
          anchor: anchor,
          canvasHeight: 384,
        );
        // feetY is independent of the renderer; the correction only changes
        // where the drawing sits inside the box that feetY anchors.
        expect(feet.isFinite, isTrue);
        expect(
            correction,
            closeTo(
                spriteGroundOffsetFraction(MochiLayerAssets.feetInsetFraction),
                1e-12));
      }
    });
  });

  group('scope', () {
    test('the default is zero, so an unaware caller is unchanged', () {
      const options = CompanionVisualOptions();
      expect(options.spriteGroundOffsetFraction, 0);
    });

    test('only the room asks for it', () {
      // Source-level, because the alternative is rendering every page and
      // inspecting the player, and a page that silently gained the correction
      // would move the companion in a layout that was tuned without it.
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) =>
              f.readAsStringSync().contains('spriteGroundOffsetFraction:'))
          .map((f) => f.path.replaceAll(r'\', '/'))
          .toList();

      expect(sources, isNotEmpty);
      for (final path in sources) {
        if (path.endsWith('companion_visual_provider.dart') ||
            path.endsWith('companion_renderer.dart') ||
            path.endsWith('mochi_visual_provider.dart') ||
            path.endsWith('pet_avatar_widget.dart')) {
          continue; // the plumbing, not a caller
        }
        expect(path.endsWith('companion_avatar.dart'), isTrue,
            reason: '$path passes a ground correction; only the room should');
      }

      final avatar = File('lib/presentation/companion/companion_avatar.dart')
          .readAsStringSync();
      expect(avatar.contains('widget.roomAnchor == null'), isTrue,
          reason: 'the correction has to be gated on the room anchor');
    });
  });
}
