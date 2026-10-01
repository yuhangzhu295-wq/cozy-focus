import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Honest reporting for a pack that is mid-production.
///
/// ## Why this is separate from the consistency suite
///
/// The other manifest tests check that a shipped pack is *internally sound*. This
/// one checks that a pack which is only partly produced says so out loud, so a
/// partial pack lands as a partial improvement rather than as a silent claim of
/// completion.
///
/// The brief is explicit that asset work must not be faked. A sequence that has
/// one of its three frames is real art and must still draw; it is not, however,
/// finished, and the gate has to be able to tell the difference.
void main() {
  final shipped = CompanionActionManifestData.manifests.keys.toList();

  group('incompleteness is reported, not hidden', () {
    test('an under-filled action resolves but reports itself incomplete', () {
      var foundPartial = false;

      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        for (final entry in manifest.actions.entries) {
          final spec = entry.value;
          // Asserted against the *effective* target, not the declared one.
          // The old form re-implemented `isComplete` in the test, so it passed
          // even when the declared target had been slaved to the frame count —
          // which is how a one-frame `idle` reported itself complete.
          expect(
            spec.isComplete,
            spec.frames.length >= spec.effectiveTargetFrameCount,
            reason: '$companion/${entry.key} completeness must be computed',
          );

          // The floor is the structural guard: no declaration may lower the bar
          // below a real animation. This is what stops the gate being silenced
          // again by writing `targetFrameCount: 1` beside a single frame.
          expect(
            spec.effectiveTargetFrameCount,
            greaterThanOrEqualTo(CompanionActionSpec.minimumViableFrames),
            reason: '$companion/${entry.key} target dropped below the floor',
          );

          if (!spec.isComplete) {
            foundPartial = true;
            expect(manifest.incompleteActions, contains(entry.key),
                reason: 'an under-filled action must be listed as incomplete');
            // It is still real art, so it must still resolve for drawing.
            expect(spec.frames, isNotEmpty,
                reason: '$companion/${entry.key} must still draw something');
          }
        }
      }

      // Not an assertion that a partial pack exists — that would fail the moment
      // the art is finished. It records which state the pack is in.
      if (foundPartial) {
        for (final companion in shipped) {
          final manifest = CompanionActionManifestData.forCompanion(companion)!;
          if (manifest.incompleteActions.isNotEmpty) {
            // ignore: avoid_print
            print('INCOMPLETE $companion: ${manifest.incompleteActions}');
          }
        }
      }
    });

    test('a target is production intent, not a transcription of the disk', () {
      // The failure this catches is silent and self-sealing: if every action
      // declares a target equal to its frame count, `isComplete` is true
      // everywhere and the gate prints `none` while the pack is unfinished.
      //
      // A short action is real art and is allowed to ship. What is not allowed
      // is *declaring* it finished, so the check is per-action rather than a
      // whole-pack count: it fails on the action that was transcribed, and
      // stays green on the ones the brief genuinely targets.
      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        for (final entry in manifest.actions.entries) {
          final spec = entry.value;
          expect(
            spec.targetFrameCount > 1 || spec.frames.length > 1,
            isTrue,
            reason:
                '$companion/${entry.key} declares a ${spec.targetFrameCount}'
                '-frame target beside ${spec.frames.length} frame(s): the target '
                'was transcribed from the disk instead of from the asset brief',
          );
        }
      }
    });

    test('a complete action is never listed as incomplete', () {
      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        for (final actionId in manifest.incompleteActions) {
          final spec = manifest.specFor(actionId)!;
          expect(spec.isComplete, isFalse,
              reason:
                  '$companion/$actionId is listed but is actually complete');
        }
      }
    });

    test('the gate can name every action that still needs frames', () {
      final pending = <String>[];
      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        for (final actionId in manifest.incompleteActions) {
          final spec = manifest.specFor(actionId)!;
          pending.add('$companion/$actionId '
              '${spec.frames.length}/${spec.targetFrameCount}');
        }
      }
      // The list is reported either way; it is the input to the asset gate.
      // ignore: avoid_print
      print(
          'ACTIONS_PENDING_FRAMES: ${pending.isEmpty ? "none" : pending.join(", ")}');
      expect(pending, isA<List<String>>());
    });
  });

  group('a partial pack still behaves like a pack', () {
    test('every action with frames can be drawn', () {
      for (final companion in shipped) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        for (final entry in manifest.actions.entries) {
          expect(entry.value.frames, isNotEmpty,
              reason: '$companion/${entry.key} has an empty frame list');
          expect(entry.value.reducedMotionFrame, isNotNull,
              reason:
                  '$companion/${entry.key} must have a reduced-motion frame');
        }
      }
    });

    test('a companion with no pack at all is simply absent, not broken', () {
      // The rabbit ships no art yet. Absence must be a null lookup, not a throw.
      expect(CompanionActionManifestData.forCompanion('rabbit'), isNull);
      expect(
          CompanionActionManifestData.forCompanion('not_a_companion'), isNull);
    });

    test('the dog pack ships all ten requested actions', () {
      final dog = CompanionActionManifestData.forCompanion('dog')!;
      expect(dog.actionIds.length, 10);
      expect(
        dog.actionIds,
        containsAll(const [
          'idle',
          'focus_read',
          'focus_write',
          'focus_think',
          'pause_rest',
          'tap_react',
          'pet_react',
          'craft_work',
          'celebrate',
          'sleep',
        ]),
      );
    });
  });
}
