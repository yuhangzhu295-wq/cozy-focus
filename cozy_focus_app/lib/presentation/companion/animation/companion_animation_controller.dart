import 'animation_state.dart';
import '../runtime/companion_pose.dart';
import '../runtime/companion_presentation_intent.dart';

/// What posture the character is in, and therefore which transitions are needed
/// to get somewhere else.
///
/// Posture is the animation layer's own bookkeeping — it is not business state
/// and not a pose. It exists so the controller can answer "do I need to sit down
/// before I can write?" without asking the behaviour layer, which has no
/// vocabulary for the question.
enum AnimationPosture {
  /// On all fours / standing. Reading, writing and crafting are not available.
  standing,

  /// At a desk or on a seat. The work states live here.
  seated,

  /// Lying down. Only sleep lives here.
  lying;
}

/// One entry in the play queue: what to draw, and how long before it hands over.
class _QueuedState {
  final AnimationState state;

  /// When this state hands over to the next, in presentation time.
  ///
  /// `null` for the sustained state at the end of the queue, which holds until
  /// the behaviour changes.
  final Duration? endsAt;

  const _QueuedState(this.state, this.endsAt);
}

/// Turns a behaviour result into an animation performance.
///
/// ## Where it sits
///
/// ```text
/// CompanionBehaviorDirector  ->  CompanionPresentationIntent  (behaviour)
///   ->  CompanionAnimationController  ->  AnimationState  (animation)
///     ->  the sprite player  ->  frames
/// ```
///
/// The director decides *what the companion is doing*. This decides *what is
/// drawn while it does it*, including the transitions the behaviour layer has no
/// concept of: a behaviour says "write", and writing is `sit_down` followed by
/// `focus_write` on a loop.
///
/// ## It decides no business
///
/// Its only input is a [CompanionPresentationIntent], which carries no XP, no
/// session status, no craft progress it can act on, and no repository. It cannot
/// reach a controller or a database: the import list below is the whole of its
/// world. A change here is therefore incapable of changing what the user has
/// earned, which is the V4.3 rule "animation may never modify business data"
/// made structural rather than conventional.
///
/// ## It owns no timer
///
/// Time is *pushed in* through [advanceTo], exactly as it is for the director,
/// so the same logic runs identically under a widget test, a unit test and the
/// live app — and there is exactly one place to look for a leak. The single
/// presentation scheduler stays `CompanionPresentationClock`; this class only
/// answers questions put to it.
///
/// ## Transitions are queued, never looped
///
/// A transition is not a destination. It plays once and hands over to the
/// sustained state behind it, so the companion can never be found looping its
/// own sit-down.
class CompanionAnimationController {
  /// How long each transition holds before handing over.
  ///
  /// These are the animation layer's own durations — a posture change is a
  /// drawing concern, not a behaviour dwell — so they do not come from the
  /// behaviour recipes. Stage 2 moves them into the state-machine manifest.
  static const Duration sitDownDuration = Duration(milliseconds: 600);
  static const Duration standUpDuration = Duration(milliseconds: 550);
  static const Duration wakeUpDuration = Duration(milliseconds: 700);

  /// The animation drawn right now.
  AnimationState _current = AnimationState.idle;

  /// The states still to play, front to back. The last entry is sustained.
  List<_QueuedState> _queue = const [];

  /// The posture the character is in once [_queue] has drained.
  AnimationPosture _posture = AnimationPosture.standing;

  /// The behaviour this performance is for. Retained only to detect a change.
  CompanionPresentationIntent? _intent;

  /// Time as of the last [advanceTo]. Monotonic in the caller's clock.
  Duration _now = Duration.zero;

  CompanionAnimationController({CompanionPresentationIntent? intent}) {
    if (intent != null) setIntent(intent);
  }

  /// The animation to draw right now.
  AnimationState get currentState => _current;

  /// Whether a transition is playing rather than a sustained state.
  bool get isTransitioning => _current.isTransitional;

  /// The posture the character will be in when the current queue drains.
  AnimationPosture get posture => _posture;

  /// The pose the current performance came from, for diagnostics and tests.
  CompanionPose? get sourcePose => _intent?.pose;

  /// Whether the controller has been given a behaviour at all.
  ///
  /// Read-only, like every other member: the controller holds an intent in order
  /// to detect changes to it, and exposes no way to alter it.
  bool get hasIntent => _intent != null;

  /// Whether the current performance was started by an overlay.
  bool get isOverlay => _intent?.isOverlayActive ?? false;

  /// Pushes a behaviour result in.
  ///
  /// Re-planning happens only when the *target* animation changes. An unrelated
  /// rebuild — a growth tick, a progress passthrough — therefore cannot restart
  /// a transition mid-play, which would read as a stutter.
  ///
  /// Returns whether the drawn animation changed.
  bool setIntent(CompanionPresentationIntent intent) {
    final target = _targetFor(intent);
    final previous = _intent;
    _intent = intent;

    // Compared against the target the *running* performance was planned for,
    // which is still the old one at this point. Comparing against anything
    // derived from `intent` would make the guard a tautology and let every
    // rebuild restart the transition.
    if (previous != null && target == _sustainedTarget) return false;

    _sustainedTarget = target;
    _replan(intent);
    return true;
  }

