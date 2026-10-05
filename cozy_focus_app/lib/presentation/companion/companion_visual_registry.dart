import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mochi_visual_provider.dart';
import 'placeholder_visual_providers.dart';
import 'runtime/companion_id.dart';
import 'pack/installed_pack_profiles.dart';
import 'pack/pack_backed_visual_provider.dart';
import 'runtime/companion_visual_provider.dart';

/// The app's companion visual registry — the one place a companion is wired in.
///
/// ## Why this is the whole extension surface
///
/// `docs/01_Companion_Runtime_Architecture_SPEC.md` §10 requires that adding a
/// fourth companion needs only `pose assets + manifest/profile`. This function is
/// the "manifest/profile" half: one profile row in
/// `companion_manifest_data.dart` plus one registration here. No page, no
/// director, no generic renderer and no species switch is involved.
///
/// The registry is built fresh per avatar rather than held globally, so a test
/// can build a registry with a substitute provider and assert the renderer
/// resolves through it without touching production wiring.
CompanionVisualRegistry buildCompanionVisualRegistry() {
  final registry = CompanionVisualRegistry();
  registry.register(MochiVisualProvider(), companionId: CompanionId.dog);
  registry.register(CatVisualProvider(), companionId: CompanionId.cat);
  registry.register(RabbitVisualProvider(), companionId: CompanionId.rabbit);
  return registry;
}

/// The registry the presentation layer resolves providers from.
///
/// A provider rather than a global, so the fourth-companion contract is
/// *testable*: a test can register a brand-new companion's provider and assert
/// that a page renders it with no page edit. It also means nothing in the widget
/// tree has to know a species to obtain a drawing.
final companionVisualRegistryProvider =
    Provider<CompanionVisualRegistry>((ref) {
  final registry = buildCompanionVisualRegistry();
  // One generic provider per installed pack, from that pack's own manifest and
  // directory. Not a class per pet: a pack is data, so the registry gains a
  // companion without a new type.
  final installed = ref.watch(installedPackProfilesProvider);
  for (final entry in installed.entries) {
    registry.register(
      PackBackedCompanionVisualProvider(
        manifest: entry.value.manifest,
        frameSource: entry.value.frameSource,
      ),
      companionId: entry.key,
    );
  }
  return registry;
});
