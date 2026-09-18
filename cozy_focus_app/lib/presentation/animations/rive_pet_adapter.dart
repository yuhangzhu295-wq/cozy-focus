import 'package:flutter/material.dart';

import '../../domain/models/enums.dart';
import 'pet_idle_fallback_view.dart';

/// Renderer-neutral extension point for a future optional companion renderer.
///
/// Android V1 deliberately ships the Flutter fallback renderer. This contract
/// preserves presentation inputs without importing an optional renderer SDK or
/// allowing widgets to manipulate renderer-specific state.
abstract class IPetRiveRenderer {
  Widget buildRiveWidget({
    required PetVisualState visualState,
    required double width,
    required double height,
    required BoxFit fit,
    double? focusProgress,
    double? craftProgress,
    Widget? fallback,
  });
}

/// Historical compatibility adapter.
///
/// Rive is not an Android V1 release dependency, so this adapter always
/// renders the supplied Flutter fallback. Keeping the adapter allows an
/// optional renderer to be introduced later without changing business callers.
class RivePetAdapter implements IPetRiveRenderer {
  const RivePetAdapter();

  @override
  Widget buildRiveWidget({
    required PetVisualState visualState,
    required double width,
    required double height,
    required BoxFit fit,
    double? focusProgress,
    double? craftProgress,
    Widget? fallback,
  }) {
    return fallback ??
        PetIdleFallbackView(
          visualState: visualState,
          size: width,
          focusProgress: focusProgress,
          craftProgress: craftProgress,
        );
  }
}
