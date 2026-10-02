import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'random_source.dart';

/// The randomness the companion's behaviour selection draws from.
///
/// ## Why this is a provider
///
/// [RandomSource] was already injectable *into the director*, and ten test
/// files use that. But `CompanionAvatar` builds its own director, so a test that
/// renders a real avatar — through the home page, the room, or the settings
/// page — had no seam at all and silently got the system RNG. Two widget tests
/// that assert on the presented state were therefore flaky by construction:
/// `which behaviour did Mochi pick` was genuinely random.
///
/// The runtime's own docs state the rule this restores: "production uses natural
/// randomness while tests inject a fixed seed, so a behaviour test can never be
/// flaky."
///
/// Production behaviour is unchanged: the default is the same
/// [SystemRandomSource] the avatar used to construct inline.
final companionRandomSourceProvider = Provider<RandomSource>(
  (ref) => SystemRandomSource(),
);
