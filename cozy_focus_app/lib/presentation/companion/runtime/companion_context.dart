import '../../../../domain/growth/growth_stage.dart';
import '../focus_phase.dart';
import '../time_of_day.dart';
import 'companion_id.dart';
import 'companion_pose.dart';
import 'presentation_vitals.dart';

/// The **Base Context** layer — *where* the companion is.
///
/// This is the coarsest layer and the only one that is allowed to outlive an
/// overlay. It is derived from real business state and is never invented.
enum CompanionBaseContext {
  home('home'),
  focus('focus'),
  pause('pause'),
  complete('complete'),
  craft('craft'),
  room('room'),
  sleep('sleep');

  final String id;
  const CompanionBaseContext(this.id);
}

/// The **Macro Behavior** layer — *what* the companion is doing.
///
/// One-to-one with a [CompanionPose] so there is exactly one place that decides
/// what a behaviour looks like. Adding a behaviour means adding a row here and a
/// pose, not editing a renderer.
enum CompanionMacroBehavior {
  idle('idle', CompanionPose.idle),
  prepare('prepare', CompanionPose.prepare),
  focusRead('focus_read', CompanionPose.focusRead),
  focusWrite('focus_write', CompanionPose.focusWrite),
  focusThink('focus_think', CompanionPose.focusThink),
  microRest('micro_rest', CompanionPose.microRest),
  glance('glance', CompanionPose.glance),
  finish('finish', CompanionPose.finish),
  craftWork('craft_work', CompanionPose.craftWork),
  roomSit('room_sit', CompanionPose.roomSit),
  roomRead('room_read', CompanionPose.roomRead),
  roomSleep('room_sleep', CompanionPose.roomSleep),
  roomWork('room_work', CompanionPose.roomWork),
  roomRelax('room_relax', CompanionPose.roomRelax),
  celebrate('celebrate', CompanionPose.celebrate),
  rest('pause_rest', CompanionPose.rest),
  sleep('sleep', CompanionPose.sleep);

  /// The wire id used by the recipe manifest.
  final String id;

  /// The pose this behaviour renders as.
  final CompanionPose pose;

  const CompanionMacroBehavior(this.id, this.pose);

  /// Parses a wire id. `null` for an unknown id, so an unknown recipe entry is
  /// dropped rather than throwing.
  static CompanionMacroBehavior? fromId(String? id) {
    if (id == null) return null;
    for (final behavior in CompanionMacroBehavior.values) {
      if (behavior.id == id) return behavior;
    }
    return null;
  }

  /// The behaviours that may run in a focus session.
  ///
  /// Named once so "Pause must not schedule Focus behaviour" is expressed as a
  /// set membership test rather than a second, drifting list.
  static const Set<CompanionMacroBehavior> focusBehaviors = {
    CompanionMacroBehavior.prepare,
    CompanionMacroBehavior.focusRead,
    CompanionMacroBehavior.focusWrite,
    CompanionMacroBehavior.focusThink,
    CompanionMacroBehavior.microRest,
    CompanionMacroBehavior.glance,
    CompanionMacroBehavior.finish,
  };
}

/// The **Temporary Overlay** layer.
///
/// Overlays never replace the base context. When one ends the previous
/// base + macro pair is restored exactly, which is what makes
/// `Focus + Read → TapReact → Focus + Read` structurally true rather than a
/// convention a page has to remember.
enum CompanionOverlay {
  none('none', null),
  tapReact('tap_react', CompanionPose.tapReact),
  petReact('pet_react', CompanionPose.petReact),
  greeting('greeting', CompanionPose.greeting),
  unlockReact('unlock_react', CompanionPose.unlockReact);

  final String id;
  final CompanionPose? pose;

  const CompanionOverlay(this.id, this.pose);

  static CompanionOverlay? fromId(String? id) {
    if (id == null) return null;
    for (final overlay in CompanionOverlay.values) {
      if (overlay.id == id) return overlay;
    }
    return null;
  }

  bool get isActive => this != CompanionOverlay.none;
}

/// Everything the presentation layer knows about the world, in one value.
///
/// ## It is a snapshot of business truth, not a copy of it
///
/// Every field is *read from* the real controllers. The runtime never writes any
/// of them back. There is no XP, coin, session-status, craft-progress or
/// inventory field here, because the presentation layer must not be able to
/// express a change to any of them.
///
/// ## Why one context object rather than many parameters
///
/// The director's eligibility decision depends on several facts at once (base
/// context, focus phase, growth stage, time of day, reduced motion). Passing
/// them individually meant every new fact touched every call site. A single
/// immutable snapshot keeps that a one-file change.
class CompanionContext {
  /// The companion this context is for.
  final CompanionId companionId;

