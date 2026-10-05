/// How complete a companion's action set is, told truthfully.
///
/// ## The three answers, and why they are three
///
/// The roadmap's requirement is a table:
///
/// ```text
/// idle       READY
/// walk       READY
/// sleep      READY
/// focus_read MISSING
/// ```
///
/// and one rule behind it: **do not silently count a fallback as an available
/// action.** A pack that declares `"semanticFallback": {"focus_read": "idle"}`
/// can be *asked* for `focus_read` and will draw its idle frames. That is a real
/// behaviour and the director may schedule it — but the pack does not ship a
/// `focus_read`, and a report that called it READY would be claiming artwork
/// that does not exist.
///
/// So there are three answers rather than two:
///
/// * **ready** — the pack ships this action's own frames.
/// * **fallback** — the pack names it and will draw something else, or has no
///   art at all and draws an alias. Available, but not this action.
/// * **missing** — the pack never mentions it.
///
/// `fallback` is deliberately *not* folded into either neighbour. Folding it
/// into `ready` overstates the pack; folding it into `missing` understates what
/// the companion can actually do.
///
/// ## What the reference is
///
/// The app's own production action vocabulary — the action ids it has a
/// production contract for — not a list invented here and not whatever action
/// names a pack happens to use. A pack may ship an action the app has no
/// contract for; that is not an incompleteness and does not appear in the
/// report, because the app has nothing to say about it.
library;

import '../animation/sprite_animation_manifest_data.dart';
import '../runtime/companion_action_manifest.dart';

/// A companion's action set, measured against the app's vocabulary.
class CompanionPackCompleteness {
  /// Actions the pack ships its own frames for.
  final Set<String> ready;

  /// Actions the pack names but does not ship frames for.
  final Set<String> fallback;

  /// Actions the app can ask for that the pack never mentions.
  final Set<String> missing;

  /// What the above were measured against.
  final Set<String> reference;

  const CompanionPackCompleteness({
    required this.ready,
    required this.fallback,
    required this.missing,
    required this.reference,
  });

  /// A companion that ships everything the app can ask for.
  ///
  /// The built-in three are this by construction, and a test asserts it rather
  /// than trusting it — built-in parity is the thing that must not quietly
  /// erode as the vocabulary grows.
  factory CompanionPackCompleteness.complete(Set<String> reference) =>
      CompanionPackCompleteness(
        ready: reference,
        fallback: const {},
        missing: const {},
        reference: reference,
      );

  /// Measures [manifest] against [reference].
  ///
  /// [reference] defaults to the app's production vocabulary. A caller may pass
  /// a narrower set — a single action, say — and get the same three answers for
  /// it.
  static CompanionPackCompleteness of(
    CompanionActionManifest manifest, {
    Set<String>? reference,
  }) {
    final vocabulary =
        reference ?? SpriteAnimationManifestData.productionActionIds;
    final ready = <String>{};
    final fallback = <String>{};
    final missing = <String>{};

    for (final actionId in vocabulary) {
      final spec = manifest.specFor(actionId);
      if (spec != null && !spec.isEmpty) {
        // Its own frames. This is the only case that counts as shipped.
        ready.add(actionId);
      } else if (manifest.namesAction(actionId)) {
        // Named — through `semanticFallback` or `drawAliases` — so the companion
        // can be asked for it and will draw something else. Available, and not
        // this action.
        fallback.add(actionId);
      } else {
        missing.add(actionId);
      }
    }

    return CompanionPackCompleteness(
      ready: Set.unmodifiable(ready),
      fallback: Set.unmodifiable(fallback),
      missing: Set.unmodifiable(missing),
      reference: Set.unmodifiable(vocabulary),
    );
  }

  int get readyCount => ready.length;
  int get fallbackCount => fallback.length;
  int get missingCount => missing.length;
  int get total => reference.length;

  /// Whether the pack ships every action the app can ask for, with no fallbacks.
  bool get isComplete => missing.isEmpty && fallback.isEmpty;

  /// `"4 / 13"`, for a UI that has no room for the lists.
  String get summary => '$readyCount / $total';

  @override
  String toString() => 'CompanionPackCompleteness($summary ready, '
      '$fallbackCount fallback, $missingCount missing)';
}
