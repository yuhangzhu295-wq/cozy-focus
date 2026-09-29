import 'dart:async';

import 'package:flutter/widgets.dart';

import 'companion_behavior_director.dart';
import 'companion_presentation_intent.dart';

/// The one presentation scheduler.
///
/// ## Why a low-rate timer rather than a per-frame ticker
///
/// `docs/01_Companion_Runtime_Architecture_SPEC.md` §6 permits exactly one
/// presentation-layer scheduler, and §61 of the reconstruction brief asks for
/// "single presentation scheduler + AnimationController for visual
/// interpolation" rather than many independent timers.
///
/// A `Ticker` would also satisfy "one scheduler", but it registers a transient
/// frame callback for as long as it runs, which means the engine is asked for a
/// frame **every vsync forever** — an idle companion would keep the app from ever
/// settling. For an app whose whole purpose is to sit quietly beside a focus
/// timer, that is a real battery cost for no visual benefit.
///
/// The director's decisions are seconds-scale: a behaviour dwells for 8–30s and
/// an overlay lasts 0.6–2.5s. [tickInterval] is therefore a quarter of a second —
/// fine enough that a behaviour change or an overlay ending is imperceptible, and
/// roughly sixty times cheaper than a frame callback. Frame-rate interpolation
/// stays where it belongs: the renderer's own AnimationControllers.
///
/// ## It rebuilds only when the presented pose changes
///
/// The intent is compared on every tick, but [setState] runs only when it
/// actually changed. A steady pose therefore costs one comparison per tick and no
/// rebuild.
///
/// ## Lifecycle
///
/// The timer and its stopwatch stop when the app is not visible and restart on
/// return, so backgrounded time never advances a behaviour — a resumed app shows
/// the companion mid-behaviour rather than having silently skipped several. Both
/// are released with the widget, so a leaked presentation timer is not
/// expressible here.
class CompanionPresentationClock extends StatefulWidget {
  final CompanionBehaviorDirector director;

  /// Builds the subtree for the current intent.
  final Widget Function(
      BuildContext context, CompanionPresentationIntent intent) builder;

  /// Invoked when the presented pose changes, for diagnostics and tests.
  final ValueChanged<CompanionPresentationIntent>? onIntentChanged;

  const CompanionPresentationClock({
    super.key,
    required this.director,
    required this.builder,
    this.onIntentChanged,
  });

  /// How often the director is asked to re-evaluate.
  ///
  /// See the class docs for why this is not a frame callback.
  static const Duration tickInterval = Duration(milliseconds: 250);

  @override
  State<CompanionPresentationClock> createState() =>
      _CompanionPresentationClockState();
}

class _CompanionPresentationClockState extends State<CompanionPresentationClock>
    with WidgetsBindingObserver {
  Timer? _timer;

  /// Presentation time accumulated from ticks.
  ///
  /// Deliberately an accumulator rather than a `Stopwatch`: a stopwatch reads
  /// wall-clock time, which a widget test's fake clock does not advance, so a
  /// stopwatch would make every timing behaviour untestable. Accumulating the
  /// tick keeps the director's clock honest under `pump()` and is accurate enough
  /// for decisions that are seconds apart. Backgrounded time never accumulates,
  /// because the timer is cancelled while the app is not visible.
  Duration _elapsed = Duration.zero;

  /// The intent the subtree was last built for.
  ///
  /// Compared against the director's *current* intent on every tick rather than
  /// against what `advanceTo` itself changed. An overlay can be triggered from a
  /// gesture between ticks, and in that case `advanceTo` sees an unchanged intent
  /// on both sides of its own call — so comparing only its return value would
  /// drop the rebuild and the overlay would never appear.
  late CompanionPresentationIntent _lastIntent;

  /// The last presentation time pushed into the director. For tests.
  Duration get elapsed => _elapsed;

  /// Whether the scheduler is currently running. For tests.
  bool get isRunning => _timer != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastIntent = widget.director.intent;
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
      // Re-render at once rather than waiting out a tick, so a resumed app never
      // shows a stale pose. No time is added: being hidden is not presentation
      // time.
      _render();
    } else {
      _stop();
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(CompanionPresentationClock.tickInterval, (_) {
      _elapsed += CompanionPresentationClock.tickInterval;
      _evaluate();
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Re-renders the current intent without advancing the clock.
  ///
  /// Used on resume, where no presentation time has passed but the tree may be
  /// showing a pose from before the app was hidden.
  void _render() {
    final intent = widget.director.intent;
    if (intent != _lastIntent) {
      _lastIntent = intent;
      widget.onIntentChanged?.call(intent);
      if (mounted) setState(() {});
    }
  }

  /// Advances the director to the current presentation time and re-renders.
  void _evaluate() {
    widget.director.advanceTo(_elapsed);
    _render();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.director.intent);
  }
}
