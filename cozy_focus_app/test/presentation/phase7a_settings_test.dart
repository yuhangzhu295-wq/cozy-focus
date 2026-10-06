import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cozy_focus_app/presentation/navigation/app_router.dart';
import 'package:cozy_focus_app/presentation/pages/home_page.dart';
import 'package:cozy_focus_app/presentation/pages/settings_page.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// A fresh router per test. The shared global kept its location between tests
/// in a file, so each test silently inherited the previous one's route.
late GoRouter router;

void main() {
  setUp(() => router = createAppRouter());
  group('Phase 7A SettingsPage Tests', () {
    testWidgets(
        '1. SettingsPage renders AppBar with title, back button, and Mochi hero with 个人中心 and subtitle',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('设置'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byType(PetAvatarWidget), findsOneWidget);
      expect(find.text('个人中心'), findsOneWidget);
      expect(find.text('和 Mochi 一起，专注更好的自己'), findsOneWidget);
      expect(find.text('Mochi 陪伴中'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. SettingsPage renders its rows with evidence-backed wording',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final expectedTitles = [
        // The design's wording, which P10 adopted when the row became real.
        '默认专注时长',
        '通知',
        '声音与触感',
        '外观',
        '语言',
        '数据与同步',
        '隐私',
      ];

      for (final title in expectedTitles) {
        expect(find.text(title), findsOneWidget);
      }

      // 专注默认 is a real setting since P10: it shows the stored value and its
      // subtitle no longer claims the value is not saved.
      expect(find.text('25 分钟'), findsOneWidget);
      expect(find.textContaining('暂不持久化保存'), findsNothing);
      expect(find.textContaining('本地离线模式，云端同步暂不可用'), findsOneWidget);
      expect(find.textContaining('权限与隐私细则尚未完备'), findsOneWidget);
    });

    testWidgets(
        '3. SettingsPage has no fake controls and three navigation chevrons',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Switch), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      // Two navigable rows plus 默认专注时长, which opens a picker rather than a
      // route but leads somewhere all the same.
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets(
        '4. HomePage gear enters SettingsPage via context.push and back button returns to HomePage',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      router.go('/');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Initial state: HomePage is visible and SettingsPage is not
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(SettingsPage), findsNothing);

      // Tap settings gear on HomePage
      final settingsFinder =
          find.widgetWithIcon(IconButton, Icons.settings_outlined);
      expect(settingsFinder, findsOneWidget);
      await tester.tap(settingsFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verified: SettingsPage is now shown on top
      expect(find.byType(SettingsPage), findsOneWidget);

      // Tap back button on SettingsPage AppBar
      final backFinder = find.widgetWithIcon(IconButton, Icons.arrow_back);
      expect(backFinder, findsOneWidget);
      await tester.tap(backFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verified: Popped back to HomePage, SettingsPage is dismissed
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(SettingsPage), findsNothing);
    });
  });
}
