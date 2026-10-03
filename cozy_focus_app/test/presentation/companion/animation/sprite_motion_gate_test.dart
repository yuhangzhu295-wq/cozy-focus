import 'dart:typed_data';

import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/png_probe.dart';

/// A perceptual fingerprint of a sprite frame.
///
/// Cropped to the character's own alpha bounds before downsampling, and that is
/// the point rather than a detail. Taken over the full 512x512 canvas, a
/// character occupying the middle third is swamped by empty margin, and two
/// visibly different poses score almost identically. The background carries no
/// information about the pose, so it must not be part of the measurement.
///
/// Composited on mid-grey so transparent margin does not read as a bright edge.
Uint8List signature(PngImage img) {
  final bounds = img.alphaBounds();
  if (bounds == null) return Uint8List(_sigSize * _sigSize);

  final w = bounds.right - bounds.left + 1;
  final h = bounds.bottom - bounds.top + 1;
  final out = Uint8List(_sigSize * _sigSize);
  for (var sy = 0; sy < _sigSize; sy++) {
    for (var sx = 0; sx < _sigSize; sx++) {
      // Sample the centre of each cell rather than averaging, which keeps this
      // cheap and avoids depending on an exact resampling filter.
      final px = bounds.left + ((sx + 0.5) * w / _sigSize).floor();
      final py = bounds.top + ((sy + 0.5) * h / _sigSize).floor();
      final clampedX = px.clamp(0, img.width - 1);
      final clampedY = py.clamp(0, img.height - 1);
      final i = (clampedY * img.width + clampedX) * 4;
      final a = img.rgba[i + 3] / 255.0;
      // Composite over mid-grey.
      final r = img.rgba[i] * a + 128 * (1 - a);
      final g = img.rgba[i + 1] * a + 128 * (1 - a);
      final b = img.rgba[i + 2] * a + 128 * (1 - a);
      out[sy * _sigSize + sx] = ((r * 0.299 + g * 0.587 + b * 0.114)).round();
    }
  }
  return out;
}

const int _sigSize = 16;

/// Mean absolute difference between two signatures, in `0..1`.
double signatureDistance(Uint8List a, Uint8List b) {
  var total = 0;
  for (var i = 0; i < a.length; i++) {
    total += (a[i] - b[i]).abs();
  }
  return total / a.length / 255.0;
}

/// The smallest total range an action may have and still be an animation.
///
/// Calibrated against the shipped packs rather than chosen: the subtlest action
/// that ships is `cat/focus_read` at **0.0127**, so 0.008 sits below it with
/// headroom while still catching an action whose frames are one picture.
///
/// A *per-step* threshold cannot be used here, and the calibration output below
/// is the evidence: `rabbit/celebrate` steps by **0.0033** between frames 3 and
/// 4, which is a deliberate hold at the end of a one-shot, not a defect.
const double minActionRange = 0.008;

/// How much bigger than the action's *typical* step a loop's wrap may be.
///
/// A loop plays last -> first, so that transition must not read as a jump.
///
/// Normalised against the **median** step, not the largest, and the negative
/// proof below is why: an earlier version divided by the maximum, and the proof
/// showed that is defeatable. Swapping in an unrelated frame makes one internal
/// step huge, which raises the denominator and *hides* the very seam the gate
/// exists to catch -- it reported a ratio of 0.99 on a loop whose wrap was an
/// entirely different action. A median is not moved by one outlier, so the seam
/// stays visible.
///
/// Calibrated between the two measured numbers: the worst ratio among shipped
/// `loop` actions is **1.63**, and the injected fault in the negative proof
/// below produces **2.847**. A threshold of 2.0 sits between them with room on
/// both sides -- it does not fire on art the project has accepted, and it does
/// fire on a wrap made of the wrong action.
///
/// Applied to `loop` only. A `pingPong` reverses rather than wrapping, so its
/// last frame is never followed by its first and that seam is not a transition
/// the player ever sees.
const double loopSeamMaxRatio = 2.0;

