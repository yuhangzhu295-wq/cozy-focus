import '../focus_phase.dart';
import 'behavior_recipe.dart';
import 'companion_action_availability.dart';
import 'companion_ambient_modifiers.dart';
import 'companion_behavior_priority.dart';
import 'companion_catalog.dart';
import 'companion_context.dart';
import 'companion_event.dart';
import 'companion_pose.dart';
import 'companion_presentation_intent.dart';
import 'companion_profile.dart';
import 'random_source.dart';

/// The single decision-maker for what the companion presents.
///
/// ## The one scheduler
///
/// `docs/01_Companion_Runtime_Architecture_SPEC.md` §6 allows exactly one
/// presentation-layer scheduler, and it decides `currentMacroBehavior`,
/// `nextBehaviorAt` and `interactionUntil`. This class is that scheduler's brain:
/// it owns no `Timer` and no `Ticker` of its own. Time is *pushed in* through
/// [advanceTo], so the same logic runs identically under a widget test, a unit
/// test and the live app — and there is exactly one place to look for a leak.
///
/// ## It is presentation, and only presentation
///
/// The director reads business truth through [CompanionContext] and writes
/// nothing back. It has no reference to a session controller, a craft
/// controller, a repository or a reward service — not by convention, but because
/// none is reachable from this file. That is what makes
/// `SECOND_BUSINESS_STATE_MACHINE = NO` structural.
///
/// ## Overlays cannot lose the base context
///
/// An overlay is stored *beside* the macro behaviour, never in place of it. The
/// macro is not cleared, not re-picked and not otherwise disturbed while an
/// overlay runs; the macro timer is merely frozen for the overlay's duration.
/// When the overlay ends, presentation returns to the same macro pose it left,
/// so `Focus + Read → TapReact → Focus + Read` is true by construction rather
/// than by a page remembering to restore something.
class CompanionBehaviorDirector {
  final CompanionCatalog catalog;
  final RandomSource random;

  CompanionContext _context;
  CompanionMacroBehavior? _macro;
  Duration? _macroEndsAt;

  CompanionOverlay _overlay = CompanionOverlay.none;
  Duration? _overlayEndsAt;

  /// The recipe slot the current macro was chosen under.
  ///
  /// When the slot changes — a phase boundary, entering pause, moving to another
  /// room anchor — the current macro is re-evaluated immediately rather than
  /// being allowed to run out its old dwell. That is what makes a phase change
  /// *visible* at the moment it happens.
  String? _macroSlot;

  Duration _now = Duration.zero;

  /// Availability per companion, resolved on demand and cached.
  ///
  /// The recipes are shared data, so the gate is what stops a companion being
  /// asked for an action it has no drawing for. Cached because it is a pure
  /// function of shipped data and re-resolving it on every pick would be work
  /// for an answer that cannot change while the app runs.
  final Map<String, CompanionActionAvailability> _availabilityCache = {};

  /// How availability is looked up. Injectable so a test can hand the director a
  /// companion with a deliberately reduced repertoire.
  final CompanionActionAvailability Function(String companionId)
      _availabilityOf;

  /// When the next overlay may start, or `null` when one may start now.
  ///
  /// Set when an overlay ends, so a rapid series of taps cannot chain reactions
  /// back to back. Stacking is already refused while one runs; this is the gap
  /// *after* it, which is what makes a second tap read as a second reaction
  /// rather than as one continuous one.
  Duration? _overlayReadyAt;

  /// The cooldown between the end of one overlay and the start of the next.
  static const Duration overlayCooldown = Duration(milliseconds: 400);

  /// When a forced celebration ends, or `null` when none is running.
  Duration? _celebrationUntil;

  /// Whether the last macro pick had to fall back because nothing in the recipe
  /// was available for this companion.
  bool _usedFallback = false;

  CompanionBehaviorDirector({
    required this.catalog,
    required CompanionContext context,
    RandomSource? random,
    CompanionActionAvailability Function(String companionId)? availabilityOf,
  })  : _context = context,
        random = random ?? SystemRandomSource(),
        _availabilityOf =
            availabilityOf ?? CompanionActionAvailabilityResolver.resolve {
    _macroSlot = _slotFor(_context);
    _pickMacro();
  }

