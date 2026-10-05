import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_frame_source.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_sprite_player.dart';

/// P32 — one player, two frame sources.
///
/// The point of the abstraction is that a built-in companion and an installed one
/// differ in exactly one place, and that the player, its timing, its loop mode and
/// its reduced-motion handling are untouched. These tests pin both halves: the
/// bundled path is unchanged, and a file-backed source resolves to a file without
/// the player needing to know which it was given.
void main() {
  const spec = CompanionActionSpec(
    actionId: 'idle',
    frames: ['idle_000.png', 'idle_001.png'],
    fps: 5,
    loopMode: SpriteLoopMode.loop,
  );

  group('the source resolves a frame path', () {
    test('bundled frames resolve to an asset', () {
      const source = CompanionFrameSource.assets();
      expect(source.isBundled, isTrue);
      expect(source.providerFor('idle_000.png'), isA<AssetImage>());
    });

    test('an installed pack resolves to a file', () {
      const source = CompanionFrameSource.directory('/data/packs/mimi');
      expect(source.isBundled, isFalse);
      final provider = source.providerFor('idle_000.png');
      expect(provider, isA<FileImage>());
      expect(
          (provider as FileImage).file.path, '/data/packs/mimi/idle_000.png');
    });
  });

  group('the player draws from either without being told which', () {
    testWidgets('bundled frames draw', (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: CompanionSpritePlayer(spec: spec, size: 64),
      ));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('a missing installed frame degrades, it does not crash',
        (tester) async {
      // The installed directory does not exist, so every frame fails to load.
      // The player's errorBuilder is what keeps that from being a crash - and a
      // missing frame is a real possibility for a pack deleted behind the app's
      // back, so it is worth pinning.
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: CompanionSpritePlayer(
          spec: spec,
          size: 64,
          frameSource: CompanionFrameSource.directory('/nonexistent/pack'),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull,
          reason: 'a frame that will not load must not throw');
    });

    testWidgets('the player accepts a real file-backed frame', (tester) async {
      // A real PNG on disk, drawn through the same widget. This is the case an
      // installed pack actually produces.
      final dir = Directory.systemTemp.createTempSync('cozy_frame_source_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      // A 1x1 transparent PNG.
      final png = <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ];
      for (final name in const ['idle_000.png', 'idle_001.png']) {
        File('${dir.path}/$name').writeAsBytesSync(png);
      }

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: CompanionSpritePlayer(
          spec: spec,
          size: 64,
          frameSource: CompanionFrameSource.directory(dir.path),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
    });
  });

  test('the source describes itself, so a log says which was used', () {
    expect(const CompanionFrameSource.assets().toString(), contains('assets'));
    expect(
        const CompanionFrameSource.directory('/x').toString(), contains('/x'));
  });
}
