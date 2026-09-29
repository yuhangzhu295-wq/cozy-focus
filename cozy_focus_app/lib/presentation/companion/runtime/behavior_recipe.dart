import 'companion_context.dart';

/// One row of the behaviour graph: for a given context slot, what may play.
///
/// Parsed from `assets/companion/behavior_recipes.json`. The recipe is *data* —
/// the director reads it generically and never switches on a context or a
/// species, which is what lets a fourth companion arrive without touching the
/// engine.
class BehaviorRecipe {
  /// The eligible macro behaviours, in manifest order.
  ///
  /// Order matters: it is the deterministic tie-break when weights are absent
  /// or equal, so a seeded test can predict the pick.
  final List<CompanionMacroBehavior> eligible;

  /// Shortest dwell for a pick from this recipe.
  final Duration minDuration;

  /// Longest dwell for a pick from this recipe.
  final Duration maxDuration;

  /// Whether the same behaviour may not be chosen twice in a row.
  final bool noImmediateRepeat;

  /// Chance per pick of taking a glance beat instead, `0.0 … 1.0`.
  ///
  /// `0` means the recipe never glances. Only `deep_focus` sets it, and only
  /// downward — a calmer phase glances *less*, which is the whole point.
  final double glanceProbability;

  const BehaviorRecipe({
    required this.eligible,
    required this.minDuration,
    required this.maxDuration,
    this.noImmediateRepeat = true,
    this.glanceProbability = 0.0,
  });

  bool get isEmpty => eligible.isEmpty;

  /// Parses one recipe object. Throws [FormatException] on malformed data so a
  /// broken manifest fails loudly at load time rather than silently at runtime.
  factory BehaviorRecipe.fromJson(Map<String, dynamic> json) {
    final rawEligible = json['eligible'];
    if (rawEligible is! List) {
      throw const FormatException('behavior recipe: "eligible" must be a list');
    }
    final eligible = <CompanionMacroBehavior>[];
    for (final entry in rawEligible) {
      final behavior = CompanionMacroBehavior.fromId(entry as String?);
      if (behavior == null) {
        throw FormatException('behavior recipe: unknown behavior "$entry"');
      }
      eligible.add(behavior);
    }

    final minSeconds = (json['minSeconds'] as num?)?.toDouble() ?? 0;
    final maxSeconds = (json['maxSeconds'] as num?)?.toDouble() ?? minSeconds;
    if (maxSeconds < minSeconds) {
      throw const FormatException(
        'behavior recipe: maxSeconds must be >= minSeconds',
      );
    }

    return BehaviorRecipe(
      eligible: List.unmodifiable(eligible),
      minDuration: Duration(milliseconds: (minSeconds * 1000).round()),
      maxDuration: Duration(milliseconds: (maxSeconds * 1000).round()),
      noImmediateRepeat: json['noImmediateRepeat'] as bool? ?? true,
      glanceProbability:
          ((json['glanceProbability'] as num?)?.toDouble() ?? 0.0)
              .clamp(0.0, 1.0),
    );
  }

  /// Whether [behavior] may play under this recipe.
  bool allows(CompanionMacroBehavior behavior) => eligible.contains(behavior);

  @override
  String toString() => 'BehaviorRecipe(${eligible.map((b) => b.id).join('|')} '
      '${minDuration.inSeconds}-${maxDuration.inSeconds}s '
      'repeat=${!noImmediateRepeat} glance=$glanceProbability)';
}

/// One overlay's timing, parsed from the manifest.
class OverlayRecipe {
  final Duration minDuration;
  final Duration maxDuration;

  /// Whether the previous base + macro pair must be restored when the overlay
  /// ends. The spec requires this; it is modelled as data so a future overlay
  /// that deliberately changes context is expressible without a code edit.
  final bool restorePrevious;

  const OverlayRecipe({
    required this.minDuration,
    required this.maxDuration,
    this.restorePrevious = true,
  });

  factory OverlayRecipe.fromJson(Map<String, dynamic> json) {
    final raw = json['durationMs'];
    if (raw is! List || raw.length != 2) {
      throw const FormatException(
          'overlay recipe: "durationMs" must be [min,max]');
    }
    final min = (raw[0] as num).toInt();
    final max = (raw[1] as num).toInt();
    if (max < min) {
      throw const FormatException('overlay recipe: durationMs max < min');
    }
    return OverlayRecipe(
      minDuration: Duration(milliseconds: min),
      maxDuration: Duration(milliseconds: max),
      restorePrevious: json['restorePrevious'] as bool? ?? true,
    );
  }

  @override
  String toString() =>
      'OverlayRecipe(${minDuration.inMilliseconds}-${maxDuration.inMilliseconds}ms)';
}
