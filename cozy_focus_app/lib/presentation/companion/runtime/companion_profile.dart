import 'companion_context.dart';
import 'companion_id.dart';

/// What a companion *is*, as data.
///
/// Parsed from `assets/companion/companion_profiles.json`. This is the whole
/// extension surface for a new companion: one profile entry, one pose pack, one
/// visual-provider registration. No page, no director, no generic renderer and
/// no species switch is involved.
class CompanionProfile {
  final CompanionId id;

  /// The user-facing name. Pages read this; they must never hard-code it.
  final String displayName;

  /// Which pose pack (visual provider) draws this companion.
  final String posePack;

  /// One-line character description, used by the companion picker.
  final String tagline;

  /// Short trait chips, used by the companion picker.
  final List<String> traits;

  /// Whether production runtime pose assets exist yet.
  ///
  /// `"GAP"` means they do not. The runtime is honest about this: it reports the
  /// gap rather than silently substituting another companion's artwork.
  final bool runtimeAssetsAvailable;

  /// The micro-motion channels this companion supports.
  ///
  /// Read by the renderer to decide which ambient channels to drive. Kept as
  /// data so a new companion declares its own channels.
  final List<String> microMotion;

  /// Relative weights for the focus work behaviours.
  ///
  /// Keyed by [CompanionMacroBehavior.id]. A missing key means "no preference".
  final Map<String, double> behaviorWeights;

  /// Overlay pose chosen for a tap.
  final CompanionOverlay tapOverlay;

  /// Overlay pose chosen for a long press.
  final CompanionOverlay longPressOverlay;

  /// Room anchor id → macro behaviour, e.g. `seat → roomSit`.
  final Map<String, CompanionMacroBehavior> roomAnchors;

  const CompanionProfile({
    required this.id,
    required this.displayName,
    required this.posePack,
    this.tagline = '',
    this.traits = const [],
    this.runtimeAssetsAvailable = false,
    this.microMotion = const [],
    this.behaviorWeights = const {},
    this.tapOverlay = CompanionOverlay.tapReact,
    this.longPressOverlay = CompanionOverlay.petReact,
    this.roomAnchors = const {},
  });

  factory CompanionProfile.fromJson(CompanionId id, Map<String, dynamic> json) {
    final anchors = <String, CompanionMacroBehavior>{};
    final rawAnchors = json['roomAnchors'];
    if (rawAnchors is Map) {
      for (final entry in rawAnchors.entries) {
        final behavior = CompanionMacroBehavior.fromId(entry.value as String?);
        if (behavior != null) anchors[entry.key as String] = behavior;
      }
    }

    final weights = <String, double>{};
    final rawWeights = json['behaviorWeights'];
    if (rawWeights is Map) {
      for (final entry in rawWeights.entries) {
        final value = entry.value;
        if (value is num) weights[entry.key as String] = value.toDouble();
      }
    }

    final interaction = json['interaction'];
    final tap = interaction is Map
        ? CompanionOverlay.fromId(interaction['tap'] as String?)
        : null;
    final longPress = interaction is Map
        ? CompanionOverlay.fromId(interaction['longPress'] as String?)
        : null;

    return CompanionProfile(
      id: id,
      displayName: json['displayName'] as String? ?? id.value,
      posePack: json['posePack'] as String? ?? id.value,
      tagline: json['tagline'] as String? ?? '',
      traits: (json['traits'] as List?)?.cast<String>() ?? const [],
      runtimeAssetsAvailable: (json['runtimeAssets'] as String?) != 'GAP',
      microMotion: (json['microMotion'] as List?)?.cast<String>() ?? const [],
      behaviorWeights: Map.unmodifiable(weights),
      tapOverlay: tap ?? CompanionOverlay.tapReact,
      longPressOverlay: longPress ?? CompanionOverlay.petReact,
      roomAnchors: Map.unmodifiable(anchors),
    );
  }

  /// The behaviour bound to [anchor], if this companion has one.
  ///
  /// Returns `null` for an unknown anchor rather than guessing, so a room item
  /// with no recipe simply produces no interaction.
  CompanionMacroBehavior? behaviorForAnchor(String anchor) =>
      roomAnchors[anchor];

  /// The relative weight for [behavior]; `1.0` when the profile expresses none.
  double weightFor(CompanionMacroBehavior behavior) =>
      behaviorWeights[behavior.id] ?? 1.0;

  @override
  String toString() =>
      'CompanionProfile(${id.value} "$displayName" pack=$posePack assets=${runtimeAssetsAvailable ? 'OK' : 'GAP'})';
}
