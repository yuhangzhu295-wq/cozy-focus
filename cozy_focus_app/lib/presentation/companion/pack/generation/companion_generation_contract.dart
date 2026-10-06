/// The contract between the app and anything that would generate a companion.
///
/// ## What this file is for, and what it deliberately is not
///
/// There is no provider configured and no credentials to configure one with, so
/// **nothing here has ever produced a companion**. What it does is fix the shape
/// of the conversation before anyone can be tempted to shape it around a
/// particular vendor: a request, a result, and a status that can say "not
/// available" as clearly as it says "done".
///
/// The status is the important part. A generation path that can only report
/// success is one that will eventually report a fake one, so
/// [CompanionGenerationStatus.blockedExternal] is a first-class outcome: the
/// honest answer when the capability is not available is to say so, not to
/// return something plausible.
///
/// ## Where a generated pack enters the app
///
/// Nowhere different from any other pack. A generation produces the bytes of a
/// `.cozy_pet`, and those bytes go through the P32 reader, the same validator and
/// the same install rules as a file a user picked. That is the architecture rule
/// from P31 — a companion's origin must not change how it behaves — and it is why
/// this contract's output is *a pack*, not a frame list or a bespoke object.
library;

import 'dart:typed_data';

/// The species a companion may be generated as.
///
/// The same three the format accepts, because a generated companion goes through
/// the same install rules and a fourth value here would be refused there.
const List<String> generationSpecies = ['dog', 'cat', 'rabbit'];

/// What is being asked for.
class CompanionGenerationRequest {
  /// The id the pack will be installed under.
  ///
  /// The same grammar the importer enforces: it becomes a directory name.
  final String packId;

  /// What the companion should be called.
  final String displayName;

  final String species;

  /// What the player asked for, in their own words.
  ///
  /// Free text, and never sent as the whole prompt: the template in
  /// `companion_generation_prompt.dart` states the contract around it. A request
  /// that only carried the player's sentence would leave the canvas, the anchors
  /// and the action list to the provider's imagination, and a pack that does not
  /// sit on the template cannot be installed.
  final String description;

  /// Which of the app's actions the companion should be able to perform.
  ///
  /// A subset of the production vocabulary, and `idle` is always included by the
  /// caller. A partial set is legal — P33's premise — so a request for four
  /// actions is a normal request, not a degraded one.
  final Set<String> actions;

  /// Reference images, if the player supplied any.
  ///
  /// Paths rather than bytes, because a provider that accepts images will want
  /// to upload them itself, and holding megabytes of PNG in a value object that
  /// travels through Riverpod is how a memory problem starts.
  final List<String> referenceImagePaths;

  const CompanionGenerationRequest({
    required this.packId,
    required this.displayName,
    required this.species,
    required this.description,
    required this.actions,
    this.referenceImagePaths = const [],
  });

  /// Why this request cannot be sent, or an empty list when it can.
  ///
  /// A pre-flight, so an obviously invalid request is refused before it costs
  /// anything. It is not the authority on the pack: the importer is, when the
  /// bytes come back.
  List<String> problems() {
    final problems = <String>[];
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(packId)) {
      problems.add('packId "$packId" is not usable as a directory name');
    }
    if (displayName.trim().isEmpty) {
      problems.add('a companion needs a name');
    }
    if (!generationSpecies.contains(species)) {
      problems.add('"$species" is not one of ${generationSpecies.join(', ')}');
    }
    if (description.trim().isEmpty) {
      problems.add('a description is what the generation is for');
    }
    if (actions.isEmpty) {
      problems.add('no actions requested');
    }
    if (!actions.contains('idle')) {
      // Without an idle there is nothing to draw while the companion stands
      // still, which the importer refuses for good reason.
      problems.add('idle must be requested');
    }
    return problems;
  }
}

/// What a generation attempt did.
enum CompanionGenerationStatus {
  /// A pack came back.
  generated,

  /// The capability is not available — no credentials, no configured provider.
  ///
  /// A first-class answer rather than an error: it is the truthful state of a
  /// build with no provider, and a caller must be able to show it without
  /// treating it as a crash.
  blockedExternal,

  /// The request was refused before it was sent.
  refused,

  /// The provider was reached and failed.
  failed,
}

/// The outcome, with the pack's bytes when there are any.
class CompanionGenerationResult {
  final CompanionGenerationStatus status;

  /// The `.cozy_pet` bytes, when [status] is [CompanionGenerationStatus.generated].
  ///
  /// Never synthesised. A result whose status is not `generated` has null bytes,
  /// so a caller cannot accidentally install a placeholder by ignoring the
  /// status.
  final Uint8List? packBytes;

  /// Why, for every status except `generated`.
  final String? detail;

  /// How many attempts were made, for the cost record.
  final int attempts;

  /// What the provider reported charging, when it reports anything.
  final double? costUsd;

  const CompanionGenerationResult({
    required this.status,
    this.packBytes,
    this.detail,
    this.attempts = 0,
    this.costUsd,
  }) : assert(
          status == CompanionGenerationStatus.generated || packBytes == null,
          'only a generated result may carry a pack. A caller that reads the '
          'bytes without checking the status would otherwise install something '
          'from a refusal, which is the fake success this contract exists to '
          'make impossible.',
        );

  bool get ok => status == CompanionGenerationStatus.generated;

  /// A refusal, before anything was sent.
  const CompanionGenerationResult.refused(String reason)
      : status = CompanionGenerationStatus.refused,
        packBytes = null,
        detail = reason,
        attempts = 0,
        costUsd = null;

  /// The capability is not available.
  ///
  /// The default answer of an unconfigured build, and the one that must never be
  /// dressed up as a success.
  const CompanionGenerationResult.blockedExternal(String reason)
      : status = CompanionGenerationStatus.blockedExternal,
        packBytes = null,
        detail = reason,
        attempts = 0,
        costUsd = null;

  @override
  String toString() => 'CompanionGenerationResult(${status.name}'
      '${detail == null ? '' : ': $detail'})';
}

/// Something that can turn a request into a pack.
///
/// Deliberately narrow: one method, and an answer that can say no. A provider is
/// reached through a policy, which is what holds the retry and cost rules, so an
/// implementation here does not have to think about either.
abstract class CompanionGenerationProvider {
  /// A stable id, for the record and for the diagnostics. Never shown to a user.
  String get providerId;

  /// Whether this provider can be used at all.
  ///
  /// The question a build with no credentials answers `false` to, and the reason
  /// the UI can say "not available" without attempting a call that would fail
  /// slowly.
  bool get isConfigured;

  /// Why it cannot be used, when [isConfigured] is false.
  String get unavailableReason;

  /// One attempt. Retrying is the policy's business, not the provider's.
  Future<CompanionGenerationResult> generate(
    CompanionGenerationRequest request,
  );
}
