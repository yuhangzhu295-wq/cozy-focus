/// The animation vocabulary the companion can *play*.
///
/// ## This is not [CompanionPose], and the difference matters
///
/// A pose is the **behaviour** layer's unit: "Mochi is writing". An animation
/// state is the **animation** layer's unit: "the sit-down transition is playing".
/// They look similar because most behaviours have a matching sustained state,
/// but they are not the same set and must not collapse into one:
///
/// * `sit_down` / `stand_up` / `walk` are animation states with no pose. They
///   exist because getting into a pose is itself something to draw.
/// * `celebrate` is a pose whose sustained animation state is `happy`.
///
/// Keeping them apart is what lets a behaviour claim a *sequence* of drawings
/// rather than one — `focus_write` becomes `sit_down` then `focus_write(loop)`,
/// which is the whole point of the V4.3 pipeline.
///
/// ## It decides nothing
///
/// This enum carries no transitions, no durations and no eligibility. Which
/// state follows which is the state machine's data, and which behaviour asked
/// for it is the director's decision. Adding a state means adding a row to the
/// projection table, not adding a branch.
enum AnimationState {
  // --- Sustained states ----------------------------------------------------
  /// Breathing in place. Multi-frame; a single PNG is not an idle loop.
  idle('idle', 'idle'),

  focusWrite('focus_write', 'focus_write'),
  focusRead('focus_read', 'focus_read'),
  focusThink('focus_think', 'focus_think'),

  /// Making something at the desk.
  craftWork('craft_work', 'craft_work'),

  sleep('sleep', 'sleep'),

  /// Settled and resting rather than asleep. Its own art, so it is its own
  /// state: projecting it onto `idle` drew the idle frames for a pose that ships
  /// a `pause_rest` sequence, which is the projection losing art it was handed.
  rest('rest', 'pause_rest'),

  /// The sustained state of the `celebrate` behaviour.
  happy('happy', 'celebrate'),

  /// The sustained state of a low-mood beat.
  sad('sad', 'sad'),

  /// Responding to a tap or a stroke.
  interact('interact', 'interact'),

  // --- Transitional states -------------------------------------------------
  /// Travelling across the room. Driven by locomotion, never by a tween.
  walk('walk', 'walk'),

  /// Standing to seated.
  sitDown('sit_down', 'sit_down'),

  /// Seated to standing.
  standUp('stand_up', 'stand_up'),

  /// Sleeping to awake.
  wakeUp('wake_up', 'wake_up');

  /// The state's own wire id, matching `animation_states.json`.
  ///
  /// Distinct from [assetActionId]: the two differ for `happy`, whose frames
  /// were authored as `celebrate`. Parsing on the asset id would make the state
  /// unaddressable by its own name.
  final String id;

  /// The sprite-action id this state draws.
  ///
  /// Distinct from the state's own name: `happy` draws the `celebrate` frames,
  /// because the animation layer names what the character is *doing* while the
  /// asset brief names the sequence that was authored. The mapping is one line
  /// here rather than a lookup scattered through the renderers.
  final String assetActionId;

  const AnimationState(this.id, this.assetActionId);

  /// Whether this state is a transition into a sustained state.
  ///
  /// A transition is never a destination: it plays once and hands over. That is
  /// what stops the companion from looping its own sit-down.
  bool get isTransitional =>
      this == AnimationState.sitDown ||
      this == AnimationState.standUp ||
      this == AnimationState.wakeUp;

  /// Whether this state can be interrupted mid-play.
  ///
  /// Mirrors the manifest's own `interruptible` contract. A transition cannot be
  /// cut: a companion that stops half-way through standing up has no pose at
  /// all, which reads as a glitch rather than as a decision.
  bool get isInterruptible => !isTransitional;

  /// Parses the state's own wire id, not its asset action id.
  ///
  /// `happy` is addressed as `happy` in the manifest even though it draws the
  /// `celebrate` frames; parsing on the asset id would make the two collide.
  static AnimationState? fromId(String? id) {
    if (id == null) return null;
    for (final state in AnimationState.values) {
      if (state.id == id) return state;
    }
    return null;
  }
}
