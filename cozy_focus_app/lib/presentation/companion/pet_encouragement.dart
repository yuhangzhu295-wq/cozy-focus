/// Mochi's encouragement engine — when Mochi speaks, and what it says.
///
/// ## Status: TEMPORARY DEFAULT MAPPING (documented, not silently invented)
///
/// V4.1 defines Mochi's *motion* in detail and its *voice* not at all. A
/// full-package search for `文案`, `message`, `气泡`, `台词`, `鼓励语`,
/// `打扰`, `愧疚` across `docs/cozy_focus_v4_1/` returns nothing; the evidence
/// is in `MOCHI_GROWTH_STAGE0_AUDIT.md` §A5/§B3. The only companion speech in
/// the shipped app is hard-coded per page (e.g. `home_page.dart`'s
/// `'继续加油！'`), with no engine, no categories, no cooldown.
///
/// The category taxonomy, the cadence budget and the copy below are therefore a
/// **chosen default**, centralised here so retuning Mochi's voice is a
/// one-file change.
///
/// ## The three hard rules, and how they are enforced
///
/// 1. **Never nag.** A standard session yields **0–3 messages**, and never
///    anything resembling one-per-minute. Enforced by
///    [PetEncouragementBudget.maxMessagesPerSession] and
///    [PetEncouragementBudget.minGapBetweenMessages] inside [decide], and
///    asserted by sweeping a whole session in `pet_encouragement_test.dart`.
/// 2. **Never interrupt the timer controls.** Structural, not conventional:
///    the engine is a pure function and the scheduler owns no `Timer`, no
///    vsync and no I/O, so it *cannot* preempt anything. The rendered bubble is
///    wrapped in an `IgnorePointer` by `PetAvatarWidget`, so it cannot swallow
///    a tap either.
/// 3. **Never guilt.** [PetEncouragementCopyGuard] holds a list of
///    guilt-inducing tokens, and the test suite fails if any string in the copy
///    table contains one. The rule is executable rather than aspirational.
///
/// ## Growth is visible in the voice
///
/// The copy table carries four variants per category, one per [GrowthStage], so
/// a sprout Mochi speaks in short, simple lines and a blooming Mochi in longer,
/// more articulate ones. This is the same "additive growth" rule the motion
/// layer follows: a later stage gains vocabulary, a younger one is not
/// silenced.
library;

import '../../domain/growth/growth_stage.dart';
import '../../domain/growth/mochi_growth_profile.dart';
import 'focus_phase.dart';
import 'time_of_day.dart';

/// The categories of thing Mochi may say.
///
/// The names are the brief's; the taxonomy is the default documented above.
enum PetMessageKind {
  /// A session just began.
  startEncouragement,

  /// Quiet company during the middle of a session.
  focusCompanion,

  /// The session passed its midpoint.
  midpointSupport,

  /// The session is nearly over.
  finishingSupport,

  /// The user paused — comfort, never reproach.
  pauseComfort,

  /// The session finished.
  completionPraise,

  /// It is late at night; care replaces encouragement.
  lateNightCare,

  /// The user came back after an absence.
  returnGreeting,

  /// The user touched Mochi.
  petTouchResponse,
}

/// One thing Mochi says, plus how long it stays on screen.
class PetMessage {
  /// Which category this belongs to.
  final PetMessageKind kind;

  /// The line itself.
  final String text;

  /// How long the bubble should remain visible.
  final Duration displayDuration;

