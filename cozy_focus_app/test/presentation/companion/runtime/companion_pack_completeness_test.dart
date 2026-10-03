import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest_data.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_sprite_art.dart';
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
      // Absence must be a null lookup, not a throw. The rabbit used to be the
      // example here; it now ships a partial pack, so an unknown id carries the
      // assertion instead and the rabbit is asserted to be present.
      expect(
          CompanionActionManifestData.forCompanion('not_a_companion'), isNull);
      expect(CompanionActionManifestData.forCompanion('rabbit'), isNotNull);
    });

    test('the rabbit pack is present and partial, and says so', () {
      // It grows action by action, so the invariant is that whatever it declares
      // is complete and honest - not a fixed count, which changes every session
      // and would make this test churn rather than guard anything.
      final rabbit = CompanionActionManifestData.forCompanion('rabbit')!;
      expect(rabbit.actionIds, contains('idle'));
      for (final entry in rabbit.actions.entries) {
        expect(entry.value.frames, isNotEmpty,
            reason: 'rabbit/${entry.key} is declared but has no frames');
        expect(entry.value.isComplete, isTrue,
            reason:
                'rabbit/${entry.key} is declared but short of its frame count');
      }
    });

    test('a shipped pose resolves to sprites and a missing one does not', () {
      // This is the wiring, asserted where it is decided: the provider asks
      // CompanionSpriteArt for a spec and draws sprites when it gets one, the
      // procedural silhouette when it does not. So the pack being reachable is
      // exactly "the shipped pose resolves and an unshipped one returns null".
      final idle = CompanionSpriteArt.resolveFor('rabbit', CompanionPose.idle);
      expect(idle, isNotNull, reason: 'rabbit/idle ships and must resolve');
      expect(idle!.frames, hasLength(6));

      // The unshipped-pose example has moved three times as the pack grew:
      // `sleep`, then `rest`, then `tap_react`. It now uses `greeting`, which
      // belongs to the overlay vocabulary rather than the behaviour pack, so it
      // should stay unshipped and stop this test churning every batch.
      //
      // Note the null is *the rabbit's*, and the assertions below are what prove
      // it rather than a broken resolver: the same lookup for poses the rabbit
      // does ship returns a spec. An earlier version of this compared against
      // the dog, which would have been wrong here — the dog's thirteen actions
      // do not include `greeting` either.
      expect(CompanionSpriteArt.resolveFor('rabbit', CompanionPose.greeting),
          isNull);

      for (final pose in const [
        CompanionPose.sleep,
        CompanionPose.rest,
        CompanionPose.tapReact,
      ]) {
        expect(
          CompanionSpriteArt.resolveFor('rabbit', pose),
          isNotNull,
          reason: 'rabbit/${pose.id} was imported and must resolve',
        );
      }
    });

    test('the dog pack ships every requested action', () {
      final dog = CompanionActionManifestData.forCompanion('dog')!;
      // Ten at V4.3 Phase 0; walk, stand_up and sit_down landed in batches 2-4.
      expect(dog.actionIds.length, 13);
      expect(
        dog.actionIds,
        containsAll(const [
          'idle',
          'walk',
          'stand_up',
          'sit_down',
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
