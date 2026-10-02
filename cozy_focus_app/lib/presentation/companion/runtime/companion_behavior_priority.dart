/// Which claim on the companion won, when several were competing.
///
/// ## What this is
///
/// The precedence already existed — it was spread across the branches of
/// `CompanionBehaviorDirector._pickMacro` and could only be read by reading
/// them. This names it, so a test can assert it and a diagnostic can report it.
///
/// It is **derived**, never stored: `currentPriority` is computed from the state
/// the director already holds, so it cannot drift out of step with what is
/// actually being presented. A stored tier would be a second source of truth.
///
/// ## Why it is not the four tiers in the brief
///
/// The brief lists `Critical / Task / Interaction / Idle`. That order cannot be
/// taken literally, because an interaction must be able to cover a running task:
/// a tap during a focus session has to produce a reaction — it is acceptance
/// criterion 3 — so `interaction` necessarily outranks `task` for as long as it
/// lasts.
///
/// The tiers here are therefore ranked by *what is being presented and why*:
///
/// ```text
/// critical     a completion. The one unconditional moment.
/// interaction  a gesture, covering whatever the macro was.
/// task         the macro comes from a task context: focus, craft, pause, sleep.
/// idle         the macro comes from an ambient context: home, room.
/// ```
///
/// `interaction` **covers** rather than replaces: when it ends, the macro it
/// covered is still there and resumes. That distinction is the whole of the
/// base/overlay separation, and it is why an interaction is a tier here without
/// being a competing behaviour.
enum CompanionBehaviorPriority {
  /// A completion. Nothing preempts it, and it is the one behaviour the brief
  /// requires to be unconditional.
  critical('critical'),

  /// A gesture covering the macro for as long as it lasts.
  interaction('interaction'),

  /// The macro of a task context — a real session or craft job.
  task('task'),

  /// The macro of an ambient context, where there is no task to be in.
  idle('idle');

  /// The wire id.
  final String id;

  const CompanionBehaviorPriority(this.id);

  /// Lower is stronger. Exposed so a test can assert the ordering rather than
  /// restate it.
  int get rank => index;

  /// Whether this tier preempts [other].
  bool outranks(CompanionBehaviorPriority other) => rank < other.rank;

  static CompanionBehaviorPriority? fromId(String? id) {
    if (id == null) return null;
    for (final priority in CompanionBehaviorPriority.values) {
      if (priority.id == id) return priority;
    }
    return null;
  }

  @override
  String toString() => 'CompanionBehaviorPriority($id)';
}
