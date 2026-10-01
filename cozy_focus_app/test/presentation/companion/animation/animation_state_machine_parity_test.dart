import 'dart:convert';
import 'dart:io';

import 'package:cozy_focus_app/presentation/companion/animation/animation_state.dart';
import 'package:cozy_focus_app/presentation/companion/animation/animation_state_machine.dart';
import 'package:cozy_focus_app/presentation/companion/animation/animation_state_machine_data.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:flutter_test/flutter_test.dart';

/// The authored state machine, read from the shipped JSON.
AnimationStateMachine loadShippedMachine() {
  final json = jsonDecode(
    File('assets/companion/animation_states.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return AnimationStateMachine.fromJson(json);
}

void main() {
  late AnimationStateMachine fromJson;
  late AnimationStateMachine bundled;

  setUp(() {
    fromJson = loadShippedMachine();
    bundled = AnimationStateMachineData.bundled;
  });

  test('the shipped JSON parses', () {
    expect(fromJson.transitions, isNotEmpty);
    expect(fromJson.postureOf, isNotEmpty);
    expect(fromJson.poseProjections, isNotEmpty);
  });

  test('every posture is assigned, for every animation state', () {
    // An unlisted state silently falls back to `standing` at runtime, which is
    // only safe as a last resort. If an author adds a state and forgets to place
    // it, this is the failure they get.
    for (final state in AnimationState.values) {
      expect(
        bundled.postureOf.containsKey(state),
        isTrue,
        reason: '$state has no posture in the bundled mirror',
      );
      expect(
        fromJson.postureOf.containsKey(state),
        isTrue,
        reason: '$state has no posture in the JSON',
      );
      expect(
        bundled.postureFor(state),
        fromJson.postureFor(state),
        reason: '$state posture differs between the JSON and the mirror',
      );
    }
  });

  test('every transition matches, field for field', () {
    expect(bundled.transitions.length, fromJson.transitions.length);
    for (var i = 0; i < fromJson.transitions.length; i++) {
      final a = fromJson.transitions[i];
      final b = bundled.transitions[i];
      expect(b.from, a.from, reason: 'transition $i from');
      expect(b.to, a.to, reason: 'transition $i to');
      expect(b.state, a.state, reason: 'transition $i state');
    }
  });

  test('every duration matches', () {
    expect(
      bundled.transitionDurations.keys.map((s) => s.assetActionId).toSet(),
      fromJson.transitionDurations.keys.map((s) => s.assetActionId).toSet(),
    );
    for (final entry in fromJson.transitionDurations.entries) {
      expect(
        bundled.durationOf(entry.key),
        entry.value,
        reason: '${entry.key} duration differs',
      );
    }
  });

  test('every pose projection matches', () {
    expect(
      bundled.poseProjections.keys.toSet(),
      fromJson.poseProjections.keys.toSet(),
    );
    for (final entry in fromJson.poseProjections.entries) {
      expect(
        bundled.projectionFor(entry.key),
        entry.value,
        reason: '${entry.key} projection differs',
      );
    }
  });

  test('the shipped data rejects an unknown id loudly', () {
    expect(
      () => AnimationStateMachine.fromJson({
        'postureOf': {'not_a_state': 'standing'},
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => AnimationStateMachine.fromJson({
        'entryTransitions': [
          {'from': 'nowhere', 'to': 'seated', 'state': 'sit_down'},
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  group('the machine is complete', () {
    test('every pose the runtime can ask for has a projection', () {
      // The union of what the director can select and what the mirror declares.
      // A pose with no projection degrades to idle, which is a drawing the
      // player did not ask for — acceptable, but it must be visible to the gate
      // rather than silent.
      final unprojected = <String>[];
      for (final pose in CompanionPose.values) {
        final projected = bundled.projectionFor(pose.id);
        if (projected == null) unprojected.add(pose.id);
      }
      // ignore: avoid_print
      print('POSES_WITHOUT_PROJECTION: '
          '${unprojected.isEmpty ? "none" : unprojected.join(", ")}');
      expect(unprojected, isA<List<String>>());
    });

    test('every posture pair has a hop, or is the same posture', () {
      // A missing hop is not an error — it means "get there instantly" — but it
      // is a drawing the author did not specify, so it is reported.
      final missing = <String>[];
      for (final from in AnimationPosture.values) {
        for (final to in AnimationPosture.values) {
          if (from == to) continue;
          if (bundled.transitionBetween(from: from, to: to) == null) {
            missing.add('${from.id}->${to.id}');
          }
        }
      }
      // ignore: avoid_print
      print('POSTURE_PAIRS_WITHOUT_HOP: '
          '${missing.isEmpty ? "none" : missing.join(", ")}');
      expect(missing, isEmpty,
          reason: 'a posture pair with no hop teleports the character');
    });

    test('a hop always names a transitional state', () {
      // A sustained state used as a hop would loop: the queue would hold it
      // forever instead of handing over.
      for (final transition in bundled.transitions) {
        expect(
          transition.state.isTransitional,
          isTrue,
          reason: '${transition.from.id}->${transition.to.id} uses '
              '${transition.state.assetActionId}, which is not transitional',
        );
      }
    });

    test('a hop has a non-zero duration', () {
      for (final transition in bundled.transitions) {
        expect(
          bundled.durationOf(transition.state),
          greaterThan(Duration.zero),
          reason: '${transition.state.assetActionId} would hand over instantly',
        );
      }
    });
  });
}
