/// Single source of truth for the local MVP user identity.
///
/// All controllers, engines, and repositories must read the user ID from
/// [currentUserIdProvider] (via Riverpod) or from [localMvpUserId] in
/// non-Riverpod contexts (e.g. DAO tests).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The single local user identifier used throughout the MVP.
const String localMvpUserId = 'default_user';

/// Riverpod provider that exposes the current user ID.
final currentUserIdProvider = Provider<String>((ref) => localMvpUserId);
