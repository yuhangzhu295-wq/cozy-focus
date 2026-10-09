import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_frame_source.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_presentation_intent.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_sprite_art.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_visual_provider.dart';

/// The sprite renderer named the companion twice.
///
/// ## Found the moment a companion came from an imported pack
///
/// Until then the home avatar drew through the rig, whose wrapper already
/// excludes what it wraps. Installing a pack-backed companion switches that
/// avatar to this renderer, and its `Semantics` wrapper did not exclude: the
/// sprite's own `semanticLabel` is `'$name $state'`, the wrapper's label is the
/// same string, and the two merged. The device tree read
///
///     小猫 空闲\n小猫 空闲, 点一下会回应，长按可以摸摸头
///
/// The static scanner could not see it — the child is not a `Text`, and the
/// string is built by the caller — so this is a device finding, pinned here.
void main() {
  const spec = CompanionActionSpec(
    actionId: 'idle',
    frames: ['assets/x/f_000.png', 'assets/x/f_001.png'],
    fps: 5,
    loopMode: SpriteLoopMode.loop,
  );

  Widget host() => const MaterialApp(
        home: Scaffold(
          body: CompanionSpriteAvatar(
            spec: spec,
            frameSource: CompanionFrameSource.assets(),
            intent: CompanionPresentationIntent(
              companionId: CompanionId('catpack'),
              pose: CompanionPose.idle,
              baseContext: CompanionBaseContext.home,
            ),
            options: CompanionVisualOptions(
              displayName: '小猫',
              size: 120,
              showStateBadge: true,
            ),
          ),
        ),
      );

  testWidgets('the state is announced once, not twice', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host());
    await tester.pump();

    // One node, one name. `find.bySemanticsLabel` matches on the node's label,
    // so a doubled label would not match this exact string at all.
    expect(find.bySemanticsLabel('小猫 空闲'), findsOneWidget);

    final node = tester.getSemantics(find.bySemanticsLabel('小猫 空闲'));
    expect(node.label, '小猫 空闲');
    expect(node.label.split('小猫 空闲').length - 1, 1,
        reason: 'the state word must appear once in the label');
    // No controller here, so no hint: the touch hint is only offered when the
    // companion actually responds.
    expect(node.hint, isEmpty);

    handle.dispose();
  });

  testWidgets('and the badge text is not a second node', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host());
    await tester.pump();

    // The badge draws the same words. It is decorative and sits inside an
    // ExcludeSemantics, so it must not produce a node of its own.
    expect(find.bySemanticsLabel('小猫 空闲'), findsOneWidget);

    handle.dispose();
  });
}
