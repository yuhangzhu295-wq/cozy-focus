import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/core/auth/current_user.dart';
import 'package:cozy_focus_app/data/local/app_database.dart'
    hide CraftJob, CraftRecipe, InventoryItem, RoomItem;
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/companion/collection/collection_acquisition.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_action_resolver.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/room/room_simulation.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';

/// P30 — the user golden flow, from clean data.
///
/// A player who has never seen the product must be able to discover and complete
/// the whole loop, and the test must not need knowledge the player does not have.
/// So every step asserts what the UI would show *and* records it, and the flow
/// reaches each state through the same call the app makes — no SQLite writes, no
/// seeding of the result.
///
/// What the fixture is allowed to do: nothing but create an empty database. In
/// particular it does **not** grant the target furniture, complete the target
/// craft or place the target furniture; those are the flow's own work, which is
/// the only way this proves anything.
///
/// The clock is injected and advanced, which is explicitly allowed.
class _MutableClock implements FocusClock {
  DateTime _now = DateTime(2026, 10, 3, 12);
  @override
  DateTime now() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

/// The target. 小床 — obtainable, in the furniture catalog, and not owned on a
/// clean database.
const _targetItemId = 'bed';

void main() {
  test('a new player can discover and complete the whole loop', () async {
    final clock = _MutableClock();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(clock),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    final steps = <Map<String, String>>[];
    void record(
      String screen,
      String action,
      String expected,
      String observed,
      String next,
    ) =>
        steps.add({
          'screen': screen,
          'action': action,
          'expected': expected,
          'observed': observed,
          'next_action_visible': next,
        });

    final craft = container.read(craftControllerProvider.notifier);
    final sim = container.read(roomSimulationProvider.notifier);

    // ── 1. clean data ─────────────────────────────────────────────────────
    container.read(homeControllerProvider);
    await craft.loadAll();
    final clean = container.read(craftControllerProvider);
    expect(clean.inventory, isEmpty, reason: 'the database starts empty');
    expect(clean.roomItems, isEmpty, reason: 'nothing is placed yet');
    expect(clean.activeJob, isNull, reason: 'no craft is running');

    // ── 2. collection: the item is visible and offers a way in ────────────
    CollectionAcquisitionViewModel collectionVm() =>
        CollectionAcquisitionViewModel.from(
          itemId: _targetItemId,
          itemName: '小床',
          obtainable: true,
          recipes: container.read(craftControllerProvider).recipes,
          activeJob: container.read(craftControllerProvider).activeJob,
          activeRecipe: container.read(craftControllerProvider).activeRecipe,
          ownedQuantity: container
              .read(craftControllerProvider)
              .inventory
              .where((i) => i.itemId == _targetItemId)
              .fold(0, (sum, i) => sum + i.quantity),
          placedCount: container
              .read(craftControllerProvider)
              .roomItems
              .where((r) => r.itemId == _targetItemId)
              .length,
        );

    final atCollection = collectionVm();
    expect(atCollection.status, CollectionAcquisitionStatus.craftable);
    expect(atCollection.isTappable, isTrue,
        reason: 'a locked but obtainable item must offer a way in');
    expect(atCollection.ctaRoute, '/craft/detail/bed');
    record(
        '图鉴 / Collection',
        '看到未收集的小床',
        '卡片可点，且指出获取路径',
        'status=${atCollection.status.name} cta=${atCollection.ctaLabel}',
        '打开获取详情');

    // ── 3. acquisition detail ─────────────────────────────────────────────
    final recipe = atCollection.recipe;
    expect(recipe, isNotNull, reason: 'the recipe is resolved from real data');
    expect(atCollection.requiredMinutes, recipe!.requiredMinutes);
    expect(atCollection.howToObtain, isNotEmpty);
    expect(atCollection.requiresMaterials, isFalse,
        reason: 'crafting costs time only; the detail says so');
    record(
        '获取详情 / Acquisition',
        '查看获取方式',
        '说明如何获得、需要多久',
        '${atCollection.howToObtain}；需要专注 ${atCollection.requiredMinutes} 分钟',
        '开始制作');

    // ── 4. start the craft, through the same call the detail page makes ───
    await container
        .read(craftEngineProvider)
        .startJob(localMvpUserId, recipe.id);
    await craft.loadAll();
    final afterStart = container.read(craftControllerProvider);
    expect(afterStart.activeJob, isNotNull, reason: 'a real job is running');
    expect(afterStart.activeJob!.recipeId, recipe.id);
    final atCrafting = collectionVm();
    expect(atCrafting.status, CollectionAcquisitionStatus.crafting);
    expect(atCrafting.ctaLabel, '继续专注');
    record(
        '制作 / Craft',
        '开始制作',
        '真实的制作任务开始',
        'job=${afterStart.activeJob!.recipeId} status=${atCrafting.status.name}',
        '继续专注');

    // ── 5. focus, and let the session settle into craft progress ──────────
    final focus = container.read(focusSessionControllerProvider.notifier);
    await focus.startSession(
      userId: localMvpUserId,
      plannedSeconds: recipe.requiredSeconds,
      mode: FocusMode.focus,
      taskName: 'P30 flow',
    );
    expect(container.read(focusSessionControllerProvider).session?.status,
        FocusSessionStatus.running);
    record('专注 / Focus', '开始专注', '专注会话真实运行', 'status=running', '专注推进制作');

    // The session must cover the recipe, so the loop closes in one pass.
    clock.advance(Duration(seconds: recipe.requiredSeconds + 60));
    await focus.completeSession();
    await focus.saveSession();
    await craft.loadAll();

    final afterFocus = container.read(craftControllerProvider);
    expect(afterFocus.activeJob, isNull,
        reason: 'the job completed, so there is no active job left');
    final inventoryQty = afterFocus.inventory
        .where((i) => i.itemId == _targetItemId)
        .fold(0, (sum, i) => sum + i.quantity);
    expect(inventoryQty, greaterThan(0),
        reason: 'completing the craft put the item in the inventory');
    record('专注完成 / Focus done', '完成专注', '专注时间变成制作进度并完成',
        'inventory=$inventoryQty', '去房间摆放');

    // ── 6. collection now reports it owned ────────────────────────────────
    final atOwned = collectionVm();
    expect(atOwned.status, CollectionAcquisitionStatus.owned);
    expect(atOwned.statusLine, '已拥有 x$inventoryQty');
    expect(atOwned.ctaRoute, '/inventory');
    record('图鉴 / Collection', '回到图鉴', '显示已拥有', atOwned.statusLine, '去房间摆放');

    // ── 7. place it, through the repository the room page writes with ─────
    await container.read(craftRepositoryProvider).placeRoomItem(RoomItem(
          id: 'room-$_targetItemId',
          userId: localMvpUserId,
          itemId: _targetItemId,
          positionX: 0.4,
          positionY: 0.6,
          scale: 1.0,
          zIndex: 1,
          isVisible: true,
          placedAt: clock.now(),
        ));
    await craft.loadAll();
    final atPlaced = collectionVm();
    expect(atPlaced.placedCount, 1);
    expect(atPlaced.status, CollectionAcquisitionStatus.placed);
    record('房间 / Room', '摆放小床', '真实房间行存在', 'placed=${atPlaced.placedCount}',
        '点击家具');

    // ── 8. the player asks the furniture for an action ────────────────────
    final bedAction = FurnitureCatalog.forId(_targetItemId)!.actions.first;
    sim.debugAdvance(const Duration(seconds: 60));
    sim.requestAction(
      itemId: _targetItemId,
      actionId: bedAction.id,
      roomItemId: 'room-$_targetItemId',
    );
    final asked = container.read(roomSimulationProvider);
    expect(asked.cause, RoomDecisionCause.playerRequest,
        reason: 'the request is accepted, not replaced');
    expect(asked.activity.actionId, bedAction.id);
    expect(asked.activity.companionAction, bedAction.companionAction);
    record(
        '房间 / Room',
        '点击小床选择「${bedAction.label}」',
        '宠物接受这个动作',
        'action=${asked.activity.actionId} cause=${asked.cause.id}',
        '宠物走过去并开始');

    // ── 9. the action holds for its promised dwell ────────────────────────
    // The housekeeping entry points the page calls must not take it away.
    sim.evaluateNow();
    sim.setArranging(true);
    sim.setArranging(false);
    final held = container.read(roomSimulationProvider);
    final owed = held.activity.endsAt - held.elapsedSinceStart;
    expect(held.activity.actionId, bedAction.id,
        reason: 'a forced re-evaluation must not replace the player action');
    expect(owed, bedAction.minDwell,
        reason: 'and the whole dwell it promised is intact');
    record(
        '房间 / Room',
        '等待',
        '动作保持承诺的时长',
        'dwell=${owed.inSeconds}s of ${bedAction.minDwell.inSeconds}s',
        '（流程结束）');

    // ── the discoverability table ─────────────────────────────────────────
    final out = File('outputs/ai_handoff/P30_USER_GOLDEN_FLOW.json');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'note':
          'Every step was reached through the call the app makes. No SQLite '
              'writes, no seeding of the target furniture, craft or placement.',
      'targetItemId': _targetItemId,
      'steps': steps,
    }));
    // ignore: avoid_print
    print('P30_STEPS=${steps.length}');
    for (final s in steps) {
      // ignore: avoid_print
      print('P30 ${s['screen']} | ${s['action']} | ${s['observed']}');
    }
  });
}
