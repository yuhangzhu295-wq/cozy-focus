import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/presentation/companion/companion_avatar.dart';
import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/companion_visual_registry.dart';
import 'package:cozy_focus_app/presentation/companion/mochi_pose_prop.dart';
import 'package:cozy_focus_app/presentation/companion/mochi_pose_spec.dart';
import 'package:cozy_focus_app/presentation/companion/placeholder_visual_providers.dart';
import 'package:cozy_focus_app/presentation/companion/procedural_companion_art.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_asset_resolver.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_behavior_director.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_manifest_data.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_presentation_intent.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_profile.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_visual_provider.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/random_source.dart';
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// A TEST-ONLY fourth companion.
//
// This is architecture proof, not production artwork. Everything a new
// companion needs is here and nowhere else: one profile, one pose pack (visual
// provider) and one registration. If the runtime were still coupled to a
// species, this file could not exist without editing production code.
// ---------------------------------------------------------------------------

const _foxId = CompanionId('fox');

const _foxProfile = CompanionProfile(
  id: _foxId,
  displayName: '小狐',
  posePack: 'fox',
  tagline: 'TEST-ONLY companion used to prove the fourth-companion contract.',
  traits: ['测试'],
  runtimeAssetsAvailable: false,
  microMotion: ['breathe', 'blink', 'ear_flick'],
  behaviorWeights: {
    'focus_read': 0.34,
    'focus_write': 0.33,
    'focus_think': 0.33,
  },
  roomAnchors: {
    'seat': CompanionMacroBehavior.roomSit,
    'lie': CompanionMacroBehavior.roomSleep,
    'front': CompanionMacroBehavior.roomRead,
    'work': CompanionMacroBehavior.roomWork,
  },
);

/// The fox's pose pack. Distinct ears and a bushy tail, so it is visibly not a
/// cat, a rabbit or a dog.
const _foxSilhouette = CompanionSilhouette(
  earShape: CompanionEarShape.triangle,
  earLength: 0.78,
  earSplay: 0.52,
  hasWhiskers: false,
  tail: CompanionTailShape.slenderCurve,
  furColor: Color(0xFFF0C9A0),
  innerEarColor: Color(0xFFE7A98F),
);

class FoxVisualProvider extends CompanionVisualProvider {
  FoxVisualProvider();

  @override
  String get posePackId => 'fox';

  @override
  Set<CompanionPose> get productionPoses => const <CompanionPose>{};

  @override
  Widget build(
    BuildContext context,
    CompanionPresentationIntent intent,
    CompanionVisualOptions options,
  ) =>
      PlaceholderCompanionAvatar(
        silhouette: _foxSilhouette,
        intent: intent,
        options: options,
        poseSpec: MochiPoseSpecs.of(intent.pose),
      );
}

/// The catalog with the fox added: the existing data plus one profile row.
CompanionCatalog catalogWithFox() => CompanionCatalog(
      profiles: {...CompanionManifestData.profiles, _foxId: _foxProfile},
      contextRecipes: CompanionManifestData.contextRecipes
          .map((context, slots) => MapEntry(context.id, slots)),
      overlayRecipes: CompanionManifestData.overlayRecipes
          .map((overlay, recipe) => MapEntry(overlay.id, recipe)),
      roomRecipes: CompanionManifestData.roomRecipes,
      defaultProfileId: CompanionManifestData.defaultProfileId,
    );

CompanionVisualRegistry registryWithFox() {
  final registry = buildCompanionVisualRegistry();
  registry.register(FoxVisualProvider(), companionId: _foxId);
  return registry;
}

class _PresetHomeController extends HomeController {
  final HomeUIState _preset;
  _PresetHomeController(super.ref, this._preset);

  @override
  Future<void> loadHomeData() async {
    state = _preset;
  }
}

void main() {
  group('the shared director accepts a companion it has never heard of', () {
    test('it schedules behaviours for the fox', () {
      final director = CompanionBehaviorDirector(
        catalog: catalogWithFox(),
        context: const CompanionContext(
          companionId: _foxId,
          baseContext: CompanionBaseContext.focus,
          hasActiveSession: true,
        ),
        random: SeededRandomSource(7),
      );

      expect(director.currentMacroBehavior, isNotNull);
      expect(
        CompanionMacroBehavior.focusBehaviors.contains(
          director.currentMacroBehavior,
        ),
        isTrue,
      );
      expect(director.intent.companionId, _foxId);
      expect(director.intent.microMotion, isNotEmpty);
    });

    test('the fox gets its own profile, not the default one', () {
      final catalog = catalogWithFox();
      expect(catalog.profileFor(_foxId).displayName, '小狐');
      expect(catalog.profileFor(_foxId).posePack, 'fox');
    });

    test('the presentation intent works for the fox unchanged', () {
      final director = CompanionBehaviorDirector(
        catalog: catalogWithFox(),
        context: const CompanionContext(
          companionId: _foxId,
          baseContext: CompanionBaseContext.home,
        ),
        random: SeededRandomSource(1),
      );
      final intent = director.intent;
      expect(intent.companionId, _foxId);
      expect(intent.baseContext, CompanionBaseContext.home);
      expect(intent.pose, isA<CompanionPose>());
    });
  });

  group('the renderer resolves through the supplied provider', () {
    test('the asset resolver finds the fox pack with no special case', () {
      final resolver = CompanionAssetResolver(
        catalog: catalogWithFox(),
        registry: registryWithFox(),
      );
      final result = resolver.resolve(_foxId, CompanionPose.focusRead);

      expect(result.posePack, 'fox');
      // The fox has no production art, and says so rather than borrowing Mochi's.
      expect(result.hasProductionAsset, isFalse);
      expect(result.gapReason, contains('fox'));
    });

    test('the fox is drawn by the fox provider, not the dog one', () {
      final registry = registryWithFox();
      expect(registry.providerForCompanion(_foxId), isA<FoxVisualProvider>());
      expect(registry.providerForPack('fox'), isA<FoxVisualProvider>());
      // The existing three are untouched.
      expect(registry.providerForCompanion(CompanionId.dog), isNotNull);
      expect(registry.providerForCompanion(CompanionId.cat), isNotNull);
      expect(registry.providerForCompanion(CompanionId.rabbit), isNotNull);
    });
  });

  group('no page edit is required', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    testWidgets('a page renders the fox with no page change', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          companionSelectionStoreProvider
              .overrideWithValue(InMemoryCompanionSelectionStore()),
          companionCatalogProvider.overrideWithValue(catalogWithFox()),
          companionVisualRegistryProvider.overrideWithValue(registryWithFox()),
          homeControllerProvider.overrideWith(
            (ref) => _PresetHomeController(
              ref,
              const HomeUIState(hasActiveSession: true),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // This is the *production* page widget, unmodified. It resolves the fox
      // through the catalog and the registry and renders it.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Center(
                child: CompanionAvatar(companionId: _foxId, size: 140),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The fox provider draws the procedural silhouette, and the shared pose
      // vocabulary gives it the same focus props Mochi and the cat use.
      expect(find.byType(ProceduralCompanionArt), findsOneWidget);
      final prop = tester.widget<MochiPoseProp>(find.byType(MochiPoseProp));
      expect(
        prop.kind,
        anyOf(
          MochiPosePropKind.openBook,
          MochiPosePropKind.notebook,
          MochiPosePropKind.thoughtBubbles,
        ),
      );
    });
  });
}
