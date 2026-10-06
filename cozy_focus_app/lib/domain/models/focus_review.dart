/// The two things a session review records besides its note.
///
/// Both are closed vocabularies rather than free text, because the point of the
/// review is that it takes seconds: a picker with four answers is answered, and a
/// text box asking "how did that feel" is skipped. They are stored as ids, so the
/// label can be reworded without a migration and the analytics can count them.
library;

/// How the session felt.
enum FocusMood {
  distracted('distracted', '分心较多', '😖'),
  okay('okay', '一般', '😐'),
  good('good', '不错', '🙂'),
  flow('flow', '心流', '😌');

  /// The stored id. Stable, because it is written to the database.
  final String id;

  /// What the picker says.
  final String label;

  /// The face the picker draws.
  ///
  /// Carried here rather than in the widget so the review screen, the record
  /// detail screen and any later summary draw the same face for the same mood.
  final String face;

  const FocusMood(this.id, this.label, this.face);

  /// The mood for a stored value, or null.
  ///
  /// Null rather than a default: the column predates this vocabulary and holds
  /// free-form strings, and showing a legacy value as 一般 would be inventing an
  /// answer the user never gave. The screen treats null as "nothing chosen",
  /// which is what it is.
  static FocusMood? fromId(String? id) {
    for (final mood in FocusMood.values) {
      if (mood.id == id) return mood;
    }
    return null;
  }

  /// The mood an old emoji value meant.
  ///
  /// The save screen used to offer six emoji. This is the mapping the migration
  /// uses, written out so it can be read and argued with rather than hidden in a
  /// SQL statement — and anything not in it is left untouched rather than
  /// guessed at.
  static FocusMood? fromLegacyEmoji(String? emoji) => _legacyEmojiToMood[emoji];

  /// Every legacy emoji this vocabulary can read, for the migration.
  static List<String> get legacyEmoji => _legacyEmojiToMood.keys.toList();

  /// The six emoji the save screen offered, as code points.
  ///
  /// Written as code points rather than as the characters themselves so this
  /// file stays plain ASCII: an emoji in source is one editor encoding change
  /// away from becoming a different string, and the migration compares these
  /// against what is stored in the database.
  static final Map<String, FocusMood> _legacyEmojiToMood = {
    String.fromCharCode(0x1F606): FocusMood.flow, // grinning squinting face
    String.fromCharCode(0x1F970): FocusMood.flow, // smiling face with hearts
    String.fromCharCode(0x1F60A): FocusMood.good, // smiling face, smiling eyes
    String.fromCharCode(0x1F642): FocusMood.good, // slightly smiling face
    String.fromCharCode(0x1F610): FocusMood.okay, // neutral face
    String.fromCharCode(0x1F97A): FocusMood.distracted, // pleading face
  };
}

/// What the session gave the user.
///
/// Several may be chosen, including none: a session that produced nothing
/// particular is a normal session, and a picker that forces a gain would make
/// the tag meaningless.
enum FocusGain {
  moreFocused('moreFocused', '更专注了'),
  clearerThinking('clearerThinking', '理清了思路'),
  newIdeas('newIdeas', '有了新想法'),
  finishedGoal('finishedGoal', '完成了小目标'),
  learnedSomething('learnedSomething', '学到新知识'),
  betterMood('betterMood', '心情变好了');

  final String id;
  final String label;

  const FocusGain(this.id, this.label);

  static FocusGain? fromId(String? id) {
    for (final gain in FocusGain.values) {
      if (gain.id == id) return gain;
    }
    return null;
  }
}

/// A session's review, as the screen collects it and the record stores it.
class FocusReview {
  /// The mood, or null when the user did not choose one.
  final FocusMood? mood;

  /// What the user did, which is the record's note.
  final String? what;

  /// The gains chosen, in the order the picker lists them.
  final List<FocusGain> gains;

  /// What to try next time.
  final String? nextIntention;

  const FocusReview({
    this.mood,
    this.what,
    this.gains = const [],
    this.nextIntention,
  });

  /// The limits the fields enforce. A review is a few seconds' work, and a field
  /// that accepts a paragraph invites writing one.
  static const int maxWhatLength = 50;
  static const int maxNextIntentionLength = 30;

  bool get isEmpty =>
      mood == null &&
      (what == null || what!.isEmpty) &&
      gains.isEmpty &&
      (nextIntention == null || nextIntention!.isEmpty);

  /// The gains as the single stored value: ids, comma separated.
  ///
  /// One column rather than a join table, because the set is a fixed vocabulary
  /// of six and nothing will ever query "every session with this gain" across a
  /// large table — it is read back to draw the review and counted in memory. A
  /// join table would be a second thing to migrate for no reader.
  static String? encodeGains(List<FocusGain> gains) {
    if (gains.isEmpty) return null;
    return gains.map((gain) => gain.id).join(',');
  }

  /// The gains a stored value holds, ignoring anything unrecognised.
  static List<FocusGain> decodeGains(String? stored) {
    if (stored == null || stored.isEmpty) return const [];
    final result = <FocusGain>[];
    for (final part in stored.split(',')) {
      final gain = FocusGain.fromId(part.trim());
      if (gain != null && !result.contains(gain)) result.add(gain);
    }
    return result;
  }
}
