import 'animation_state.dart';
import 'animation_state_machine.dart';
import 'animation_state_machine_data.dart';
import '../runtime/companion_pose.dart';
import '../runtime/companion_presentation_intent.dart';

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
  /// The machine this controller consults.
  ///
  /// Injected rather than read from a global so a test can supply a machine with
  /// one hop removed and assert the companion simply does not make it. Defaults
  /// to the shipped data.
  final AnimationStateMachine machine;

  /// The animation drawn right now.
  AnimationState _current = AnimationState.idle;

  /// The states still to play, front to back. The last entry is sustained.
  List<_QueuedState> _queue = const [];

  /// The posture the character is in once [_queue] has drained.
  AnimationPosture _posture = AnimationPosture.standing;

  /// Whether the companion is travelling between two anchors right now.
  bool _travelling = false;

  /// The behaviour this performance is for. Retained only to detect a change.
  CompanionPresentationIntent? _intent;

  /// Time as of the last [advanceTo]. Monotonic in the caller's clock.
  Duration _now = Duration.zero;

  CompanionAnimationController({
    CompanionPresentationIntent? intent,
    AnimationStateMachine? machine,
  }) : machine = machine ?? AnimationStateMachineData.bundled {
    if (intent != null) setIntent(intent);
  }

  /// Adopts the opening pose without staging a journey that never happened.
  /// Subsequent [setIntent] calls still use the machine's posture transitions.
  void settleAt(CompanionPresentationIntent intent) {
    _intent = intent;
    _sustainedTarget = _targetFor(intent);
    _current = _sustainedTarget;
    _posture = machine.postureFor(_current);
    _queue = [_QueuedState(_current, null)];
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

  /// Whether the companion is travelling between two anchors.
  bool get isTravelling => _travelling;

  /// Tells the controller the companion is travelling, or has arrived.
  ///
  /// ## Why travel is its own input
  ///
  /// Travel is an *animation* fact, not a behaviour. The director still believes
  /// the companion is on its way to write, and there is no pose that means
  /// "walking" — so it arrives here directly rather than as a pose the behaviour
  /// layer would have to invent.
  ///
  /// Starting a journey makes the sustained state `walk`. If the companion was
  /// seated, the machine's own posture hop puts `stand_up` in front of it, so the
  /// sequence is `stand_up → walk` without either state being named here.
  /// Arriving clears the flag and re-plans against the behaviour's pose, which
  /// queues `sit_down` when the destination is a seated one.
  ///
  /// Returns whether the drawn animation changed.
  bool setTravelling(bool travelling) {
    if (travelling == _travelling) return false;
    // Recorded before the intent check: a page can report travel before the
    // first behaviour has arrived, and the flag has to survive until it does.
    _travelling = travelling;
    final intent = _intent;
    if (intent == null) return false;
    _sustainedTarget = _targetFor(intent);
    _replan(intent);
    return true;
  }

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
      _posture = machine.postureFor(_queue.last.state);
    }
    return changed;
  }

  /// Rebuilds the queue for a (possibly new) sustained target.
  void _replan(CompanionPresentationIntent intent) {
    final target = _sustainedTarget;
    final targetPosture = machine.postureFor(target);

    // An overlay is brief and returns to what it covered, so it never triggers a
    // posture change: a companion that stands up to acknowledge a tap and then
    // sits back down is doing something the player did not ask for.
    if (intent.isOverlayActive) {
      _queue = [_QueuedState(target, null)];
      _current = target;
      _posture = _posture; // unchanged
      return;
    }

    final entry = machine.transitionBetween(
      from: _posture,
      to: targetPosture,
    );
    if (entry == null) {
      _queue = [_QueuedState(target, null)];
      _current = target;
      _posture = targetPosture;
      return;
    }

    final entryEndsAt = _now + machine.durationOf(entry);
    _queue = [
      _QueuedState(entry, entryEndsAt),
      _QueuedState(target, null),
    ];
    _current = entry;
    _posture = targetPosture;
  }

  /// The sustained animation a behaviour asks for.
  ///
  /// Read from the machine's projection table rather than switched on here, so
  /// adding a pose is a row in `animation_states.json` plus one in the mirror —
  /// not a new `case`. A pose the machine does not list falls back to `idle`,
  /// which is the one state every companion ships.
  AnimationState _targetFor(CompanionPresentationIntent intent) {
    // A journey outranks the behaviour's pose: the companion is walking now, and
    // what it is walking *towards* is still whatever the director chose.
    if (_travelling) return AnimationState.walk;
    return machine.projectionFor(intent.pose.id) ?? AnimationState.idle;
  }
}
