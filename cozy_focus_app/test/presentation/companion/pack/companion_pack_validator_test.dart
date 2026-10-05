import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_validator.dart';

/// P32 — a pack from outside the app is untrusted input.
///
/// These tests are the refusal side of the standard. Each one is a pack that a
/// lenient parser would happily turn into objects and the runtime would then draw
/// wrongly, or fail on in a way that looks like a rendering bug.
void main() {
  /// A pack that passes, used as the base for the single-fault cases below.
  Map<String, dynamic> goodManifest() => {
        'companionId': 'mimi',
        'canvasWidth': 512,
        'canvasHeight': 512,
        'groundBaseline': 458,
        'centerAnchor': 255,
        'actions': {
          'idle': {
            'frames': ['idle_000.png', 'idle_001.png'],
            'fps': 5,
            'loopMode': 'loop',
          },
          'walk': {
            'frames': ['walk_000.png', 'walk_001.png'],
            'fps': 8,
            'loopMode': 'loop',
          },
        },
      };

  const goodFiles = {
    'idle_000.png',
    'idle_001.png',
    'walk_000.png',
    'walk_001.png',
  };

  PackValidationResult run(
    Map<String, dynamic> manifest, {
    Set<String> files = goodFiles,
    String? expectedId,
  }) =>
      CompanionPackValidator.validate(
        manifest: manifest,
        availableFiles: files,
        expectedId: expectedId,
      );

  test('a well-formed pack passes', () {
    final result = run(goodManifest());
    expect(result.ok, isTrue, reason: '$result');
  });

  group('identity', () {
    test('a missing companionId is refused', () {
      final m = goodManifest()..remove('companionId');
      expect(run(m).codes, contains('missing_companion_id'));
    });

    test('a manifest that disagrees with the install id is refused', () {
      // Otherwise the pack would register under one id and render from another.
      expect(run(goodManifest(), expectedId: 'other').codes,
          contains('companion_id_mismatch'));
    });
  });

  group('canvas and anchors', () {
    test('a missing canvas is refused rather than defaulted', () {
      final m = goodManifest()..remove('canvasWidth');
      expect(run(m).codes, contains('missing_canvas'));
    });

    test('a canvas below the floor is refused', () {
      final m = goodManifest()
        ..['canvasWidth'] = 32
        ..['canvasHeight'] = 32;
      expect(run(m).codes, contains('canvas_too_small'));
    });

    test('an anchor outside the canvas is refused', () {
      // The case that matters: a pack whose frames and anchors agree with each
      // other but place the companion off the canvas.
      final m = goodManifest()..['groundBaseline'] = 900;
      expect(run(m).codes, contains('baseline_out_of_canvas'));
    });
  });

  group('actions', () {
    test('a pack with no actions is refused', () {
      final m = goodManifest()..['actions'] = <String, dynamic>{};
      expect(run(m).codes, contains('no_actions'));
    });

    test('a single-frame action is refused as a still image', () {
      final m = goodManifest();
      (m['actions'] as Map)['walk'] = {
        'frames': ['walk_000.png'],
        'fps': 8,
        'loopMode': 'loop',
      };
      expect(run(m).codes, contains('action_too_short'));
    });

    test('a non-positive fps is refused', () {
      final m = goodManifest();
      (m['actions'] as Map)['walk'] = {
        'frames': ['walk_000.png', 'walk_001.png'],
        'fps': 0,
        'loopMode': 'loop',
      };
      expect(run(m).codes, contains('invalid_fps'));
    });

    test('an unknown loop mode is refused, not defaulted', () {
      final m = goodManifest();
      (m['actions'] as Map)['walk'] = {
        'frames': ['walk_000.png', 'walk_001.png'],
        'fps': 8,
        'loopMode': 'bounce',
      };
      expect(run(m).codes, contains('unknown_loop_mode'));
    });
  });

  group('frame paths', () {
    test('a frame the pack does not contain is refused', () {
      final m = goodManifest();
      (m['actions'] as Map)['walk'] = {
        'frames': ['walk_000.png', 'walk_999.png'],
        'fps': 8,
        'loopMode': 'loop',
      };
      expect(run(m).codes, contains('missing_frame_file'));
    });

    test('an absolute path is refused', () {
      expect(CompanionPackValidator.unsafePathReason('/etc/passwd'),
          'absolute path');
      expect(CompanionPackValidator.unsafePathReason(r'C:\frames\a.png'),
          'absolute path (drive letter)');
    });

    test('a directory escape is refused', () {
      // The pack is extracted into a sandbox; a path that climbs out of it is
      // the one case where sanitising and hoping is not good enough.
      expect(CompanionPackValidator.unsafePathReason('../../secrets.png'),
          'directory escape');
      expect(CompanionPackValidator.unsafePathReason('a/../../b.png'),
          'directory escape');
      expect(CompanionPackValidator.unsafePathReason('a\\..\\b.png'),
          'directory escape');
    });

    test('a null byte is refused', () {
      expect(
          CompanionPackValidator.unsafePathReason('a\u0000.png'), 'null byte');
    });

    test('an ordinary relative path is allowed', () {
      expect(CompanionPackValidator.unsafePathReason('idle_000.png'), isNull);
      expect(
          CompanionPackValidator.unsafePathReason('sub/idle_000.png'), isNull);
    });

    test('a repeated frame in one action is refused', () {
      final m = goodManifest();
      (m['actions'] as Map)['walk'] = {
        'frames': ['walk_000.png', 'walk_000.png'],
        'fps': 8,
        'loopMode': 'loop',
      };
      expect(run(m).codes, contains('duplicate_frame'));
    });
  });

  group('idle is the minimum', () {
    test('a pack with no idle is refused', () {
      // The director hands an ungrounded context `idle` even when availability
      // omits it, so this would fail as a rendering bug rather than a gap.
      final m = goodManifest();
      (m['actions'] as Map).remove('idle');
      expect(run(m).codes, contains('no_idle'));
    });

    test('a one-frame idle is refused', () {
      final m = goodManifest();
      (m['actions'] as Map)['idle'] = {
        'frames': ['idle_000.png'],
        'fps': 5,
        'loopMode': 'loop',
      };
      expect(run(m).codes, contains('idle_too_short'));
    });
  });

  group('fallbacks must point at something real', () {
    test('a dangling semanticFallback is refused', () {
      final m = goodManifest()
        ..['semanticFallback'] = {'celebrate': 'idle', 'stretch': 'nope'};
      expect(run(m).codes, contains('dangling_semanticFallback'));
    });

    test('a dangling drawAlias is refused', () {
      final m = goodManifest()..['drawAliases'] = {'room_sit': 'missing'};
      expect(run(m).codes, contains('dangling_drawAliases'));
    });

    test('a fallback pointing at a real action is allowed', () {
      final m = goodManifest()..['semanticFallback'] = {'celebrate': 'idle'};
      expect(run(m).ok, isTrue, reason: '${run(m)}');
    });
  });

  test('a partial pack is valid: idle and walk alone are enough', () {
    // P33's premise. A pack is not required to ship the production action set,
    // and this validator must not invent that requirement.
    final m = goodManifest();
    (m['actions'] as Map).remove('walk');
    final result = run(m, files: {'idle_000.png', 'idle_001.png'});
    expect(result.ok, isTrue, reason: '$result');
  });

  test('every violation is reported, not just the first', () {
    // A pack author needs the whole list to fix the pack in one pass.
    final m = goodManifest()
      ..remove('canvasWidth')
      ..['groundBaseline'] = 9999;
    (m['actions'] as Map).remove('idle');
    final result = run(m);
    expect(result.codes, contains('missing_canvas'));
    expect(result.codes, contains('no_idle'));
    expect(result.violations.length, greaterThan(1));
  });
}
