import 'dart:math' as math;

import '../room/anchor_point.dart';

/// Where the companion is while it travels between two anchors.
///
/// ## Why this exists
///
/// Movement used to be `AnimatedPositioned`: a 700 ms tween on `left`/`top`.
/// The companion slid across the room showing one still image the whole way,
/// which is the "picture player" problem. A tween moves a *box*; it cannot tell
/// the sprite player that the character is walking.
///
/// This turns travel into **data**: a progress, a phase and a facing. Position
/// is still interpolated, but the interpolation is now something the animation
/// layer can read, so the walk frames can be selected from it.
///
/// ## It owns no timer
///
/// Time is pushed in through [advanceTo], like the behaviour director and the
/// animation controller, so the same logic runs under a unit test, a widget test
/// and the live app — and there is exactly one scheduler in the app.
///
/// ## It decides no business
///
/// Its vocabulary is two anchor points and a duration. No companion id, no
/// vitals, no repository: a change here cannot alter what the user has earned.
class LocomotionController {
  /// The default travel speed, in canvas-units per second.
  ///
  /// Canvas units are normalised to the room, so this is a fraction of the room
  /// per second. Measured against the room's own width rather than guessed.
  static const double unitsPerSecond = 0.55;

  /// The slowest a trip can be, so a step across the room is not instantaneous.
  static const Duration minTravel = Duration(milliseconds: 420);

  /// The longest a trip can be, so crossing the whole room stays snappy.
  static const Duration maxTravel = Duration(milliseconds: 2200);

  /// The anchor being travelled from.
  AnchorPoint? _from;

  /// The anchor being travelled to.
  AnchorPoint? _to;

  /// Travel duration for the current trip.
  Duration _duration = Duration.zero;

  /// Elapsed travel time for the current trip.
  Duration _elapsed = Duration.zero;

  /// Whether a trip is under way.
  bool _travelling = false;

  /// The facing at the start of the trip, held for its duration.
  ///
  /// Facing is decided once, at departure: a companion that flipped direction
  /// mid-stride because the target's x crossed its own would look like it
  /// could not make up its mind.
  double _facing = 0;

  /// Starts a trip from [from] to [to].
  ///
  /// Returns `false` when the two are the same point, in which case no trip is
  /// started — the caller keeps drawing the companion where it already is.
  bool startTravel({
    required AnchorPoint from,
    required AnchorPoint to,
  }) {
    if (from.id == to.id && _distance(from, to) < _sameSpotEpsilon) {
      return false;
    }
    _from = from;
    _to = to;
    _duration = _durationFor(distance: _distance(from, to));
    _elapsed = Duration.zero;
    _travelling = true;
    _facing = to.x >= from.x ? 1.0 : -1.0;
    return true;
  }

  /// Below this distance two anchors are the same spot, and no trip is needed.
  static const double _sameSpotEpsilon = 0.002;

  /// Cancels any trip. Used when the target disappears — the furniture the
  /// companion was walking to was removed mid-stride.
  void cancelTravel() {
    _travelling = false;
    _from = null;
    _to = null;
    _elapsed = Duration.zero;
    _duration = Duration.zero;
  }

  /// Advances the trip by [step] and reports whether it finished on this call.
  bool advance(Duration step) {
    if (!_travelling) return false;
    _elapsed += step;
    if (_elapsed < _duration) return false;
    _elapsed = _duration;
    _travelling = false;
    return true;
  }

  /// Advances to an absolute elapsed time, for tests that hold their own clock.
  bool advanceTo(Duration elapsed) {
    if (!_travelling) return false;
    _elapsed = elapsed;
    if (_elapsed < _duration) return false;
    _elapsed = _duration;
    _travelling = false;
    return true;
  }

  bool get isTravelling => _travelling;

  /// Whether a trip has been started and finished.
  ///
  /// Distinguished from "no trip": once the companion has arrived, the target is
  /// still where it is. Collapsing the two made [progress] read `0.0` after
  /// arrival, which put the settled position back at the departure anchor.
  bool get hasArrived => !_travelling && _to != null;

  /// The anchor being travelled to, or `null` when no trip has been started.
  AnchorPoint? get target => _to;

  /// How long the current trip lasts. Zero when none has been started.
  Duration get duration => _duration;

  /// How far through the trip, `0…1`.
  ///
  /// `1.0` once arrived, `0.0` when there is no trip at all. The distinction is
  /// what keeps a settled companion at its destination.
  double get progress {
    if (_to == null) return 0.0;
    if (_duration == Duration.zero) return 1.0;
    if (!_travelling && _elapsed >= _duration) return 1.0;
    final ratio = _elapsed.inMicroseconds / _duration.inMicroseconds;
    return ratio.clamp(0.0, 1.0);
  }

  /// Where the companion's feet are right now, in normalised canvas space.
  ///
  /// Falls back to [target] when settled, or to the floor anchor's own spot
  /// when there is no trip at all, so a caller can always read a position.
  ({double x, double y}) get position {
    final from = _from;
    final to = _to;
    if (from == null || to == null) {
      return (x: to?.x ?? 0.5, y: to?.y ?? 0.70);
    }
    final t = progress;
    return (
      x: from.x + (to.x - from.x) * t,
      y: from.y + (to.y - from.y) * t,
    );
  }

  /// The stride phase, `0…1`, for selecting a walk frame.
  ///
  /// Two cycles per trip regardless of trip length: a longer walk takes more
  /// strides at the same cadence rather than one slow motion. That is what makes
  /// a short step and a long walk look like the same gait.
  ///
  /// It is `0.0` at the start, at the exact half-way point and on arrival,
  /// because the cycle count is a whole number — those are stride boundaries,
  /// not a stalled gait.
  double get gaitPhase {
    if (!_travelling) return 0.0;
    return (progress * _strideCycles) % 1.0;
  }

  static const double _strideCycles = 2.0;

  /// Which leg of the stride the character is on, `0…[strideCount - 1]`.
  ///
  /// Derived from [gaitPhase] so the animation layer can index the walk frames
  /// without knowing how long the trip is.
  int strideFor({required int strideCount}) {
    if (strideCount <= 0 || !_travelling) return 0;
    return (gaitPhase * strideCount).floor() % strideCount;
  }

  /// `1` for right, `-1` for left. Held for the whole trip.
  double get facing => _facing;

  /// The travel duration for a distance, inside [minTravel]…[maxTravel].
  static Duration _durationFor({required double distance}) {
    final seconds = distance / unitsPerSecond;
    final ms = (seconds * 1000).round();
    return Duration(
      milliseconds: ms.clamp(
        minTravel.inMilliseconds,
        maxTravel.inMilliseconds,
      ),
    );
  }

  static double _distance(AnchorPoint a, AnchorPoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