  const PetMessage({
    required this.kind,
    required this.text,
    this.displayDuration = PetEncouragementBudget.displayDuration,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetMessage &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          text == other.text &&
          displayDuration == other.displayDuration;

  @override
  int get hashCode => Object.hash(kind, text, displayDuration);

  @override
  String toString() => 'PetMessage(${kind.name}: "$text")';
}

/// The anti-harassment budget and the window constants the engine reads.
///
/// Every number the engine depends on lives here, so a cadence change is a
/// one-file edit and the test suite can assert the whole session shape.
abstract final class PetEncouragementBudget {
  const PetEncouragementBudget._();

  /// **Hard cap.** A standard session produces at most this many messages.
  ///
  /// Deliberately a flat cap rather than a duration-scaled one: a 90-minute
  /// session being *quieter* than a 25-minute one is the correct failure
  /// direction. Silence never bothers anyone; nagging does.
  static const int maxMessagesPerSession = 3;

  /// The minimum silence between two messages.
  ///
  /// 150 s = 2.5 minutes, chosen to make "never every minute" arithmetically
  /// impossible rather than merely unlikely.
  static const Duration minGapBetweenMessages = Duration(seconds: 150);

  /// The shorter silence allowed after a pause.
  ///
  /// Pausing is a thing the *user* just did, so a word is responsive rather
  /// than an interruption. Still a real gap, still counted against the cap.
  static const Duration minGapAfterPause = Duration(seconds: 30);

  /// Mochi says nothing at all before this much of a session has passed.
  ///
  /// Prevents a message landing in the same breath as the start tap.
  static const Duration firstMessageDelay = Duration(seconds: 25);

  /// How long a message stays on screen.
  static const Duration displayDuration = Duration(seconds: 12);

  /// At or below this happiness, the chattiest category is withheld.
  static const int lowHappinessThreshold = 40;

  /// A session still below this normalised progress counts as "just started",
  /// which is what makes [PetMessageKind.startEncouragement] the opening line.
  static const double openingUntil = 0.30;

  /// The midpoint band. Progress inside it unlocks
  /// [PetMessageKind.midpointSupport].
  static const double midpointStart = 0.45;
  static const double midpointEnd = 0.58;
}

/// The copy table, and the guilt guard that keeps it honest.
abstract final class PetEncouragementCopy {
  const PetEncouragementCopy._();

  /// The line for [kind] at [stage].
  ///
  /// The variant is chosen by the growth stage's own index, so a stage change
  /// is observable in what Mochi says and the choice stays deterministic — no
  /// randomness, no clock, no hash seed.
  static String forKind(PetMessageKind kind, GrowthStage stage) {
    final variants = table[kind]!;
    return variants[stage.index % variants.length];
  }

  /// Every category, with one variant per growth stage in stage order.
  static const Map<PetMessageKind, List<String>> table = {
    PetMessageKind.startEncouragement: [
      '开始啦。Mochi 陪你。',
      '已经开始了，慢慢来就好。',
      '开头最难，你已经跨过去了。',
      '开始了。这段时间，我们各自专心。',
    ],
    PetMessageKind.focusCompanion: [
      'Mochi 在旁边。',
      'Mochi 在这里，不吵你。',
      '我也在做我的事，就在你旁边。',
      '不用管我，专心做你的就好。',
    ],
    PetMessageKind.midpointSupport: [
      '走了一半啦。',
      '一半了。要不要喝口水？',
      '已经过半，节奏保持住。',
      '一半过去了。剩下的会更顺。',
    ],
    PetMessageKind.finishingSupport: [
      '快到了哦。',
      '最后一点点，稳住就好。',
      '快到终点了，保持这个呼吸。',
      '就差一点。别急，慢慢收尾。',
    ],
    PetMessageKind.pauseComfort: [
      '停下来也可以的。',
      '暂停不会清零，随时可以继续。',
      '停下来也算数，先喘口气。',
      '歇一会儿挺好。想回来的时候我在。',
    ],
    PetMessageKind.completionPraise: [
      '完成啦！好棒。',
      '这一段专注，收好啦。',
      '完成得挺稳的，这是你挣来的。',
      '今天这一段，是你的了 ♡',
    ],
    PetMessageKind.lateNightCare: [
      '很晚啦，早点睡。',
      '夜深了，做完这段就去休息吧。',
      '很晚了。Mochi 陪你把这段收尾，然后去睡好吗？',
      '这个点还在，我陪着。但这段结束，就去睡吧。',
    ],
    PetMessageKind.returnGreeting: [
      '回来啦！',
      '回来啦，我在的。',
      '好久不见，Mochi 一直在。',
      '你回来了。我一直在这儿。',
    ],
    PetMessageKind.petTouchResponse: [
      '嘿嘿 ♡',
      '摸摸头，收到啦 ♡',
      '在呢在呢 ♡',
      '嗯，我在 ♡',
    ],
  };
}

/// The executable form of "never guilt".
///
/// A convention nobody can test is a convention that decays. Every string in
/// [PetEncouragementCopy.table] is checked against [forbiddenTokens], and any
/// hit fails the build — so a well-meaning future edit that adds
/// "别浪费这次专注" is caught before it ships.
abstract final class PetEncouragementCopyGuard {
  const PetEncouragementCopyGuard._();

  /// Tokens that make a line reproachful rather than supportive.
  ///
  /// Kept to unambiguous reproach: each of these reads as blame, debt, or
  /// comparison no matter how it is wrapped. Ordinary care words such as
  /// `应该` / `必须` are deliberately *not* here — "该休息了" is kindness, and a
  /// guard that fires on kindness would be turned off within a week.
  static const List<String> forbiddenTokens = [
    // blame / waste
    '浪费', '白费', '亏', '可惜', '活该',
    // reproach
    '又没', '怎么还没', '你怎', '为什么没', '别再', '加把劲', '抓紧',
    // failure framing
    '失败', '落后', '差劲', '比不上', '别人都',
    // debt / guilt
    '对不起', '惩罚', '失望', '不够努力', '懒',
  ];

  /// Every forbidden token present in [text], in table order.
  ///
  /// Returns an empty list for a clean line.
  static List<String> violationsIn(String text) =>
      forbiddenTokens.where(text.contains).toList(growable: false);

  /// Whether [text] is free of every forbidden token.
  static bool isClean(String text) => violationsIn(text).isEmpty;

  /// Every offending line in [PetEncouragementCopy.table], as
  /// `KIND -> "line" (token)`.
  ///
  /// Empty when the whole table is clean.
  static List<String> auditCopyTable() {
    final findings = <String>[];
    for (final entry in PetEncouragementCopy.table.entries) {
      for (final line in entry.value) {
        final violations = violationsIn(line);
        if (violations.isNotEmpty) {
          findings
              .add('${entry.key.name} -> "$line" (${violations.join(', ')})');
        }
      }
    }
    return findings;
  }
}

/// Everything [PetEncouragementEngine.decide] needs to make a call.
///
/// This is exactly the input set the brief specifies — focus state, progress,
/// time of day, growth stage, happiness, and the time since the last message —
/// plus the per-session count that makes the budget checkable.
class PetEncouragementInput {
  /// Whether the session is currently paused.
  final bool isPaused;

  /// `elapsed / target`, or `null` when there is no usable target.
  final double? progress;

  /// How much of the session has elapsed.
  final Duration elapsed;

  /// The band of the day, from [TimeOfDayResolver].
  final TimeOfDayBand timeOfDay;

  /// The resolved growth stage, which selects the wording.
  final MochiGrowthProfile growth;

  /// The real happiness score, `0`–`100`.
  final int happinessScore;

  /// Time since Mochi last spoke in this session.
  final Duration sinceLastMessage;

  /// How many messages this session has already produced.
  final int messagesThisSession;

  /// How many messages have been produced since the current pause began.
  ///
  /// A pause is a discrete event, not a stretch of time to be filled: Mochi says
  /// **one** comforting thing each time the user stops, and then leaves them
  /// alone for as long as they stay stopped. Without this, a user who steps away
  /// for ten minutes would collect the whole session budget while away from the
  /// screen — the opposite of the intent.
  final int messagesThisPause;

  const PetEncouragementInput({
    required this.isPaused,
    required this.elapsed,
    required this.timeOfDay,
    required this.growth,
    required this.happinessScore,
    required this.sinceLastMessage,
    required this.messagesThisSession,
    this.messagesThisPause = 0,
    this.progress,
  });

  /// The long-arc phase implied by [progress], or `null` when there is none.
  FocusPhase? get phase => FocusPhaseResolver.resolve(progress);
}

/// The pure decision function, plus the stateless message factories.
abstract final class PetEncouragementEngine {
  const PetEncouragementEngine._();

  /// What Mochi should say right now, or `null` to stay quiet.
  ///
  /// Pure: the same input always yields the same answer, nothing is written,
  /// and no clock is read. Callers own the counters and pass them in, which is
  /// what makes the cadence exhaustively testable.
  ///
  /// Silence is the default. Every branch below has to earn its message.
  static PetMessage? decide(PetEncouragementInput input) {
    // Rule 1: the hard cap. Nothing else can override it.
    if (input.messagesThisSession >=
        PetEncouragementBudget.maxMessagesPerSession) {
      return null;
    }

    // Rule 1b: nothing lands in the opening seconds of a session.
    if (input.elapsed < PetEncouragementBudget.firstMessageDelay) return null;

    // A pause is a user action, so it gets the shorter gap — but never a
    // shorter gap than the pause gap, never a free pass past the cap, and never
    // more than one comfort line per pause.
    if (input.isPaused) {
      if (input.messagesThisPause > 0) return null;
      if (input.messagesThisSession > 0 &&
          input.sinceLastMessage < PetEncouragementBudget.minGapAfterPause) {
        return null;
      }
      return _compose(PetMessageKind.pauseComfort, input);
    }

    // Every other category waits out the full silence.
    if (input.messagesThisSession > 0 &&
        input.sinceLastMessage < PetEncouragementBudget.minGapBetweenMessages) {
      return null;
    }

    final progress = input.progress;

    // The opening line: the first thing said in a session, while it is still
    // early. Gated on progress rather than on `FocusPhase.starting` because the
    // first legal moment (25 s) is already past `startingUntil` in a short
    // session — gating on the phase would silently drop the greeting there.
    if (input.messagesThisSession == 0 &&
        (progress == null || progress < PetEncouragementBudget.openingUntil)) {
      return _compose(PetMessageKind.startEncouragement, input);
    }

    // Most specific first. A line about where the session actually is beats a
    // general one: at 95% of a late-night session "就差一点，慢慢收尾" is more
    // useful than "该睡了", and the care line is still there for the gaps.
    if (progress != null) {
      if (progress > FocusPhaseSpec.deepFocusUntil) {
        return _compose(PetMessageKind.finishingSupport, input);
      }
      if (progress >= PetEncouragementBudget.midpointStart &&
          progress <= PetEncouragementBudget.midpointEnd) {
        return _compose(PetMessageKind.midpointSupport, input);
      }
    }

    // Late at night, care replaces the chatty filler.
    if (input.timeOfDay == TimeOfDayBand.lateNight) {
      return _compose(PetMessageKind.lateNightCare, input);
    }

    // The chattiest category is the one withheld from a struggling user, and it
    // is only allowed early in a session. Withholding is the right response to
    // low happiness: fewer interruptions, not more sympathy.
    if (input.happinessScore >= PetEncouragementBudget.lowHappinessThreshold &&
        input.messagesThisSession <= 1) {
      return _compose(PetMessageKind.focusCompanion, input);
    }

    return null;
  }

  /// Mochi greets a returning user.
  ///
  /// Late at night this is care rather than a greeting — the kind returned says
  /// which, so the caller never has to re-derive the policy. Not part of
  /// [decide] because it is triggered by an absence, not by session progress.
  static PetMessage greeting({
    required MochiGrowthProfile growth,
    required TimeOfDayBand timeOfDay,
  }) =>
      _compose(
        timeOfDay == TimeOfDayBand.lateNight
            ? PetMessageKind.lateNightCare
            : PetMessageKind.returnGreeting,
        PetEncouragementInput(
          isPaused: false,
          elapsed: Duration.zero,
          timeOfDay: timeOfDay,
          growth: growth,
          happinessScore: 50,
          sinceLastMessage: Duration.zero,
          messagesThisSession: 0,
        ),
      );

  /// Mochi responds to being touched.
  ///
  /// User-initiated, so it is outside the session budget entirely — it is not
  /// Mochi interrupting, it is Mochi answering.
  static PetMessage touchResponse({required MochiGrowthProfile growth}) =>
      _compose(
        PetMessageKind.petTouchResponse,
        PetEncouragementInput(
          isPaused: false,
          elapsed: Duration.zero,
          timeOfDay: TimeOfDayBand.midday,
          growth: growth,
          happinessScore: 50,
          sinceLastMessage: Duration.zero,
          messagesThisSession: 0,
        ),
      );

  /// Mochi praises a finished session.
  ///
  /// Fired once at the boundary, so it is outside the session budget.
  static PetMessage completionPraise({required MochiGrowthProfile growth}) =>
      _compose(
        PetMessageKind.completionPraise,
        PetEncouragementInput(
          isPaused: false,
          elapsed: Duration.zero,
          timeOfDay: TimeOfDayBand.midday,
          growth: growth,
          happinessScore: 50,
          sinceLastMessage: Duration.zero,
          messagesThisSession: 0,
        ),
      );

  static PetMessage _compose(
          PetMessageKind kind, PetEncouragementInput input) =>
      PetMessage(
        kind: kind,
        text: PetEncouragementCopy.forKind(kind, input.growth.stage),
      );
}

/// Owns the counters the pure engine cannot own, and nothing else.
///
/// The engine is pure; "how many messages so far", "how long since the last one"
/// and "has this pause already been acknowledged" are state. Keeping that state
/// here — instead of in a page's `State` — means the cadence can be tested as a
/// plain object, and the page's only job is to call [advance] from its existing
/// one-second tick.
///
/// **It owns no `Timer`, no vsync and no I/O.** That is the structural half of
/// "never interrupt the timer controls": there is no second clock here that
/// could race the session's own display ticker.
class PetEncouragementScheduler {
  PetMessage? _current;
  int _messagesThisSession = 0;
  int _messagesThisPause = 0;
  int _lastMessageAtSeconds = -1;
  int _shownAtSeconds = -1;
  int _lastElapsedSeconds = -1;
  bool _wasPaused = false;

  /// The message that should be on screen right now, if any.
  PetMessage? get currentMessage => _current;

  /// How many messages this session has produced. Never exceeds
  /// [PetEncouragementBudget.maxMessagesPerSession].
  int get messagesThisSession => _messagesThisSession;

  /// Clears all state, for the start of a new session.
  void reset() {
    _current = null;
    _messagesThisSession = 0;
    _messagesThisPause = 0;
    _lastMessageAtSeconds = -1;
    _shownAtSeconds = -1;
    _lastElapsedSeconds = -1;
    _wasPaused = false;
  }

  /// Advances the timeline to [elapsed] and returns what Mochi should say.
  ///
  /// ## [elapsed] must be a monotonic timeline, not the session's displayed
  /// elapsed time
  ///
  /// A paused session's displayed elapsed time **freezes** — that is correct for
  /// the timer, but it is the wrong clock here: with a frozen timeline the
  /// scheduler would keep returning the message that was already on screen, so
  /// a comfort line could never follow an opening line, and a bubble could never
  /// expire. Callers pass "how long has this session been open", which advances
  /// whether or not the user is paused.
  ///
  /// Idempotent for a given [elapsed]: calling it twice in the same second
  /// returns the same answer and cannot spend two messages. A pause that begins
  /// and ends inside one second is therefore picked up on the next tick — the
  /// tick is one second, so the delay is at most that.
  PetMessage? advance({
    required Duration elapsed,
    required bool isPaused,
    required TimeOfDayBand timeOfDay,
    required MochiGrowthProfile growth,
    required int happinessScore,
    double? progress,
  }) {
    // A new pause starts with a fresh comfort allowance.
    if (isPaused && !_wasPaused) _messagesThisPause = 0;
    _wasPaused = isPaused;

    final nowSeconds = elapsed.inSeconds;
    if (nowSeconds == _lastElapsedSeconds) return _current;
    _lastElapsedSeconds = nowSeconds;

    // An on-screen message keeps the floor until its window closes. Nothing is
    // decided while it is showing, so a message can never be replaced mid-read.
    if (_current != null) {
      if (nowSeconds - _shownAtSeconds <
          PetEncouragementBudget.displayDuration.inSeconds) {
        return _current;
      }
      _current = null;
    }

    final sinceLast = _lastMessageAtSeconds < 0
        ? Duration(seconds: nowSeconds)
        : Duration(seconds: nowSeconds - _lastMessageAtSeconds);

    final message = PetEncouragementEngine.decide(
      PetEncouragementInput(
        isPaused: isPaused,
        progress: progress,
        elapsed: elapsed,
        timeOfDay: timeOfDay,
        growth: growth,
        happinessScore: happinessScore,
        sinceLastMessage: sinceLast,
        messagesThisSession: _messagesThisSession,
        messagesThisPause: _messagesThisPause,
      ),
    );

    if (message != null) {
      _current = message;
      _shownAtSeconds = nowSeconds;
      _lastMessageAtSeconds = nowSeconds;
      _messagesThisSession++;
      if (message.kind == PetMessageKind.pauseComfort) _messagesThisPause++;
    }

    return _current;
  }
}
