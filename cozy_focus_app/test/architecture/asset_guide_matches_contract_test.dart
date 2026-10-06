import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/animation/sprite_animation_manifest_data.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest_data.dart';

/// P40 — the asset guide has to describe the asset format.
///
/// ## Why a documentation test
///
/// `docs/companion_assets.md` told readers for a long time that the canvas was
/// 1024×1024 with anchors at 919 / 511, while every shipped pack is 512×512 with
/// 458 / 255. Nothing checked it, so nothing caught it — and the failure mode is
/// not a wrong sentence: someone following that guide would author a pack on the
/// wrong canvas, and then every frame would be refused by a validator whose
/// message would not mention the guide at all.
///
/// A claim that was wrong for that long, in the file a contributor reads first,
/// is worth a test. These read the document and compare it against the code that
/// actually enforces the numbers, so the two cannot drift apart again.
void main() {
  final doc = File('docs/companion_assets.md').readAsStringSync();

  group('the asset guide describes the real contract', () {
    test('the canvas it states is the canvas the packs declare', () {
      final contract = SpriteAnimationManifestData.forCompanion('dog')!;
      expect(
          doc, contains('${contract.canvasWidth} × ${contract.canvasHeight}'),
          reason: 'the guide must state the real canvas');
    });

    test('the anchors it states are the anchors the packs declare', () {
      final contract = SpriteAnimationManifestData.forCompanion('dog')!;
      expect(doc, contains('${contract.groundBaseline}'));
      expect(doc, contains('${contract.centerAnchor}'));
      expect(doc, contains('y = ${contract.groundBaseline}'));
      expect(doc, contains('x = ${contract.centerAnchor}'));
      expect(doc, contains('y = ${contract.groundBaseline}'));
      expect(doc, contains('x = ${contract.centerAnchor}'));
    });

    test('every shipped pack agrees with the guide', () {
      // The guide states one canvas for the format, so every shipped pack has to
      // match it - otherwise the guide is right for one pack and wrong for the
      // rest, which is the state it was in.
      //
      // Read from the JSON contracts rather than the Dart mirror, because the
      // mirror deliberately carries only the dog: duplicating three identical
      // 13-asset blocks as Dart consts would be a second copy to keep in step,
      // and nothing reads the cat's or the rabbit's plan at runtime. The JSON is
      // where their contracts live, and it is what the tooling reads.
      for (final id in CompanionActionManifestData.manifests.keys) {
        final path = 'assets/companions/$id/animation_manifest.json';
        expect(File(path).existsSync(), isTrue,
            reason: '$id must have a geometry contract at $path');
        final contract =
            jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
        expect(contract['groundBaseline'], 458, reason: id);
        expect(contract['centerAnchor'], 255, reason: id);
        final canvas = contract['canvas'] as Map<String, dynamic>;
        expect(canvas['width'], 512, reason: id);
        expect(canvas['height'], 512, reason: id);
      }
    });

    test('and it describes the user-install path, not only the bundled one',
        () {
      // The guide used to describe only how to add a *shipped* companion, which
      // is the path a contributor takes and not the path a user's pack takes.
      // Someone reading it to understand custom companions would have concluded
      // a pack must be added to `pubspec.yaml`.
      expect(doc, contains('.cozy_pet'));
      expect(doc, contains('cozy_pet_builder'));
    });
  });
}
