import '../focus_phase.dart';
import 'behavior_recipe.dart';
import 'companion_catalog.dart';
import 'companion_context.dart';
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

  CompanionBehaviorDirector({
    required this.catalog,
    required CompanionContext context,
    RandomSource? random,
  })  : _context = context,
        random = random ?? SystemRandomSource() {
    _macroSlot = _slotFor(_context);
    _pickMacro();
  }

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

  /// Picks the next macro behaviour from the active recipe.
  void _pickMacro() {
    // Business-truth gate. A base context is a *claim* that the app is in that
    // state; the companion must not animate a state the business layer is not
    // actually in. `docs/03_互动业务流与状态闭环.md` requires craft behaviour to
    // come from a real `CraftJob`, and a focus behaviour from a real session —
    // so an ungrounded context falls back to idle rather than playing it.
    if (!_contextIsGrounded) {
      _macro = CompanionMacroBehavior.idle;
      _macroEndsAt = _now + _ungroundedDwell;
      return;
    }

    final activeRecipe = recipe;
    if (activeRecipe == null || activeRecipe.isEmpty) {
      _macro = null;
      _macroEndsAt = null;
      return;
    }

    final chosen = _choose(activeRecipe);
    _macro = chosen;
    _macroEndsAt = _now +
        random.durationBetween(
          activeRecipe.minDuration,
          activeRecipe.maxDuration,
        );
  }

  /// How long an ungrounded context dwells before being re-evaluated.
  static const Duration _ungroundedDwell = Duration(seconds: 4);

  /// Whether the current base context is backed by real business truth.
  bool get _contextIsGrounded => switch (_context.baseContext) {
        CompanionBaseContext.craft => _context.hasActiveCraft,
        CompanionBaseContext.focus => _context.hasActiveSession,
        CompanionBaseContext.home ||
        CompanionBaseContext.pause ||
        CompanionBaseContext.complete ||
        CompanionBaseContext.room ||
        CompanionBaseContext.sleep =>
          true,
      };

  /// Chooses one eligible behaviour, honouring weights, glance probability and
  /// the no-immediate-repeat rule.
  CompanionMacroBehavior _choose(BehaviorRecipe recipe) {
    var pool = recipe.eligible;

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
    // back, which would read as a twitch rather than as a glance.
    if (recipe.glanceProbability > 0 &&
        _macro != CompanionMacroBehavior.glance &&
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
