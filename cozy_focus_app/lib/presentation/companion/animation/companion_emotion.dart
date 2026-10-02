/// The companion's emotional presentation state, derived from its condition.
///
/// ## Why this is not a second vitals system
///
/// The vitals **are** the truth: they track the companion's condition. The
/// emotion is a **label** on top — a single word that says how the companion
/// feels right now, derived from those vitals and from the current context. It
/// is recomputed on demand, never stored, and never persisted.
///
/// ## It is presentation, not a maintenance burden
///
/// CozyFocus is supportive. The emotion is never a punishment system, never a
/// guilt mechanic, never "you abandoned me." A low-mood reading is a *neutral*
/// presentation fact (the companion is subdued), not a judgment on the player.
/// There is no pet death, no hunger, no illness.
///
/// ## It does not override authoritative context
///
/// The base context (focus, pause, craft, complete) always wins. Emotion
/// modifies the *flavour* of a behaviour within the allowed context — it does
/// not make a focus session into room play, or a celebration into a nap.
enum CompanionEmotion {
  /// The default state. Neutral, settled, doing whatever the context asks.
  calm('calm'),

  /// A recent positive event (completion or warm interaction) has lifted the
  /// companion's presentation above its baseline.
  happy('happy'),

  /// The companion is alert and expressive — typically after a recent
  /// interaction or in a room with things to do.
  curious('curious'),

  /// Low energy. The companion prefers rest-compatible behaviours.
  tired('tired'),

  /// Low mood. The companion is subdued, not distressed.
  lowMood('lowMood');

  final String id;

  const CompanionEmotion(this.id);

  static CompanionEmotion? fromId(String? id) {
    if (id == null) return null;
    for (final emotion in CompanionEmotion.values) {
      if (emotion.id == id) return emotion;
    }
    return null;
  }

  @override
  String toString() => 'CompanionEmotion($id)';
}