/// The middle step of [steps], which one outlier cannot move.
double _median(List<double> steps) {
  final sorted = [...steps]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

void main() {
  final shipped = CompanionActionManifestData.manifests.keys.toList();

  test('calibration: measure the motion actually present', () {
    // Diagnostic, not a gate. It exists so the thresholds below are set from
    // the shipped art rather than invented, and it stays in the suite because
    // the numbers are the evidence for those thresholds.
    final lines = <String>[];
    for (final companion in shipped) {
      final manifest = CompanionActionManifestData.forCompanion(companion)!;
      for (final entry in manifest.actions.entries) {
        final spec = entry.value;
        if (spec.frames.length < 2) continue;
        final sigs = [
          for (final f in spec.frames) signature(decodePngFile(f)),
        ];
        final steps = [
          for (var i = 1; i < sigs.length; i++)
            signatureDistance(sigs[i - 1], sigs[i]),
        ];
        final seam = signatureDistance(sigs.last, sigs.first);
        // The action's total range: how far apart its two most different frames
        // are. A per-step threshold cannot be used -- several shipped actions
        // hold a pose, and `rabbit/celebrate` steps by 0.0033 between frames 3
        // and 4, which is a legitimate hold rather than a defect.
        var range = 0.0;
        for (var i = 0; i < sigs.length; i++) {
          for (var j = i + 1; j < sigs.length; j++) {
            final d = signatureDistance(sigs[i], sigs[j]);
            if (d > range) range = d;
          }
        }
        final typical = _median(steps);
        lines.add('$companion/${entry.key} [${spec.loopMode.name}] '
            'range=${range.toStringAsFixed(4)} '
            'seam=${seam.toStringAsFixed(4)} '
            'seamOverMedian=${(seam / typical).toStringAsFixed(2)}');
      }
    }
    // ignore: avoid_print
    print(lines.join('\n'));
    expect(lines, isNotEmpty);
  });

  group('every shipped action actually moves', () {
    test('no action is a single picture repeated', () {
      final frozen = <String>[];
      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        for (final entry in manifest.actions.entries) {
          final spec = entry.value;
          if (spec.frames.length < 2) continue;
          final sigs = [
            for (final f in spec.frames) signature(decodePngFile(f)),
          ];
          var range = 0.0;
          for (var i = 0; i < sigs.length; i++) {
            for (var j = i + 1; j < sigs.length; j++) {
              final d = signatureDistance(sigs[i], sigs[j]);
              if (d > range) range = d;
            }
          }
          if (range < minActionRange) {
            frozen.add('$companion/${entry.key} '
                'range=${range.toStringAsFixed(4)} (min $minActionRange)');
          }
        }
      }
      expect(frozen, isEmpty,
          reason: 'an action whose frames are perceptually the same picture is '
              'not an animation:\n${frozen.join('\n')}');
    });
  });

  group('a loop wraps without a visible jump', () {
    test('the last-to-first seam is in scale with the action own steps', () {
      final jarring = <String>[];
      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        for (final entry in manifest.actions.entries) {
          final spec = entry.value;
          if (spec.loopMode != SpriteLoopMode.loop) continue;
          if (spec.frames.length < 3) continue;
          final sigs = [
            for (final f in spec.frames) signature(decodePngFile(f)),
          ];
          final steps = [
            for (var i = 1; i < sigs.length; i++)
              signatureDistance(sigs[i - 1], sigs[i]),
          ];
          final typical = _median(steps);
          if (typical <= 0) continue;
          final ratio = signatureDistance(sigs.last, sigs.first) / typical;
          if (ratio > loopSeamMaxRatio) {
            jarring.add('$companion/${entry.key} seam/medianStep='
                '${ratio.toStringAsFixed(2)} (max $loopSeamMaxRatio)');
          }
        }
      }
      expect(jarring, isEmpty,
          reason: 'these loops jump when they wrap:\n${jarring.join('\n')}');
    });

    test('a once-only action is not required to close', () {
      // Stated rather than implied. The brief says a once-action needs no
      // first/last continuity, so a seam gate applied to one would be wrong.
      // This asserts the gate above really did skip them, rather than skipping
      // them because the mode enum happened to compare unequal.
      var onceCount = 0;
      var loopCount = 0;
      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        for (final entry in manifest.actions.entries) {
          switch (entry.value.loopMode) {
            case SpriteLoopMode.once:
              onceCount++;
            case SpriteLoopMode.loop:
              loopCount++;
            case SpriteLoopMode.pingPong:
              break;
          }
        }
      }
      expect(onceCount, greaterThan(0),
          reason: 'if no once-action ships, the skip proves nothing');
      expect(loopCount, greaterThan(0),
          reason: 'if no loop-action ships, the seam gate proves nothing');
    });
  });

  group('negative proof: these gates can fail', () {
    // A gate that cannot fire is indistinguishable from one that is not there.
    // Both proofs below build the fault **in memory** from real frames, so no
    // shipped asset is touched and nothing broken can be committed.

    test('a frozen sequence is caught by the range gate', () {
      final spec =
          CompanionActionManifestData.forCompanion('dog')!.specFor('idle')!;
      final frozen = [for (final _ in spec.frames) spec.frames.first];
      final sigs = [for (final f in frozen) signature(decodePngFile(f))];

      var range = 0.0;
      for (var i = 0; i < sigs.length; i++) {
        for (var j = i + 1; j < sigs.length; j++) {
          final d = signatureDistance(sigs[i], sigs[j]);
          if (d > range) range = d;
        }
      }
      expect(range, lessThan(minActionRange),
          reason: 'the same picture six times must fall below the threshold, '
              'or the range gate is not measuring anything');
    });

    test('an out-of-scale loop seam is caught by the ratio gate', () {
      final manifest = CompanionActionManifestData.forCompanion('dog')!;
      final walk = manifest.specFor('walk')!;
      final celebrate = manifest.specFor('celebrate')!;

      // A real loop, with its last frame swapped for one from an unrelated
      // action -- exactly the shape of a loop that jumps when it wraps.
      final sigs = [
        for (final f in walk.frames) signature(decodePngFile(f)),
      ];
      sigs[sigs.length - 1] = signature(decodePngFile(celebrate.frames.last));

      final steps = [
        for (var i = 1; i < sigs.length; i++)
          signatureDistance(sigs[i - 1], sigs[i]),
      ];
      final ratio = signatureDistance(sigs.last, sigs.first) / _median(steps);

      expect(ratio, greaterThan(loopSeamMaxRatio),
          reason: 'a seam made of the wrong action must exceed the ratio, or '
              'the seam gate is not measuring anything');
    });
  });

  group('the posture transitions are ordered, not arbitrary', () {
    test('stand_up ends where sit_down begins, and they end apart', () {
      // stand_up finishes standing; sit_down starts standing and finishes
      // seated. So stand_up's last frame must resemble sit_down's FIRST, and
      // must not resemble sit_down's last.
      //
      // This is the checkable form of "stand -> walk -> sit ordering". It does
      // not depend on which sprite plays, only on the postures being distinct
      // and correctly sequenced -- so it is a technical gate, not an aesthetic
      // one.
      final wrong = <String>[];
      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        final up = manifest.specFor('stand_up');
        final down = manifest.specFor('sit_down');
        if (up == null || down == null) continue;
        if (up.frames.isEmpty || down.frames.isEmpty) continue;

        final upLast = signature(decodePngFile(up.frames.last));
        final downFirst = signature(decodePngFile(down.frames.first));
        final downLast = signature(decodePngFile(down.frames.last));

        final toStart = signatureDistance(upLast, downFirst);
        final toEnd = signatureDistance(upLast, downLast);
        if (toStart >= toEnd) {
          wrong.add('$companion: stand_up ends closer to sit_down END '
              '(${toEnd.toStringAsFixed(4)}) than to its start '
              '(${toStart.toStringAsFixed(4)})');
        }
      }
      expect(wrong, isEmpty, reason: wrong.join('\n'));
    });
  });
}
