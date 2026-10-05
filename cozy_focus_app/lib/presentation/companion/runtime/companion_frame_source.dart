/// Where a sprite frame's bytes come from.
///
/// ## Why this exists
///
/// A companion's frames are bundled assets when it ships with the app, and files
/// on disk when it was installed from a pack. The player is the same player
/// either way — the timing, the loop mode and the reduced-motion handling do not
/// change — and the only thing that differs is which `ImageProvider` resolves a
/// frame path.
///
/// So the choice lives here, in one value the player is handed, rather than in a
/// page. A page that branched on "is this a custom pet" would be the first place
/// a second rendering path appears, and the brief forbids exactly that.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';

/// Resolves a frame path to something that can be drawn.
class CompanionFrameSource {
  /// The directory frames live in, or null when they are bundled assets.
  final String? directory;

  /// Frames bundled with the app. The default, and what every built-in pack uses.
  const CompanionFrameSource.assets() : directory = null;

  /// Frames in an installed pack's directory.
  const CompanionFrameSource.directory(String this.directory);

  bool get isBundled => directory == null;

  /// The provider for [frame].
  ///
  /// The same `Image` widget draws both, so the only difference between a
  /// built-in companion and an installed one is this call.
  ImageProvider providerFor(String frame) {
    final root = directory;
    if (root == null) return AssetImage(frame);
    return FileImage(File('$root/$frame'));
  }

  @override
  String toString() => isBundled
      ? 'CompanionFrameSource(assets)'
      : 'CompanionFrameSource($directory)';
}
