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

  /// The action this is about, when the violation is about one.
  ///
  /// The prose a person reads is chosen by [code] alone, and for the action
  /// codes that sentence is the same whichever action it is about — so a pack
  /// with thirteen malformed actions produced thirteen copies of one sentence
  /// naming nothing. Carrying the id here lets the message say which action.
  final String? actionId;

  const PackViolation(this.code, this.detail, {this.actionId});

  @override
  String toString() =>
      actionId == null ? '$code: $detail' : '$code [action $actionId]: $detail';
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

  /// The most frames one action may carry.
  ///
  /// A memory bound, and the reason it belongs here rather than in the player:
  /// the player precaches the *active sequence* in full, deliberately, so that an
  /// animation does not stutter while its frames decode. That is fine for a
  /// companion animation and not fine for an action that declares thousands of
  /// frames — the archive policy allows 4096 entries, and at 512x512 RGBA each
  /// decoded frame is about a megabyte, so an unbounded action is a pack that
  /// exhausts memory by being well formed.
  ///
  /// 64 is generous rather than tight: the shipped packs use between two and six
  /// frames per action, and at 8fps 64 frames is an eight-second animation.
  static const int maxFramesPerAction = 64;

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

    // The runtime needs this and the validator used not to ask for it.
    //
    // `InstalledPackProfiles` drops a pack whose manifest declares no `posePack`
    // (`if (manifest.posePack.isEmpty) return null;`) because the visual registry
    // keys its providers by that string. Validating everything else and not this
    // let a pack pass import, install, and become the selection — and then be
    // dropped on the next load. The companion list showed nothing selected and
    // the companion itself was nowhere, which is what a device walk found.
    final posePack = manifest['posePack'];
    if (posePack is! String || posePack.trim().isEmpty) {
      reject(
          'missing_pose_pack',
          'posePack is absent or empty; the runtime cannot look up a provider '
              'for this pack without it');
    } else if (!isSafePackId(posePack)) {
      reject(
          'unsafe_pose_pack', 'posePack "$posePack" cannot be a provider key');
    }

    // The nested shape, because it is the one the runtime already parses
    // (`CompanionActionManifest.fromJson`) and the one the shipped packs use. An
    // earlier version of this file invented top-level `canvasWidth`/`canvasHeight`
    // - a parallel format by another name, and exactly what the brief forbids.
    final canvas = manifest['canvas'];
    final width = canvas is Map ? canvas['width'] : null;
    final height = canvas is Map ? canvas['height'] : null;
    if (width is! int || height is! int) {
      reject('missing_canvas',
          'canvas must be an object with integer width and height');
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
      // Every refusal from here to the end of this iteration is about
      // this action, so the message can name it.
      void rejectAction(String code, String detail) =>
          problems.add(PackViolation(code, detail, actionId: id));

      if (spec is! Map) {
        rejectAction('action_not_a_map', 'action "$id" is not an object');
        continue;
      }

      final frames = spec['frames'];
      if (frames is! List || frames.isEmpty) {
        rejectAction('action_without_frames', 'action "$id" lists no frames');
      } else {
        if (frames.length < minFramesPerAction) {
          rejectAction(
              'action_too_short',
              'action "$id" has ${frames.length} frame(s); a still image is not '
                  'an animation');
        }
        if (frames.length > maxFramesPerAction) {
          // Refused rather than trimmed: the player holds a whole sequence in
          // memory, so accepting this would install a pack that can exhaust it.
          rejectAction(
              'action_too_long',
              'action "$id" has ${frames.length} frames, above the '
                  '$maxFramesPerAction a sequence may carry');
        }
        final seen = <String>{};
        for (final frame in frames) {
          if (frame is! String || frame.trim().isEmpty) {
            rejectAction(
                'invalid_frame_path', 'action "$id" has a non-string frame');
            continue;
          }
          final unsafe = unsafePathReason(frame);
          if (unsafe != null) {
            rejectAction(
                'unsafe_frame_path', 'action "$id" frame "$frame": $unsafe');
            continue;
          }
          if (!availableFiles.contains(frame)) {
            rejectAction(
                'missing_frame_file',
                'action "$id" references "$frame", which the pack does not '
                    'contain');
          }
          if (!seen.add(frame)) {
            rejectAction('duplicate_frame',
                'action "$id" lists "$frame" more than once');
          }
        }
      }

      final fps = spec['fps'];
      if (fps is! int || fps <= 0) {
        rejectAction('invalid_fps', 'action "$id" has fps "$fps"');
      }

      final loopMode = spec['loopMode'];
      if (loopMode is! String || !loopModes.contains(loopMode)) {
        rejectAction(
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

  /// Whether [id] can be used as a pack id, a directory name and a provider key.
  ///
  /// One implementation, here, because this file is the leaf both callers can
  /// read: `CompanionPackInstallRules` delegates to it. Two copies of a rule
  /// like this is how the validator and the loader came to disagree about
  /// `posePack` in the first place.
  static bool isSafePackId(String id) =>
      RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(id);
}
