/// Retry and cost rules for a generation attempt.
///
/// ## Why the rules live here and not in a provider
///
/// A provider that retried itself would have to decide how many times, how long
/// to wait, and when to stop spending — and each provider would decide
/// differently, which is how one integration ends up retrying six times against
/// a rate limit while another gives up on the first 503.
///
/// So the policy is one object, applied by a wrapper around whichever provider is
/// configured. A provider makes one attempt and reports what it cost.
///
/// ## Why there is a ceiling at all
///
/// A generation is the only operation in this app that spends money per call. A
/// retry loop without a ceiling is a bug that bills the user, so the ceiling is
/// part of the contract rather than a setting someone has to remember to pass.
library;

import 'companion_generation_contract.dart';

/// How many attempts, how far apart, and how much may be spent.
class CompanionGenerationPolicy {
  /// The most attempts for one request, including the first.
  final int maxAttempts;

  /// The wait before attempt *n*, where *n* is 1-based and the first attempt
  /// happens immediately.
  ///
  /// Doubling rather than fixed, because the failures worth retrying — a rate
  /// limit, a transient 503 — are the ones a fixed short delay makes worse.
  final Duration baseBackoff;

  /// The most a single request may cost across all its attempts.
  ///
  /// Not a target: an attempt that would cross it is not made. A provider that
  /// does not report a cost is treated as costing nothing, which is the honest
  /// reading of "unknown" only because the ceiling exists to bound a *known*
  /// spend — a provider that hides its price is a provider to configure a budget
  /// for at the account, not here.
  final double maxCostUsd;

  const CompanionGenerationPolicy({
    this.maxAttempts = 3,
    this.baseBackoff = const Duration(seconds: 2),
    this.maxCostUsd = 1.0,
  });

  /// A policy that makes one attempt and never waits.
  ///
  /// For tests, and for a caller that wants a failure fast.
  static const CompanionGenerationPolicy singleAttempt =
      CompanionGenerationPolicy(maxAttempts: 1, baseBackoff: Duration.zero);

  /// The delay before the attempt numbered [attempt] (1-based).
  Duration backoffFor(int attempt) =>
      baseBackoff * (1 << (attempt - 1).clamp(0, 8));
}

/// Runs a provider under a policy.
///
/// The only thing that decides whether another attempt happens, so a caller gets
/// one place to read for "what did this cost and how many times did it try".
class CompanionGenerationRunner {
  final CompanionGenerationProvider provider;
  final CompanionGenerationPolicy policy;

  /// Waits between attempts. Injected so a test does not sleep.
  final Future<void> Function(Duration) delay;

  const CompanionGenerationRunner({
    required this.provider,
    this.policy = const CompanionGenerationPolicy(),
    this.delay = _realDelay,
  });

  static Future<void> _realDelay(Duration duration) =>
      Future<void>.delayed(duration);

  /// Attempts the generation, within the policy.
  ///
  /// An unconfigured provider is reported as [CompanionGenerationStatus
  /// .blockedExternal] without being called: there is nothing to try, and a
  /// failure would misdescribe a missing capability as a broken one.
  Future<CompanionGenerationResult> run(
    CompanionGenerationRequest request,
  ) async {
    final problems = request.problems();
    if (problems.isNotEmpty) {
      return CompanionGenerationResult.refused(problems.join('; '));
    }

    if (!provider.isConfigured) {
      return CompanionGenerationResult.blockedExternal(
        '${provider.providerId} is not configured: ${provider.unavailableReason}',
      );
    }

    var spent = 0.0;
    CompanionGenerationResult? last;

    for (var attempt = 1; attempt <= policy.maxAttempts; attempt++) {
      if (attempt > 1) await delay(policy.backoffFor(attempt - 1));

      final result = await provider.generate(request);
      spent += result.costUsd ?? 0;
      last = CompanionGenerationResult(
        status: result.status,
        packBytes: result.packBytes,
        detail: result.detail,
        attempts: attempt,
        costUsd: spent,
      );

      if (result.ok) return last;

      // A refusal or a missing capability is not worth another attempt: neither
      // changes by asking again, and retrying a refusal would only spend money
      // to be refused again.
      if (result.status == CompanionGenerationStatus.refused ||
          result.status == CompanionGenerationStatus.blockedExternal) {
        return last;
      }

      if (spent >= policy.maxCostUsd) {
        return CompanionGenerationResult(
          status: CompanionGenerationStatus.failed,
          detail: 'stopped after $attempt attempt(s): the cost ceiling of '
              '${policy.maxCostUsd} was reached',
          attempts: attempt,
          costUsd: spent,
        );
      }
    }

    return last!;
  }
}
