/// Where installed companion packs live.
///
/// ## Why this is its own file
///
/// Both the pack profiles and the installed-pack registry need this value, and
/// each of those needs the other. Keeping the root here is what stops that from
/// being a circular import: the one thing two modules must agree on is a value
/// neither of them owns.
///
/// ## Why it is a plain value and not a lookup
///
/// `CompanionCatalog` is synchronous and a build must not await a path, so the
/// app resolves the directory once at startup and overrides this. Until it does,
/// nothing is installed — which is true, and a better answer than a guess.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The directory installed packs live under, or null when none is known.
final companionPackRootProvider = Provider<String?>((ref) => null);
