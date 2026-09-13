import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import '../../domain/models/enums.dart';
import 'pet_idle_fallback_view.dart';

/// Abstract contract for Pet Rive animation rendering.
/// Business controllers never manipulate Rive StateMachineController or Artboards directly.
abstract class IPetRiveRenderer {
  Widget buildRiveWidget({
    required PetVisualState visualState,
    required double width,
    required double height,
    required BoxFit fit,
    void Function(Artboard)? onInit,
    Widget? fallback,
  });
}

/// Default RivePetAdapter implementation.
/// Truthfully attempts to load the Rive asset; when the asset is absent or
/// initialization fails, gracefully renders [fallback] (the Flutter Mochi fallback),
/// ensuring the UI never crashes, blanks, or hangs in an infinite loading state.
class RivePetAdapter implements IPetRiveRenderer {
  final String assetPath;
  final String stateMachineName;

  const RivePetAdapter({
    this.assetPath = 'assets/animations/mochi.riv',
    this.stateMachineName = 'State Machine 1',
  });

  @override
  Widget buildRiveWidget({
    required PetVisualState visualState,
    required double width,
    required double height,
    required BoxFit fit,
    void Function(Artboard)? onInit,
    Widget? fallback,
  }) {
    return _RivePetAssetLoader(
      assetPath: assetPath,
      stateMachineName: stateMachineName,
      visualState: visualState,
      width: width,
      height: height,
      fit: fit,
      onInit: onInit,
      fallback: fallback,
    );
  }
}

class _RivePetAssetLoader extends StatefulWidget {
  final String assetPath;
  final String stateMachineName;
  final PetVisualState visualState;
  final double width;
  final double height;
  final BoxFit fit;
  final void Function(Artboard)? onInit;
  final Widget? fallback;

  const _RivePetAssetLoader({
    required this.assetPath,
    required this.stateMachineName,
    required this.visualState,
    required this.width,
    required this.height,
    required this.fit,
    this.onInit,
    this.fallback,
  });

  @override
  State<_RivePetAssetLoader> createState() => _RivePetAssetLoaderState();
}

class _RivePetAssetLoaderState extends State<_RivePetAssetLoader> {
  Future<RiveFile?>? _loadFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFuture ??= _loadAsset();
  }

  @override
  void didUpdateWidget(covariant _RivePetAssetLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _loadFuture = _loadAsset();
    }
  }

  Future<RiveFile?> _loadAsset() async {
    try {
      final bundle = DefaultAssetBundle.of(context);
      return await RiveFile.asset(widget.assetPath, bundle: bundle);
    } catch (_) {
      // Asset is absent or failed initialization. Fall back gracefully.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveFallback = widget.fallback ??
        PetIdleFallbackView(
          visualState: widget.visualState,
          size: widget.width,
        );

    return FutureBuilder<RiveFile?>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError &&
            snapshot.data != null) {
          final riveFile = snapshot.data!;
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: RiveAnimation.direct(
              riveFile,
              fit: widget.fit,
              stateMachines: [widget.stateMachineName],
              onInit: widget.onInit,
              placeHolder: effectiveFallback,
            ),
          );
        }

        return effectiveFallback;
      },
    );
  }
}
