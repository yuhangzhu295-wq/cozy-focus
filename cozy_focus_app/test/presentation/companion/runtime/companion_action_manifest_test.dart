import 'dart:convert';
import 'dart:io';

import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest_data.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards for the sprite asset pack.
///
/// ## What these can and cannot prove
///
/// They can prove that the pack is *internally consistent*: that every declared
/// frame exists, that frames of one action share a canvas so the companion cannot
/// jump, that successive frames are not byte-identical, and that the Dart mirror
/// of the manifests still matches the JSON the pipeline writes.
///
/// They cannot judge whether a drawing is beautiful or on-model. That is the
/// visual acceptance gate, and the brief is explicit that it must not be faked by
/// a unit test.
void main() {
  /// The companion ids that ship an action pack.
  final shipped = CompanionActionManifestData.manifests.keys.toList();

  File manifestFile(String companion) =>
      File('assets/companions/$companion/manifest.json');

  group('manifest parity', () {
    test('every shipped manifest exists as JSON and as Dart data', () {
      expect(shipped, isNotEmpty);
      for (final companion in shipped) {
        expect(manifestFile(companion).existsSync(), isTrue,
            reason: '$companion has Dart data but no manifest.json');
      }
    });

    test('the Dart mirror matches the shipped JSON field for field', () {
      for (final companion in shipped) {
        final json = jsonDecode(manifestFile(companion).readAsStringSync())
            as Map<String, dynamic>;
        final parsed = CompanionActionManifest.fromJson(json);
        final mirrored = CompanionActionManifestData.forCompanion(companion)!;

        expect(mirrored.companionId, parsed.companionId);
        expect(mirrored.posePack, parsed.posePack);
        expect(mirrored.canvasWidth, parsed.canvasWidth);
        expect(mirrored.canvasHeight, parsed.canvasHeight);
        expect(mirrored.groundBaseline, parsed.groundBaseline);
        expect(mirrored.centerAnchor, parsed.centerAnchor);
        expect(mirrored.actionIds, parsed.actionIds);
        expect(mirrored.semanticFallback, parsed.semanticFallback);

        for (final actionId in parsed.actionIds) {
          final a = mirrored.specFor(actionId)!;
          final b = parsed.specFor(actionId)!;
          // The JSON stores bare filenames (it is the pipeline's authoring form);
          // the Dart mirror stores resolvable asset paths. The parity that
          // matters is that they name the same frames, in the same order.
          expect(
            a.frames.map((f) => f.split('/').last).toList(),
            b.frames,
            reason: '$companion/$actionId frames',
          );
          expect(a.fps, b.fps, reason: '$companion/$actionId fps');
          expect(a.loopMode, b.loopMode, reason: '$companion/$actionId loop');
          expect(a.interruptible, b.interruptible,
              reason: '$companion/$actionId interruptible');
          expect(a.targetFrameCount, b.targetFrameCount,
              reason: '$companion/$actionId targetFrameCount');
        }
      }
    });
  });

  group('files and dimensions', () {
    test('every declared frame exists on disk', () {
      final missing = <String>[];
      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        for (final path in manifest.allFrames) {
          if (!File(path).existsSync()) missing.add(path);
        }
      }
      expect(missing, isEmpty,
          reason: 'missing frames:\n${missing.join('\n')}');
    });

    test('the manifest names only its own companion directory', () {
      // A companion must never reference another companion's frames — that is
      // the silent cross-species substitution the brief forbids.
      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        for (final path in manifest.allFrames) {
          expect(path, startsWith('assets/companions/$companion/'),
              reason: '$companion references a foreign frame: $path');
        }
      }
    });

    test('every action declares a non-empty frame list and sane fps', () {
      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        for (final entry in manifest.actions.entries) {
          expect(entry.value.frames, isNotEmpty,
              reason: '$companion/${entry.key} has no frames');
          expect(entry.value.fps, inInclusiveRange(1, 30),
              reason: '$companion/${entry.key} fps');
          expect(entry.value.frameDuration.inMilliseconds, greaterThan(0));
        }
      }
    });
  });

  group('the canvas contract', () {
    test('all frames of one companion share a canvas and an anchor', () {
      // This is what stops a pose change from making the companion jump. The
      // canvas is baked into the PNGs by the production pipeline, so it is read
      // back from the files rather than trusted from the manifest.
      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        final sizes = <String>{};
        for (final path in manifest.allFrames) {
          final bytes = File(path).readAsBytesSync();
          sizes.add(_pngSize(bytes));
        }
        expect(sizes.length, 1,
            reason: '$companion frames disagree on canvas: $sizes');
        final only = sizes.single;
        expect(only, '${manifest.canvasWidth}x${manifest.canvasHeight}',
            reason: '$companion manifest canvas does not match its files');
      }
    });

    test('every frame is a PNG with an alpha channel', () {
      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        for (final path in manifest.allFrames) {
          final bytes = File(path).readAsBytesSync();
          // PNG colour type 6 is truecolour with alpha; 4 is grey+alpha.
          final colorType = bytes[25];
          expect(colorType, anyOf(4, 6),
              reason: '$path is not an alpha PNG (colour type $colorType)');
        }
      }
    });
  });

  group('motion is real', () {
    test('successive frames of an action are not identical', () {
      // The brief's image-diff rule: an action whose frames are byte-identical is
      // not an animation. This is a *threshold*, not an artistic judgement.
      final frozen = <String>[];
      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        for (final entry in manifest.actions.entries) {
          final frames = entry.value.frames;
          if (frames.length < 2) continue;
          for (var i = 1; i < frames.length; i++) {
            final a = File(frames[i - 1]).readAsBytesSync();
            final b = File(frames[i]).readAsBytesSync();
            if (_sameBytes(a, b)) {
              frozen.add('$companion/${entry.key} frame $i is a duplicate');
            }
          }
        }
      }
      expect(frozen, isEmpty, reason: frozen.join('\n'));
    });
  });

  group('fallback stays inside the species', () {
    test('a missing action degrades to a sibling, never to another companion',
        () {
      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        for (final pose in CompanionPose.values) {
          final spec = manifest.resolve(pose);
          if (spec == null) continue;
          for (final frame in spec.frames) {
            expect(frame, startsWith('assets/companions/$companion/'),
                reason: '$companion/${pose.id} fell back outside its own pack');
          }
        }
      }
    });

    test('an action with no sequence and no sibling resolves to idle', () {
      const manifest = CompanionActionManifest(
        companionId: 'test',
        posePack: 'test',
        canvasWidth: 8,
        canvasHeight: 8,
        groundBaseline: 8,
        centerAnchor: 4,
        actions: {
          'idle': CompanionActionSpec(
            actionId: 'idle',
            frames: ['assets/companions/test/idle_000.png'],
          ),
        },
      );

      // An action the pack has never heard of must not invent frames.
      expect(manifest.resolve(CompanionPose.celebrate)?.actionId, 'idle');
      expect(manifest.hasExactAction(CompanionPose.celebrate), isFalse);
    });

    test('a pack with no idle at all reports nothing rather than guessing', () {
      const manifest = CompanionActionManifest(
        companionId: 'test',
        posePack: 'test',
        canvasWidth: 8,
        canvasHeight: 8,
        groundBaseline: 8,
        centerAnchor: 4,
        actions: {
          'focus_read': CompanionActionSpec(
            actionId: 'focus_read',
            frames: ['assets/companions/test/focus_read_000.png'],
          ),
        },
      );
      expect(manifest.resolve(CompanionPose.sleep), isNull);
    });

    test('a declared semantic fallback is honoured when it exists', () {
      const manifest = CompanionActionManifest(
        companionId: 'test',
        posePack: 'test',
        canvasWidth: 8,
        canvasHeight: 8,
        groundBaseline: 8,
        centerAnchor: 4,
        actions: {
          'idle': CompanionActionSpec(
            actionId: 'idle',
            frames: ['assets/companions/test/idle_000.png'],
          ),
          'room_read': CompanionActionSpec(
            actionId: 'room_read',
            frames: ['assets/companions/test/room_read_000.png'],
          ),
        },
        semanticFallback: {'focus_read': 'room_read'},
      );
      expect(manifest.resolve(CompanionPose.focusRead)?.actionId, 'room_read');
    });

    test('a behaviour-only chain never becomes a drawing', () {
      // `celebrate -> idle` is a legitimate behaviour fallback and an
      // illegitimate drawing one. Substituting the idle sequence would replace a
      // pose that carries a confetti accent with a placid drawing.
      final dog = CompanionActionManifestData.forCompanion('dog')!;
      expect(dog.semanticFallback[CompanionPose.celebrate.id], 'idle');
      // The behaviour chain still says "degrade to idle", but the drawing is the
      // celebration's own sequence — the chain was never consulted for it.
      expect(
          dog.specForRendering(CompanionPose.celebrate)?.actionId, 'celebrate');
      expect(dog.specForRendering(CompanionPose.tapReact), isNotNull,
          reason: 'tap_react has its own sequence');
      expect(dog.specForRendering(CompanionPose.petReact), isNotNull,
          reason: 'pet_react has its own sequence');
      expect(dog.specForRendering(CompanionPose.craftWork), isNotNull,
          reason: 'craft_work has its own sequence');
      expect(dog.specForRendering(CompanionPose.celebrate), isNotNull,
          reason: 'celebrate has its own sequence');
      expect(dog.specForRendering(CompanionPose.sleep), isNotNull,
          reason: 'sleep has its own sequence');
      // A pose the pack genuinely does not cover still falls through to the rig.
      expect(dog.specForRendering(CompanionPose.greeting), isNull);
    });
  });

  group('reduced motion', () {
    test('room anchors reuse a semantic action instead of duplicating art', () {
      // The brief forbids generating room-only variants unless visual evidence
      // proves they are needed. A bookshelf reads and a desk writes, so those
      // anchors resolve to the focus sequences that already exist.
      final dog = CompanionActionManifestData.forCompanion('dog')!;

      expect(dog.hasExactAction(CompanionPose.roomRead), isFalse,
          reason: 'a room-only duplicate must not exist without evidence');
      expect(
          dog.specForRendering(CompanionPose.roomRead)?.actionId, 'focus_read',
          reason: 'bookshelf must reuse the reading sequence');
      expect(
          dog.specForRendering(CompanionPose.roomWork)?.actionId, 'focus_write',
          reason: 'desk must reuse the writing sequence');

      // The dog pack has no `sleep` sequence yet. Behaviour selection may still
      // degrade to idle, but rendering must not: substituting the idle drawing
      // for the bed pose would be worse than the rig's own fallback. It becomes
      // `sleep` the moment that sequence lands, with no code change.
      // With the sleep sequence now shipped, the bed reuses it directly.
      expect(dog.resolve(CompanionPose.roomSleep)?.actionId, 'sleep');
      expect(dog.specForRendering(CompanionPose.roomSleep)?.actionId, 'sleep');
      // A pose with no sequence and no alias must not borrow a drawing at all.
      expect(dog.specForRendering(CompanionPose.greeting), isNull,
          reason: 'a missing drawing must not be substituted from idle');

      // Whatever it resolves to, it is always the same companion's frames.
      for (final pose in const [
        CompanionPose.roomRead,
        CompanionPose.roomWork,
        CompanionPose.roomSleep,
        CompanionPose.roomSit,
        CompanionPose.roomRelax,
      ]) {
        final spec = dog.specForRendering(pose);
        if (spec == null) continue;
        for (final frame in spec.frames) {
          expect(frame, startsWith('assets/companions/dog/'));
        }
      }
    });

    test('holds a frame from the same action', () {
      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        for (final entry in manifest.actions.entries) {
          final spec = entry.value;
          final held = spec.reducedMotionFrame;
          expect(held, isNotNull);
          expect(spec.frames, contains(held),
              reason:
                  '$companion/${entry.key} reduced motion must stay in-action');
        }
      }
    });

    test('an out-of-range index clamps rather than throwing', () {
      const spec = CompanionActionSpec(
        actionId: 'idle',
        frames: ['a.png', 'b.png'],
        reducedMotionFrames: [99],
      );
      expect(spec.reducedMotionFrame, 'b.png');
    });
  });
}

/// Reads the IHDR width/height of a PNG without decoding it.
String _pngSize(List<int> bytes) {
  int be32(int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
  return '${be32(16)}x${be32(20)}';
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
