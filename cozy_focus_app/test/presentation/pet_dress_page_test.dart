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
import 'package:cozy_focus_app/presentation/pages/pet_dress_page.dart';
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
    appRouter.go('/');
  });

  tearDown(() async {
    appRouter.go('/');
    container.dispose();
    await db.close();
  });

  group('Phase 5: Growth > Pet Dress Page Tests', () {
    testWidgets('1. Route resolution: /growth/dress resolves to PetDressPage',
        (tester) async {
      await tester.pumpWidget(createRouterTestApp(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      appRouter.go('/growth/dress');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PetDressPage), findsOneWidget);
    });

    testWidgets('2. Route resolution: /dress resolves to PetDressPage',
        (tester) async {
      await tester.pumpWidget(createRouterTestApp(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      appRouter.go('/dress');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PetDressPage), findsOneWidget);
    });

    testWidgets('3. Renders honest unavailable state when pet data is absent',
        (tester) async {
      await tester.pumpWidget(createTestApp(container, const PetDressPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Truthful empty-state header and preview section
      expect(find.text('宠物装扮'), findsOneWidget);
      expect(find.text('暂未领养宠物，暂无可用装扮'), findsOneWidget);
      expect(find.text('暂无可装扮的宠物伙伴'), findsOneWidget);

      // Ensure fabricated identities or equipped states are absent
      expect(find.text('Mochi 的衣橱'), findsNothing);
      expect(find.text('Mochi 试衣间 🌱'), findsNothing);
      expect(find.text('当前装扮：原皮伙伴 (暂无已装备外饰)'), findsNothing);

      // Truthful notice
      expect(find.text('装扮系统未连接数据，暂无可用装扮，无法穿戴。'), findsOneWidget);
    });

    testWidgets('4. Reflects real adopted pet identity dynamically',
        (tester) async {
      final petRepo = container.read(petRepositoryProvider);
      final pet = Pet(
        id: 'pet_custom_1',
        userId: localMvpUserId,
        characterId: 'mochi',
        species: PetSpecies.dog,
        name: '豆豆',
        adoptedAt: clock.now(),
      );
      await petRepo.savePet(pet);

      await tester.pumpWidget(createTestApp(container, const PetDressPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('豆豆 的衣橱'), findsOneWidget);
      expect(find.text('豆豆 试衣间 🌱'), findsOneWidget);
      expect(find.text('豆豆'), findsOneWidget);
      expect(find.text('当前装扮：暂无已装备外饰'), findsOneWidget);
    });

    testWidgets(
        '5. Outfit catalog cards show truthful status and no fake equip actions',
        (tester) async {
      await tester.pumpWidget(createTestApp(container, const PetDressPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('装扮图鉴'), findsOneWidget);
      expect(find.text('基础红项圈'), findsOneWidget);
      expect(find.text('暖冬姜黄围巾'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('小画家贝雷帽'), 150);
      expect(find.text('小画家贝雷帽'), findsOneWidget);
      expect(find.text('绅士小领结'), findsOneWidget);

      // All rendered buttons should have disabled (null) onPressed and honest '未连接' text
      final buttonFinder = find.byType(OutlinedButton);
      expect(buttonFinder, findsWidgets);

      for (final element in buttonFinder.evaluate()) {
        final button = element.widget as OutlinedButton;
        expect(button.onPressed, isNull);
      }

      // Ensure no fake equipped or owned claims are present
      expect(find.text('已穿戴'), findsNothing);
      expect(find.text('已拥有'), findsNothing);
      expect(find.text('穿戴'), findsNothing);
    });

    testWidgets('6. Bottom navigation has exactly 3 items with 成长 selected',
        (tester) async {
      await tester.pumpWidget(createTestApp(container, const PetDressPage()));
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

      appRouter.go('/growth/dress');
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

      // Back to dress page
      appRouter.go('/growth/dress');
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

      // Back to dress page
      appRouter.go('/growth/dress');
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