  /// What this companion can actually be asked to play.
  CompanionActionAvailability get availability {
    final id = _context.companionId.value;
    return _availabilityCache.putIfAbsent(id, () => _availabilityOf(id));
  }

  /// Whether the current macro is a graceful degradation rather than a real
  /// pick — nothing in the recipe was available for this companion.
  ///
  /// Reported rather than hidden: a fallback is not a distinct behaviour, not a
  /// completed asset and not a passed visual gate, so a caller that wants to
  /// claim behaviour variety has to consult this first.
  bool get isUsingFallback => _usedFallback;

  /// Which claim on the companion won, right now.
  ///
  /// Derived from the state the director already holds — never stored — so it
  /// cannot drift from what is actually being presented. See
  /// [CompanionBehaviorPriority] for why the tiers are ordered as they are.
  CompanionBehaviorPriority get currentPriority {
    // A completion, whether it arrived as an event or as the completed context.
    if (isCelebrating ||
        _context.baseContext == CompanionBaseContext.complete) {
      return CompanionBehaviorPriority.critical;
    }
    // A gesture covering the macro. It outranks the macro without replacing it.
    if (_overlay.isActive) return CompanionBehaviorPriority.interaction;
    return switch (_context.baseContext) {
      CompanionBaseContext.focus ||
      CompanionBaseContext.craft ||
      CompanionBaseContext.pause ||
      CompanionBaseContext.sleep =>
        CompanionBehaviorPriority.task,
      CompanionBaseContext.home ||
      CompanionBaseContext.room =>
        CompanionBehaviorPriority.idle,
      // `complete` is handled above; listed so the switch stays exhaustive
      // rather than silently falling through if a context is added.
      CompanionBaseContext.complete => CompanionBehaviorPriority.critical,
    };
  }

  /// Whether a forced celebration is running.
  bool get isCelebrating =>
      _celebrationUntil != null && _now < _celebrationUntil!;

  /// The current business snapshot.
  CompanionContext get context => _context;

  /// The macro behaviour in force, or `null` when nothing is scheduled.
  CompanionMacroBehavior? get currentMacroBehavior => _macro;

  /// When the current macro behaviour will be re-picked.
  Duration? get nextBehaviorAt => _macroEndsAt;

  /// When the current overlay will end, or `null` when none is running.
  Duration? get interactionUntil => _overlayEndsAt;

  /// The overlay currently covering the macro behaviour.
  CompanionOverlay get overlay => _overlay;

  /// The current presentation time.
  Duration get now => _now;

  /// The profile of the companion in context.
  CompanionProfile get profile => catalog.profileFor(_context.companionId);

  String _slotFor(CompanionContext context) => CompanionCatalog.slotFor(
        context.baseContext,
        phase: context.focusPhase,
        roomAnchor: context.roomAnchor,
      );

  /// The recipe governing the current context, if any.
  BehaviorRecipe? get recipe => catalog.recipeFor(
        _context.baseContext,
        phase: _context.focusPhase,
        roomAnchor: _context.roomAnchor,
      );

  /// Pushes a new business snapshot in.
  ///
  /// Called when business state changes, not every frame. The macro is re-picked
  /// only when the recipe slot changed or the running macro became ineligible —
  /// so an unrelated rebuild (a growth tick, a happiness change) does not restart
  /// the behaviour mid-dwell.
  void updateContext(CompanionContext next) {
    _context = next;
    final slot = _slotFor(next);
    if (slot != _macroSlot) {
      _macroSlot = slot;
      _pickMacro();
      return;
    }
    if (!_contextIsGrounded && _macro != CompanionMacroBehavior.idle) {
      // The job or session ended while the same slot stayed selected. Drop the
      // now-ungrounded behaviour immediately rather than letting it finish.
      _pickMacro();
      return;
    }
    final current = _macro;
    final active = recipe;
    if (current != null && active != null && !active.allows(current)) {
      // e.g. Pause entered while a focus behaviour was running. Pause's recipe
      // does not allow focus behaviours, so this is where "Pause must not
      // schedule Focus behaviour" is enforced — as data, not as a special case.
      _pickMacro();
    }
  }

