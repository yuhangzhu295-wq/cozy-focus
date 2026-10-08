import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest_data.dart';

/// A pack's two manifests have to say the same thing about its geometry.
///
/// ## Found by comparing them
///
/// Each shipped pack carries two files: `animation_manifest.json`, the authoring
/// contract that `tools/audit_pack_geometry.py` holds the frames to, and
/// `manifest.json`, the runtime manifest the app actually plays from. The
/// rabbit's said **459** and **458** — the runtime one a pixel lower than its own
/// contract, and a pixel lower than the frames, which the audit measures at 458
/// on all three packs.
///
/// Nothing checked the two against each other. `asset_guide_matches_contract_test`
/// guards the contract's numbers, and the audit guards the frames against the
/// contract, but the value the app *places sprites with* was never compared to
/// either. A pixel is invisible; the reason to test it is the next drift, which
/// will not be a pixel.
///
/// The contract's `anchorTolerancePx` does not apply here, deliberately: that
/// tolerance exists to absorb noise in *measuring frames*, and two declarations
/// of the same number have no measurement in them. They are either equal or one
/// of them is wrong.
void main() {
  final packIds = CompanionActionManifestData.manifests.keys.toList();

  Map<String, dynamic> readJson(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  test('every shipped pack has both manifests', () {
    expect(packIds, isNotEmpty);
    for (final id in packIds) {
      for (final name in const ['manifest.json', 'animation_manifest.json']) {
        expect(File('assets/companions/$id/$name').existsSync(), isTrue,
            reason: '$id/$name');
      }
    }
  });

  test('the runtime manifest declares the contract\'s geometry', () {
    for (final id in packIds) {
      final runtime = readJson('assets/companions/$id/manifest.json');
      final contract =
          readJson('assets/companions/$id/animation_manifest.json');

      expect(runtime['groundBaseline'], contract['groundBaseline'],
          reason:
              '$id: the app places sprites with this number, and the frames '
              'are authored to the contract\'s');
      expect(runtime['centerAnchor'], contract['centerAnchor'], reason: id);
      expect(runtime['canvas'], contract['canvas'], reason: id);
      expect(runtime['companionId'], id, reason: id);
    }
  });

  test('and the contract is the one the guide and the audit agree on', () {
    // Not a restatement of the other test: it pins that the numbers both files
    // are being compared against are still the format's, so a change that moved
    // both files together could not pass as agreement.
    for (final id in packIds) {
      final contract =
          readJson('assets/companions/$id/animation_manifest.json');
      expect(contract['groundBaseline'], 458, reason: id);
      expect(contract['centerAnchor'], 255, reason: id);
      expect(contract['canvas'], {'width': 512, 'height': 512}, reason: id);
    }
  });
}
