import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_sprite_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A one-shot action that is chosen again has to play again.
///
/// ## The defect this pins
///
/// `SpriteLoopMode.once` clamps on the last frame, which is correct while the
/// behaviour is in force. But the completion screen's recipe lists only
/// `celebrate`, so the director re-chooses celebrate every dwell - and because
/// the *action id* was unchanged, the player saw no reason to reset and held
/// that one still frame. On the device that was one 0.6s animation followed by
/// eleven seconds of pixel-identical frames, on the screen whose whole job is to
/// celebrate, while the same companion animates continuously on the home screen.
///
/// The spec instance is deliberately shared across the rebuilds below. That is
/// the whole point: production passes the same `const` spec every time, which is
/// why neither `!identical(oldWidget.spec, widget.spec)` nor the action-id check
/// could ever fire.
void main() {
  const spec = CompanionActionSpec(
    actionId: 'celebrate',
    frames: [
      'assets/companions/test/celebrate_000.png',
      'assets/companions/test/celebrate_001.png',
      'assets/companions/test/celebrate_002.png',
      'assets/companions/test/celebrate_003.png',
      'assets/companions/test/celebrate_004.png',
    ],
    fps: 10,
    loopMode: SpriteLoopMode.once,
  );

  Widget build(Object? token) => MaterialApp(
        home: Scaffold(
          body: CompanionSpritePlayer(
            spec: spec,
            size: 64,
            restartToken: token,
          ),
        ),
      );

  /// The asset the player is currently drawing.
  ///
  /// The frames are not real files, so the player's `errorBuilder` draws an
  /// empty box - but the `Image` widget, and therefore the provider naming the
  /// frame, is still in the tree, which is what this reads.
  String drawnFrame(WidgetTester tester) {
    final image = tester.widget<Image>(find.byType(Image));
    return (image.image as AssetImage).assetName;
  }

  /// Pump past the end of the 5-frame, 10fps clip.
  Future<void> playToEnd(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a one-shot holds its last frame while it stays chosen',
      (tester) async {
    await tester.pumpWidget(build('token-a'));
    await playToEnd(tester);
    expect(drawnFrame(tester), spec.frames.last,
        reason: 'a once action clamps at its end; that part was never wrong');
  });

  testWidgets('the same one-shot chosen again starts over', (tester) async {
    await tester.pumpWidget(build('token-a'));
    await playToEnd(tester);
    expect(drawnFrame(tester), spec.frames.last);

    // The director re-picked the same behaviour: same spec, new presentation.
    await tester.pumpWidget(build('token-b'));
    await tester.pump();

    expect(drawnFrame(tester), spec.frames.first,
        reason: 'choosing the same one-shot again must play it again, not hold '
            'the frame the first run stopped on');
  });

  testWidgets('a rebuild that is not a new choice does not restart it',
      (tester) async {
    await tester.pumpWidget(build('token-a'));
    await playToEnd(tester);
    expect(drawnFrame(tester), spec.frames.last);

    // Same spec, same token: an ordinary rebuild - a repaint, a parent setState.
    // Restarting here would make the celebration stutter on every frame the
    // avatar rebuilds.
    await tester.pumpWidget(build('token-a'));
    await tester.pump();

    expect(drawnFrame(tester), spec.frames.last,
        reason: 'the token is what marks a new choice; a rebuild alone is not '
            'one');
  });

  testWidgets('a looping action is never restarted by the token',
      (tester) async {
    // Restarting a loop would be a visible hiccup for no gain, so the token is
    // deliberately ignored for anything that is not a one-shot.
    const loop = CompanionActionSpec(
      actionId: 'idle',
      frames: [
        'assets/companions/test/idle_000.png',
        'assets/companions/test/idle_001.png',
        'assets/companions/test/idle_002.png',
      ],
      fps: 10,
      loopMode: SpriteLoopMode.loop,
    );

    Widget buildLoop(Object? token) => MaterialApp(
          home: Scaffold(
            body: CompanionSpritePlayer(
              spec: loop,
              size: 64,
              restartToken: token,
            ),
          ),
        );

    await tester.pumpWidget(buildLoop('token-a'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final before = drawnFrame(tester);

    await tester.pumpWidget(buildLoop('token-b'));
    await tester.pump();

    expect(drawnFrame(tester), before,
        reason: 'a loop must carry on from where it was, token or no token');
  });
}