  /// Advances the presentation clock. Safe to call every frame.
  ///
  /// Returns `true` when the presented pose changed, so a scheduler can avoid
  /// redundant work without having to diff the intent itself.
  bool advanceTo(Duration now) {
    final previous = intent;
    _now = now;

    if (_overlay.isActive && _overlayEndsAt != null && now >= _overlayEndsAt!) {
      _overlay = CompanionOverlay.none;
      _overlayEndsAt = null;
      // The gap before the next overlay may start.
      _overlayReadyAt = now + overlayCooldown;
    }

    if (_celebrationUntil != null && now >= _celebrationUntil!) {
      _celebrationUntil = null;
      // Re-pick at once so the celebration hands over to the context's own
      // behaviour rather than holding the last frame until the dwell expires.
      _pickMacro();
    }

    if (_macroEndsAt != null && now >= _macroEndsAt!) {
      _pickMacro();
    }

    return intent != previous;
  }

  /// Starts a temporary overlay.
  ///
  /// Returns `true` when the overlay actually started. Refuses when one is
  /// already running, which is the anti-stacking rule from
  /// `docs/04_Behavior_Graph_SPEC.md` ("cooldown：复用/集中管理，禁止动画叠栈")
  /// expressed in one place instead of at each gesture.
  bool triggerOverlay(CompanionOverlay overlay) {
    if (!overlay.isActive) return false;
    if (_overlay.isActive) return false;
    // The cooldown after the previous overlay, so rapid taps do not chain.
    if (_overlayReadyAt != null && _now < _overlayReadyAt!) return false;
    // An overlay is an action too, so it is gated like any other: a companion
    // with no drawing for the reaction is not asked for one.
    final pose = overlay.pose;
    if (pose == null || !availability.canSchedule(pose)) return false;

    final overlayRecipe = catalog.overlayRecipeFor(overlay);
    if (overlayRecipe == null) return false;

    final duration = random.durationBetween(
      overlayRecipe.minDuration,
      overlayRecipe.maxDuration,
    );

    _overlay = overlay;
    _overlayEndsAt = _now + duration;

    // Freeze the macro for the overlay's duration so the behaviour resumes where
    // it left off rather than expiring underneath the overlay. Only meaningful
    // when a restore was requested — the manifest controls that.
    if (overlayRecipe.restorePrevious && _macroEndsAt != null) {
      _macroEndsAt = _macroEndsAt! + duration;
    }

    return true;
  }

  /// Clears any running overlay immediately.
  ///
  /// Used on lifecycle transitions (route pop, app backgrounded) so a stale
  /// overlay cannot be presented after the moment that justified it has passed.
  void clearOverlay() {
    _overlay = CompanionOverlay.none;
    _overlayEndsAt = null;
  }

  /// Feeds one presentation event in.
  ///
  /// Returns whether the presented pose changed, so a caller can avoid a
  /// redundant rebuild without diffing the intent.
  ///
  /// ## Two kinds of event, one authority
  ///
  /// A **gesture** becomes an overlay and leaves the macro untouched. A
  /// **transition** forces an immediate re-pick, so a completion or a pause is
  /// visible the moment it happens rather than up to a dwell later.
  ///
  /// Neither path is a second scheduler: both end in the same `_pickMacro` and
  /// the same `intent` getter as every other input. Events are an *input* to the
  /// one behaviour authority, not a parallel one.
  bool dispatch(CompanionEvent event) {
    final previous = intent;
    switch (event) {
      case CompanionEvent.tap:
        triggerOverlay(profile.tapOverlay);
      case CompanionEvent.longPress:
        triggerOverlay(profile.longPressOverlay);
      case CompanionEvent.focusCompleted:
        _forceCelebration();
      case CompanionEvent.focusStarted:
      case CompanionEvent.pauseStarted:
      case CompanionEvent.resumed:
      case CompanionEvent.roomActionChanged:
        // The context carrying the new state is pushed separately; the event
        // exists so the change lands now instead of at the next dwell. It also
        // releases a running celebration, because the world moved on.
        _celebrationUntil = null;
        _pickMacro();
    }
    return intent != previous;
  }