  /// Where the companion is.
  final CompanionBaseContext baseContext;

  /// The macro behaviour currently in force, or `null` before the director has
  /// picked one (or while an overlay is running with `restorePrevious`).
  final CompanionMacroBehavior? macroBehavior;

  /// The overlay currently covering the macro behaviour.
  final CompanionOverlay overlay;

  /// Whether a real focus session is under way.
  ///
  /// Kept separate from [focusPhase] on purpose: a page knows a session is live
  /// from the session engine even when it has no progress figure to hand over, and
  /// "is a session running" must not silently become "is progress known".
  final bool hasActiveSession;

  /// Long-arc focus phase, or `null` when the phase is not known.
  final FocusPhase? focusPhase;

  /// `elapsed / target` for the running focus session, or `null`.
  final double? focusProgress;

  /// `progressSeconds / requiredSeconds` for the active craft job, or `null`.
  ///
  /// `null` means *no real craft job* — which is exactly the condition under
  /// which craft behaviour must not play.
  final double? craftProgress;

  /// The real shared growth stage (never a per-companion XP tier).
  final GrowthStage growthStage;

  /// The real time-of-day band. Presentation/copy/behaviour only.
  final TimeOfDayBand timeOfDay;

  /// Whether the platform asks for reduced motion.
  final bool reducedMotion;

  /// The companion's own condition, when the caller has real vitals to hand.
  ///
  /// A read-only projection — see [PresentationVitals]. A page that knows
  /// nothing about the companion's condition passes nothing and gets
  /// [PresentationVitals.neutral], which contributes nothing, so this input is
  /// additive and cannot change behaviour that already existed.
  final PresentationVitals vitals;

  /// The room anchor the companion is bound to, when in the room context.
  ///
  /// This is a *presentation* anchor id (`seat` / `lie` / `front` / `work`), not
  /// a furniture coordinate. Business `RoomItem` positions stay authoritative.
  final String? roomAnchor;

  const CompanionContext({
    required this.companionId,
    required this.baseContext,
    this.macroBehavior,
    this.overlay = CompanionOverlay.none,
    this.hasActiveSession = false,
    this.focusPhase,
    this.focusProgress,
    this.craftProgress,
    this.growthStage = GrowthStage.sprout,
    this.timeOfDay = TimeOfDayBand.midday,
    this.reducedMotion = false,
    this.roomAnchor,
    this.vitals = PresentationVitals.neutral,
  });

  /// Whether a real craft job is active. Craft behaviour is gated on this.
  bool get hasActiveCraft => craftProgress != null;

  CompanionContext copyWith({
    CompanionId? companionId,
    CompanionBaseContext? baseContext,
    CompanionMacroBehavior? macroBehavior,
    bool clearMacroBehavior = false,
    CompanionOverlay? overlay,
    bool? hasActiveSession,
    FocusPhase? focusPhase,
    bool clearFocus = false,
    double? focusProgress,
    double? craftProgress,
    bool clearCraft = false,
    GrowthStage? growthStage,
    TimeOfDayBand? timeOfDay,
    bool? reducedMotion,
    String? roomAnchor,
    PresentationVitals? vitals,
    bool clearRoomAnchor = false,
  }) {
    return CompanionContext(
      companionId: companionId ?? this.companionId,
      baseContext: baseContext ?? this.baseContext,
      macroBehavior:
          clearMacroBehavior ? null : (macroBehavior ?? this.macroBehavior),
      overlay: overlay ?? this.overlay,
      hasActiveSession: hasActiveSession ?? this.hasActiveSession,
      focusPhase: clearFocus ? null : (focusPhase ?? this.focusPhase),
      focusProgress: clearFocus ? null : (focusProgress ?? this.focusProgress),
      craftProgress: clearCraft ? null : (craftProgress ?? this.craftProgress),
      growthStage: growthStage ?? this.growthStage,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      roomAnchor: clearRoomAnchor ? null : (roomAnchor ?? this.roomAnchor),
      vitals: vitals ?? this.vitals,
    );
  }

  @override
  String toString() =>
      'CompanionContext(${companionId.value} base=${baseContext.id} '
      'macro=${macroBehavior?.id ?? '-'} overlay=${overlay.id} '
      'phase=${focusPhase?.label ?? '-'} craft=${craftProgress != null})';
}
