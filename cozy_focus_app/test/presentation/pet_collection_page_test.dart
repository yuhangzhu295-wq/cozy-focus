import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cozy_focus_app/data/local/app_database.dart'
    hide
        Pet,
        PetMemory,
        FocusSession,
        FocusRecord,
        CraftJob,
        CraftRecipe,
        InventoryItem,
        RoomItem;
import 'package:cozy_focus_app/core/auth/current_user.dart';
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/pet_models.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/navigation/app_router.dart';
import 'package:cozy_focus_app/presentation/pages/pet_collection_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

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

Widget createRouterTestApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
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
    appRouter.go('/');
  });

  tearDown(() async {
    appRouter.go('/');
    container.dispose();
    await db.close();
  });

  group('Phase 5: Growth > Pet Collection Page Tests', () {
    testWidgets(
        '1. Route resolution: /growth/collection resolves to PetCollectionPage',
        (tester) async {
      await tester.pumpWidget(createRouterTestApp(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      appRouter.go('/growth/collection');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PetCollectionPage), findsOneWidget);
    });

    testWidgets(
        '2. Route resolution: /collection resolves to PetCollectionPage',
        (tester) async {
      await tester.pumpWidget(createRouterTestApp(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      appRouter.go('/collection');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PetCollectionPage), findsOneWidget);
    });

    testWidgets('3. Renders collection header, summary card and catalog items',
        (tester) async {
      await tester
          .pumpWidget(createTestApp(container, const PetCollectionPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('收藏图鉴'), findsOneWidget);
      expect(find.text('图鉴预览 · 物品收集'), findsOneWidget);
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('植物'), findsOneWidget);
      expect(find.text('家具'), findsOneWidget);
      expect(find.text('生活'), findsOneWidget);
      expect(find.text('特别'), findsOneWidget);
      expect(find.text('温馨布艺沙发'), findsOneWidget);
      expect(find.text('暂无宠物陪伴，前往成长页领养宠物伙伴吧！'), findsOneWidget);
      expect(find.text('已拥有 0 件'), findsOneWidget);
    });

    testWidgets(
        '4. Renders truthful empty inventory state without fake unlocked ownership',
        (tester) async {
      await tester
          .pumpWidget(createTestApp(container, const PetCollectionPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('已拥有 0 件'), findsOneWidget);
      expect(find.text('未收集'), findsWidgets);
      expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    });

    testWidgets(
        '5. Truthfully displays repository-backed inventory quantity > 0 as owned',
        (tester) async {
      final craftRepo = container.read(craftRepositoryProvider);
      await craftRepo.upsertInventoryItem(InventoryItem(
        id: 'inv-sofa-1',
        userId: localMvpUserId,
        itemId: 'sofa',
        quantity: 2,
        updatedAt: clock.now(),
      ));

      final petRepo = container.read(petRepositoryProvider);
      await petRepo.savePet(Pet(
        id: 'pet_custom_1',
        userId: localMvpUserId,
        characterId: 'mochi',
        species: PetSpecies.dog,
        name: '可可',
        adoptedAt: clock.now(),
      ));

      await tester
          .pumpWidget(createTestApp(container, const PetCollectionPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('可可 的收藏屋'), findsOneWidget);
      expect(find.text('已拥有 1 件'), findsOneWidget);
      expect(find.text('已拥有 (x2)'), findsOneWidget);
    });

    testWidgets('6. Bottom navigation has exactly 3 items with 成长 selected',
        (tester) async {
      await tester
          .pumpWidget(createTestApp(container, const PetCollectionPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final navFinder = find.byType(BottomNavigationBar);
      expect(navFinder, findsOneWidget);
      final BottomNavigationBar nav = tester.widget(navFinder);
      expect(nav.items.length, equals(3));
      expect(nav.items[0].label, equals('首页'));
      expect(nav.items[1].label, equals('记录'));
      expect(nav.items[2].label, equals('成长'));
      expect(nav.currentIndex, equals(2));
    });

    testWidgets('7. Bottom navigation triggers truthful routing',
        (tester) async {
      await tester.pumpWidget(createRouterTestApp(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      appRouter.go('/growth/collection');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap index 0 (首页 icon)
      await tester.tap(find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.byIcon(Icons.home_rounded)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(appRouter.routerDelegate.currentConfiguration.uri.toString(),
          equals('/'));

      // Back to collection page
      appRouter.go('/growth/collection');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap index 1 (记录 icon)
      await tester.tap(find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.byIcon(Icons.bar_chart_rounded)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(appRouter.routerDelegate.currentConfiguration.uri.toString(),
          equals('/records'));

      // Back to collection page
      appRouter.go('/growth/collection');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap index 2 (成长 icon)
      await tester.tap(find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.byIcon(Icons.eco_outlined)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(appRouter.routerDelegate.currentConfiguration.uri.toString(),
          equals('/growth'));
    });
  });
}
