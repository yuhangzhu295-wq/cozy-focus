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
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/pet_models.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/navigation/app_router.dart';
import 'package:cozy_focus_app/presentation/pages/mochi_growth_page.dart';
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
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Phase 5: Growth > Mochi Page Tests', () {
    testWidgets('1. Shows truthful empty state when no pet exists',
        (tester) async {
      await tester
          .pumpWidget(createTestApp(container, const MochiGrowthPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('暂未领养宠物'), findsOneWidget);
      expect(find.text('开始第一次专注，领养你的专属 Mochi 吧！'), findsOneWidget);
      expect(find.text('前往首页'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets(
        '2. Data-backed rendering of pet name, level, XP, focus minutes, and happiness',
        (tester) async {
      final petRepo = container.read(petRepositoryProvider);
      final pet = Pet(
        id: 'pet_mochi_1',
        userId: localMvpUserId,
        characterId: 'mochi',
        species: PetSpecies.dog,
        name: 'Mochi',
        adoptedAt: clock.now(),
      );
      await petRepo.savePet(pet);

      final progress = PetProgress(
        id: 'prog_mochi_1',
        petId: 'pet_mochi_1',
        level: 3,
        experiencePoints: 245,
        totalFocusMinutes: 120,
        happinessScore: 92,
        updatedAt: clock.now(),
      );
      await petRepo.savePetProgress(progress);

      await tester
          .pumpWidget(createTestApp(container, const MochiGrowthPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header and Hero verification
      expect(find.text('成长'), findsWidgets);
      expect(find.text('Mochi'), findsWidgets);
      expect(find.text('Lv.3 伙伴'), findsOneWidget);
      expect(find.text('Mochi 正在陪伴你成长 🌱'), findsOneWidget);

      // XP progress bar text
      expect(find.text('经验值 (XP)'), findsOneWidget);
      expect(find.text('45 / 100 XP (总计 245 XP)'), findsOneWidget);

      // Attribute cards
      expect(find.text('成长属性'), findsOneWidget);
      expect(find.text('Lv.3'), findsOneWidget);
      expect(find.text('245 XP'), findsOneWidget);
      expect(find.text('120 分钟'), findsOneWidget);
      expect(find.text('92 / 100'), findsOneWidget);

      // Scroll to reveal happiness card
      await tester.scrollUntilVisible(find.text('幸福感'), 100);
      expect(find.text('幸福感'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
    });

    testWidgets('3. Has exactly 3 bottom-nav items with 成长 selected',
        (tester) async {
      await tester
          .pumpWidget(createTestApp(container, const MochiGrowthPage()));
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

    testWidgets('4. /growth route resolves to MochiGrowthPage', (tester) async {
      await tester.pumpWidget(createRouterTestApp(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      appRouter.go('/growth');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MochiGrowthPage), findsOneWidget);
    });

    testWidgets(
        '4b. Collection entry exists in Growth page and navigates to /growth/collection',
        (tester) async {
      final petRepo = container.read(petRepositoryProvider);
      final pet = Pet(
        id: 'pet_mochi_1',
        userId: localMvpUserId,
        characterId: 'mochi',
        species: PetSpecies.dog,
        name: 'Mochi',
        adoptedAt: clock.now(),
      );
      await petRepo.savePet(pet);

      await tester.pumpWidget(createRouterTestApp(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      appRouter.go('/growth');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final buttonFinder = find.byKey(const Key('growth_collection_button'));
      expect(buttonFinder, findsOneWidget);
      expect(find.text('图鉴'), findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        appRouter.routerDelegate.currentConfiguration.uri.toString(),
        equals('/growth/collection'),
      );
    });

    testWidgets('5. XP calculation handles boundary values properly',
        (tester) async {
      final petRepo = container.read(petRepositoryProvider);
      final pet = Pet(
        id: 'pet_boundary',
        userId: localMvpUserId,
        characterId: 'mochi',
        species: PetSpecies.dog,
        name: 'Mochi',
        adoptedAt: clock.now(),
      );
      await petRepo.savePet(pet);

      final progress = PetProgress(
        id: 'prog_boundary',
        petId: 'pet_boundary',
        level: 1,
        experiencePoints: 0,
        totalFocusMinutes: 0,
        happinessScore: 0,
        updatedAt: clock.now(),
      );
      await petRepo.savePetProgress(progress);

      await tester
          .pumpWidget(createTestApp(container, const MochiGrowthPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('0 / 100 XP (总计 0 XP)'), findsOneWidget);
      expect(find.text('Lv.1'), findsOneWidget);
      expect(find.text('0 XP'), findsOneWidget);
      expect(find.text('0 分钟'), findsOneWidget);
      expect(find.text('0 / 100'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('0%'), 100);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets(
        '6. Regression: Pet exists without PetProgress renders honest missing-progress state',
        (tester) async {
      final petRepo = container.read(petRepositoryProvider);
      final pet = Pet(
        id: 'pet_no_progress',
        userId: localMvpUserId,
        characterId: 'mochi',
        species: PetSpecies.dog,
        name: 'Mochi',
        adoptedAt: clock.now(),
      );
      await petRepo.savePet(pet);

      await tester
          .pumpWidget(createTestApp(container, const MochiGrowthPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Real pet identity is displayed
      expect(find.text('Mochi'), findsWidgets);
      expect(find.text('Mochi 等待开启成长记录 🌱'), findsOneWidget);
      expect(find.text('暂无成长数据'), findsOneWidget);
      expect(find.text('完成一次专注，记录你的陪伴时光与经验成长。'), findsOneWidget);
      expect(find.text('前往首页'), findsOneWidget);

      // Fabricated stats and defaults must NOT be rendered
      expect(find.text('Lv.1 伙伴'), findsNothing);
      expect(find.text('成长属性'), findsNothing);
      expect(find.text('幸福感'), findsNothing);
      expect(find.text('经验值 (XP)'), findsNothing);

      // Navigation is preserved
      final navFinder = find.byType(BottomNavigationBar);
      expect(navFinder, findsOneWidget);
      final BottomNavigationBar nav = tester.widget(navFinder);
      expect(nav.currentIndex, equals(2));
    });
  });
}
