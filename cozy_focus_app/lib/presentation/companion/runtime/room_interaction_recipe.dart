import 'companion_context.dart';

/// Binds a room furniture item to the behaviour the companion performs on it.
///
/// Parsed from `assets/companion/room_interaction_recipes.json`, which mirrors
/// `docs/06_Room_Craft_Collection_Recipe_SPEC.md`.
///
/// ## The business gate is data, not a convention
///
/// The spec requires `owned && placed && visible`. That triple is modelled as the
/// [requires] list so the eligibility check is driven by the manifest rather than
/// by a page remembering to test all three. A page that forgot one would be a bug
/// the data cannot express.
///
/// Nothing here rewrites a business `RoomItem` coordinate. The recipe supplies a
/// *presentation anchor id*; the business position stays authoritative.
class RoomInteractionRecipe {
  /// The item id this recipe is keyed by, e.g. `sofa`.
  final String itemId;

  /// The presentation anchor id, e.g. `seat`, `lie`, `front`, `work`.
  final String anchor;

  /// The macro behaviour performed on this item.
  final CompanionMacroBehavior behavior;

  /// The required business predicates. Always includes `owned`, `placed`,
  /// `visible` in the shipped manifest.
  final List<String> requires;

  const RoomInteractionRecipe({
    required this.itemId,
    required this.anchor,
    required this.behavior,
    this.requires = const ['owned', 'placed', 'visible'],
  });

  factory RoomInteractionRecipe.fromJson(
      String itemId, Map<String, dynamic> json) {
    final behaviorId = json['behavior'] as String?;
    final behavior = CompanionMacroBehavior.fromId(behaviorId);
    if (behavior == null) {
      throw FormatException(
        'room recipe "$itemId": unknown behavior "$behaviorId"',
      );
    }
    return RoomInteractionRecipe(
      itemId: itemId,
      anchor: json['anchor'] as String? ?? 'front',
      behavior: behavior,
      requires: (json['requires'] as List?)?.cast<String>() ??
          const ['owned', 'placed', 'visible'],
    );
  }

  @override
  String toString() =>
      'RoomInteractionRecipe($itemId → ${behavior.id} @ $anchor)';
}
