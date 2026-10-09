import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_install_plan.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_validator.dart';
import 'package:cozy_focus_app/presentation/pages/companion_import_page.dart';

/// Found by importing a real pack on a device.
///
/// The pack was built from the app's own cat frames but left out each action's
/// `fps` and `loopMode`. Thirteen actions meant twenty-six violations, and the
/// refusal screen listed them one per violation — so a person read
///
///     动作的播放速度不对。
///     动作的循环方式看不懂，装进来会不知道该怎么播。
///
/// thirteen times over, naming no action and burying nothing else, because the
/// sentence is chosen by `code` alone and the action name only ever lived in the
/// violation's `detail`, which the prose drops.
void main() {
  Map<String, dynamic> twoBadActions() => {
        'companionId': 'catpack',
        'posePack': 'catpack',
        'canvas': {'width': 512, 'height': 512},
        'groundBaseline': 458,
        'centerAnchor': 255,
        'actions': {
          'idle': {
            'frames': ['idle_000.png', 'idle_001.png'],
          },
          'walk': {
            'frames': ['walk_000.png', 'walk_001.png'],
          },
        },
      };

  const files = {
    'idle_000.png',
    'idle_001.png',
    'walk_000.png',
    'walk_001.png',
  };

  PackValidationResult run(Map<String, dynamic> manifest) =>
      CompanionPackValidator.validate(
        manifest: manifest,
        availableFiles: files,
      );

  test('an action-level refusal says which action it is about', () {
    final result = run(twoBadActions());

    final fps = result.violations.where((v) => v.code == 'invalid_fps');
    expect(fps.map((v) => v.actionId), containsAll(<String>['idle', 'walk']));
    // The detail already named it; the structured field is what the message
    // uses, so the two must agree.
    for (final v in fps) {
      expect(v.detail, contains('"${v.actionId}"'));
    }
  });

  test('a pack with no posePack is refused, not installed and then dropped',
      () {
    // The loader (`InstalledPackProfiles`) drops a pack whose manifest declares
    // no posePack, because the visual registry keys providers by it. The
    // validator did not ask, so a device walk got a pack that installed, became
    // the selection, and then vanished from the companion list.
    final valid = twoBadActions()
      ..['posePack'] = 'catpack'
      ..['actions'] = {
        'idle': {
          'frames': ['idle_000.png', 'idle_001.png'],
          'fps': 5,
          'loopMode': 'loop',
        },
      };
    expect(run(valid).ok, isTrue, reason: '${run(valid)}');

    final without = Map<String, dynamic>.from(valid)..remove('posePack');
    expect(run(without).codes, contains('missing_pose_pack'));

    final empty = Map<String, dynamic>.from(valid)..['posePack'] = '  ';
    expect(run(empty).codes, contains('missing_pose_pack'));

    final unsafe = Map<String, dynamic>.from(valid)..['posePack'] = '../escape';
    expect(run(unsafe).codes, contains('unsafe_pose_pack'));
  });

  test('the id rule has one implementation', () {
    // Two copies is how the validator and the loader drifted apart.
    expect(CompanionPackValidator.isSafePackId('catpack'), isTrue);
    expect(CompanionPackInstallRules.isSafePackId('catpack'), isTrue);
    expect(CompanionPackValidator.isSafePackId('../escape'), isFalse);
    expect(CompanionPackInstallRules.isSafePackId('../escape'), isFalse);
  });

  test('a manifest-level refusal is not about an action', () {
    final m = twoBadActions()..remove('companionId');
    final result = run(m);
    final id =
        result.violations.firstWhere((v) => v.code == 'missing_companion_id');
    expect(id.actionId, isNull);
  });

  test('two bad actions give two lines, each naming both', () {
    final result = run(twoBadActions());
    expect(result.violations, hasLength(4),
        reason: 'fps and loopMode, on each of two actions');

    final lines = summarisePackRefusals(result.violations);
    expect(lines, hasLength(2), reason: 'one line per fault, not per action');
    expect(lines.map((l) => l.count), everyElement(2));
    expect(lines.map((l) => l.actions), everyElement(['idle', 'walk']));
    expect(lines.map(renderPackRefusalLine), [
      '动作的播放速度不对。（动作：idle、walk）',
      '动作的循环方式看不懂，装进来会不知道该怎么播。（动作：idle、walk）',
    ]);
  });

  test('thirteen bad actions are one line, not thirteen', () {
    // The shape the device actually produced.
    final violations = [
      for (var i = 0; i < 13; i++)
        PackViolation('invalid_fps', 'action "a$i" has fps "null"',
            actionId: 'a$i'),
    ];
    final lines = summarisePackRefusals(violations);
    expect(lines, hasLength(1));
    expect(lines.single.count, 13);
    expect(lines.single.actions, hasLength(13));
    expect(
        renderPackRefusalLine(lines.single), '动作的播放速度不对。（13 个动作，如 a0、a1、a2 等）');
  });

  test('a manifest-level sentence repeated is counted, not repeated', () {
    final violations = [
      for (var i = 0; i < 3; i++)
        const PackViolation('no_idle', 'a pack must ship an idle action'),
    ];
    final lines = summarisePackRefusals(violations);
    expect(lines, hasLength(1));
    expect(lines.single.count, 3);
    expect(lines.single.actions, isEmpty);
    expect(renderPackRefusalLine(lines.single),
        '这个包缺少 idle（待机）动作，伙伴站着不动时就没东西可放。（3 处）');
  });
}
