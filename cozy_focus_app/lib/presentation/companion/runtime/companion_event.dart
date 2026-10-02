/// The smallest typed event model the companion presentation layer needs.
///
/// ## Scope, deliberately narrow
///
/// This is **not** an application event bus. It carries nothing between pages,
/// nothing between layers, and no payloads: an event here is a *signal to the
/// behaviour director* that something happened which the director could not
/// infer from the context it is handed.
///
/// The distinction matters. Base context, focus phase, growth stage and the
/// clock already arrive through [CompanionContext] and are read on every update.
/// What a context snapshot cannot express is *a moment*: a tap, the instant a
/// session completes. Those are events.
///
/// ## It cannot touch business state
///
/// Nothing here awards XP or coins, writes a record, advances a craft job,
/// changes inventory or touches room ownership. The enum has no vocabulary for
/// any of it, and the director that consumes it has no repository to reach. An
/// event is therefore incapable of changing what the user has earned — which is
/// the rule "animation may never modify business data" made structural.
enum CompanionEvent {
  /// The player tapped the companion.
  tap('tap'),

  /// The player held the companion.
  longPress('long_press'),

  /// A real focus session began.
  focusStarted('focus_started'),

  /// A real focus session completed.
  ///
  /// Always resolves to a celebration, regardless of the hour, the growth stage
  /// or any ambient weighting. See `CompanionBehaviorDirector.dispatch`.
  focusCompleted('focus_completed'),

  /// A running session was paused — the companion's break.
  pauseStarted('pause_started'),

  /// A paused session was resumed.
  resumed('resumed'),

  /// The room's chosen anchor changed.
  roomActionChanged('room_action_changed');

  final String id;

  const CompanionEvent(this.id);

  /// Whether this event is a player gesture rather than a state transition.
  ///
  /// Gestures become overlays; transitions force an immediate re-pick. Keeping
  /// the distinction on the type stops the two paths from being confused at a
  /// call site.
  bool get isGesture =>
      this == CompanionEvent.tap || this == CompanionEvent.longPress;

  static CompanionEvent? fromId(String? id) {
    if (id == null) return null;
    for (final event in CompanionEvent.values) {
      if (event.id == id) return event;
    }
    return null;
  }

  @override
  String toString() => 'CompanionEvent($id)';
}