  /// Pins the macro to a celebration for one dwell.
  ///
  /// ## The hard rule
  ///
  /// A completed session always celebrates — whatever the hour, the growth
  /// stage, or any ambient weighting. The recipe layer already guarantees most
  /// of this: `complete` is excluded from `CompanionAmbientModifiers`, so no
  /// time-of-day or growth contribution can reach its pool, and its recipe lists
  /// only `celebrate`. This latch makes the guarantee independent of *when* the
  /// page gets round to pushing the completed context — the event alone is
  /// enough.
  ///
  /// It still respects availability: a companion with no celebration drawing
  /// degrades like anything else rather than being asked for art it lacks.
  void _forceCelebration() {
    const celebrate = CompanionMacroBehavior.celebrate;
    if (!availability.canSchedule(celebrate.pose)) {
      _usedFallback = true;
      _pickMacro();
      return;
    }
    final completeRecipe = catalog.recipeFor(CompanionBaseContext.complete);
    final dwell = completeRecipe == null
        ? const Duration(seconds: 8)
        : random.durationBetween(
            completeRecipe.minDuration,
            completeRecipe.maxDuration,
          );
    _celebrationUntil = _now + dwell;
    _macro = celebrate;
    _macroEndsAt = _celebrationUntil;
    _usedFallback = !availability.hasOwnDrawing(celebrate.pose);
  }

  /// Picks the next macro behaviour from the active recipe.
  void _pickMacro() {
    // A forced celebration outranks everything: it is a *moment*, not a state,
    // and it is the one behaviour the brief requires to be unconditional.
    if (isCelebrating) {
      _macro = CompanionMacroBehavior.celebrate;
      _macroEndsAt = _celebrationUntil;
      _usedFallback = !availability.hasOwnDrawing(CompanionPose.celebrate);
      return;
    }

    // Business-truth gate. A base context is a *claim* that the app is in that
    // state; the companion must not animate a state the business layer is not
    // actually in. `docs/03_互动业务流与状态闭环.md` requires craft behaviour to
    // come from a real `CraftJob`, and a focus behaviour from a real session —
    // so an ungrounded context falls back to idle rather than playing it.
    if (!_contextIsGrounded) {
      _macro = CompanionMacroBehavior.idle;
      _macroEndsAt = _now + _ungroundedDwell;
      _usedFallback = !availability.hasOwnDrawing(CompanionPose.idle);
      return;
    }

    final activeRecipe = recipe;
    if (activeRecipe == null || activeRecipe.isEmpty) {
      _macro = null;
      _macroEndsAt = null;
      _usedFallback = false;
      return;
    }

    final modifier = ambientModifier;
    final choice = _choose(activeRecipe, modifier);

    if (choice == null) {
      // Nothing this recipe offers has a drawing for this companion. Degrade to
      // idle and *say so*: a fallback is not a distinct behaviour, so a caller
      // that wants to claim variety has to consult `isUsingFallback` first.
      _usedFallback = true;
      _macro = availability.canSchedule(CompanionPose.idle)
          ? CompanionMacroBehavior.idle
          : null;
      _macroEndsAt = _now + _ungroundedDwell;
      return;
    }

    // A behaviour whose drawing is a fallback is not a distinct behaviour, so
    // it is reported rather than counted as variety.
    _usedFallback = !availability.hasOwnDrawing(choice.pose);
    _macro = choice;

    final dwell = random.durationBetween(
      activeRecipe.minDuration,
      activeRecipe.maxDuration,
    );
    _macroEndsAt = _now + _scaled(dwell, modifier.dwellScale);
  }

  /// The growth + time-of-day contribution for the current context.
  ///
  /// Both are presentation facts derived from real data — the shared growth
  /// stage and the wall clock — and neither can reach the reward economy. Task
  /// contexts get the neutral modifier, so a focus session and a craft job
  /// present identically at every stage and every hour.
  AmbientModifier get ambientModifier => CompanionAmbientModifiers.resolve(
        baseContext: _context.baseContext,
        growthStage: _context.growthStage,
        timeOfDayBand: _context.timeOfDay,
        vitals: _context.vitals,
      );

  /// Applies a dwell multiplier, never returning a non-positive duration.
  static Duration _scaled(Duration base, double scale) {
    if (scale.isNaN || scale.isInfinite || scale <= 0) return base;
    final ms = (base.inMilliseconds * scale).round();
    return Duration(milliseconds: ms < 1 ? 1 : ms);
  }

  /// How long an ungrounded context dwells before being re-evaluated.
  static const Duration _ungroundedDwell = Duration(seconds: 4);

