import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/growth/growth_stage.dart';
import 'package:cozy_focus_app/presentation/companion/animation/animation_state.dart';
import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_availability_provider.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_completeness.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_root.dart';
import 'package:cozy_focus_app/presentation/companion/focus_phase.dart';
import 'package:cozy_focus_app/presentation/companion/companion_visual_registry.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_pack_profiles.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_pack_registry.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_packs_provider.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_availability.dart';
import 'package:cozy_focus_app/presentation/companion/pack/pack_backed_visual_provider.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_presentation_intent.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_visual_provider.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_behavior_director.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/random_source.dart';
import 'package:cozy_focus_app/presentation/companion/time_of_day.dart';

/// P33 — a pack that ships only some actions, gated honestly.
///
/// ## The defect these exist for
///
/// `CompanionActionAvailabilityResolver.resolve` answers from the compiled-in
/// table, which knows the three shipped companions. An installed pack is not in
/// that table, so the resolver fell back to the **dog** — handing a pack the
/// dog's thirteen capabilities while the pack's own artwork was honest about the
/// poses it does not ship. The behaviour side and the drawing side disagreed:
/// the pack was asked for `focus_read` and drew an empty box.
///
/// The existing invariant tests could not catch it. They hand the director a
/// synthetic `CompanionActionAvailability`, which proves the *gate* works and
/// says nothing about whether the gate is *fed the truth*. These tests install a
/// real pack and ask the real providers.
void main() {
  late Directory packRoot;

  setUp(() {
    packRoot = Directory.systemTemp.createTempSync('cozy_partial_');
  });

  tearDown(() {
    if (packRoot.existsSync()) packRoot.deleteSync(recursive: true);
  });

  final png = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  /// Writes a pack that ships [actions], each with two frames.
  ///
  /// [fallbacks] declares `semanticFallback` entries, which is how a pack says
  /// "I can be asked for this and will draw something else".
  void writePack(
    String packId, {
    required List<String> actions,
    Map<String, String> fallbacks = const {},
    Map<String, String> aliases = const {},
  }) {
    final dir = Directory('${packRoot.path}/$packId')
      ..createSync(recursive: true);
    File('${dir.path}/manifest.json').writeAsStringSync(jsonEncode({
      'companionId': packId,
      'displayName': '小豆',
      'species': 'cat',
      'posePack': '${packId}_art',
      'canvas': {'width': 512, 'height': 512},
      'groundBaseline': 458,
      'centerAnchor': 255,
      'actions': {
        for (final action in actions)
          action: {
            'frames': ['${action}_000.png', '${action}_001.png'],
            'fps': 5,
            'loopMode': 'loop',
          },
      },
      if (fallbacks.isNotEmpty) 'semanticFallback': fallbacks,
      if (aliases.isNotEmpty) 'drawAliases': aliases,
    }));
    for (final action in actions) {
      for (final frame in ['${action}_000.png', '${action}_001.png']) {
        File('${dir.path}/$frame').writeAsBytesSync(png);
      }
    }
  }

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      companionPackRootProvider.overrideWithValue(packRoot.path),
      companionSelectionStoreProvider
          .overrideWithValue(InMemoryCompanionSelectionStore()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  /// Installs [packId] and lets the profiles load.
  Future<ProviderContainer> containerWithPack(
    String packId, {
    List<String> actions = const ['idle', 'walk'],
    Map<String, String> fallbacks = const {},
  }) async {
    writePack(packId, actions: actions, fallbacks: fallbacks);
    final c = container();
    c.read(installedPacksProvider.notifier).install(
          InstalledCompanionPack(
            packId: packId,
            displayName: '小豆',
            species: 'cat',
            source: 'local_import',
            formatVersion: 1,
            checksum: 'abc',
            relativeDirectory: 'companion_packs/$packId',
          ),
        );
    await settle();
    return c;
  }

  // ─────────────────── the capability answer must be the pack's ──────────────

  group('the availability answer comes from the pack', () {
    test('the raw resolver still answers an unknown id with the dog', () async {
      // Pinned deliberately, and it is the negative proof for this phase: the
      // same question asked two ways gets two answers, and the naive one is
      // wrong.
      //
      // `resolve` is correct for an id the build ships and wrong for a pack a
      // user brought, and the two are indistinguishable to it. Routing around
      // that is what the provider exists for — so this test fails the day
      // someone deletes the provider and calls the resolver directly again.
      final c = await containerWithPack('xiaomao');
      final naive = CompanionActionAvailabilityResolver.resolve('xiaomao');
      final correct = c.read(companionAvailabilityProvider)('xiaomao');

      expect(naive.companionId, 'dog');
      expect(naive.canSchedule(CompanionPose.focusRead), isTrue,
          reason:
              'the dog can read, and the resolver does not know this is not '
              'the dog');

      expect(correct.companionId, 'xiaomao');
      expect(correct.canSchedule(CompanionPose.focusRead), isFalse,
          reason: 'the pack ships no focus_read, so it must not be asked');
    });

    test('the provider answers an installed pack with what it ships', () async {
      final c = await containerWithPack('xiaomao');
      final availability = c.read(companionAvailabilityProvider)('xiaomao');

      expect(availability.companionId, 'xiaomao');
      // `schedulable` is pose-keyed. The pack ships the actions `idle` and
      // `walk`, and `walk` is not a pose - it is an animation state, asked for
      // by id - so `idle` is the only pose it serves.
      expect(availability.schedulable, {'idle'});
      expect(availability.schedulable, isNot(contains('focus_read')),
          reason: 'the pack ships no focus_read and must not be asked for one');
      expect(availability.schedulable, isNot(contains('celebrate')));
      expect(availability.schedulable, isNot(contains('sleep')));
      // A pack has no production contract, so nothing is "planned" for it.
      expect(availability.planned, isEmpty);
      expect(availability.targets, isEmpty);
    });

    test('the provider leaves the built-in three alone', () async {
      final c = await containerWithPack('xiaomao');
      final dog = c.read(companionAvailabilityProvider)('dog');

      expect(dog.companionId, 'dog');
      expect(dog.schedulable, contains('focus_read'));
      // The contract's target frame counts are reported for a companion that has
      // a contract, and nothing is "planned" — the dog ships everything its
      // contract declares, which is a fact worth pinning rather than a gap.
      expect(dog.targets, isNotEmpty);
      expect(dog.planned, isEmpty);
    });

    test('the behaviour answer and the drawing answer agree', () async {
      // The two sides that disagreed. `productionPoses` is what the provider can
      // draw; `schedulable` is what the director may ask for. For a pack they
      // must describe the same action set.
      final c = await containerWithPack('xiaomao');
      final provider = c
          .read(companionVisualRegistryProvider)
          .providerForCompanion(const CompanionId('xiaomao'))!;
      final availability = c.read(companionAvailabilityProvider)('xiaomao');

      final drawable = provider.productionPoses.map((pose) => pose.id).toSet();
      expect(drawable, {'idle'});
      expect(availability.schedulable, drawable,
          reason: 'the behaviour side and the drawing side must agree');

      // And the animation-state action is drawable by id, which is the other
      // half of "what this pack can draw": walk has no pose, so it is absent
      // from `productionPoses` and present here.
      final runtime =
          c.read(installedPackProfilesProvider)[const CompanionId('xiaomao')]!;
      expect(runtime.manifest.specFor('walk'), isNotNull);
      expect(runtime.manifest.specFor('sleep'), isNull);
    });

    test('a declared fallback is schedulable, and not counted as ready',
        () async {
      // The pack names focus_read and will draw its idle instead. The director
      // may schedule it; the report must not call it an action this pack ships.
      final c = await containerWithPack(
        'xiaomao',
        actions: const ['idle', 'walk'],
        fallbacks: const {'focus_read': 'idle'},
      );
      final availability = c.read(companionAvailabilityProvider)('xiaomao');

      expect(availability.canSchedule(CompanionPose.focusRead), isTrue,
          reason: 'the pack declared a behaviour for it');
      expect(availability.hasOwnDrawing(CompanionPose.focusRead), isFalse,
          reason: 'but it draws something else, so it is not its own action');

      final completeness = c.read(companionCompletenessProvider)('xiaomao');
      expect(completeness.ready, {'idle', 'walk'});
      expect(completeness.fallback, {'focus_read'},
          reason: 'a fallback is neither ready nor missing');
      expect(completeness.missing, isNot(contains('focus_read')));
      expect(completeness.summary, '2 / 13');
    });
  });

  // ─────────────────────── the director never overreaches ───────────────────

  group('the director never selects a capability the pack lacks', () {
    /// A director for [companionId], fed the real provider's answer.
    CompanionBehaviorDirector directorFor(
      ProviderContainer c,
      CompanionId companionId, {
      CompanionBaseContext base = CompanionBaseContext.focus,
      FocusPhase? phase = FocusPhase.working,
    }) =>
        CompanionBehaviorDirector(
          catalog: c.read(companionCatalogProvider),
          context: CompanionContext(
            companionId: companionId,
            baseContext: base,
            focusPhase: phase,
            growthStage: GrowthStage.sprout,
            timeOfDay: TimeOfDayBand.midday,
            hasActiveSession: true,
          ),
          random: SeededRandomSource(7),
          availabilityOf: c.read(companionAvailabilityProvider),
        );

    test('through a whole focus session it only ever picks idle or walk',
        () async {
      final c = await containerWithPack('xiaomao');
      final d = directorFor(c, const CompanionId('xiaomao'));
      final availability = c.read(companionAvailabilityProvider)('xiaomao');

      for (var i = 0; i < 300; i++) {
        d.advanceTo(Duration(milliseconds: i * 1000));
        final macro = d.currentMacroBehavior;
        if (macro == null) continue; // a gated-out context, which is honest
        expect(availability.canSchedule(macro.pose), isTrue,
            reason: 'selected ${macro.id} (${macro.pose.id}), '
                'which this pack does not ship');
      }
    });

    test('a focus recipe naming three actions yields only what exists',
        () async {
      // The shared recipe lists focus_read, focus_write and focus_think for
      // every companion. This pack ships none of them, so the director must not
      // produce any of them, whatever the recipe says.
      final c = await containerWithPack('xiaomao');
      final d = directorFor(c, const CompanionId('xiaomao'));

      final seen = <String>{};
      for (var i = 0; i < 300; i++) {
        d.advanceTo(Duration(milliseconds: i * 1000));
        final macro = d.currentMacroBehavior;
        if (macro != null) seen.add(macro.pose.id);
      }

      expect(seen, isNot(contains('focus_read')));
      expect(seen, isNot(contains('focus_write')));
      expect(seen, isNot(contains('focus_think')));
      expect(seen.difference({'idle', 'walk'}), isEmpty,
          reason: 'only what the pack ships: $seen');
    });

    test('a companion with only idle degrades rather than inventing', () async {
      final c = await containerWithPack('tiny', actions: const ['idle']);
      final d = directorFor(c, const CompanionId('tiny'));

      for (var i = 0; i < 120; i++) {
        d.advanceTo(Duration(milliseconds: i * 1000));
        final macro = d.currentMacroBehavior;
        if (macro == null) continue;
        expect(macro.pose, CompanionPose.idle);
      }
    });

    test('an installed pack with everything still behaves like a built-in',
        () async {
      // The gate must not turn a complete pack into a crippled one.
      final c = await containerWithPack(
        'full',
        actions: const [
          'idle',
          'walk',
          'sleep',
          'sit_down',
          'stand_up',
          'focus_read',
          'focus_write',
          'focus_think',
          'craft_work',
          'pause_rest',
          'celebrate',
          'tap_react',
          'pet_react',
        ],
      );
      final availability = c.read(companionAvailabilityProvider)('full');
      // Ten, not thirteen: the contract's action list includes walk, sit_down
      // and stand_up, which are animation states rather than poses, so they are
      // drawable by id and absent from a pose-keyed answer. Worth pinning - the
      // two vocabularies overlap and neither contains the other.
      expect(availability.schedulable.length, 10);
      expect(availability.schedulable, contains('focus_read'));

      final d = directorFor(c, const CompanionId('full'));
      final seen = <String>{};
      for (var i = 0; i < 300; i++) {
        d.advanceTo(Duration(milliseconds: i * 1000));
        final macro = d.currentMacroBehavior;
        if (macro != null) seen.add(macro.pose.id);
      }
      expect(seen.intersection({'focus_read', 'focus_write', 'focus_think'}),
          isNotEmpty,
          reason: 'a complete pack should still show the focus variety');
    });
  });

  // ───────────────────────────── completeness ──────────────────────────────

  group('completeness', () {
    test('a built-in reports complete, and that is asserted not assumed', () {
      final completeness = CompanionPackCompleteness.of(
        CompanionActionManifest.fromJson(
          jsonDecode(File('assets/companions/dog/manifest.json')
              .readAsStringSync()) as Map<String, dynamic>,
        ),
      );
      expect(completeness.isComplete, isTrue,
          reason: 'the shipped companion must ship the whole vocabulary');
      expect(completeness.missing, isEmpty);
      expect(completeness.fallback, isEmpty);
      expect(completeness.total, 13);
    });

    test('a partial pack names what is missing', () {
      final completeness = CompanionPackCompleteness.of(
        CompanionActionManifest.fromJson({
          'companionId': 'x',
          'canvas': {'width': 512, 'height': 512},
          'groundBaseline': 458,
          'centerAnchor': 255,
          'actions': {
            'idle': {
              'frames': ['a.png', 'b.png'],
              'fps': 5,
              'loopMode': 'loop',
            },
          },
        }),
      );

      expect(completeness.ready, {'idle'});
      expect(completeness.missing, contains('focus_read'));
      expect(completeness.summary, '1 / 13');
      expect(completeness.isComplete, isFalse);
    });

    test('an action the app has no contract for is not counted either way', () {
      // A pack may ship an action the app never asks for. That is not an
      // incompleteness, and the app has nothing to say about it.
      final completeness = CompanionPackCompleteness.of(
        CompanionActionManifest.fromJson({
          'companionId': 'x',
          'canvas': {'width': 512, 'height': 512},
          'groundBaseline': 458,
          'centerAnchor': 255,
          'actions': {
            'idle': {
              'frames': ['a.png', 'b.png'],
              'fps': 5,
              'loopMode': 'loop',
            },
            'backflip': {
              'frames': ['c.png', 'd.png'],
              'fps': 5,
              'loopMode': 'loop',
            },
          },
        }),
      );

      expect(completeness.ready, {'idle'});
      expect(completeness.reference, isNot(contains('backflip')));
      expect(completeness.total, 13);
    });
  });

  // ────────────── an animation state the pack cannot draw is declined ────────

  group('the animation state does not override with art the pack lacks', () {
    /// The drawing decision, asked directly.
    ///
    /// Deliberately not a widget pump. Rendering a pack means reading frames from
    /// disk, and a widget test that waits on a file-backed image stream hangs
    /// rather than fails — the same trap the P32 hot-install tests hit. The
    /// decision is what matters here, so it is asked of the provider rather than
    /// read off a rendered tree.
    CompanionActionSpec? specFor(
      ProviderContainer c,
      String packId, {
      required CompanionPose pose,
      AnimationState? state,
    }) =>
        (c
                    .read(companionVisualRegistryProvider)
                    .providerForCompanion(CompanionId(packId))
                as PackBackedCompanionVisualProvider)
            .specFor(
          CompanionPresentationIntent(
            companionId: CompanionId(packId),
            baseContext: CompanionBaseContext.home,
            pose: pose,
          ),
          CompanionVisualOptions(animationState: state),
        );

    test('a walk override on a pack with no walk draws the pose instead',
        () async {
      final c = await containerWithPack('xiaomao', actions: const ['idle']);

      // The room's walk override, forced onto a pack that ships no walk. The
      // override is declined and the pose is drawn, rather than an empty box.
      expect(
        specFor(c, 'xiaomao',
                pose: CompanionPose.idle, state: AnimationState.walk)
            ?.actionId,
        'idle',
        reason: 'the companion must still be drawn, doing what it can',
      );
    });

    test('a walk override on a pack that ships walk draws the walk', () async {
      final c = await containerWithPack(
        'xiaomao',
        actions: const ['idle', 'walk'],
      );

      expect(
        specFor(c, 'xiaomao',
                pose: CompanionPose.idle, state: AnimationState.walk)
            ?.actionId,
        'walk',
        reason: 'a pack that has the art must still be overridden by it',
      );
    });

    test('a pack with nothing for the pose and no override draws nothing',
        () async {
      final c = await containerWithPack('xiaomao', actions: const ['idle']);

      // `celebrate` is neither shipped nor aliased, so there is nothing honest
      // to draw. Borrowing another companion's art would be worse than an empty
      // box: it would report a companion that is not there.
      expect(
        specFor(c, 'xiaomao', pose: CompanionPose.celebrate),
        isNull,
      );
    });
  });
}
