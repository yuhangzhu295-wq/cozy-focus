import 'dart:io';

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
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/pet_models.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/companion/companion_avatar.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/navigation/app_router.dart';
import 'package:cozy_focus_app/presentation/pages/pet_dress_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';
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
    router.go('/');
  });

  tearDown(() async {
    router.go('/');
    container.dispose();
    await db.close();
  });

  group('Phase 5: Growth > Pet Dress Page Tests', () {
    testWidgets('1. Route resolution: /growth/dress resolves to PetDressPage',
        (tester) async {
      await tester.pumpWidget(createRouterTestApp(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      router.go('/growth/dress');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PetDressPage), findsOneWidget);
    });

    testWidgets('2. Route resolution: /dress resolves to PetDressPage',
        (tester) async {
      await tester.pumpWidget(createRouterTestApp(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      router.go('/dress');
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
      // The catalog is a lazily built SliverGrid below the preview. Scroll it
      // into view before asserting on cards: the first row need not be built at
      // the initial scroll offset on every screen size.
      await tester.scrollUntilVisible(find.text('基础红项圈'), 150);
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

      router.go('/growth/dress');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap index 0 (首页 icon)
      await tester.tap(find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.byIcon(Icons.home_rounded)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(router.routerDelegate.currentConfiguration.uri.toString(),
          equals('/'));

      // Back to dress page
      router.go('/growth/dress');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap index 1 (记录 icon)
      await tester.tap(find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.byIcon(Icons.bar_chart_rounded)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(router.routerDelegate.currentConfiguration.uri.toString(),
          equals('/records'));

      // Back to dress page
      router.go('/growth/dress');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap index 2 (成长 icon)
      await tester.tap(find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.byIcon(Icons.eco_outlined)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(router.routerDelegate.currentConfiguration.uri.toString(),
          equals('/growth'));
    });
  });

  /// STAGE 5 / C8 — dress-up is preview-only, and that is enforced rather than
  /// assumed.
  ///
  /// The page already behaves honestly. The problem with honesty that lives
  /// only in the current source is that one edit turns it into a lie: a single
  /// `onPressed: () => ...` would let the screen claim to dress Mochi while
  /// nothing in the app can store an outfit. These tests make each honest
  /// behaviour fail loudly if it stops being true.
  group('C8: dress-up is preview-only and cannot pretend otherwise', () {
    /// A tall surface so the whole preview grid builds at once. The guard wants
    /// to count *every* card, not whichever ones the sliver happened to lay out.
    Future<void> pumpDress(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(createTestApp(container, const PetDressPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> adoptPet() async {
      await container.read(petRepositoryProvider).savePet(Pet(
            id: 'pet_c8',
            userId: localMvpUserId,
            characterId: 'mochi',
            species: PetSpecies.dog,
            name: '豆豆',
            adoptedAt: clock.now(),
          ));
    }

    testWidgets('every preview card carries a disabled action', (tester) async {
      await pumpDress(tester);

      final buttons = find.byType(OutlinedButton);
      expect(buttons, findsNWidgets(kPreviewOutfitCatalog.length),
          reason: 'each catalog item gets exactly one action slot');

      for (final element in buttons.evaluate()) {
        expect((element.widget as OutlinedButton).onPressed, isNull,
            reason: 'a preview card must not offer a working equip action');
      }
      expect(find.text('未连接'), findsNWidgets(kPreviewOutfitCatalog.length),
          reason: 'and each must say so, rather than looking merely disabled');
    });

    testWidgets('no control anywhere on the page is a usable action',
        (tester) async {
      // The strong form of "no fake equip action": walk every button-shaped
      // widget the page renders and prove not one of them is enabled. A guard
      // written against `OutlinedButton` alone would miss a `FilledButton`
      // equip action added later; this one would not.
      await adoptPet();
      await pumpDress(tester);

      final buttonTypes = <Finder>[
        find.byType(OutlinedButton),
        find.byType(FilledButton),
        find.byType(ElevatedButton),
        find.byType(TextButton),
      ];
      final enabled = <String>[];
      for (final finder in buttonTypes) {
        for (final element in finder.evaluate()) {
          final widget = element.widget;
          final onPressed = switch (widget) {
            OutlinedButton(:final onPressed) => onPressed,
            FilledButton(:final onPressed) => onPressed,
            ElevatedButton(:final onPressed) => onPressed,
            TextButton(:final onPressed) => onPressed,
            _ => null,
          };
          if (onPressed != null) enabled.add('${widget.runtimeType}');
        }
      }

      expect(enabled, isEmpty,
          reason: 'the dress page is a preview: its only interactive controls '
              'are navigation, which is why nothing here may be enabled. If a '
              'real outfit flow is ever built, build the data layer first and '
              'update this guard deliberately.');
    });

    testWidgets('nothing is drawn on the pet', (tester) async {
      await adoptPet();
      await pumpDress(tester);

      final avatar =
          tester.widget<CompanionAvatar>(find.byType(CompanionAvatar));
      expect(avatar.accessory, isNull,
          reason: 'a catalog preview must not put anything on the pet');

      // The renderer reads the accessory it is given, so check the value that
      // actually reaches the drawing code rather than only the parameter.
      final pet = tester.widget<PetAvatarWidget>(find.byType(PetAvatarWidget));
      expect(pet.accessory, isNull,
          reason: 'the renderer must receive no accessory at all');
    });

    testWidgets('the only equipment claim on screen is the denial',
        (tester) async {
      await adoptPet();
      await pumpDress(tester);

      final claims = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data ?? '')
          .where((label) =>
              label.contains('已装备') ||
              label.contains('已穿戴') ||
              label.contains('已拥有') ||
              label.contains('已解锁'))
          .toList();

      expect(claims, ['当前装扮：暂无已装备外饰'],
          reason: 'the page may state that nothing is equipped; it may never '
              'state that something is');
    });

    test('no outfit contract exists in the domain or data layer', () {
      // "Nothing is equipped" is only honest because nothing *can* be equipped.
      // This is the structural half of the claim: if an outfit repository or
      // entity ever appears, the preview page has to be revisited rather than
      // silently keep denying that anything is equipped.
      final tokens = [
        'Outfit',
        'outfit',
        'Equip',
        'equip',
        'Wearable',
        'wearable'
      ];
      final offenders = <String>[];

      for (final root in ['lib/domain', 'lib/data']) {
        final directory = Directory(root);
        expect(directory.existsSync(), isTrue,
            reason: '$root must exist for this guard to mean anything');
        for (final entity in directory.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final text = entity.readAsStringSync();
          for (final token in tokens) {
            if (text.contains(token)) offenders.add('${entity.path} -> $token');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'there is no outfit contract; the dress page must not be '
              'reading one, and the app must not be able to persist an outfit');
    });

    test('the page source states the denial and makes no positive claim', () {
      final source =
          File('lib/presentation/pages/pet_dress_page.dart').readAsStringSync();
      expect(source, isNotEmpty);

      for (final claim in ['已穿戴', '已拥有', '已解锁', '穿戴成功', '装备成功']) {
        expect(source.contains(claim), isFalse,
            reason: 'the page must never render the claim "$claim"');
      }
      expect(source.contains('暂无已装备外饰'), isTrue,
          reason:
              'the page must keep stating plainly that nothing is equipped');
    });
  });
}
