import 'package:cozy_focus_app/presentation/companion/animation/locomotion_controller.dart';
import 'package:cozy_focus_app/presentation/companion/room/anchor_point.dart';
import 'package:flutter_test/flutter_test.dart';

AnchorPoint anchor(String id, {double x = 0.3, double y = 0.6}) =>
    AnchorPoint(id: id, itemId: 'i-$id', roomItemId: 'r-$id', x: x, y: y);

void main() {
  group('a trip produces movement data, not just a position', () {
    test('travelling reports progress between the two anchors', () {
      final locomotion = LocomotionController();
      final from = anchor('a', x: 0.2, y: 0.6);
      final to = anchor('b', x: 0.8, y: 0.6);

      expect(locomotion.startTravel(from: from, to: to), isTrue);
      expect(locomotion.isTravelling, isTrue);
      expect(locomotion.progress, 0.0);

      // A quarter of the way in, the position is a quarter of the way there.
      locomotion.advanceTo(locomotion.duration ~/ 4);
      final mid = locomotion.position;
      expect(mid.x, greaterThan(from.x));
      expect(mid.x, lessThan(to.x));
    });

    test('the stride index changes during a trip', () {
      final locomotion = LocomotionController();
      locomotion.startTravel(
        from: anchor('a', x: 0.2, y: 0.6),
        to: anchor('b', x: 0.8, y: 0.6),
      );

      // The whole point of this class: a walk is not a slide. If the stride
      // never changes, there is nothing for the walk frames to select on and
      // the companion is still a still image being moved.
      final strides = <int>{};
      for (var ms = 0; ms <= 600; ms += 50) {
        locomotion.advanceTo(Duration(milliseconds: ms));
        strides.add(locomotion.strideFor(strideCount: 6));
      }
      expect(strides.length, greaterThan(1),
          reason: 'a trip must pass through more than one stride');
    });

    test('the gait phase stays inside one cycle', () {
      final locomotion = LocomotionController();
      locomotion.startTravel(
        from: anchor('a', x: 0.1, y: 0.6),
        to: anchor('b', x: 0.9, y: 0.6),
      );
      for (var ms = 0; ms <= 2000; ms += 40) {
        locomotion.advanceTo(Duration(milliseconds: ms));
        expect(
          locomotion.gaitPhase,
          inInclusiveRange(0.0, 1.0),
          reason: 'gait phase must stay in 0…1 at $ms ms',
        );
      }
    });

    test('facing is decided at departure and held', () {
      final rightward = LocomotionController();
      rightward.startTravel(
        from: anchor('a', x: 0.2, y: 0.6),
        to: anchor('b', x: 0.8, y: 0.6),
      );
      expect(rightward.facing, 1.0);

      final leftward = LocomotionController();
      leftward.startTravel(
        from: anchor('a', x: 0.8, y: 0.6),
        to: anchor('b', x: 0.2, y: 0.6),
      );
      expect(leftward.facing, -1.0);
      // Held for the trip: the companion does not change its mind mid-stride.
      leftward.advanceTo(const Duration(milliseconds: 100));
      expect(leftward.facing, -1.0);
    });
  });

  group('a trip ends', () {
    test('advance reports completion exactly once', () {
      final locomotion = LocomotionController();
      locomotion.startTravel(
        from: anchor('a', x: 0.2, y: 0.6),
        to: anchor('b', x: 0.9, y: 0.6),
      );

      const step = Duration(milliseconds: 100);
      var completions = 0;
      for (var i = 0; i < 60; i++) {
        if (locomotion.advance(step)) completions++;
      }
      expect(completions, 1);
      expect(locomotion.isTravelling, isFalse);
      expect(locomotion.progress, 1.0);
    });

    test('the settled position is the target, exactly', () {
      final locomotion = LocomotionController();
      final to = anchor('b', x: 0.8, y: 0.55);
      locomotion.startTravel(from: anchor('a', x: 0.2, y: 0.6), to: to);
      locomotion.advanceTo(LocomotionController.maxTravel);

      // Arrived, and still at the destination: a settled companion does not
      // snap back to where it set off from.
      expect(locomotion.hasArrived, isTrue);
      final settled = locomotion.position;
      expect(settled.x, to.x);
      expect(settled.y, to.y);
    });

    test('a trip to the same spot is not started', () {
      final locomotion = LocomotionController();
      final spot = anchor('a', x: 0.4, y: 0.5);
      expect(locomotion.startTravel(from: spot, to: spot), isFalse);
      expect(locomotion.isTravelling, isFalse);
    });

    test('cancelling leaves no trip', () {
      final locomotion = LocomotionController();
      locomotion.startTravel(
        from: anchor('a', x: 0.2, y: 0.6),
        to: anchor('b', x: 0.8, y: 0.6),
      );
      // What happens when the furniture being walked to is removed.
      locomotion.cancelTravel();
      expect(locomotion.isTravelling, isFalse);
      expect(locomotion.target, isNull);
      expect(locomotion.gaitPhase, 0.0);
    });
  });

  group('timing is bounded', () {
    test('a longer trip is not a slower gait', () {
      // Both trips run the same number of stride cycles, so a long walk takes
      // more strides rather than one slow-motion stride.
      final short = LocomotionController();
      short.startTravel(
        from: anchor('a', x: 0.4, y: 0.5),
        to: anchor('b', x: 0.9, y: 0.5),
      );
      final long = LocomotionController();
      long.startTravel(
        from: anchor('a', x: 0.1, y: 0.5),
        to: anchor('b', x: 0.9, y: 0.5),
      );

      // A quarter through each trip, both are mid-cycle rather than at a stride
      // boundary — the cadence is the same, the long walk just takes more
      // strides. (Exactly half way is a boundary and reads 0.0 by design.)
      short.advanceTo(short.duration ~/ 4);
      long.advanceTo(long.duration ~/ 4);
      expect(short.gaitPhase, greaterThan(0.0));
      expect(long.gaitPhase, greaterThan(0.0));
    });

    test('a stride index of zero is safe', () {
      final locomotion = LocomotionController();
      locomotion.startTravel(
        from: anchor('a', x: 0.2, y: 0.6),
        to: anchor('b', x: 0.8, y: 0.6),
      );
      expect(locomotion.strideFor(strideCount: 0), 0);
    });
  });
}
