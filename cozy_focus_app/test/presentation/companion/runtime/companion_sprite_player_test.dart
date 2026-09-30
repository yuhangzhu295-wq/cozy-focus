import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_sprite_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Behaviour of the one generic sprite player.
///
/// These are about the player's *contract* — loop modes, reduced motion,
/// visibility and disposal — not about any companion. The player must contain no
/// dog, cat, rabbit or Focus logic, so a synthetic spec is enough to pin all of
/// it down.
void main() {
  CompanionActionSpec spec({
    int count = 3,
    SpriteLoopMode loop = SpriteLoopMode.loop,
    int fps = 10,
    List<int> reduced = const [0],
  }) =>
      CompanionActionSpec(
        actionId: 'test_action',
        frames: [
          for (var i = 0; i < count; i++)
            'assets/x/f_${i.toString().padLeft(3, '0')}.png'
        ],
        fps: fps,
        loopMode: loop,
        reducedMotionFrames: reduced,
      );

  Widget host(Widget child, {bool enabled = true}) => MaterialApp(
        home: Scaffold(
          body: TickerMode(enabled: enabled, child: Center(child: child)),
        ),
      );

  /// The frame index the player is currently showing.
  int shownIndex(WidgetTester tester) {
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    final name = provider.assetName.split('/').last;
    return int.parse(name.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  group('frame rate', () {
    testWidgets('advances at the action\'s own rate, not per frame',
        (tester) async {
      await tester.pumpWidget(host(
        CompanionSpritePlayer(spec: spec(fps: 10), size: 100),
      ));
      await tester.pump();
      expect(shownIndex(tester), 0);

      // Half a frame interval: still the same frame.
      await tester.pump(const Duration(milliseconds: 50));
      expect(shownIndex(tester), 0);

      await tester.pump(const Duration(milliseconds: 50));
      expect(shownIndex(tester), 1);
    });

    test('the interval is clamped to a sane range', () {
      expect(
        const CompanionActionSpec(actionId: 'a', frames: ['f'], fps: 0)
            .frameDuration,
        const Duration(seconds: 1),
      );
      expect(
        const CompanionActionSpec(actionId: 'a', frames: ['f'], fps: 999)
            .frameDuration,
        const Duration(milliseconds: 33),
      );
    });
  });

  group('loop modes', () {
    testWidgets('loop wraps back to the first frame', (tester) async {
      await tester.pumpWidget(host(
        CompanionSpritePlayer(
          spec: spec(count: 3, loop: SpriteLoopMode.loop, fps: 10),
          size: 100,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(shownIndex(tester), 2);

      await tester.pump(const Duration(milliseconds: 100));
      expect(shownIndex(tester), 0, reason: 'loop must wrap');
    });

    testWidgets('pingPong reverses instead of wrapping', (tester) async {
      await tester.pumpWidget(host(
        CompanionSpritePlayer(
          spec: spec(count: 3, loop: SpriteLoopMode.pingPong, fps: 10),
          size: 100,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(shownIndex(tester), 2);

      // Forward again would be frame 0 in loop mode; ping-pong steps back to 1.
      await tester.pump(const Duration(milliseconds: 100));
      expect(shownIndex(tester), 1, reason: 'ping-pong must reverse');
    });

    testWidgets('once holds the final frame', (tester) async {
      await tester.pumpWidget(host(
        CompanionSpritePlayer(
          spec: spec(count: 3, loop: SpriteLoopMode.once, fps: 10),
          size: 100,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(shownIndex(tester), 2);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(shownIndex(tester), 2, reason: 'a one-shot must not restart');
    });
  });

  group('reduced motion', () {
    testWidgets('holds the declared frame and never advances', (tester) async {
      await tester.pumpWidget(host(
        CompanionSpritePlayer(
          spec: spec(count: 3, fps: 10, reduced: const [1]),
          size: 100,
          reducedMotion: true,
        ),
      ));
      await tester.pump();
      expect(shownIndex(tester), 1);

      await tester.pump(const Duration(seconds: 2));
      expect(shownIndex(tester), 1, reason: 'reduced motion must not animate');
    });

    testWidgets('keeps the same semantic action, not a different one',
        (tester) async {
      await tester.pumpWidget(host(
        CompanionSpritePlayer(
          spec: spec(count: 3),
          size: 100,
          reducedMotion: true,
        ),
      ));
      await tester.pump();

      // The player still reports the action it was given; reduced motion changes
      // how much moves, never which action is presented.
      final rendered = tester.widget<CompanionSpritePlayer>(
        find.byType(CompanionSpritePlayer),
      );
      expect(rendered.spec.actionId, 'test_action');
    });
  });

  group('visibility', () {
    testWidgets('does not animate while its subtree is disabled',
        (tester) async {
      await tester.pumpWidget(host(
        CompanionSpritePlayer(spec: spec(fps: 10), size: 100),
        enabled: false,
      ));
      await tester.pump();
      expect(shownIndex(tester), 0);

      await tester.pump(const Duration(seconds: 1));
      expect(shownIndex(tester), 0,
          reason: 'a hidden companion must not animate');
    });

    testWidgets('animates once the subtree is enabled again', (tester) async {
      await tester.pumpWidget(host(
        CompanionSpritePlayer(spec: spec(fps: 10), size: 100),
        enabled: false,
      ));
      await tester.pump();
      await tester.pumpWidget(host(
        CompanionSpritePlayer(spec: spec(fps: 10), size: 100),
        enabled: true,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(shownIndex(tester), 1);
    });
  });

  group('lifecycle', () {
    testWidgets('disposing the player leaves no pending timer', (tester) async {
      await tester.pumpWidget(host(
        CompanionSpritePlayer(spec: spec(fps: 10), size: 100),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(host(const SizedBox.shrink()));
      await tester.pump();
      // A leaked Timer would be reported by the test framework at teardown.
      expect(find.byType(CompanionSpritePlayer), findsNothing);
    });

    testWidgets('switching action restarts from the first frame',
        (tester) async {
      await tester.pumpWidget(host(
        CompanionSpritePlayer(spec: spec(count: 3, fps: 10), size: 100),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(shownIndex(tester), 1);

      await tester.pumpWidget(host(
        const CompanionSpritePlayer(
          spec: CompanionActionSpec(
            actionId: 'other_action',
            frames: [
              'assets/x/other_000.png',
              'assets/x/other_001.png',
            ],
            fps: 10,
          ),
          size: 100,
        ),
      ));
      await tester.pump();
      expect(shownIndex(tester), 0,
          reason: 'a new action must not inherit the previous index');
    });
  });

  group('degenerate input', () {
    testWidgets('a single-frame action renders and does not spin',
        (tester) async {
      await tester.pumpWidget(host(
        CompanionSpritePlayer(spec: spec(count: 1, fps: 10), size: 100),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(shownIndex(tester), 0);
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