  /// The sustained state the current queue leads to.
  AnimationState _sustainedTarget = AnimationState.idle;

  /// Advances the performance to [now] and hands over finished transitions.
  ///
  /// Returns whether the drawn animation changed.
  bool advanceTo(Duration now) {
    _now = now;
    if (_queue.length <= 1) return false;

    var changed = false;
    // A `while` rather than an `if`: under a coarse clock (or a test that jumps
    // time) more than one transition can complete between two calls, and
    // handing over only one would leave the queue stale.
    while (_queue.length > 1) {
      final next = _queue[1];
      final endsAt = _queue.first.endsAt;
      if (endsAt == null || now < endsAt) break;
      _queue = _queue.sublist(1);
      _current = next.state;
      changed = true;
    }
    if (_queue.isNotEmpty) {
      _posture = _postureOf(_queue.last.state);
    }
    return changed;
  }

  /// Rebuilds the queue for a (possibly new) sustained target.
  void _replan(CompanionPresentationIntent intent) {
    final target = _sustainedTarget;
    final targetPosture = _postureOf(target);

    // An overlay is brief and returns to what it covered, so it never triggers a
    // posture change: a companion that stands up to acknowledge a tap and then
    // sits back down is doing something the player did not ask for.
    if (intent.isOverlayActive) {
      _queue = [_QueuedState(target, null)];
      _current = target;
      _posture = _posture; // unchanged
      return;
    }

    final entry = _entryTransition(from: _posture, to: targetPosture);
    if (entry == null) {
      _queue = [_QueuedState(target, null)];
      _current = target;
      _posture = targetPosture;
      return;
    }

    final entryEndsAt = _now + _durationOf(entry);
    _queue = [
      _QueuedState(entry, entryEndsAt),
      _QueuedState(target, null),
    ];
    _current = entry;
    _posture = targetPosture;
  }

  /// The sustained animation a behaviour asks for.
  ///
  /// A pure projection: input is the pose the director chose, output is one
  /// animation state. No branch on a companion, a page or a level.
  AnimationState _targetFor(CompanionPresentationIntent intent) {
    switch (intent.pose) {
      case CompanionPose.focusWrite:
      case CompanionPose.finish:
      case CompanionPose.roomWork:
        return AnimationState.focusWrite;
      case CompanionPose.focusRead:
      case CompanionPose.roomRead:
        return AnimationState.focusRead;
      case CompanionPose.focusThink:
        return AnimationState.focusThink;
      case CompanionPose.craftWork:
        return AnimationState.craftWork;
      case CompanionPose.celebrate:
        return AnimationState.happy;
      case CompanionPose.sleep:
      case CompanionPose.roomSleep:
        return AnimationState.sleep;
      case CompanionPose.tapReact:
      case CompanionPose.petReact:
      case CompanionPose.unlockReact:
      case CompanionPose.greeting:
        return AnimationState.interact;
      case CompanionPose.idle:
      case CompanionPose.prepare:
      case CompanionPose.glance:
      case CompanionPose.microRest:
      case CompanionPose.rest:
      case CompanionPose.roomSit:
      case CompanionPose.roomRelax:
        return AnimationState.idle;
    }
  }

  /// Which posture an animation leaves the character in.
  static AnimationPosture _postureOf(AnimationState state) {
    switch (state) {
      case AnimationState.focusWrite:
      case AnimationState.focusRead:
      case AnimationState.focusThink:
      case AnimationState.craftWork:
        return AnimationPosture.seated;
      case AnimationState.sleep:
        return AnimationPosture.lying;
      case AnimationState.idle:
      case AnimationState.happy:
      case AnimationState.sad:
      case AnimationState.interact:
      case AnimationState.walk:
      case AnimationState.sitDown:
      case AnimationState.standUp:
      case AnimationState.wakeUp:
        return AnimationPosture.standing;
    }
  }

  /// The transition needed to move between postures, or `null` when none is.
  ///
  /// Standing to standing and seated to seated are both already there. Lying to
  /// seated goes through standing, which is what `wake_up` then `sit_down`
  /// express; the controller queues only the first because the second is decided
  /// once the first completes and the posture is known.
  static AnimationState? _entryTransition({
    required AnimationPosture from,
    required AnimationPosture to,
  }) {
    if (from == to) return null;
    switch (to) {
      case AnimationPosture.seated:
      case AnimationPosture.lying:
        // Both destinations are reached by sitting: the character settles before
        // it sleeps. Lying adds a sleep transition afterwards, which is planned
        // once this one completes and the posture is settled.
        return AnimationState.sitDown;
      case AnimationPosture.standing:
        return from == AnimationPosture.lying
            ? AnimationState.wakeUp
            : AnimationState.standUp;
    }
  }

  static Duration _durationOf(AnimationState state) {
    switch (state) {
      case AnimationState.sitDown:
        return sitDownDuration;
      case AnimationState.standUp:
        return standUpDuration;
      case AnimationState.wakeUp:
        return wakeUpDuration;
      case AnimationState.idle:
      case AnimationState.focusWrite:
      case AnimationState.focusRead:
      case AnimationState.focusThink:
      case AnimationState.craftWork:
      case AnimationState.sleep:
      case AnimationState.happy:
      case AnimationState.sad:
      case AnimationState.interact:
      case AnimationState.walk:
        return Duration.zero;
    }
  }
}
