import 'package:cozy_focus_app/presentation/companion/mochi_pose_spec.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:flutter_test/flutter_test.dart';

/// The three focus poses must be *visibly* distinct.
///
/// `docs/02_Pose_Asset_First_制作方案.md` requires Read / Write / Think to be
/// different silhouettes, and the reconstruction brief explicitly forbids passing
/// a 1px / 0.5° parameter tweak off as a new macro action. These tests pin the
/// distinction so a future retune cannot quietly collapse the three poses back
/// into one shape with different numbers.
void main() {
  const focusPoses = [
    CompanionPose.focusRead,
    CompanionPose.focusWrite,
    CompanionPose.focusThink,
  ];

  /// A head/ear swing smaller than this reads as noise, not as a different pose.
  const visibleAngle = 0.15; // radians ≈ 8.6°

  /// An eye-squash difference smaller than this is not perceivable at avatar size.
  const visibleEyeDelta = 0.15;

  double angleDelta(MochiPoseSpec a, MochiPoseSpec b) {
    final head = (a.headRotation - b.headRotation).abs();
    final ear = (a.earRotation - b.earRotation).abs();
    return head > ear ? head : ear;
  }

  group('the pose table is total', () {
    test('every CompanionPose has a row', () {
      for (final pose in CompanionPose.values) {
        expect(
          MochiPoseSpecs.table.containsKey(pose),
          isTrue,
          reason: 'no MochiPoseSpec for ${pose.id}',
        );
      }
    });

    test('the table declares no pose that is not a CompanionPose', () {
      for (final key in MochiPoseSpecs.table.keys) {
        expect(CompanionPose.values, contains(key));
      }
    });
  });

  group('focusRead / focusWrite / focusThink are visibly distinct', () {
    test('each carries a different prop, so the silhouettes differ', () {
      final props = focusPoses.map((p) => MochiPoseSpecs.of(p).prop).toList();
      expect(props.toSet().length, 3, reason: 'props were $props');
      expect(props, isNot(contains(MochiPosePropKind.none)));
    });

    test('no two focus poses differ only by parameters', () {
      for (var i = 0; i < focusPoses.length; i++) {
        for (var j = i + 1; j < focusPoses.length; j++) {
          final a = MochiPoseSpecs.of(focusPoses[i]);
          final b = MochiPoseSpecs.of(focusPoses[j]);

          final silhouetteDiffers = a.prop != b.prop;
          final postureDiffers = angleDelta(a, b) >= visibleAngle ||
              (a.eyeScaleY - b.eyeScaleY).abs() >= visibleEyeDelta;

          expect(
            silhouetteDiffers || postureDiffers,
            isTrue,
            reason:
                '${focusPoses[i].id} and ${focusPoses[j].id} are too similar',
          );
        }
      }
    });

    test('read and think look in opposite directions', () {
      final read = MochiPoseSpecs.of(CompanionPose.focusRead);
      final think = MochiPoseSpecs.of(CompanionPose.focusThink);
      // Reading looks down, thinking looks up — a sign change, not a magnitude
      // tweak, which is what makes the pair unmistakable.
      expect(read.headRotation, lessThan(0));
      expect(think.headRotation, greaterThan(0));
    });

    test('writing is the deepest head-down pose of the three', () {
      final write = MochiPoseSpecs.of(CompanionPose.focusWrite);
      for (final other in [CompanionPose.focusRead, CompanionPose.focusThink]) {
        expect(
          write.headRotation,
          lessThan(MochiPoseSpecs.of(other).headRotation),
          reason: 'writing should bow further than ${other.id}',
        );
      }
    });

    test('the props themselves are three different kinds', () {
      expect(MochiPoseSpecs.of(CompanionPose.focusRead).prop,
          MochiPosePropKind.openBook);
      expect(MochiPoseSpecs.of(CompanionPose.focusWrite).prop,
          MochiPosePropKind.notebook);
      expect(MochiPoseSpecs.of(CompanionPose.focusThink).prop,
          MochiPosePropKind.thoughtBubbles);
    });
  });

  group('pause and completion are visibly what they claim', () {
    test('pause rests: eyes mostly closed and a resting marker', () {
      final rest = MochiPoseSpecs.of(CompanionPose.rest);
      final idle = MochiPoseSpecs.of(CompanionPose.idle);

      expect(rest.eyeScaleY, lessThan(0.35));
      expect(rest.prop, MochiPosePropKind.restZ);
      expect(idle.eyeScaleY - rest.eyeScaleY, greaterThan(visibleEyeDelta));
    });

    test('completion celebrates: an upward pose with confetti', () {
      final celebrate = MochiPoseSpecs.of(CompanionPose.celebrate);
      final idle = MochiPoseSpecs.of(CompanionPose.idle);

      expect(celebrate.prop, MochiPosePropKind.confetti);
      expect(celebrate.headRotation, greaterThan(idle.headRotation));
      expect(celebrate.earRotation, greaterThan(idle.earRotation));
    });

    test('pause and sleep both rest but are not the same pose', () {
      final rest = MochiPoseSpecs.of(CompanionPose.rest);
      final sleep = MochiPoseSpecs.of(CompanionPose.sleep);

      expect(rest.eyeScaleY, isNot(sleep.eyeScaleY));
      expect(angleDelta(rest, sleep), greaterThan(0.0));
    });
  });

  group('overlay poses are distinct from the work poses', () {
    test('tap and long press carry different props', () {
      final tap = MochiPoseSpecs.of(CompanionPose.tapReact);
      final pet = MochiPoseSpecs.of(CompanionPose.petReact);
      expect(tap.prop, MochiPosePropKind.tapSpark);
      expect(pet.prop, MochiPosePropKind.heart);
    });

    test('no overlay pose is identical to a focus pose', () {
      for (final overlay in [
        CompanionPose.tapReact,
        CompanionPose.petReact,
        CompanionPose.greeting,
        CompanionPose.unlockReact,
      ]) {
        final o = MochiPoseSpecs.of(overlay);
        for (final focus in focusPoses) {
          final f = MochiPoseSpecs.of(focus);
          expect(o.prop == f.prop && angleDelta(o, f) == 0.0, isFalse);
        }
      }
    });
  });

  group('reduced motion', () {
    test('preserves the semantic pose — prop and eye squash survive', () {
      for (final pose in CompanionPose.values) {
        final full = MochiPoseSpecs.of(pose);
        final damped = MochiPoseSpecs.damped(full);

        expect(damped.prop, full.prop, reason: '${pose.id} prop');
        expect(damped.eyeScaleY, full.eyeScaleY, reason: '${pose.id} eyes');
      }
    });

    test('reduces the movement channels', () {
      for (final pose in CompanionPose.values) {
        final full = MochiPoseSpecs.of(pose);
        final damped = MochiPoseSpecs.damped(full);

        expect(damped.headRotation.abs(),
            lessThanOrEqualTo(full.headRotation.abs()),
            reason: '${pose.id} head');
        expect(
            damped.earRotation.abs(), lessThanOrEqualTo(full.earRotation.abs()),
            reason: '${pose.id} ear');
        expect(damped.sproutRotation.abs(),
            lessThanOrEqualTo(full.sproutRotation.abs()),
            reason: '${pose.id} sprout');
        expect(damped.bodyDy.abs(), lessThanOrEqualTo(full.bodyDy.abs()),
            reason: '${pose.id} body');
        expect(damped.headDy.abs(), lessThanOrEqualTo(full.headDy.abs()),
            reason: '${pose.id} headDy');
      }
    });

    test('a pose with real movement is actually damped', () {
      final full = MochiPoseSpecs.of(CompanionPose.sleep);
      final damped = MochiPoseSpecs.damped(full);

      expect(damped.headRotation.abs(), lessThan(full.headRotation.abs()));
      expect(damped.earRotation.abs(), lessThan(full.earRotation.abs()));
      expect(damped.bodyDy.abs(), lessThan(full.bodyDy.abs()));
    });

    test('a damped focus pose is still recognisably that pose', () {
      final read = MochiPoseSpecs.of(CompanionPose.focusRead);
      final damped = MochiPoseSpecs.damped(read);
      expect(damped.prop, MochiPosePropKind.openBook);
      // Still looking down, just less far.
      expect(damped.headRotation, lessThan(0));
    });
  });

  group('scaling', () {
    test('pixel offsets scale with the avatar size, angles do not', () {
      final spec = MochiPoseSpecs.of(CompanionPose.focusWrite);
      final doubled = spec.scaledTo(MochiPoseSpec.referenceSize * 2);

      expect(doubled.headDy, closeTo(spec.headDy * 2, 0.001));
      expect(doubled.bodyDy, closeTo(spec.bodyDy * 2, 0.001));
      expect(doubled.headRotation, spec.headRotation);
      expect(doubled.eyeScaleY, spec.eyeScaleY);
    });

    test('the reference size is a no-op', () {
      final spec = MochiPoseSpecs.of(CompanionPose.focusRead);
      expect(spec.scaledTo(MochiPoseSpec.referenceSize), same(spec));
    });
  });
}
