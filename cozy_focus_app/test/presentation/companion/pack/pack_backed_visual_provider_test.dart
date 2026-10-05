import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/pack/pack_backed_visual_provider.dart';
import 'package:cozy_focus_app/presentation/companion/animation/animation_state.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_frame_source.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_presentation_intent.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_visual_provider.dart';

/// P32E — one generic provider, instantiated per pack.
///
/// The brief forbids a provider class per custom pet, and this is why it is not
/// needed: a pack is data, and the only thing that differs between two of them is
/// which data and which directory. What these tests pin is the honesty rule - a
/// pack draws what it ships and nothing else.
void main() {
  /// A manifest for a pack that ships idle and walk only.
  CompanionActionManifest manifest({bool withWalk = true}) =>
      CompanionActionManifest.fromJson({
        'companionId': 'mimi',
        'posePack': 'mimi_art',
        'canvas': {'width': 512, 'height': 512},
        'groundBaseline': 458,
        'centerAnchor': 255,
        'actions': {
          'idle': {
            'frames': ['idle_000.png', 'idle_001.png'],
            'fps': 5,
            'loopMode': 'loop',
          },
          if (withWalk)
            'walk': {
              'frames': ['walk_000.png', 'walk_001.png'],
              'fps': 8,
              'loopMode': 'loop',
            },
        },
      });

  PackBackedCompanionVisualProvider provider({bool withWalk = true}) =>
      PackBackedCompanionVisualProvider(
        manifest: manifest(withWalk: withWalk),
        frameSource: const CompanionFrameSource.directory('/data/packs/mimi'),
      );

  CompanionPresentationIntent intentFor(CompanionPose pose) =>
      CompanionPresentationIntent(
        companionId: const CompanionId('mimi'),
        baseContext: CompanionBaseContext.home,
        pose: pose,
      );

  test('the provider serves the pack its manifest names', () {
    expect(provider().posePackId, 'mimi_art',
        reason: 'the pose pack id is what the registry resolves by');
  });

  test('production poses are the ones the pack ships its own frames for', () {
    final poses = provider().productionPoses;
    expect(poses, contains(CompanionPose.idle));
    expect(poses, isNot(contains(CompanionPose.celebrate)),
        reason: 'a pack that ships nothing for a pose must not claim it');
  });

  group('drawing', () {
    testWidgets('a pose the pack ships draws through the shared player',
        (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => provider().build(
            context,
            intentFor(CompanionPose.idle),
            const CompanionVisualOptions(size: 64),
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('a pose the pack does not ship draws nothing', (tester) async {
      // The honesty rule. Borrowing a built-in's art would report a custom
      // companion that is not actually there.
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => provider().build(
            context,
            intentFor(CompanionPose.celebrate),
            const CompanionVisualOptions(size: 64),
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(Image), findsNothing,
          reason: 'a pose with no frames must not be drawn as something else');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a walk frame is asked for by id, not by pose', (tester) async {
      // Walk has no CompanionPose behind it, so it is requested by animation
      // state - the same way the built-in provider asks.
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => provider().build(
            context,
            intentFor(CompanionPose.idle),
            const CompanionVisualOptions(
              size: 64,
              animationState: AnimationState.walk,
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
    });
  });

  test('two packs are two instances of one class, not two classes', () {
    final a = PackBackedCompanionVisualProvider(
      manifest: manifest(),
      frameSource: const CompanionFrameSource.directory('/a'),
    );
    final b = PackBackedCompanionVisualProvider(
      manifest: manifest(withWalk: false),
      frameSource: const CompanionFrameSource.directory('/b'),
    );
    expect(a.runtimeType, b.runtimeType);
    // They differ by their actions, not their poses: `walk` is an animation
    // state with no CompanionPose behind it, so both packs expose the same pose
    // set while shipping a different action set.
    expect(a.manifest.actionIds, isNot(equals(b.manifest.actionIds)),
        reason: 'they differ by data, which is the point');
    expect(a.productionPoses, equals(b.productionPoses));
  });
}
