import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/pet_models.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/navigation/app_router.dart';
import 'package:cozy_focus_app/presentation/pages/mochi_growth_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/core/auth/current_user.dart';

/// A fresh router per test. The shared global kept its location between tests
/// in a file, so each test silently inherited the previous one's route.
late GoRouter router;

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
      routerConfig: router,
    ),
  );
}

void main() {
  late AppDatabase db;
  late _TestClock clock;
  late ProviderContainer container;

  setUp(() async {
    router = createAppRouter();
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

  /// One adopted pet with the given totals, so a test exercises the page's
  /// data-backed branch instead of the empty state.
  Future<void> seedPet({
    required int totalFocusMinutes,
    int happiness = 92,
  }) async {
    final petRepo = container.read(petRepositoryProvider);
    await petRepo.savePet(Pet(
      id: 'pet_mochi_1',
      userId: localMvpUserId,
      characterId: 'mochi',
      species: PetSpecies.dog,
      name: 'Mochi',
      adoptedAt: clock.now(),
    ));
    await petRepo.savePetProgress(PetProgress(
      id: 'prog_mochi_1',
      petId: 'pet_mochi_1',
      level: 3,
      experiencePoints: 245,
      totalFocusMinutes: totalFocusMinutes,
      happinessScore: happiness,
      updatedAt: clock.now(),
    ));
  }

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

      // Attribute cards. Three of them: design 10 annotates 只保留最关键的 3 项
      // 数据 and then names them. The fourth tile was 心情指数 and printed the
      // same happinessScore that the next assertion covers on the 幸福感 card, so
      // it is asserted *absent* rather than quietly deleted from this list.
      expect(find.text('成长属性'), findsOneWidget);
      expect(find.text('Lv.3'), findsOneWidget);
      expect(find.text('245 XP'), findsOneWidget);
      expect(find.text('120 分钟'), findsOneWidget);
      expect(find.text('心情指数'), findsNothing);
      expect(find.text('92 / 100'), findsNothing);

      // Scroll to reveal happiness card — the value the dropped tile carried
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

      router.go('/growth');
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

      router.go('/growth');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final buttonFinder = find.byKey(const Key('growth_collection_button'));
      expect(buttonFinder, findsOneWidget);
      // Scoped to the button. The page also renders GrowthSubNav, which carries
      // its own 图鉴 pill, so an unscoped text match finds two and only ever
      // found one while the shared router leaked a location into this test.
      expect(
        find.descendant(of: buttonFinder, matching: find.text('图鉴')),
        findsOneWidget,
      );

      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
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
      // The 心情指数 tile is gone (design 10 names three tiles, and the 幸福感
      // card below shows this same number), so the tile text must be absent. The
      // value itself is asserted on the card, two lines down.
      expect(find.text('0 / 100'), findsNothing);

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

    testWidgets('6. 最近解锁 lists finished crafts, and stays away when none',
        (tester) async {
      // Design 10 draws 最近解锁 with three dated cards. It is derived from
      // finished craft jobs, so it must be absent — not empty — when nothing has
      // finished, and must name the recipe and its date when something has.
      final petRepo = container.read(petRepositoryProvider);
      await petRepo.savePet(Pet(
        id: 'pet_1',
        userId: localMvpUserId,
        characterId: 'mochi',
        species: PetSpecies.dog,
        name: 'Mochi',
        adoptedAt: clock.now(),
      ));
      await petRepo.savePetProgress(PetProgress(
        id: 'prog_1',
        petId: 'pet_1',
        level: 3,
        experiencePoints: 245,
        totalFocusMinutes: 120,
        happinessScore: 92,
        updatedAt: clock.now(),
      ));

      // A tall surface: the section sits below the hero and the stats grid, and
      // a sliver outside the viewport is not built at all.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester
          .pumpWidget(createTestApp(container, const MochiGrowthPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('最近解锁'), findsNothing,
          reason: 'nothing has been crafted, so there is nothing to list');

      final craftRepo = container.read(craftRepositoryProvider);
      final recipe = (await craftRepo.findAllRecipes()).first;
      await craftRepo.saveJob(CraftJob(
        id: 'job_1',
        userId: localMvpUserId,
        recipeId: recipe.id,
        status: CraftJobStatus.completed,
        progressSeconds: recipe.requiredMinutes * 60,
        startedAt: DateTime(2026, 10, 2, 9),
        completedAt: DateTime(2026, 10, 2, 10),
        rewardClaimed: true,
      ));

      // The section's own provider reads the database, so re-read it now that
      // there is something to find.
      container.invalidate(recentCraftUnlocksProvider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
          await container.read(recentCraftUnlocksProvider.future), isNotEmpty,
          reason: 'the provider should see the finished craft');
      expect(find.text('最近解锁'), findsOneWidget);
      expect(find.text(recipe.name), findsOneWidget);
      expect(find.text('10月2日'), findsOneWidget);
      expect(find.text('查看全部 >'), findsOneWidget);
    });

    testWidgets('7. The stat row is the board\'s three tiles, on one line',
        (tester) async {
      await seedPet(totalFocusMinutes: 120);

      await tester
          .pumpWidget(createTestApp(container, const MochiGrowthPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The board annotates 只保留最关键的 3 项数据 and names the three.
      expect(find.text('当前等级'), findsOneWidget);
      expect(find.text('累计经验'), findsOneWidget);
      expect(find.text('陪伴专注'), findsOneWidget);
      // ...and the row holds nothing else. This is the assertion that fails if
      // the fourth tile comes back.
      expect(find.text('心情指数'), findsNothing);

      // One row, not two rows of two. The board draws the three side by side, so
      // their vertical centres share a line; a 2x2 grid would put two of them on
      // a second line and only this catches that.
      final centres = ['当前等级', '累计经验', '陪伴专注']
          .map((t) => tester.getCenter(find.text(t)).dy)
          .toList();
      expect(centres[0], closeTo(centres[1], 1.0),
          reason: 'the three tiles must share one row');
      expect(centres[1], closeTo(centres[2], 1.0),
          reason: 'the three tiles must share one row');

      // And the number the dropped tile carried is still on the page, once.
      await tester.scrollUntilVisible(find.text('幸福感'), 100);
      expect(find.text('92%'), findsOneWidget);
    });

    testWidgets('8. Three tiles survive 360dp and a value longer than the tile',
        (tester) async {
      // 360dp is the narrowest width this app is checked at, and three tiles
      // across it is the case the fourth tile never had to survive. The board's
      // own example value is 8 小时 35 分, so a long value is expected here
      // rather than hypothetical.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await seedPet(totalFocusMinutes: 12345);

      await tester
          .pumpWidget(createTestApp(container, const MochiGrowthPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // An overflow is reported as an exception during pump. Taking it here
      // makes the failure name the overflow instead of surfacing later as an
      // unrelated assertion error. This is the assertion that found the XP row
      // overflowing at this width.
      expect(tester.takeException(), isNull,
          reason: 'three tiles at 360dp must not overflow');

      // Still the full value: shrunk to fit rather than clipped or ellipsised,
      // because a truncated number is a wrong number.
      expect(find.text('12345 分钟'), findsOneWidget);

      // And the XP line stays ONE line. A Flexible alone stops the overflow by
      // letting the text wrap, which is why this assertion is here: the board
      // draws that line whole, and a wrapped line makes the card grow. The test
      // font is about 1.7x wider than a real one, so this is the case that
      // wraps without a FittedBox. Two lines at fontSize 12 is roughly 29px.
      final xpLine = tester.getSize(find.text('45 / 100 XP (总计 245 XP)'));
      expect(xpLine.height, lessThan(20),
          reason: 'the XP line must stay one line rather than wrap');

      // And the three are still on one line at this width.
      final centres = ['当前等级', '累计经验', '陪伴专注']
          .map((t) => tester.getCenter(find.text(t)).dy)
          .toList();
      expect(centres[0], closeTo(centres[1], 1.0));
      expect(centres[1], closeTo(centres[2], 1.0));
    });
  });
}
