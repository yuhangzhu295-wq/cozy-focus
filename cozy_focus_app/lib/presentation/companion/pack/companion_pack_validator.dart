/// Strict validation for a companion pack that came from outside the app.
///
/// `CompanionActionManifest.fromJson` is deliberately **lenient** — it defaults a
/// missing canvas, missing anchors and an unknown loop mode — because it reads
/// data compiled into the build by us. That leniency is right there and wrong
/// here. A pack a user imports is untrusted input, and "the parser accepted it"
/// is not "the pack is valid"; it is only "the parser did not have to guess quite
/// as much". So validation is a separate, strict step that refuses rather than
/// filling in defaults.
///
/// It does not unzip, decode PNGs or touch the filesystem. It is handed the
/// pack's relative paths and the manifest's own claims, which keeps the
/// security-relevant judgement testable without an archive library and keeps path
/// handling in one place.
library;

/// One reason a pack was refused.
class PackViolation {
  /// A stable code, so a caller can branch without matching prose.
  final String code;

  /// What was wrong, naming the offending value.
  final String detail;

  const PackViolation(this.code, this.detail);

  @override
  String toString() => '$code: $detail';
}

/// The outcome of validating one pack.
class PackValidationResult {
  final List<PackViolation> violations;

  const PackValidationResult(this.violations);

  bool get ok => violations.isEmpty;

  List<String> get codes => [for (final v in violations) v.code];

  @override
  String toString() => ok
      ? 'PackValidationResult(ok)'
      : 'PackValidationResult(${violations.length}): '
          '${violations.join('; ')}';
}

/// Validates a pack manifest against the files the pack actually contains.
abstract final class CompanionPackValidator {
  const CompanionPackValidator._();

  /// The loop modes the runtime can play. An unknown one is refused rather than
  /// defaulted, because defaulting silently changes how a pack animates.
  static const Set<String> loopModes = {'loop', 'pingpong', 'once'};

  /// The smallest canvas the runtime can place.
  static const int minCanvas = 64;

  /// Every action must carry at least this many frames. One frame is a still
  /// image, not an animation, and the player advances by frame index.
  static const int minFramesPerAction = 2;

