import 'package:cozy_focus_app/presentation/companion/runtime/companion_asset_resolver.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_presentation_intent.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_visual_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_test_support.dart';

/// A provider with a declared set of production poses.
class _FakeProvider extends CompanionVisualProvider {
  @override
  final String posePackId;

  @override
  final Set<CompanionPose> productionPoses;

  _FakeProvider(this.posePackId, this.productionPoses);

  @override
  Widget build(
    BuildContext context,
    CompanionPresentationIntent intent,
    CompanionVisualOptions options,
  ) =>
      const SizedBox.shrink();
}

void main() {
  late CompanionCatalog catalog;

  setUp(() => catalog = loadShippedCatalog());

  CompanionAssetResolver resolverWith(
    Iterable<CompanionVisualProvider> providers,
  ) =>
      CompanionAssetResolver(
        catalog: catalog,
        registry: CompanionVisualRegistry.of(providers),
      );

  group('CompanionAssetResolver', () {
    test('reports ASSET_GAP when no provider is registered for the pack', () {
      final resolver = resolverWith(const []);
      final result = resolver.resolve(CompanionId.dog, CompanionPose.focusRead);

      expect(result.hasProductionAsset, isFalse);
      expect(result.gapReason, contains('no visual provider'));
      expect(result.toString(), contains(CompanionAssetResolution.gapToken));
    });

    test('reports ASSET_GAP for a pose the pack does not have', () {
      final resolver = resolverWith([
        _FakeProvider('mochi', {CompanionPose.idle}),
      ]);

      expect(
        resolver
            .resolve(CompanionId.dog, CompanionPose.idle)
            .hasProductionAsset,
        isTrue,
      );

      final missing =
          resolver.resolve(CompanionId.dog, CompanionPose.focusRead);
      expect(missing.hasProductionAsset, isFalse);
      expect(missing.gapReason, contains('focus_read'));
      expect(missing.gapReason, contains('mochi'));
    });

    test('resolves an asset key without a page ever knowing a path', () {
      final resolver = resolverWith([
        _FakeProvider('mochi', CompanionPose.values.toSet()),
      ]);

      final result =
          resolver.resolve(CompanionId.dog, CompanionPose.focusWrite);
      expect(result.hasProductionAsset, isTrue);
      expect(result.assetKey, 'mochi/focus_write');
      expect(result.posePack, 'mochi');
    });

    test('each companion resolves against its own pack, not the default one',
        () {
      final resolver = resolverWith([
        _FakeProvider('mochi', {CompanionPose.idle}),
        _FakeProvider('cat', {CompanionPose.idle, CompanionPose.focusThink}),
      ]);

      expect(
        resolver
            .resolve(CompanionId.cat, CompanionPose.focusThink)
            .hasProductionAsset,
        isTrue,
      );
      expect(
        resolver
            .resolve(CompanionId.dog, CompanionPose.focusThink)
            .hasProductionAsset,
        isFalse,
      );
    });

    test('an unregistered companion falls back to the default profile pack',
        () {
      final resolver = resolverWith([
        _FakeProvider('mochi', {CompanionPose.idle}),
      ]);
      // Unknown id → dog profile → mochi pack, so it still resolves.
      final result =
          resolver.resolve(const CompanionId('unicorn'), CompanionPose.idle);
      expect(result.hasProductionAsset, isTrue);
      expect(result.posePack, 'mochi');
    });

    test('audit reports a truthful gap count for a companion', () {
      final resolver = resolverWith([
        _FakeProvider('mochi', {CompanionPose.idle, CompanionPose.celebrate}),
      ]);
      final audit = resolver.audit(CompanionId.dog);

      expect(audit.length, CompanionPose.values.length);
      expect(
        audit.values.where((r) => r.hasProductionAsset).length,
        2,
      );
    });
  });
}
