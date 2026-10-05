import 'dart:async';

import 'companion_frame_source.dart';

import 'package:flutter/material.dart';

import 'companion_action_manifest.dart';

/// The one generic sprite player.
///
/// ## What it is responsible for
///
/// Precache the frames of the active sequence, present the active frame, advance
/// it at the action's own frame rate, honour Reduced Motion, stop when it is not
/// visible, and dispose its scheduling cleanly.
///
/// ## What it is deliberately not
///
/// It has no dog logic, no cat logic, no rabbit logic and no Focus business
/// logic. It is handed a [CompanionActionSpec] and draws it. Which action plays
/// is the behaviour director's decision; which *frame* plays is this widget's,
/// and the two responsibilities are never merged.
///
/// ## Why it is not a 60 fps renderer
///
/// Frames advance on a timer at the action's own rate — 3 to 8 fps for these
/// packs. A permanent per-frame renderer would burn battery to redraw an
/// unchanged drawing, and the brief forbids it.
class CompanionSpritePlayer extends StatefulWidget {
  /// The action to play.
  final CompanionActionSpec spec;

  /// Rendered box size. The square canvas is fitted inside it.
  final double size;

  /// Whether large motion must be suppressed.
  ///
  /// Reduced motion keeps the *semantic* action and holds one representative
  /// frame rather than swapping in a different action.
  final bool reducedMotion;

  /// Semantic label for assistive technology.
  final String? semanticLabel;

  /// Whether the widget may animate at all. A caller that knows the companion is
  /// off-screen or the page is inactive passes `false`.
  final bool enabled;

  /// Where the frames' bytes come from.
  ///
  /// Bundled assets by default, which is what every built-in pack uses. An
  /// installed pack passes its own directory. The player, its timing, its loop
  /// mode and its reduced-motion handling are unchanged either way - only the
  /// provider differs, which is what keeps this one player rather than two.
  final CompanionFrameSource frameSource;

  const CompanionSpritePlayer({
    super.key,
    required this.spec,
    required this.size,
    this.reducedMotion = false,
    this.semanticLabel,
    this.enabled = true,
    this.frameSource = const CompanionFrameSource.assets(),
  });

  @override
  State<CompanionSpritePlayer> createState() => _CompanionSpritePlayerState();
}

class _CompanionSpritePlayerState extends State<CompanionSpritePlayer>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _index = 0;

  /// The direction for [SpriteLoopMode.pingPong].
  int _direction = 1;

  /// The frames whose images have already been precached, so a rebuild does not
  /// re-issue every precache.
  final Set<String> _precached = {};

  bool _appActive = true;
  bool _tickerEnabled = true;

  List<String> get _frames => widget.spec.frames;

  bool get _animating =>
      widget.enabled &&
      _appActive &&
      _tickerEnabled &&
      !widget.reducedMotion &&
      _frames.length > 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode is how Flutter says "this subtree is not visible". Honouring it
    // is what stops a hidden companion from animating.
    final enabled = TickerMode.of(context);
    if (enabled != _tickerEnabled) {
      _tickerEnabled = enabled;
      _sync();
    }
    _precache();
  }

  @override
  void didUpdateWidget(covariant CompanionSpritePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new action starts from its own first frame rather than inheriting the
    // previous action's index.
    if (!identical(oldWidget.spec, widget.spec) ||
        oldWidget.spec.actionId != widget.spec.actionId) {
      _index = 0;
      _direction = 1;
      _precached.clear();
    }
    _sync();
    _precache();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A backgrounded app must not keep a timer alive. Business time is unaffected
    // — the focus clock owns that, not this widget.
    final active = state == AppLifecycleState.resumed;
    if (active != _appActive) {
      _appActive = active;
      _sync();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Starts, stops or restarts the frame timer to match the current conditions.
  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (!_animating) {
      if (widget.reducedMotion && _index != 0) {
        setState(() => _index = 0);
      }
      return;
    }
    _timer = Timer.periodic(widget.spec.frameDuration, (_) => _advance());
  }

  void _advance() {
    if (!mounted || _frames.isEmpty) return;
    final next = _nextIndex();
    if (next == _index) return;
    setState(() => _index = next);
  }

  int _nextIndex() {
    final count = _frames.length;
    switch (widget.spec.loopMode) {
      case SpriteLoopMode.loop:
        return (_index + 1) % count;
      case SpriteLoopMode.pingPong:
        if (count == 1) return 0;
        var next = _index + _direction;
        if (next >= count) {
          _direction = -1;
          next = count - 2;
        } else if (next < 0) {
          _direction = 1;
          next = 1;
        }
        return next.clamp(0, count - 1);
      case SpriteLoopMode.once:
        return _index + 1 >= count ? _index : _index + 1;
    }
  }

  /// Precaches the active sequence's frames.
  ///
  /// Only this sequence: the caller decides what else is likely next, and the
  /// brief forbids holding every frame of every action in memory at once.
  void _precache() {
    if (!mounted) return;
    for (final path in _frames) {
      if (_precached.contains(path)) continue;
      _precached.add(path);
      final provider = widget.frameSource.providerFor(path);
      precacheImage(provider, context, onError: (_, __) {
        // A missing frame must degrade to "not drawn", never to a crash. The
        // asset tests are what catch a genuinely missing file.
        _precached.remove(path);
      });
    }
  }

  /// The frame path to draw right now.
  String? get _currentFrame {
    if (_frames.isEmpty) return null;
    if (widget.reducedMotion) return widget.spec.reducedMotionFrame;
    return _frames[_index.clamp(0, _frames.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final frame = _currentFrame;
    if (frame == null) return SizedBox.square(dimension: widget.size);

    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: SizedBox.square(
        dimension: widget.size,
        child: Image(
          // The same widget for both sources: `Image.asset` is only shorthand for
          // `Image(image: AssetImage(...))`, so the built-in path is unchanged.
          image: widget.frameSource.providerFor(frame),
          fit: BoxFit.contain,
          // The canvas is identical across frames, so smoothing between frames
          // is only ever a sub-pixel resample.
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder: (_, __, ___) => SizedBox.square(dimension: widget.size),
        ),
      ),
    );
  }
}
