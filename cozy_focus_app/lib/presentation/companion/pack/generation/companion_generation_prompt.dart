/// What would be sent to a generation provider, and why it is shaped this way.
///
/// ## The player's sentence is not the prompt
///
/// A request carries free text — "a sleepy grey cat who likes rain". If that were
/// the whole prompt, the provider would be free to invent the canvas, the
/// anchors, the action names and the frame counts, and the result would be a
/// pack that cannot be installed. So the template states the contract around the
/// player's words: this canvas, these anchors, this action vocabulary, this many
/// frames, this file layout.
///
/// The vocabulary and the frame counts are read from the app's own production
/// contract rather than written here, so a prompt cannot promise a companion the
/// app has no way to play.
///
/// ## It is not sent to anyone
///
/// No provider is configured. This exists so that when one is, the contract is
/// already written down and reviewed rather than improvised at the call site.
library;

import '../../animation/sprite_animation_manifest_data.dart';
import '../../runtime/companion_action_manifest_data.dart';
import 'companion_generation_contract.dart';

/// One block of the prompt, kept separate so a caller can log or test a piece
/// without asserting on a wall of prose.
class CompanionGenerationPrompt {
  /// The instruction to the model.
  final String instruction;

  /// The player's own words, verbatim.
  final String description;

  /// The technical contract, as text.
  final String contract;

  const CompanionGenerationPrompt({
    required this.instruction,
    required this.description,
    required this.contract,
  });

  /// The whole prompt, in the order a reader would want it.
  String get text => '$instruction\n\n$contract\n\nSubject: $description';

  /// The prompt for [request].
  static CompanionGenerationPrompt forRequest(
    CompanionGenerationRequest request,
  ) {
    final vocabulary = SpriteAnimationManifestData.productionActionIds.toList()
      ..sort();
    final targets = <String>[];
    for (final action in vocabulary) {
      final frames = _frameTarget(action);
      targets.add(frames == null ? action : '$action ($frames frames)');
    }

    return CompanionGenerationPrompt(
      instruction:
          'Create a sprite sheet set for a small 2D cartoon companion animal. '
          'Flat-shaded cartoon art, soft rounded shapes, no outlines heavier '
          'than 3px, transparent background. The character must be drawn on the '
          'same rig and scale in every frame of an action so it does not jitter.',
      description: request.description.trim(),
      contract: [
        'Technical contract:',
        '- Canvas: exactly 512x512 pixels per frame, PNG, transparent '
            'background.',
        '- The character\'s ground contact line (the bottom of its feet) must '
            'sit at y=458 in every frame.',
        '- The character\'s horizontal centre must sit at x=255 in every frame.',
        '- Species: ${request.species}.',
        '- Actions to produce: ${request.actions.toList()..sort()}.',
        '- Each action needs at least two distinct frames; a single frame is a '
            'still image, not an animation.',
        '- One PNG file per frame, named "<action>_<index>.png" with a '
            'three-digit index starting at 000.',
        '- Every frame must be visibly different from every other frame in its '
            'action. Duplicated frames are rejected.',
        '- Actions the app knows, with their frame counts, for reference: '
            '${targets.join(', ')}.',
        '- Do not produce frames for actions that were not requested.',
      ].join('\n'),
    );
  }

  /// The app's declared frame count for [action], or null when it has none.
  static int? _frameTarget(String action) {
    for (final contract in SpriteAnimationManifestData.byCompanion.values) {
      final asset = contract.assets[action];
      if (asset != null) return asset.targetFrameCount;
    }
    return null;
  }
}

/// The action vocabulary a generated pack may declare.
///
/// Exposed so a caller can offer a choice without reaching into the animation
/// data, and so a test can assert the two agree.
Set<String> get generationActionVocabulary {
  final declared =
      CompanionActionManifestData.manifests.values.expand((m) => m.actionIds);
  return {...declared, ...SpriteAnimationManifestData.productionActionIds};
}
