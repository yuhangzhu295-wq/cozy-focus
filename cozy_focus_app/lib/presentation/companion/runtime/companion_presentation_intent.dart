import '../time_of_day.dart';
import 'companion_context.dart';
import 'companion_id.dart';
import 'companion_pose.dart';

/// What the renderer is told to present, and nothing more.
///
/// ## The decoupling boundary
///
/// The director produces this. The renderer consumes it. The director therefore
/// cannot know whether a pose becomes a `CustomPainter`, a PNG, an SVG or a Rive
/// state machine — `docs/01_Companion_Runtime_Architecture_SPEC.md` §9 requires
/// that swapping the renderer must not touch the director or the business layer.
///
/// Everything here is *presentation*: a pose, a micro-motion channel list, an
/// anchor id. There is deliberately no XP, no reward, no session status and no
/// craft progress — the intent has no vocabulary with which to change business
/// state.
class CompanionPresentationIntent {
  /// Which companion to draw.
  final CompanionId companionId;

  /// The pose to present. This is the semantic unit, never a frame.
  final CompanionPose pose;

  /// The macro behaviour in force underneath any overlay.
  ///
  /// Kept alongside [pose] so a renderer can animate *between* behaviours rather
  /// than only reacting to the current one, and so tests can assert the macro
  /// that an overlay is covering.
  final CompanionMacroBehavior? macroBehavior;

  /// The base context the companion is in. Overlays never change this.
  final CompanionBaseContext baseContext;

  /// The overlay currently covering the macro behaviour, if any.
  final CompanionOverlay overlay;

  /// Whether [pose] came from an overlay rather than the macro behaviour.
  final bool isOverlayActive;

  /// The micro-motion channels this companion supports.
  ///
  /// Data-driven from the profile, so a new companion declares its own channels
  /// and the generic renderer needs no new branch.
  final List<String> microMotion;

  /// Whether large motion must be suppressed.
  ///
  /// Reduced motion preserves the *semantic* pose — it never changes which pose
  /// is presented — and only lowers translation, bounce, rotation and
  /// ear/tail intensity. Keeping the flag on the intent (rather than letting a
  /// renderer decide for itself) is what makes that guarantee testable.
  final bool reducedMotion;

  /// The presentation anchor in the room, when in the room context.
  final String? roomAnchor;

  /// The time-of-day band, for copy and tint. Never for behaviour eligibility
  /// that could change what the companion *is* doing.
  final TimeOfDayBand timeOfDay;

  /// The real focus progress passthrough, or `null` when no session runs.
  final double? focusProgress;

  /// The real craft progress passthrough, or `null` when no craft job runs.
  final double? craftProgress;

  const CompanionPresentationIntent({
    required this.companionId,
    required this.pose,
    required this.baseContext,
    this.macroBehavior,
    this.overlay = CompanionOverlay.none,
    this.isOverlayActive = false,
    this.microMotion = const [],
    this.reducedMotion = false,
    this.roomAnchor,
    this.timeOfDay = TimeOfDayBand.midday,
    this.focusProgress,
    this.craftProgress,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanionPresentationIntent &&
          runtimeType == other.runtimeType &&
          companionId == other.companionId &&
          pose == other.pose &&
          macroBehavior == other.macroBehavior &&
          baseContext == other.baseContext &&
          overlay == other.overlay &&
          isOverlayActive == other.isOverlayActive &&
          reducedMotion == other.reducedMotion &&
          roomAnchor == other.roomAnchor &&
          timeOfDay == other.timeOfDay;

  @override
  int get hashCode => Object.hash(
        companionId,
        pose,
        macroBehavior,
        baseContext,
        overlay,
        isOverlayActive,
        reducedMotion,
        roomAnchor,
        timeOfDay,
      );

  @override
  String toString() => 'CompanionPresentationIntent(${companionId.value} '
      'pose=${pose.id} macro=${macroBehavior?.id ?? '-'} '
      'base=${baseContext.id} overlay=${overlay.id} '
      'reducedMotion=$reducedMotion)';
}
