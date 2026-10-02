import 'dart:io';

import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest_data.dart';
import 'package:cozy_focus_app/presentation/companion/animation/sprite_animation_manifest_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every sprite pack on disk must be reachable from the built bundle.
///
/// ## The defect this exists to prevent
///
/// The cat pack shipped 14 frames and a manifest that `pubspec.yaml` never
/// named. Flutter does not recurse into asset subdirectories, so every cat frame
/// was absent from the bundle — and `CompanionSpritePlayer` degrades a missing
/// frame to an empty box rather than an error, so the cat drew blank and nothing
/// failed. It was found by reading the manifest against the pubspec by hand,
/// which is not a mechanism.
///
/// This is that mechanism. It is the "APK bundling" step of the asset
/// integration checklist, automated, so the class of bug cannot come back
/// silently.
///
/// ## What it checks
///
/// Three ways for a pack to be unreachable, all fatal:
///
/// 1. a directory under `assets/companions/` holding frames that `pubspec.yaml`
///    does not name — the original defect;
/// 2. a companion with a runtime manifest whose pack directory is not named;
/// 3. a frame path in any manifest that no declared directory covers.
void main() {
  /// The asset directories `pubspec.yaml` declares.
  ///
  /// Parsed by line rather than with a YAML parser: the project has no `yaml`
  /// dependency, and adding one to the app for a build-time question would be a
  /// release-size cost. The shape being read is a flat list under
  /// `flutter: assets:`, which is stable and trivially scannable.
  List<String> declaredAssetDirs() {
    final lines = File('pubspec.yaml').readAsLinesSync();
    final dirs = <String>[];
    var inAssets = false;
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trimLeft().startsWith('#')) continue;
      if (line.startsWith('  assets:')) {
        inAssets = true;
        continue;
      }
      if (!inAssets) continue;
      // A list entry under assets.
      final match = RegExp(r'^\s+-\s+(\S+)\s*$').firstMatch(line);
      if (match != null) {
        dirs.add(match.group(1)!);
        continue;
      }
      // Anything else ends the block: a new top-level key or a non-list line.
      if (line.trim().isEmpty) continue;
      if (!line.startsWith('    ')) {
        inAssets = false;
      }
    }
    return dirs;
  }

  /// Whether [path] sits inside one of [dirs].
  ///
  /// A directory entry covers its own files only. `assets/companions/dog/`
  /// therefore covers `assets/companions/dog/idle_000.png` and does **not**
  /// cover `assets/companions/cat/idle_000.png` — which is the whole point,
  /// since that is precisely the mistake that shipped.
  bool isCovered(String path, List<String> dirs) => dirs.any((dir) {
        final prefix = dir.endsWith('/') ? dir : '$dir/';
        if (!path.startsWith(prefix)) return false;
        final rest = path.substring(prefix.length);
        // Flutter does not recurse: only a direct child is covered.
        return rest.isNotEmpty && !rest.contains('/');
      });

  late List<String> declared;

  setUpAll(() => declared = declaredAssetDirs());

  group('the pubspec parser', () {
    test('it finds the asset directories, so the checks below are not vacuous',
        () {
      // A parser that returned nothing would make every check below pass while
      // proving nothing. The count is asserted for that reason.
      expect(declared, isNotEmpty);
      expect(declared, contains('assets/companions/dog/'));
      expect(declared, contains('assets/companions/cat/'));
    });

    test('a directory entry does not cover a sibling directory', () {
      // The negative control for the rule itself.
      expect(
        isCovered(
            'assets/companions/dog/idle_000.png', ['assets/companions/dog/']),
        isTrue,
      );
      expect(
        isCovered(
            'assets/companions/cat/idle_000.png', ['assets/companions/dog/']),
        isFalse,
        reason: 'this is the exact mistake that made the cat invisible',
      );
    });

    test('a directory entry does not cover a nested subdirectory', () {
      // Flutter does not recurse, so neither does this.
      expect(
        isCovered(
          'assets/companions/dog/mochi/idle_000.png',
          ['assets/companions/dog/'],
        ),
        isFalse,
      );
    });
  });

  group('every pack on disk is declared', () {
    test('no pack directory holds frames that pubspec.yaml does not name', () {
      final root = Directory('assets/companions');
      expect(root.existsSync(), isTrue,
          reason: 'the pack root moved — this check is now looking at nothing');

      final undeclared = <String>[];
      var packsSeen = 0;
      for (final entity in root.listSync()) {
        if (entity is! Directory) continue;
        final frames = entity
            .listSync()
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.png'))
            .toList();
        if (frames.isEmpty) continue;
        packsSeen++;
        if (!isCovered(frames.first.path.replaceAll(r'\', '/'), declared)) {
          undeclared.add('${entity.path} (${frames.length} frames)');
        }
      }

      // A scan that found no packs would pass while checking nothing.
      expect(packsSeen, greaterThanOrEqualTo(2),
          reason: 'found only $packsSeen packs — the scan is looking in the '
              'wrong place');
      expect(undeclared, isEmpty,
          reason: 'these packs are on disk but absent from the bundle, so they '
              'will draw as empty boxes with no error:\n${undeclared.join('\n')}');
    });

    test('every companion with a manifest has a declared pack directory', () {
      for (final companion in CompanionActionManifestData.manifests.keys) {
        final dir = 'assets/companions/$companion/';
        expect(declared, contains(dir),
            reason: '$companion ships a manifest but its frames are not in the '
                'bundle');
      }
    });
  });

  group('every referenced frame is covered', () {
    test('no manifest names a frame outside a declared directory', () {
      final uncovered = <String>[];
      for (final entry in CompanionActionManifestData.manifests.entries) {
        for (final path in entry.value.allFrames) {
          if (!isCovered(path, declared)) {
            uncovered.add('${entry.key}: $path');
          }
        }
      }
      expect(uncovered, isEmpty,
          reason:
              'frames referenced but not bundled:\n${uncovered.join('\n')}');
    });

    test('the contract does not plan frames into a hidden place', () {
      // The contract is the pipeline's own statement of where art will go: a
      // planned action will be written as
      // `assets/companions/<companionId>/<action>_000.png`. If that path were
      // not covered, batch 1 would land invisible — the same defect as the cat,
      // caught one step earlier.
      final uncovered = <String>[];
      for (final contract in SpriteAnimationManifestData.byCompanion.values) {
        for (final actionId in contract.actionIds) {
          final path =
              'assets/companions/${contract.companionId}/${actionId}_000.png';
          if (!isCovered(path, declared)) uncovered.add(path);
        }
      }
      expect(uncovered, isEmpty,
          reason: 'planned frames would not be bundled:\n'
              '${uncovered.join('\n')}');
    });
  });
}
