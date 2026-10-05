import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/core/auth/current_user.dart';
import 'package:cozy_focus_app/data/local/app_database.dart'
    hide InventoryItem, RoomItem;
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_root.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_pack_registry.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_packs_provider.dart';
import 'package:cozy_focus_app/presentation/companion/room/room_simulation.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';

/// P35 — the room's gate is fed the *selected companion's* capabilities.
///
/// ## Why this test exists separately from `room_capability_test`
///
/// That file proves the rule: a decision never names an action the companion
/// cannot perform. This one proves the rule is *fed the truth* in production.
/// The two are different failures, and the P33 audit found the second one while
/// every gate test passed — a gate handed the wrong capabilities is a gate that
/// agrees with itself and refuses nothing.
///
/// So this drives the real `RoomSimulationController`, with a real installed
/// pack, a real sofa in the database, and the real availability provider.
void main() {
  late AppDatabase db;
  late Directory packRoot;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    packRoot = Directory.systemTemp.createTempSync('cozy_room_cap_');
  });

  tearDown(() async {
    await db.close();
    if (packRoot.existsSync()) packRoot.deleteSync(recursive: true);
  });

  final png = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ];

  /// A pack that ships only [actions].
  void writePack(String packId, List<String> actions) {
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
    }));
    for (final action in actions) {
      for (final frame in ['${action}_000.png', '${action}_001.png']) {
        File('${dir.path}/$frame').writeAsBytesSync(png);
      }
    }
  }

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      companionPackRootProvider.overrideWithValue(packRoot.path),
      companionSelectionStoreProvider
          .overrideWithValue(InMemoryCompanionSelectionStore()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  /// Owns and places a sofa, so the room has somewhere to sit.
  Future<void> placeSofa(ProviderContainer c) async {
    await c.read(craftRepositoryProvider).upsertInventoryItem(InventoryItem(
          id: 'inv-sofa',
          userId: localMvpUserId,
          itemId: 'sofa',
          quantity: 1,
          updatedAt: DateTime(2026, 10, 1),
        ));
    await c.read(craftRepositoryProvider).placeRoomItem(RoomItem(
          id: 'room-sofa',
          userId: localMvpUserId,
          itemId: 'sofa',
          positionX: 0.3,
          positionY: 0.6,
          scale: 1.0,
          zIndex: 1,
          isVisible: true,
          placedAt: DateTime(2026, 10, 1),
        ));
    await c.read(craftControllerProvider.notifier).loadAll();
  }

  /// Drives the simulation through a break, which is the branch that sends the
  /// companion to a seat, and returns the state it settled on.
  Future<RoomSimulationState> breakState(ProviderContainer c) async {
    final simulation = c.read(roomSimulationProvider.notifier);
    simulation.debugAdvance(Duration.zero);
    simulation.setFocusPaused(true);
    await settle();
    return c.read(roomSimulationProvider);
  }

  test('the dog still rests on the sofa', () async {
    final c = container();
    await placeSofa(c);
    final before = c.read(roomSimulationProvider).vitals.energy;

    final state = await breakState(c);

    expect(state.activity.companionAction, isNotNull,
        reason: 'a companion that can sit must still be sent to the sofa');
    expect(state.vitals.energy, greaterThanOrEqualTo(before));
  });

  test('an installed pack that cannot sit is given no action and no effect',
      () async {
    writePack('partial', ['idle']);
    final c = container();
    c.read(installedPacksProvider.notifier).install(
          const InstalledCompanionPack(
            packId: 'partial',
            displayName: '小豆',
            species: 'cat',
            source: 'local_import',
            formatVersion: 1,
            checksum: 'abc',
            relativeDirectory: 'companion_packs/partial',
          ),
        );
    await settle();
    expect(
      await c
          .read(companionSelectionProvider.notifier)
          .select(const CompanionId('partial')),
      isTrue,
      reason: 'the pack must be selectable for this test to mean anything',
    );
    await placeSofa(c);

    final state = await breakState(c);

    // The room has a sofa, the companion is on a break, and the pack ships no
    // sofa action. So the honest outcome is no action and no rest — not a rest
    // the player cannot see.
    expect(state.activity.companionAction, isNull,
        reason: 'the room must not commit an action the pack cannot perform');
    expect(state.activity.actionId, isNull);
    expect(state.vitals.energy, RoomSimulationState.initial.vitals.energy,
        reason: 'and must not apply the effect of a rest that did not happen');
  });

  test('and it can still rest once it ships the action', () async {
    // The guard against over-gating: the same pack, given the action, is sent to
    // the sofa. Without this the rule could be satisfied by refusing everything.
    writePack('fuller', ['idle', 'room_sit', 'pause_rest', 'sleep']);
    final c = container();
    c.read(installedPacksProvider.notifier).install(
          const InstalledCompanionPack(
            packId: 'fuller',
            displayName: '小豆',
            species: 'cat',
            source: 'local_import',
            formatVersion: 1,
            checksum: 'abc',
            relativeDirectory: 'companion_packs/fuller',
          ),
        );
    await settle();
    await c
        .read(companionSelectionProvider.notifier)
        .select(const CompanionId('fuller'));
    await placeSofa(c);

    final state = await breakState(c);

    expect(state.activity.companionAction, isNotNull,
        reason: 'a pack that ships the action must be allowed to use it');
  });
}
