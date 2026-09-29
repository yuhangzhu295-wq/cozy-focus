import 'package:flutter/widgets.dart';

import '../../controllers/pet_motion_controller.dart';
import 'companion_presentation_intent.dart';
import 'companion_visual_provider.dart';

/// The generic companion renderer.
///
/// ## What it knows, and what it deliberately does not
///
/// It knows: an intent, a visual provider, and a size. It does **not** know
/// `dog`, `cat`, `rabbit` or `fox`. There is no species parameter, no species
/// field and no species switch anywhere in this file — the provider already
/// decided how to draw. Adding a fourth companion therefore cannot require an
/// edit here, which is the extensibility contract
/// (`docs/01_..._SPEC.md` §10) made structural.
///
/// ## Ownership
///
/// It owns a [PetMotionController] when the caller does not supply one, and
/// disposes exactly what it created. Micro-motion (breathe / blink / ear / tail)
/// is a *renderer* concern, which is why it lives here rather than in the
/// director — the director schedules behaviours, the renderer animates a pose.
class CompanionRenderer extends StatefulWidget {
  final CompanionPresentationIntent intent;
  final CompanionVisualProvider provider;
  final CompanionVisualOptions options;

  const CompanionRenderer({
    super.key,
    required this.intent,
    required this.provider,
    this.options = const CompanionVisualOptions(),
  });

  @override
  State<CompanionRenderer> createState() => _CompanionRendererState();
}

class _CompanionRendererState extends State<CompanionRenderer> {
  PetMotionController? _ownedController;

  PetMotionController? get _controller =>
      widget.options.controller ?? _ownedController;

  @override
  void initState() {
    super.initState();
    if (widget.options.controller == null) {
      _ownedController = PetMotionController();
    }
  }

  @override
  void dispose() {
    // Only what this widget created. A caller-supplied controller is the
    // caller's to dispose, and disposing it here would detach a sibling.
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = CompanionVisualOptions(
      displayName: widget.options.displayName,
      size: widget.options.size,
      message: widget.options.message,
      accessory: widget.options.accessory,
      showStateBadge: widget.options.showStateBadge,
      controller: _controller,
      focusProgress: widget.options.focusProgress,
      focusCategoryId: widget.options.focusCategoryId,
      onTapReact: widget.options.onTapReact,
      onLongPressReact: widget.options.onLongPressReact,
    );

    return widget.provider.build(context, widget.intent, options);
  }
}
