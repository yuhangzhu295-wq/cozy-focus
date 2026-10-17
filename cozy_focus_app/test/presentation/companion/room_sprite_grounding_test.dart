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
      final correction = spriteGroundOffsetFor(
        targetFeetFraction: 1 - rigInset,
        spriteFeetInsetFraction: kSpriteFeetInsetFraction,
      );

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
      expect(
          spriteGroundOffsetFor(
            targetFeetFraction: 1 - MochiLayerAssets.feetInsetFraction,
            spriteFeetInsetFraction: kSpriteFeetInsetFraction,
          ),
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
      const rigInset = MochiLayerAssets.feetInsetFraction;
      final feet = CompanionPlacement.feetYFor(
        anchor: anchor,
        canvasHeight: 384,
      );
      // The exact contract, not "some number": the box is the rig's box, and
      // no correction parameter exists to change it.
      expect(box.top, closeTo(feet - 92 * (1 - rigInset), 1e-9));
      expect(box.size, 92);
    });

    test('the corrected sprite paws land on the contact line at every anchor',
        () {
      // The real composition: box top + the sprite's own ink bottom + the
      // in-box correction. This is what the previous version failed to assert -
      // it compared a constant to itself.
      final offset = spriteGroundOffsetFor(
        targetFeetFraction: 1 - MochiLayerAssets.feetInsetFraction,
        spriteFeetInsetFraction: kSpriteFeetInsetFraction,
      );

      for (final (itemId, surface) in const [
        ('', 0.0), // the floor anchor - the case that had no correction
        ('desk', 0.25),
        ('sofa', 0.42),
        ('bed', 0.5),
        ('chair', 0.74),
        ('table', 1.0),
      ]) {
        final anchor = AnchorPoint(
          id: 'a',
          itemId: itemId,
          roomItemId: 'r',
          x: 0.5,
          y: 0.7,
          surfaceFraction: surface,
        );
        final feet = CompanionPlacement.feetYFor(
          anchor: anchor,
          canvasHeight: 384,
        );
        final box = CompanionPlacement.boxFor(
          anchor: anchor,
          canvasWidth: 360,
          canvasHeight: 384,
          avatarSize: 92,
          feetInsetFraction: MochiLayerAssets.feetInsetFraction,
        );
        final paws = box.top +
            box.size * (1 - kSpriteFeetInsetFraction) +
            offset * box.size;
        expect(paws, closeTo(feet, 1e-9),
            reason: '$itemId: the sprite paws must land on the contact line');
      }
    });
  });

  group('scope', () {
    test('the default is null, so an unaware caller is unchanged', () {
      const options = CompanionVisualOptions();
      expect(options.spriteFeetTargetFraction, isNull);
    });

    test('only the room asks for it', () {
      // Source-level, because the alternative is rendering every page and
      // inspecting the player, and a page that silently gained the correction
      // would move the companion in a layout that was tuned without it.
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where(
              (f) => f.readAsStringSync().contains('spriteFeetTargetFraction:'))
          .map((f) => f.path.replaceAll(r'\', '/'))
          .toList();

      expect(sources, isNotEmpty);
      for (final path in sources) {
        if (path.endsWith('companion_visual_provider.dart') ||
            path.endsWith('companion_renderer.dart')) {
          continue; // the plumbing, not a caller
        }
        expect(path.endsWith('companion_avatar.dart'), isTrue,
            reason: '$path passes a ground target; only the room should');
      }

      final avatar = File('lib/presentation/companion/companion_avatar.dart')
          .readAsStringSync();
      // Gated on `inRoom`, not on the anchor: the floor anchor has no itemId,
      // so its role is null and an anchor-based gate left the most common
      // position without the correction.
      expect(avatar.contains('!widget.inRoom'), isTrue,
          reason: 'the correction has to be gated on the room flag');
      expect(avatar.contains('widget.roomAnchor == null'), isFalse,
          reason: 'the anchor is not the same fact as being in the room');

      final roomPage =
          File('lib/presentation/pages/room_page.dart').readAsStringSync();
      expect(roomPage.contains('inRoom: true'), isTrue,
          reason: 'the room must tell the avatar it is in the room');

      // Every sprite entry point has to forward the option. The first version
      // only did this on the dog's path, so the cat, the rabbit and imported
      // packs silently lost it.
      for (final path in const [
        'lib/presentation/companion/runtime/companion_sprite_art.dart',
        'lib/presentation/companion/placeholder_visual_providers.dart',
        'lib/presentation/widgets/pet_avatar_widget.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('groundOffsetFraction:'), isTrue,
            reason: '$path drops the ground correction');
      }
    });
  });
}
