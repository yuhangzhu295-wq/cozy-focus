import 'mochi_visual_provider.dart';
import 'placeholder_visual_providers.dart';
import 'runtime/companion_id.dart';
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