  /// Validates [manifest] against [availableFiles].
  ///
  /// [availableFiles] are the pack's relative paths as extracted. [expectedId] is
  /// the id the caller intends to install under, when it has one; the manifest
  /// must agree, or the pack would register under one id and render from another.
  static PackValidationResult validate({
    required Map<String, dynamic> manifest,
    required Set<String> availableFiles,
    String? expectedId,
  }) {
    final problems = <PackViolation>[];
    void reject(String code, String detail) =>
        problems.add(PackViolation(code, detail));

    final companionId = manifest['companionId'];
    if (companionId is! String || companionId.trim().isEmpty) {
      reject('missing_companion_id', 'companionId is absent or empty');
    } else if (expectedId != null && companionId != expectedId) {
      reject(
          'companion_id_mismatch',
          'manifest says "$companionId" but the pack is being installed as '
              '"$expectedId"');
    }

    final width = manifest['canvasWidth'];
    final height = manifest['canvasHeight'];
    if (width is! int || height is! int) {
      reject(
          'missing_canvas', 'canvasWidth/canvasHeight must both be integers');
    } else if (width < minCanvas || height < minCanvas) {
      reject('canvas_too_small', '${width}x$height is below ${minCanvas}px');
    }

    final baseline = manifest['groundBaseline'];
    final centre = manifest['centerAnchor'];
    if (baseline is! int || centre is! int) {
      reject('missing_anchors',
          'groundBaseline/centerAnchor must both be integers');
    } else if (height is int && width is int) {
      if (baseline < 0 || baseline > height) {
        reject('baseline_out_of_canvas',
            'groundBaseline $baseline is outside a canvas of height $height');
      }
      if (centre < 0 || centre > width) {
        reject('centre_out_of_canvas',
            'centerAnchor $centre is outside a canvas of width $width');
      }
    }

    final actions = manifest['actions'];
    if (actions is! Map || actions.isEmpty) {
      reject('no_actions', 'the pack declares no actions at all');
      return PackValidationResult(problems);
    }

    final actionIds = <String>{};
    for (final entry in actions.entries) {
      final id = entry.key as String;
      final spec = entry.value;
      actionIds.add(id);

      if (spec is! Map) {
        reject('action_not_a_map', 'action "$id" is not an object');
        continue;
      }

      final frames = spec['frames'];
      if (frames is! List || frames.isEmpty) {
        reject('action_without_frames', 'action "$id" lists no frames');
      } else {
        if (frames.length < minFramesPerAction) {
          reject(
              'action_too_short',
              'action "$id" has ${frames.length} frame(s); a still image is not '
                  'an animation');
        }
        final seen = <String>{};
        for (final frame in frames) {
          if (frame is! String || frame.trim().isEmpty) {
            reject('invalid_frame_path', 'action "$id" has a non-string frame');
            continue;
          }
          final unsafe = unsafePathReason(frame);
          if (unsafe != null) {
            reject('unsafe_frame_path', 'action "$id" frame "$frame": $unsafe');
            continue;
          }
          if (!availableFiles.contains(frame)) {
            reject(
                'missing_frame_file',
                'action "$id" references "$frame", which the pack does not '
                    'contain');
          }
          if (!seen.add(frame)) {
            reject('duplicate_frame',
                'action "$id" lists "$frame" more than once');
          }
        }
      }

      final fps = spec['fps'];
      if (fps is! int || fps <= 0) {
        reject('invalid_fps', 'action "$id" has fps "$fps"');
      }

      final loopMode = spec['loopMode'];
      if (loopMode is! String || !loopModes.contains(loopMode)) {
        reject(
            'unknown_loop_mode',
            'action "$id" has loopMode "$loopMode"; the runtime plays '
                '${loopModes.join(', ')}');
      }
    }

    // A decodable idle is the minimum. The director hands an ungrounded context
    // `idle` even when availability does not list it, so a pack without one
    // fails in a way that looks like a rendering bug rather than a missing
    // action.
    final idle = actions['idle'];
    if (idle is! Map) {
      reject('no_idle', 'a pack must ship an idle action to be installable');
    } else if (idle['frames'] is! List ||
        (idle['frames'] as List).length < minFramesPerAction) {
      reject('idle_too_short',
          'idle must carry at least $minFramesPerAction frames to be animated');
    }

    // A fallback that points nowhere is a promise the pack cannot keep.
    for (final key in const ['semanticFallback', 'drawAliases']) {
      final table = manifest[key];
      if (table == null) continue;
      if (table is! Map) {
        reject('invalid_$key', '$key must be an object');
        continue;
      }
      for (final entry in table.entries) {
        final target = entry.value;
        if (target is! String || !actionIds.contains(target)) {
          reject(
              'dangling_$key',
              '$key["${entry.key}"] points at "$target", which is not an action '
                  'in this pack');
        }
      }
    }

    return PackValidationResult(problems);
  }

  /// Why [path] may not be used, or null when it is safe.
  ///
  /// Relative, inside the pack, not a directory escape. A pack naming
  /// `../../something` is reaching outside the sandbox it was extracted into, and
  /// the answer is to refuse the pack rather than sanitise the path and hope.
  static String? unsafePathReason(String path) {
    if (path.startsWith('/') || path.startsWith('\\')) {
      return 'absolute path';
    }
    if (RegExp(r'^[A-Za-z]:').hasMatch(path)) {
      return 'absolute path (drive letter)';
    }
    if (path.split(RegExp(r'[/\\]')).contains('..')) {
      return 'directory escape';
    }
    if (path.contains('\u0000')) return 'null byte';
    return null;
  }
}
