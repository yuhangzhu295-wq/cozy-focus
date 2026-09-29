import 'dart:convert';
import 'dart:io';

import 'package:cozy_focus_app/presentation/companion/runtime/companion_catalog.dart';

/// Loads the *shipped* manifests rather than hand-built doubles.
///
/// The runtime is data-driven, so a test that parsed a fake map would prove
/// nothing about the data the app actually ships. Reading the real files keeps
/// the manifest and the engine honest about each other.
CompanionCatalog loadShippedCatalog() {
  Map<String, dynamic> read(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  return CompanionCatalog.fromJson(
    behaviorRecipes: read('assets/companion/behavior_recipes.json'),
    companionProfiles: read('assets/companion/companion_profiles.json'),
    roomInteractionRecipes:
        read('assets/companion/room_interaction_recipes.json'),
  );
}
