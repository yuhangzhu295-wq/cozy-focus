import 'dart:convert';
import 'dart:io';

import 'package:cozy_focus_app/presentation/companion/animation/sprite_animation_asset.dart';
import 'package:cozy_focus_app/presentation/companion/animation/sprite_animation_manifest.dart';
import 'package:cozy_focus_app/presentation/companion/animation/sprite_animation_manifest_data.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// The authored animation contract, read from the shipped JSON.
SpriteAnimationManifest loadShippedManifest() {
  final json = jsonDecode(
    File('assets/companions/dog/animation_manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return SpriteAnimationManifest.fromJson(json);
}

void main() {
  late SpriteAnimationManifest fromJson;
  late SpriteAnimationManifest bundled;

  setUp(() {
    fromJson = loadShippedManifest();
    bundled = SpriteAnimationManifestData.mochi;
  });

  group('the authored contract and the Dart mirror do not drift', () {
    test('the shipped JSON parses', () {
      expect(fromJson.assets, isNotEmpty);
      expect(fromJson.firstBatch, isNotEmpty);
    });

    test('the pack identity and canvas match', () {
      expect(bundled.companionId, fromJson.companionId);
      expect(bundled.posePack, fromJson.posePack);
      expect(bundled.canvasWidth, fromJson.canvasWidth);
      expect(bundled.canvasHeight, fromJson.canvasHeight);
      expect(bundled.groundBaseline, fromJson.groundBaseline);
      expect(bundled.centerAnchor, fromJson.centerAnchor);
      expect(bundled.anchorTolerancePx, fromJson.anchorTolerancePx);
      expect(bundled.firstBatch, fromJson.firstBatch);
    });

    test('every asset matches, field for field', () {
      expect(bundled.actionIds, fromJson.actionIds);
      for (final actionId in fromJson.actionIds) {
        final a = fromJson.assetFor(actionId)!;
        final b = bundled.assetFor(actionId)!;
        expect(b.targetFrameCount, a.targetFrameCount,
            reason: '$actionId targetFrameCount');
        expect(b.fps, a.fps, reason: '$actionId fps');
        expect(b.loopMode, a.loopMode, reason: '$actionId loopMode');
        expect(b.role, a.role, reason: '$actionId role');
      }
    });

    test('an unknown role or a bad target is rejected loudly', () {
      expect(
        () => SpriteAnimationAsset.fromJson('x', {
          'targetFrameCount': 3,
          'role': 'not_a_role',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SpriteAnimationAsset.fromJson('x', {
          'targetFrameCount': 0,
          'role': 'ambient',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('firstBatch may not name an action with no contract', () {
      expect(
        () => SpriteAnimationManifest.fromJson({
          'canvas': {'width': 8, 'height': 8},
          'assets': {
            'idle': {'targetFrameCount': 1, 'role': 'ambient'},
          },
          'firstBatch': ['walk'],
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('the contract and the shipped pack agree', () {
    test('nothing ships without a contract', () {
      // A frame path the pipeline has no contract for is art nobody planned and
      // nothing will maintain. The reverse (a contract with no frames) is the
      // normal mid-production state and is asserted below.
      final runtime = CompanionActionManifestData.forCompanion('dog')!;
      for (final actionId in runtime.actionIds) {
        expect(bundled.assetFor(actionId), isNotNull,
            reason: 'dog/$actionId ships frames but has no contract');
      }
    });

    test('a produced action agrees with its contract on rate and loop', () {
      final runtime = CompanionActionManifestData.forCompanion('dog')!;
      for (final actionId in runtime.actionIds) {
        final spec = runtime.specFor(actionId)!;
        final asset = bundled.assetFor(actionId)!;
        expect(spec.fps, asset.fps, reason: 'dog/$actionId fps');
        expect(spec.loopMode, asset.loopMode, reason: 'dog/$actionId loopMode');
      }
    });

    test('a contracted action that has not shipped is absent, not faked', () {
      // The whole reason the contract exists: `walk`, `sit_down` and `stand_up`
      // are planned and must not appear in the runtime pack with stand-in
      // frames. If one is added, it has to be added as real art, which moves it
      // out of this list.
      final runtime = CompanionActionManifestData.forCompanion('dog')!;
      final planned = bundled.actionIds.difference(runtime.actionIds);
      expect(
        planned,
        {'sit_down', 'stand_up'},
        reason: 'the planned set changed - update this expectation only if the '
            'art really landed or was really replanned. walk landed in batch 2.',
      );
      for (final actionId in planned) {
        expect(runtime.specFor(actionId), isNull,
            reason: 'dog/$actionId is planned but ships frames');
      }
    });
  });

  group('the contract is complete for its first batch', () {
    test('every first-batch action has a contract', () {
      for (final actionId in bundled.firstBatch) {
        expect(bundled.assetFor(actionId), isNotNull, reason: actionId);
      }
    });

    test('the first batch is exactly the four ambient and transition actions',
        () {
      expect(
        bundled.firstBatch.toSet(),
        {'idle', 'walk', 'sit_down', 'stand_up'},
      );
    });

    test('a transition is a one-shot and an ambient action loops', () {
      for (final actionId in bundled.firstBatch) {
        final asset = bundled.assetFor(actionId)!;
        if (asset.role == SpriteAssetRole.transition) {
          expect(asset.isOneShot, isTrue,
              reason: '$actionId is a transition but loops');
        } else {
          expect(asset.isOneShot, isFalse,
              reason: '$actionId is ambient but plays once');
        }
      }
    });
  });
}
