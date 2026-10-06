/// The provider this build actually has, which is none.
///
/// ## Why there is a class for "no provider"
///
/// Because the alternative is a null, and a null invites a caller to decide what
/// to do about it — and the tempting thing to do about a missing generator is to
/// produce something anyway. A provider that exists and answers
/// [CompanionGenerationStatus.blockedExternal] cannot be mistaken for a success:
/// there are no bytes in the result, so there is nothing to install by accident.
///
/// This is also why it is not a mock. A mock would return a pack, and the first
/// person to point the app at it would see a companion appear and believe the
/// feature worked. The spike's deterministic harness lives in the tests, where it
/// cannot be reached from the app.
///
/// ## What would replace it
///
/// A real provider, configured from credentials this build does not have. When
/// that happens, the result is a `.cozy_pet` and it goes through the P32 reader,
/// the same validator and the same install rules as a file a user picked — so the
/// only thing that changes is where the bytes came from.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'companion_generation_contract.dart';

/// The answer of a build with no generation configured.
class UnconfiguredGenerationProvider implements CompanionGenerationProvider {
  const UnconfiguredGenerationProvider();

  @override
  String get providerId => 'unconfigured';

  @override
  bool get isConfigured => false;

  @override
  String get unavailableReason =>
      'no generation provider is configured in this build';

  @override
  Future<CompanionGenerationResult> generate(
    CompanionGenerationRequest request,
  ) async =>
      // Reached only if a caller bypasses the runner, which checks
      // `isConfigured` first. It still answers honestly rather than throwing:
      // the capability is missing, and that is a state, not a fault.
      const CompanionGenerationResult.blockedExternal(
        'no generation provider is configured in this build',
      );
}

/// The generation provider this build has.
///
/// Overridden in a test with a deterministic harness, and — in a build that has
/// credentials — with a real provider. Nothing else about the app changes when
/// that happens, which is the point of the abstraction.
final companionGenerationProvider = Provider<CompanionGenerationProvider>(
  (ref) => const UnconfiguredGenerationProvider(),
);

/// Whether generation is available at all.
///
/// A separate provider so a screen can say "not available" without holding a
/// provider, and so a test can assert the unconfigured state without reaching
/// through the runner.
final companionGenerationAvailableProvider = Provider<bool>(
  (ref) => ref.watch(companionGenerationProvider).isConfigured,
);
