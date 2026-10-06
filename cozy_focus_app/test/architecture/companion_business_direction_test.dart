import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// P9 — the animation layer expresses business state and never writes it.
///
/// ## Why this is a test and not a convention
///
/// The brief is explicit: 动画层绝对禁止修改 任务数据 / 专注时间 / XP / 奖励 / 任务进度 /
/// 数据库状态. That rule is easy to keep while nobody is tempted and easy to lose
/// the moment a page wants the pet to "know" something. So it is checked by
/// reading the imports: the animation and companion-art files must not depend on
/// the repositories, the DAOs or the database, which are the only ways anything
/// can be written.
///
/// The reverse direction is allowed and is where the new phases plug in: a screen
/// derives a `PetVisualState` from facts it already has and hands it to
/// `CompanionAvatar`.
void main() {
  /// Files that draw or drive the companion.
  const animationFiles = [
    'lib/presentation/companion/companion_avatar.dart',
    'lib/presentation/companion/companion_business_state.dart',
    'lib/presentation/companion/mochi_pose_prop.dart',
    'lib/presentation/companion/procedural_companion_art.dart',
    'lib/presentation/companion/room/furniture_action_resolver.dart',
  ];

  /// Anything that can write. Importing one of these from the animation layer is
  /// how the rule would actually be broken.
  const writePaths = [
    'data/local/app_database.dart',
    'data/local/daos/',
    'data/repositories/',
    'domain/repositories/i_',
  ];

  test('the animation layer cannot reach a writer', () {
    final offenders = <String>[];

    for (final path in animationFiles) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path should exist');
      final source = file.readAsStringSync();
      for (final line in source.split('\n')) {
        if (!line.startsWith('import ') && !line.startsWith('export ')) {
          continue;
        }
        for (final forbidden in writePaths) {
          if (line.contains(forbidden)) {
            offenders.add('$path -> ${line.trim()}');
          }
        }
      }
    }

    expect(offenders, isEmpty,
        reason:
            'the animation layer may read a derived PetVisualState and draw '
            'it; it may not import anything that writes');
  });

  test('the state it is given is derived, not stored', () {
    // The one place business facts become a pet state. It imports controllers,
    // which is the allowed direction, and it must not import a repository or the
    // database.
    final source =
        File('lib/presentation/companion/companion_business_state.dart')
            .readAsStringSync();

    expect(source.contains('domain/repositories/'), isFalse,
        reason: 'deriving a state does not need a repository');
    expect(source.contains('app_database.dart'), isFalse,
        reason: 'and it certainly does not need the database');
    expect(source.contains('PetVisualState'), isTrue,
        reason: 'it returns the app\'s existing vocabulary');
  });

  test('the new feature pages hand the pet a state rather than writing one',
      () {
    // The rest screen and the focus screen both supply a state. Neither may reach
    // past CompanionAvatar into the animation internals.
    for (final path in const [
      'lib/presentation/pages/rest_page.dart',
      'lib/presentation/pages/focus_active_page.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source.contains('visualStateOverride'), isTrue, reason: path);
      for (final forbidden in const [
        'CompanionAnimationController',
        'CompanionBehaviorDirector',
        'CompanionSpritePlayer',
      ]) {
        expect(source.contains(forbidden), isFalse,
            reason: '$path must go through CompanionAvatar, not $forbidden');
      }
    }
  });
}
