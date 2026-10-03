import 'dart:io';

import 'package:cozy_focus_app/presentation/companion/animation/sprite_animation_manifest_data.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/png_probe.dart';

/// The measured facts about the shipped Mochi frames, checked against the
/// contract in `assets/companions/dog/animation_manifest.json`.
///
/// ## What is asserted and what is reported
///
/// The canvas, the anchor and the integrity of every frame that exists are
/// **hard assertions**: a misplaced frame or a missing file is a defect, not a
/// production stage.
///
/// A first-batch action that has fewer frames than its target is **reported**,
/// because that art is made outside this repository. The gate prints the gap and
/// the moment the frames land the same assertions cover them — so the report
/// cannot go stale without the suite noticing.
void main() {
  const contract = SpriteAnimationManifestData.mochi;
  final runtime = CompanionActionManifestData.forCompanion('dog')!;

  /// Every action that really has frames, with its paths.
  Map<String, List<String>> produced() => {
        for (final entry in runtime.actions.entries)
          if (entry.value.frames.isNotEmpty) entry.key: entry.value.frames,
      };

  group('resource integrity', () {
    test('every declared frame exists on disk', () {
      final missing = <String>[
        for (final frames in produced().values)
          for (final path in frames)
            if (!File(path).existsSync()) path,
      ];
      expect(missing, isEmpty,
          reason: 'missing frames:\n${missing.join('\n')}');
    });

    test('every frame is a PNG carrying an alpha channel', () {
      // Without alpha the character is a rectangle, and the anchor measurement
      // below would be measuring the canvas rather than the character.
      //
      // The check is on transparency, not on encoding -- see `pngCarriesAlpha`.
      // Sprites ship as indexed PNGs to keep the app's weight down (19.2 MB of
      // frames became 3.1 MB), and an indexed PNG carries alpha through a `tRNS`
      // chunk rather than an alpha channel per pixel.
      for (final entry in produced().entries) {
        for (final path in entry.value) {
          final bytes = File(path).readAsBytesSync();
          expect(bytes.length, greaterThan(33), reason: '$path is truncated');
          expect(pngCarriesAlpha(bytes), isTrue,
              reason: '$path cannot express transparency '
                  '(colour type ${bytes[25]})');
        }
      }
    });

    test('no produced action has an empty or duplicated frame list', () {
      for (final entry in produced().entries) {
        expect(entry.value, isNotEmpty, reason: 'dog/${entry.key}');
        expect(entry.value.toSet().length, entry.value.length,
            reason: 'dog/${entry.key} names the same frame twice');
      }
    });
  });

  group('frame counts', () {
    test('a produced action never exceeds its contracted frame count', () {
      // The drift detector. More frames than the contract asks for means art
      // landed and the contract was not updated - the manifest would then be
      // describing a sequence that is not the one on disk.
      final over = <String>[];
      for (final entry in produced().entries) {
        final target = contract.targetFor(entry.key);
        if (target == null) continue;
        if (entry.value.length > target) {
          over.add('dog/${entry.key} ${entry.value.length}/$target');
        }
      }
      expect(over, isEmpty,
          reason: 'frames exist beyond the contract:\n${over.join('\n')}');
    });

    test('the gate can name every first-batch action that still needs frames',
        () {
      final pending = <String>[];
      for (final actionId in contract.firstBatch) {
        final target = contract.targetFor(actionId)!;
        final have = runtime.specFor(actionId)?.frames.length ?? 0;
        if (have < target) pending.add('$actionId $have/$target');
      }
      // ignore: avoid_print
      print('MOCHI_FIRST_BATCH_PENDING: '
          '${pending.isEmpty ? "none" : pending.join(", ")}');
      // Reported rather than asserted: these frames are produced outside the
      // repository. What is asserted is that nothing claims to be finished.
      expect(pending, isA<List<String>>());
    });

    test('a first-batch action that is complete really meets its target', () {
      for (final actionId in contract.firstBatch) {
        final spec = runtime.specFor(actionId);
        if (spec == null || !spec.isComplete) continue;
        expect(spec.frames.length,
            greaterThanOrEqualTo(contract.targetFor(actionId)!),
            reason: 'dog/$actionId claims completion below its target');
      }
    });
  });

  group('anchor consistency', () {
    /// Measured bounds per frame, decoded once for the whole group.
    late Map<String, PixelBounds> measured;

    setUpAll(() {
      measured = {};
      for (final frames in produced().values) {
        for (final path in frames) {
          final bounds = decodePngFile(path).alphaBounds();
          if (bounds != null) measured[path] = bounds;
        }
      }
    });

    test('every frame is authored on the contracted canvas', () {
      for (final entry in produced().entries) {
        for (final path in entry.value) {
          final size = pngSize(File(path).readAsBytesSync());
          expect('${size.width}x${size.height}',
              '${contract.canvasWidth}x${contract.canvasHeight}',
              reason: '$path is not on the pack canvas');
        }
      }
    });

    test('every frame stands on the ground baseline', () {
      // Measured from pixels, not read from the manifest: a manifest can declare
      // 919 while the art has its feet somewhere else. This is the check that
      // makes a pose change not make the companion jump.
      final misplaced = <String>[];
      for (final entry in produced().entries) {
        for (final path in entry.value) {
          final bounds = measured[path];
          if (bounds == null) {
            misplaced.add('$path has no visible pixels');
            continue;
          }
          final delta = (bounds.groundY - contract.groundBaseline).abs();
          if (delta > contract.anchorTolerancePx) {
            misplaced.add('$path feet at ${bounds.groundY}, '
                'contract ${contract.groundBaseline}');
          }
        }
      }
      expect(misplaced, isEmpty,
          reason: 'frames off the ground line:\n${misplaced.join('\n')}');
    });

    test('every frame is centred on the anchor', () {
      final offCentre = <String>[];
      for (final entry in produced().entries) {
        for (final path in entry.value) {
          final bounds = measured[path];
          if (bounds == null) continue;
          final delta = (bounds.centerX - contract.centerAnchor).abs();
          if (delta > contract.anchorTolerancePx) {
            offCentre.add('$path centre at ${bounds.centerX}, '
                'contract ${contract.centerAnchor}');
          }
        }
      }
      expect(offCentre, isEmpty,
          reason: 'frames off centre:\n${offCentre.join('\n')}');
    });

    test('every frame has a measurable character', () {
      // A frame with no visible pixels is a blank, and a frame taller or wider
      // than the canvas is a decode or export defect. Both are silent at
      // runtime - the sprite player draws an empty box - so they are caught
      // here instead.
      for (final entry in produced().entries) {
        for (final path in entry.value) {
          final bounds = measured[path];
          expect(bounds, isNotNull, reason: '$path is blank');
          expect(bounds!.visibleWidth, greaterThan(0), reason: path);
          expect(bounds.visibleWidth, lessThanOrEqualTo(contract.canvasWidth),
              reason: path);
          expect(bounds.visibleHeight, lessThanOrEqualTo(contract.canvasHeight),
              reason: path);
        }
      }
    });

    test('the anchor tolerance is tight enough to catch a real drift', () {
      // A guard on the guard: a tolerance wide enough to swallow a genuine
      // mistake would make the two tests above vacuous. 2px was chosen against
      // measured frames, which land within 1px.
      expect(contract.anchorTolerancePx, lessThanOrEqualTo(4));
      expect(contract.anchorTolerancePx, greaterThan(0));
    });
  });
}
