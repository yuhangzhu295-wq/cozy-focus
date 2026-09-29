import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'companion_behavior_director.dart';
import 'companion_presentation_intent.dart';

/// The one presentation clock.
///
/// ## Why a single ticker
///
/// `docs/01_Companion_Runtime_Architecture_SPEC.md` §6 permits exactly one
/// presentation-layer scheduler, and §61 of the reconstruction brief asks for
/// "single presentation scheduler + AnimationController for visual
/// interpolation" rather than many independent timers. This widget is that single
/// scheduler: one [Ticker] drives the director, and the director owns every
/// timing decision. Blink, ear-twitch and every other micro-motion remain the
/// *renderer's* AnimationControllers, not extra schedulers.
///
/// ## It rebuilds only when the presented pose changes
///
/// A ticker fires every frame, but [setState] is called only when
/// [CompanionBehaviorDirector.advanceTo] reports a change. A steady pose
/// therefore costs one comparison per frame and no rebuild.
///
/// ## Lifecycle
///
/// The ticker is muted when the app is not visible and resumed on return, and it
/// is disposed with the widget. That is the whole lifecycle surface, so a leaked
/// presentation timer is not expressible here.
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

  @override
  State<CompanionPresentationClock> createState() =>
      _CompanionPresentationClockState();
}

class _CompanionPresentationClockState extends State<CompanionPresentationClock>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  /// The intent the subtree was last built for.
  ///
  /// Compared against the director's *current* intent every tick rather than
  /// against what `advanceTo` itself changed. An overlay can be triggered from a
  /// gesture between ticks, and in that case `advanceTo` sees an unchanged intent
  /// on both sides of its own call — so comparing only its return value would
  /// drop the rebuild and the overlay would never appear.
  late CompanionPresentationIntent _lastIntent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastIntent = widget.director.intent;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop scheduling while backgrounded so a resumed app never presents a
    // stale behaviour, and so no work happens off-screen.
    if (state == AppLifecycleState.resumed) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    _lastElapsed = elapsed;
    widget.director.advanceTo(elapsed);

    final intent = widget.director.intent;
    if (intent != _lastIntent) {
      _lastIntent = intent;
      widget.onIntentChanged?.call(intent);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.director.intent);
  }

  /// The last presentation time pushed into the director. For tests.
  Duration get elapsed => _lastElapsed;
}
