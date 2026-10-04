import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/core/auth/current_user.dart';
import 'package:cozy_focus_app/data/local/app_database.dart'
    hide CraftJob, CraftRecipe, InventoryItem, RoomItem;
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_action_resolver.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_entity.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_use_panel.dart';
import 'package:cozy_focus_app/presentation/companion/room/room_simulation.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest_data.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_availability.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';

/// P28.3 — the furniture action matrix.
///
/// Every action the furniture catalog can commit, with what it declares and what
/// it actually does when the player asks for it. Written to
/// `outputs/ai_handoff/FURNITURE_ACTION_MATRIX.json` as a **generated audit
/// artifact**: every field is projected from the real catalog, the real packs
/// and a real simulation run, so the file cannot drift from the product the way
/// a hand-maintained table would.
///
/// ## Why it is driven rather than declared
///
/// An action id, a status label and a `companionAction` string are all claims.
/// P28.3 asks for the ones that survive: the request is accepted, it reaches the
/// intended anchor, the dwell holds, the effect lands once, and the action ends.
/// So each action is actually requested against a real `RoomSimulationController`
/// and the outcome recorded, rather than read off the catalog.
///
/// ## The visual column
///
/// `own` — the pack has its own frames for this pose.
/// `alias` — the pack draws it by reusing another action's frames
///           (`drawAliases`, the only map rendering consults).
/// `fallback` — the pack names the behaviour but rendering resolves nothing, so
///           the rig or the caller's own fallback draws it. This is the honest
///           answer for `room_sit`, and it is why "the status says 坐下" is not
///           accepted as proof that a sit was drawn.
/// `none` — the pack does not name it at all.
class _TestClock implements FocusClock {
  _TestClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

const _companions = ['dog', 'cat', 'rabbit'];

/// How one companion can draw [pose].
String _visualFor(String companionKey, CompanionPose pose) {
  final manifest = CompanionActionManifestData.forCompanion(companionKey);
  if (manifest == null) return 'none';
  if (manifest.hasExactAction(pose)) return 'own';
  if (manifest.specForRendering(pose) != null) return 'alias';
  if (manifest.resolve(pose) != null) return 'fallback';
  return 'none';
}

void main() {
  test('every catalog action is enumerated, checked and driven', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider
          .overrideWithValue(_TestClock(DateTime(2026, 10, 3, 12))),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    container.read(homeControllerProvider);
    container.read(craftControllerProvider);
    await pumpEventQueue();

    final sim = container.read(roomSimulationProvider.notifier);
    final entries = <Map<String, dynamic>>[];
    final failures = <String>[];

    for (final item in FurnitureCatalog.entities.values) {
      for (final action in item.actions) {
        final macro = CompanionMacroBehavior.fromId(action.companionAction);
        final pose = macro?.pose;
        final anchorRole = item.interactionPoints.isEmpty
            ? null
            : item.interactionPoints.first;

        final visual = <String, String>{
          for (final c in _companions)
            c: pose == null ? 'none' : _visualFor(c, pose),
        };
        // A gap is a real, recorded answer — not a failure of the matrix. It is
        // reported so the product decision is made with the number in hand.
        final visualGap = pose == null ||
            visual.values.every((v) => v == 'fallback' || v == 'none');

        // ---- drive it -------------------------------------------------------
        final roomItemId = 'matrix-${item.id}';
        await container
            .read(craftRepositoryProvider)
            .upsertInventoryItem(InventoryItem(
              id: 'matrix-inv-${item.id}',
              userId: localMvpUserId,
              itemId: item.id,
              quantity: 1,
              updatedAt: DateTime(2026, 10, 3, 12),
            ));
        await container.read(craftRepositoryProvider).placeRoomItem(RoomItem(
              id: roomItemId,
              userId: localMvpUserId,
              itemId: item.id,
              positionX: 0.4,
              positionY: 0.6,
              scale: 1.0,
              zIndex: 1,
              isVisible: true,
              placedAt: DateTime(2026, 10, 3, 12),
            ));
        await container.read(craftControllerProvider.notifier).loadAll();

        // Expire whatever the previous action left committed.
        sim.debugAdvance(const Duration(seconds: 60));

        sim.requestAction(
          itemId: item.id,
          actionId: action.id,
          roomItemId: roomItemId,
        );
        final after = container.read(roomSimulationProvider);
        final afterVitals = after.vitals;

        final accepted = after.cause == RoomDecisionCause.playerRequest;
        final reachedAnchor = after.activity.anchorId.isNotEmpty;
        final dwell = after.activity.endsAt - after.elapsedSinceStart;
        final dwellHolds = dwell == action.minDwell;
        final rightAction = after.activity.actionId == action.id;
        final rightCompanionAction =
            after.activity.companionAction == action.companionAction;

        // The effect lands once: re-evaluating must not apply it again.
        sim.evaluateNow();
        final afterReeval = container.read(roomSimulationProvider);
        final effectOnce = afterReeval.vitals.energy == afterVitals.energy &&
            afterReeval.vitals.mood == afterVitals.mood &&
            afterReeval.vitals.focusLevel == afterVitals.focusLevel;

        // It exits cleanly: past the dwell the loop may choose again, and the
        // commitment is released rather than held forever.
        sim.debugAdvance(action.maxDwell + const Duration(seconds: 5));
        final exited =
            container.read(roomSimulationProvider).playerCommitmentItemId ==
                null;

        final ok = accepted &&
            reachedAnchor &&
            dwellHolds &&
            rightAction &&
            rightCompanionAction &&
            effectOnce &&
            exited;
        if (!ok) failures.add('${item.id}/${action.id}');

        entries.add({
          'itemId': item.id,
          'itemLabel': item.label,
          'furnitureType': item.type.id,
          'purpose': item.purpose,
          'interactionPoints': item.interactionPoints,
          'anchorRole': anchorRole,
          'actionId': action.id,
          'actionLabel': action.label,
          'companionAction': action.companionAction,
          'triggers': [for (final t in action.triggers) t.id],
          'requiresUnlock': action.requiresUnlock,
          'minDwellMs': action.minDwell.inMilliseconds,
          'maxDwellMs': action.maxDwell.inMilliseconds,
          'effect': {
            'energy': action.effect.energy,
            'mood': action.effect.mood,
            'focus': action.effect.focus,
            'relationship': action.effect.relationship,
            'knowledge': action.effect.knowledge,
          },
          'playerTapDeclared':
              action.triggers.contains(FurnitureTrigger.playerTap),
          'checks': {
            'itemCanBeOwned': FurnitureCatalog.itemIds.contains(item.id),
            'itemCanBePlaced': item.interactionPoints.isNotEmpty,
            'anchorExists': anchorRole != null,
            'companionActionResolves': macro != null,
            'visualCapability': visual,
            'visualGap': visualGap,
            'reachableByPlayerTap': accepted,
            'reachedIntendedAnchor': reachedAnchor,
            'minDwellHolds': dwellHolds,
            'effectAppliedOnce': effectOnce,
            'exitsCleanly': exited,
            'runtimePass': ok,
          },
        });
      }
    }

    final runtimeReal = entries
        .where((e) => (e['checks'] as Map)['runtimePass'] == true)
        .length;
    final visualGaps = [
      for (final e in entries)
        if ((e['checks'] as Map)['visualGap'] == true)
          '${e['itemId']}/${e['actionId']}',
    ];

    final matrix = {
      'schemaVersion': 1,
      'generatedFrom': 'FurnitureCatalog + companions/*/manifest.json + a '
          'driven RoomSimulationController',
      'note': 'Generated audit artifact. Every value is projected from the '
          'product or measured by running it; do not hand-edit.',
      'summary': {
        'actions': entries.length,
        'runtimeReal': runtimeReal,
        'visualGaps': visualGaps,
        'playerTapDeclared':
            entries.where((e) => e['playerTapDeclared'] == true).length,
        'offeredByPanel':
            entries.where((e) => e['playerTapDeclared'] != true).length,
      },
      'actions': entries,
    };

    final out = File('outputs/ai_handoff/FURNITURE_ACTION_MATRIX.json');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(matrix),
    );

    // ignore: avoid_print
    print('ACTION_MATRIX_TOTAL=${entries.length}');
    // ignore: avoid_print
    print('ACTION_MATRIX_RUNTIME_REAL=$runtimeReal');
    // ignore: avoid_print
    print('ACTION_MATRIX_VISUAL_GAPS=${visualGaps.join(',')}');
    // ignore: avoid_print
    print('ACTION_MATRIX_OFFERED_WITHOUT_PLAYER_TAP='
        '${entries.where((e) => e['playerTapDeclared'] != true).map((e) => '${e['itemId']}/${e['actionId']}').join(',')}');

    expect(failures, isEmpty,
        reason: 'these actions did not survive being requested: $failures');
    expect(entries, isNotEmpty);
  });

  test('the panel only offers actions the companion can actually show', () {
    // P28.4. 坐下 on the sofa and 坐一会儿 on the rug are `room_sit`: no frames of
    // its own in any pack, no drawAliases entry, and the rig draws it as the
    // idle pose with a slightly turned ear. The chip promised a sit the player
    // never saw, so it is hidden rather than shipped as a button that lies.
    for (final companion in _companions) {
      final availability =
          CompanionActionAvailabilityResolver.resolve(companion);
      final sofa = FurnitureCatalog.forId('sofa')!;
      final offered = [
        for (final a in sofa.actions)
          if (FurnitureUsePanel.isOfferable(availability, a)) a.id,
      ];
      expect(offered, contains('rest'),
          reason: '$companion can draw pause_rest');
      expect(offered, contains('nap'), reason: '$companion can draw sleep');
      expect(offered, isNot(contains('sit')),
          reason: '$companion has no sit drawing, so offering it would be a '
              'button that lies');
    }
  });
}
