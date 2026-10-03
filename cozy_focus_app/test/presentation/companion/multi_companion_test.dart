import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/companion_visual_registry.dart';
import 'package:cozy_focus_app/presentation/companion/mochi_pose_spec.dart';
import 'package:cozy_focus_app/presentation/companion/procedural_companion_art.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_asset_resolver.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_manifest_data.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:cozy_focus_app/presentation/pages/companion_picker_page.dart';
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

class _PresetHomeController extends HomeController {
  final HomeUIState _preset;
  _PresetHomeController(super.ref, this._preset);

  @override
  Future<void> loadHomeData() async {
    state = _preset;
  }
}

/// Waits for the selection's asynchronous restore/write to land.
///
/// The store touches the file system, so a single microtask turn is not enough;
/// this is a real (short) delay rather than a `pump` because there is no widget
/// tree involved.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 60));

/// Deletes [dir], ignoring the Windows case where a handle is still open.
Future<void> _deleteQuietly(Directory dir) async {
  try {
    await dir.delete(recursive: true);
  } on FileSystemException {
    // Temp directory; the OS will reclaim it.
  }
}

void main() {
  group('CompanionSelection', () {
    test('defaults to the shipped default companion', () async {
      final selection = CompanionSelection(InMemoryCompanionSelectionStore());
      await settle();
      expect(selection.state, CompanionId.dog);
    });

    test('selecting a companion persists it', () async {
      final store = InMemoryCompanionSelectionStore();
      final selection = CompanionSelection(store);
      await settle();

      expect(await selection.select(CompanionId.cat), isTrue);
      expect(selection.state, CompanionId.cat);
      expect(await store.read(), CompanionId.cat);
    });

    test('an unknown companion id is refused rather than stored', () async {
      final store = InMemoryCompanionSelectionStore();
      final selection = CompanionSelection(store);
      await settle();

      expect(await selection.select(const CompanionId('dragon')), isFalse);
      expect(selection.state, CompanionId.dog);
      expect(await store.read(), isNull);
    });

    test('a stored selection is restored on start', () async {
      final selection = CompanionSelection(
        InMemoryCompanionSelectionStore(CompanionId.rabbit),
      );
      await settle();
      expect(selection.state, CompanionId.rabbit);
    });

    test('an unknown stored id degrades to the default', () async {
      final selection = CompanionSelection(
        InMemoryCompanionSelectionStore(const CompanionId('dragon')),
      );
      await settle();
      expect(selection.state, CompanionId.dog);
    });

    test('the selection survives a restart', () async {
      final dir = await Directory.systemTemp.createTemp('companion-selection');
      addTearDown(() => _deleteQuietly(dir));

      final first = CompanionSelection(
        FileCompanionSelectionStore(directoryOverride: dir),
      );
      await settle();
      await first.select(CompanionId.cat);

      // A second store over the same file stands in for an app restart.
      final second = CompanionSelection(
        FileCompanionSelectionStore(directoryOverride: dir),
      );
      await settle();
      expect(second.state, CompanionId.cat);
    });

    test('a corrupt selection file degrades instead of throwing', () async {
      final dir = await Directory.systemTemp.createTemp('companion-corrupt');
      addTearDown(() => _deleteQuietly(dir));
      File('${dir.path}/${FileCompanionSelectionStore.fileName}')
          .writeAsStringSync('{not json');

      final selection = CompanionSelection(
        FileCompanionSelectionStore(directoryOverride: dir),
      );
      await settle();
      expect(selection.state, CompanionId.dog);
    });

    test('the stored file contains only the selected id', () async {
      final dir = await Directory.systemTemp.createTemp('companion-minimal');
      addTearDown(() => _deleteQuietly(dir));

      final store = FileCompanionSelectionStore(directoryOverride: dir);
      await store.write(CompanionId.rabbit);

      final decoded = jsonDecode(
        File('${dir.path}/${FileCompanionSelectionStore.fileName}')
            .readAsStringSync(),
      );
      expect(decoded, {'selectedCompanionId': 'rabbit'});
    });
  });

  group('the registry serves all three companions from one runtime', () {
    test('every shipped companion has a visual provider', () {
      final registry = buildCompanionVisualRegistry();
      for (final id in CompanionManifestData.profiles.keys) {
        expect(registry.providerForCompanion(id), isNotNull, reason: id.value);
      }
      expect(registry.registeredPacks.toSet(), {'mochi', 'cat', 'rabbit'});
    });

    test('the asset gap is reported per pose, and never overstated', () {
      final resolver = CompanionAssetResolver(
        catalog: bundledCompanionCatalog(),
        registry: buildCompanionVisualRegistry(),
      );

      // Which poses ship real art, per companion. Every pose *not* listed must
      // still report ASSET_GAP rather than quietly borrowing a neighbouring
      // action, and no companion may claim art it does not have.
      const dogPosesWithArt = {
        CompanionPose.idle,
        CompanionPose.focusRead,
        CompanionPose.focusWrite,
        CompanionPose.focusThink,
        CompanionPose.rest,
        CompanionPose.tapReact,
        CompanionPose.petReact,
        CompanionPose.craftWork,
        CompanionPose.celebrate,
        CompanionPose.sleep,
      };

      // The cat pack now covers the same pose vocabulary as the dog: all
      // thirteen actions ship, and only `focus_write` is still short of its
      // frame count (two of four), which is a frame-count matter and not a
      // pose gap. `walk`, `sit_down` and `stand_up` are locomotion and posture
      // states rather than behaviour poses, so they do not appear here.
      const catPosesWithArt = {
        CompanionPose.idle,
        CompanionPose.focusRead,
        CompanionPose.focusThink,
        CompanionPose.focusWrite,
        CompanionPose.craftWork,
        CompanionPose.rest,
        CompanionPose.celebrate,
        CompanionPose.tapReact,
        CompanionPose.petReact,
        CompanionPose.sleep,
      };

      // The rabbit pack is in production. `idle`, `craft_work` and `focus_read`
      // ship; `walk`, `sit_down` and `stand_up` are locomotion and posture
      // states rather than behaviour poses, so they do not appear here. Every
      // pose not listed must still report ASSET_GAP rather than borrowing a
      // neighbour's art, which is what the loop below asserts.
      const rabbitPosesWithArt = {
        CompanionPose.idle,
        CompanionPose.craftWork,
        CompanionPose.focusRead,
      };

      for (final id in CompanionManifestData.profiles.keys) {
        for (final pose in CompanionPose.values) {
          final result = resolver.resolve(id, pose);
          final expected = switch (id) {
            CompanionId.dog => dogPosesWithArt.contains(pose),
            CompanionId.cat => catPosesWithArt.contains(pose),
            CompanionId.rabbit => rabbitPosesWithArt.contains(pose),
            _ => false,
          };
          expect(
            result.hasProductionAsset,
            expected,
            reason: '${id.value}/${pose.id} asset expectation',
          );
          if (!expected) {
            expect(result.gapReason, isNotNull,
                reason: '${id.value}/${pose.id}');
          }
        }
      }

      // No companion may claim a pose outside its own declared set.
      for (final id in CompanionManifestData.profiles.keys) {
        final claimed = resolver
            .audit(id)
            .values
            .where((r) => r.hasProductionAsset)
            .map((r) => r.pose)
            .toSet();
        final declared = switch (id) {
          CompanionId.dog => dogPosesWithArt,
          CompanionId.cat => catPosesWithArt,
          CompanionId.rabbit => rabbitPosesWithArt,
          _ => const <CompanionPose>{},
        };
        expect(
          claimed.difference(declared),
          isEmpty,
          reason: '${id.value} claims art it does not have',
        );
      }
    });

    test('the cat and rabbit are drawn as their own species, not as Mochi', () {
      // Distinct silhouettes are the whole point: substituting the dog's art for
      // the cat is exactly what the brief forbids.
      expect(CompanionSilhouettes.cat.earShape, CompanionEarShape.triangle);
      expect(CompanionSilhouettes.rabbit.earShape, CompanionEarShape.long);
      expect(CompanionSilhouettes.cat.hasWhiskers, isTrue);
      expect(CompanionSilhouettes.rabbit.hasWhiskers, isFalse);
      expect(
        CompanionSilhouettes.cat.furColor,
        isNot(CompanionSilhouettes.rabbit.furColor),
      );
    });
  });

  group('one director, three companions', () {
    test('the same director drives any companion id', () {
      // The director takes the companion from the context, so switching
      // companion changes only what is drawn — never which engine runs.
      final catalog = bundledCompanionCatalog();
      for (final id in CompanionManifestData.profiles.keys) {
        final profile = catalog.profileFor(id);
        expect(profile.displayName, isNotEmpty);
        expect(profile.posePack, isNotEmpty);
        expect(profile.microMotion, isNotEmpty);
      }
      expect(
        CompanionManifestData.profiles.keys.toSet(),
        {CompanionId.dog, CompanionId.cat, CompanionId.rabbit},
      );
    });

    test('all three share the same pose vocabulary and pose specs', () {
      // A pose must mean the same thing for every companion, or the shared
      // director would not be able to drive them all.
      for (final pose in CompanionPose.values) {
        expect(MochiPoseSpecs.table.containsKey(pose), isTrue);
      }
    });
  });

  group('CompanionPickerPage', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    Widget app(ProviderContainer c) => UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CompanionPickerPage(),
          ),
        );

    ProviderContainer containerWith(InMemoryCompanionSelectionStore store) {
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          companionSelectionStoreProvider.overrideWithValue(store),
          homeControllerProvider.overrideWith(
            (ref) => _PresetHomeController(ref, const HomeUIState()),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    testWidgets('lists every companion the catalog declares', (tester) async {
      final c = containerWith(InMemoryCompanionSelectionStore());
      await tester.pumpWidget(app(c));
      await tester.pump();

      expect(find.text('选择你的伙伴 🌱'), findsOneWidget);
      expect(find.text('Mochi'), findsWidgets);
      expect(find.text('小猫'), findsWidgets);
      expect(find.text('小兔'), findsWidgets);
      expect(find.text('确定伙伴'), findsOneWidget);
    });

    testWidgets('tapping a companion selects and persists it', (tester) async {
      final store = InMemoryCompanionSelectionStore();
      final c = containerWith(store);
      await tester.pumpWidget(app(c));
      await tester.pump();

      await tester.tap(find.text('小猫').first);
      await tester.pump();

      expect(c.read(companionSelectionProvider), CompanionId.cat);
      expect(await store.read(), CompanionId.cat);
    });

    testWidgets('each companion shows its own tagline and traits',
        (tester) async {
      final c = containerWith(InMemoryCompanionSelectionStore());
      await tester.pumpWidget(app(c));
      await tester.pump();

      final catalog = bundledCompanionCatalog();
      for (final id in catalog.companionIds) {
        final profile = catalog.profileFor(id);
        expect(find.text(profile.tagline), findsOneWidget, reason: id.value);
      }
      // Traits repeat between companions (陪伴 appears on all three), so this
      // asserts presence rather than a count.
      expect(find.text('灵动'), findsOneWidget);
      expect(find.text('治愈'), findsOneWidget);
      expect(find.text('温柔'), findsWidgets);
    });

    testWidgets('the selected companion is marked as selected', (tester) async {
      final c = containerWith(InMemoryCompanionSelectionStore(CompanionId.cat));
      await tester.pumpWidget(app(c));
      await tester.pump();
      await tester.pump();

      // The selected card announces itself; the unselected ones do not.
      expect(find.bySemanticsLabel(RegExp('已选择')), findsOneWidget);
      final semantics = tester.getSemantics(
        find.bySemanticsLabel(RegExp('已选择')),
      );
      expect(semantics.hasFlag(SemanticsFlag.isSelected), isTrue);
    });
  });
}
