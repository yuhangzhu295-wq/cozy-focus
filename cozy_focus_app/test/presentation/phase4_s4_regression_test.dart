import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cozy_focus_app/data/local/app_database.dart'
    hide FocusSession, Pet, CraftJob, CraftRecipe, InventoryItem, RoomItem;
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';
import 'package:cozy_focus_app/presentation/pages/home_page.dart';
import 'package:cozy_focus_app/presentation/pages/craft_list_page.dart';
import 'package:cozy_focus_app/presentation/pages/craft_detail_page.dart';
import 'package:cozy_focus_app/presentation/pages/inventory_page.dart';
import 'package:cozy_focus_app/presentation/pages/room_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/core/auth/current_user.dart';

class _TestClock implements FocusClock {
  final DateTime _now;
  _TestClock(this._now);
  @override
  DateTime now() => _now;
}

Widget createTestApp(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    ),
  );
}

void main() {
  late AppDatabase db;
  late _TestClock clock;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _TestClock(DateTime(2026, 9, 12, 10, 0, 0));
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider.overrideWithValue(clock),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('V4.1 S4 Focused Regression & Widget Tests', () {
    testWidgets(
        '1. HomePage: Settings gear is honestly disabled (onPressed is null)',
        (tester) async {
      await tester.pumpWidget(createTestApp(container, const HomePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final settingsFinder =
          find.widgetWithIcon(IconButton, Icons.settings_outlined);
      expect(settingsFinder, findsOneWidget);
      final IconButton button = tester.widget(settingsFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('2. HomePage: Has exactly three bottom navigation items',
        (tester) async {
      await tester.pumpWidget(createTestApp(container, const HomePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final navFinder = find.byType(BottomNavigationBar);
      expect(navFinder, findsOneWidget);
      final BottomNavigationBar nav = tester.widget(navFinder);
      expect(nav.items.length, equals(3));
      expect(nav.items[0].label, equals('首页'));
      expect(nav.items[1].label, equals('记录'));
      expect(nav.items[2].label, equals('成长'));
    });

    testWidgets(
        '3. CraftListPage: Owned recipe displays 已拥有 xN and is under 可制作',
        (tester) async {
      final craftRepo = container.read(craftRepositoryProvider);
      await craftRepo.upsertInventoryItem(InventoryItem(
        id: 'inv-sofa-1',
        userId: localMvpUserId,
        itemId: 'sofa',
        quantity: 2,
        updatedAt: clock.now(),
      ));

      await container.read(craftControllerProvider.notifier).loadAll();

      await tester.pumpWidget(createTestApp(container, const CraftListPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Header exists and section contains available recipes
      expect(find.text('制作'), findsOneWidget);
      expect(find.text('已拥有 x2'), findsOneWidget);
      expect(find.text('可制作'), findsWidgets);
      expect(find.text('已获得'), findsNothing);
    });

    testWidgets(
        '4. CraftDetailPage: Owned item shows 已拥有 xN and allows repeat crafting',
        (tester) async {
      final craftRepo = container.read(craftRepositoryProvider);
      await craftRepo.upsertInventoryItem(InventoryItem(
        id: 'inv-sofa-1',
        userId: localMvpUserId,
        itemId: 'sofa',
        quantity: 3,
        updatedAt: clock.now(),
      ));

      await container.read(craftControllerProvider.notifier).loadAll();

      await tester.pumpWidget(
          createTestApp(container, const CraftDetailPage(recipeId: 'sofa')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('已拥有 x3'), findsOneWidget);
      expect(find.text('再次制作'), findsOneWidget);
      expect(find.text('查看库存'), findsOneWidget);

      await tester.tap(find.text('再次制作'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final activeJob = await craftRepo.findActiveJobByUser(localMvpUserId);
      expect(activeJob, isNotNull);
      expect(activeJob!.recipeId, equals('sofa'));
      expect(find.text('制作进度'), findsOneWidget);
      expect(find.text('取消制作'), findsOneWidget);
    });

    testWidgets(
        '5. CraftDetailPage: Other active job blocks starting a new craft',
        (tester) async {
      final craftRepo = container.read(craftRepositoryProvider);
      await craftRepo.saveJob(CraftJob(
        id: 'job-sofa-active',
        userId: localMvpUserId,
        recipeId: 'sofa',
        status: CraftJobStatus.inProgress,
        progressSeconds: 300,
        startedAt: clock.now(),
        rewardClaimed: false,
      ));

      await container.read(craftControllerProvider.notifier).loadAll();

      await tester.pumpWidget(
          createTestApp(container, const CraftDetailPage(recipeId: 'table')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('⚙️ 当前有其他制作任务进行中'), findsOneWidget);
      expect(find.text('每次只能制作一件家具，完成或取消后再开始'), findsOneWidget);
      expect(find.text('开始制作'), findsNothing);
      expect(find.text('再次制作'), findsNothing);
    });

    testWidgets(
        '6. InventoryPage: Displays real owned quantity and room placement status',
        (tester) async {
      final craftRepo = container.read(craftRepositoryProvider);
      await craftRepo.upsertInventoryItem(InventoryItem(
        id: 'inv-sofa-1',
        userId: localMvpUserId,
        itemId: 'sofa',
        quantity: 2,
        updatedAt: clock.now(),
      ));
      await craftRepo.placeRoomItem(RoomItem(
        id: 'room-sofa-1',
        userId: localMvpUserId,
        itemId: 'sofa',
        positionX: 0.3,
        positionY: 0.4,
        scale: 1.0,
        zIndex: 1,
        isVisible: true,
        placedAt: clock.now(),
      ));

      await container.read(craftControllerProvider.notifier).loadAll();

      await tester.pumpWidget(createTestApp(container, const InventoryPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('房间装修'), findsOneWidget);
      expect(find.text('拥有 x2'), findsOneWidget);
      expect(find.text('已摆放 1 · 可摆放 1'), findsOneWidget);
    });

    testWidgets('7. RoomPage: Enforces quantity limits when placing items',
        (tester) async {
      final craftRepo = container.read(craftRepositoryProvider);
      await craftRepo.upsertInventoryItem(InventoryItem(
        id: 'inv-sofa-1',
        userId: localMvpUserId,
        itemId: 'sofa',
        quantity: 1,
        updatedAt: clock.now(),
      ));
      await craftRepo.placeRoomItem(RoomItem(
        id: 'room-sofa-1',
        userId: localMvpUserId,
        itemId: 'sofa',
        positionX: 0.5,
        positionY: 0.5,
        scale: 1.0,
        zIndex: 1,
        isVisible: true,
        placedAt: clock.now(),
      ));

      await container.read(craftControllerProvider.notifier).loadAll();

      await tester.pumpWidget(createTestApp(container, const RoomPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Mochi 的小房间'), findsOneWidget);

      await tester.tap(find.text('摆放家具'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // All inventory copies are already placed, so panel indicates no placeable items
      expect(find.text('库存中没有可摆放的家具'), findsOneWidget);
    });
  });
}