  /// Whether the current base context is backed by real business truth.
  bool get _contextIsGrounded => switch (_context.baseContext) {
        CompanionBaseContext.craft => _context.hasActiveCraft,
        // A session is grounded when the page says one is running, or when it
        // supplied a phase. Both are real business truth; neither is inferred.
        CompanionBaseContext.focus =>
          _context.hasActiveSession || _context.focusPhase != null,
        CompanionBaseContext.home ||
        CompanionBaseContext.pause ||
        CompanionBaseContext.complete ||
        CompanionBaseContext.room ||
        CompanionBaseContext.sleep =>
          true,
      };

  /// Chooses one eligible behaviour, honouring weights, glance probability and
  /// the no-immediate-repeat rule.
  ///
  /// Returns `null` when nothing in the pool is available for this companion,
  /// which is the caller's cue to degrade and report rather than to present an
  /// action the companion has no drawing for.
  CompanionMacroBehavior? _choose(
      BehaviorRecipe recipe, AmbientModifier modifier) {
    // The ambient pool is the recipe's own list plus whatever growth and the
    // hour contribute. Additive, so a stage can never take a behaviour away.
    var pool = <CompanionMacroBehavior>[
      ...recipe.eligible,
      ...modifier.extraEligible.where((b) => !recipe.eligible.contains(b)),
    ];

    // Capability gate. The recipes are shared data across companions, so this is
    // where a companion that ships no `focus_write` sequence stops being asked
    // for one. A behaviour whose only possible drawing is a last-resort fallback
    // is not a behaviour this companion has.
    pool = pool
        .where((behavior) => availability.canSchedule(behavior.pose))
        .toList(growable: false);
    if (pool.isEmpty) return null;

    // No immediate repeat. Skipped when the pool would become empty, otherwise a
    // single-behaviour recipe (craft, celebrate, sleep) could never pick again
    // and the companion would freeze.
    if (recipe.noImmediateRepeat && _macro != null && pool.length > 1) {
      final filtered =
          pool.where((behavior) => behavior != _macro).toList(growable: false);
      if (filtered.isNotEmpty) pool = filtered;
    }

    // Glance is a modifier rather than a pool member in deep focus, so it is
    // rolled before the weighted pick. It is never allowed to repeat back to
    // back, which would read as a twitch rather than as a glance — and it is
    // gated like any other behaviour, so a companion with no glance drawing is
    // never rolled into one.
    if (recipe.glanceProbability > 0 &&
        _macro != CompanionMacroBehavior.glance &&
        availability.canSchedule(CompanionMacroBehavior.glance.pose) &&
        random.nextDouble() < recipe.glanceProbability) {
      return CompanionMacroBehavior.glance;
    }

    final weights = profile.behaviorWeights;
    var total = 0.0;
    for (final behavior in pool) {
      total += weights[behavior.id] ?? 1.0;
    }
    if (total <= 0) return pool.first;

    var roll = random.nextDouble() * total;
    for (final behavior in pool) {
      roll -= weights[behavior.id] ?? 1.0;
      if (roll <= 0) return behavior;
    }
    return pool.last;
  }

  /// The current presentation intent.
  ///
  /// The overlay's pose wins when one is running; otherwise the macro's pose. The
  /// base context and the macro behaviour are reported unchanged either way, which
  /// is what lets a caller (or a test) see what the overlay is covering.
  CompanionPresentationIntent get intent {
    final activeOverlay = _overlay;
    final pose = activeOverlay.isActive
        ? activeOverlay.pose!
        : (_macro?.pose ?? CompanionPose.idle);

    return CompanionPresentationIntent(
      companionId: _context.companionId,
      pose: pose,
      macroBehavior: _macro,
      baseContext: _context.baseContext,
      overlay: activeOverlay,
      isOverlayActive: activeOverlay.isActive,
      microMotion: profile.microMotion,
      reducedMotion: _context.reducedMotion,
      roomAnchor: _context.roomAnchor,
      timeOfDay: _context.timeOfDay,
      focusProgress: _context.focusProgress,
      craftProgress: _context.craftProgress,
    );
  }

  /// Convenience: the pose that would be presented right now.
  CompanionPose get pose => intent.pose;

  /// The focus phase the current behaviour was chosen under.
  FocusPhase? get focusPhase => _context.focusPhase;

  @override
  String toString() =>
      'CompanionBehaviorDirector(${_context.companionId.value} '
      'macro=${_macro?.id ?? '-'} overlay=${_overlay.id} now=${_now.inMilliseconds}ms)';
}
