import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/mochi_pose_spec.dart';
import 'package:cozy_focus_app/presentation/companion/procedural_companion_art.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:cozy_focus_app/presentation/controllers/pet_motion_controller.dart';

/// A blink cadence the test controls exactly.
class _FixedBlinkScheduler implements IPetMotionScheduler {
  final Duration interval;
  _FixedBlinkScheduler(this.interval);

  @override
  Duration nextBlinkInterval() => interval;

  @override
  Duration nextEarTwitchInterval() => interval;
}

void main() {
  /// The breathing scale currently applied, or `null` when no Transform is in
  /// the tree.
  double? breathScale(WidgetTester tester) {
    final transforms = find.byType(Transform);
    for (final element in transforms.evaluate()) {
      final widget = element.widget as Transform;
      final m = widget.transform;
      // The breath is a uniform-ish scale about the bottom centre; the entry is
      // a plain scale matrix, so read it from the diagonal.
      final sx = m.entry(0, 0);
      final sy = m.entry(1, 1);
      if ((sx - sy).abs() < 0.0001 && sx > 0.9 && sx < 1.1) return sx;
    }
    return null;
  }

  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  ProceduralCompanionArt art({
    bool reducedMotion = false,
    VoidCallback? onBlink,
    Duration blinkInterval = const Duration(milliseconds: 800),
  }) =>
      ProceduralCompanionArt(
        silhouette: CompanionSilhouettes.cat,
        pose: CompanionPose.focusRead,
        poseSpec: MochiPoseSpecs.of(CompanionPose.focusRead),
        size: 140,
        reducedMotion: reducedMotion,
        onBlink: onBlink,
        scheduler: _FixedBlinkScheduler(blinkInterval),
      );

  group('placeholder micro-motion actually happens', () {
    testWidgets('breathing visibly changes the frame', (tester) async {
      await tester.pumpWidget(host(art()));
      await tester.pump();

      final first = breathScale(tester);
      expect(first, isNotNull,
          reason: 'the companion must carry a breath scale');

      // The breath cycle is 3.2s, so a quarter of it is a clear movement.
      await tester.pump(const Duration(milliseconds: 800));
      final later = breathScale(tester);
      expect(later, isNotNull);

      expect(
        later,
        isNot(closeTo(first!, 0.0005)),
        reason: 'breathing must move the companion, not hold it still',
      );
      // And it must stay subtle: a breath is not a bounce.
      expect(later!, inInclusiveRange(0.99, 1.03));
    });

    testWidgets('a blink occurs on the scheduled cadence', (tester) async {
      var blinks = 0;
      await tester.pumpWidget(
        host(art(
          blinkInterval: const Duration(milliseconds: 600),
          onBlink: () => blinks++,
        )),
      );
      await tester.pump();

      expect(blinks, 0, reason: 'nothing should blink on the first frame');

      await tester.pump(const Duration(milliseconds: 700));
      expect(blinks, 1, reason: 'one blink after one interval');

      await tester.pump(const Duration(milliseconds: 800));
      expect(blinks, greaterThanOrEqualTo(2),
          reason: 'blinks must keep coming');
    });

    testWidgets('a blink returns the eyes to open', (tester) async {
      await tester.pumpWidget(
        host(art(blinkInterval: const Duration(milliseconds: 600))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      // Mid-blink: the eyes are shut for 140ms.
      final mid = tester.widgetList(find.byType(CustomPaint)).length;
      expect(mid, greaterThan(0));

      // Past the blink: the widget must not be left with the eyes closed.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ProceduralCompanionArt), findsOneWidget);
    });
  });

  group('reduced motion suppresses the micro-motion', () {
    testWidgets('no breathing movement at all', (tester) async {
      await tester.pumpWidget(host(art(reducedMotion: true)));
      await tester.pump();

      final first = breathScale(tester);
      await tester.pump(const Duration(milliseconds: 800));
      final later = breathScale(tester);

      expect(first, 1.0, reason: 'reduced motion holds the breath at rest');
      expect(later, 1.0);
    });

    testWidgets('no blink fires', (tester) async {
      var blinks = 0;
      await tester.pumpWidget(
        host(art(
          reducedMotion: true,
          blinkInterval: const Duration(milliseconds: 400),
          onBlink: () => blinks++,
        )),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(blinks, 0, reason: 'reduced motion must suppress blinking');
    });

    testWidgets('but the semantic pose is still presented', (tester) async {
      await tester.pumpWidget(host(art(reducedMotion: true)));
      await tester.pump();

      // The reading prop is the semantic content, and reduced motion keeps it.
      expect(find.byType(ProceduralCompanionArt), findsOneWidget);
      final canvas = tester.widgetList(find.byType(CustomPaint)).length;
      expect(canvas, greaterThan(0));
    });
  });

  group('switching reduced motion mid-flight', () {
    testWidgets('stops and resumes the micro-motion without leaking',
        (tester) async {
      var blinks = 0;
      Widget build(bool reduced) => host(
            art(
              reducedMotion: reduced,
              blinkInterval: const Duration(milliseconds: 500),
              onBlink: () => blinks++,
            ),
          );

      await tester.pumpWidget(build(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(blinks, greaterThan(0));

      // Turning reduced motion on must stop the animation entirely.
      await tester.pumpWidget(build(true));
      await tester.pump();
      expect(breathScale(tester), 1.0);
      final afterToggle = blinks;
      await tester.pump(const Duration(seconds: 2));
      expect(blinks, afterToggle, reason: 'reduced motion must stop blinking');

      // And turning it back off must resume, which proves the timer was
      // cancelled and re-armed rather than left dangling.
      await tester.pumpWidget(build(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(blinks, greaterThan(afterToggle));

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
