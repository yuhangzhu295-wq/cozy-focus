import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cozy_focus_app/presentation/navigation/app_router.dart';
import 'package:cozy_focus_app/presentation/pages/home_page.dart';
import 'package:cozy_focus_app/presentation/pages/settings_page.dart';
import 'package:cozy_focus_app/presentation/pages/notifications_page.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

void main() {
  group('Phase 7B NotificationsPage Tests', () {
    testWidgets(
        '1. NotificationsPage renders title, back arrow icon, and PetAvatarWidget',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const NotificationsPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('通知设置'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byType(PetAvatarWidget), findsOneWidget);
      expect(find.text('小小提醒\n大大进步！'), findsOneWidget);
      expect(
        find.text('让 Mochi 在合适的时间陪伴你，养成更好的专注习惯。'),
        findsOneWidget,
      );
      expect(find.text('Mochi 陪伴中'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '2. NotificationsPage renders expected notification labels and repeating status strings',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const NotificationsPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final expectedLabels = [
        '每日专注提醒',
        '睡前关怀提醒',
        '周报提醒',
        '成长里程碑',
        '静音时段',
        '提醒方式',
      ];

      for (final label in expectedLabels) {
        expect(find.text(label), findsOneWidget);
      }

      expect(find.text('当前版本尚未接入系统通知'), findsNWidgets(6));
      expect(find.text('不可配置'), findsNWidgets(6));
    });

    testWidgets(
        '3. NotificationsPage has NO interactive toggles, switches, list tiles, or bottom bar',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const NotificationsPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Switch), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets(
        '4. SettingsPage has two chevron_right icons for navigable settings',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SettingsPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
      expect(
        find.widgetWithText(GestureDetector, '通知'),
        findsOneWidget,
      );
    });

    testWidgets(
        '5. Router journey: Home -> Settings -> Notifications -> Settings -> Home',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: appRouter,
          ),
        ),
      );

      appRouter.go('/');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Initially on HomePage
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(SettingsPage), findsNothing);
      expect(find.byType(NotificationsPage), findsNothing);

      // 2. Tap settings gear on HomePage -> navigate to SettingsPage
      final settingsGear =
          find.widgetWithIcon(IconButton, Icons.settings_outlined);
      expect(settingsGear, findsOneWidget);
      await tester.tap(settingsGear);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(NotificationsPage), findsNothing);

      // 3. Tap '通知' card on SettingsPage -> navigate to NotificationsPage
      final notificationsCard = find.text('通知');
      expect(notificationsCard, findsOneWidget);
      await tester.tap(notificationsCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(NotificationsPage), findsOneWidget);

      // 4. Tap back arrow on NotificationsPage -> return to SettingsPage
      final notifBack = find.widgetWithIcon(IconButton, Icons.arrow_back);
      expect(notifBack, findsOneWidget);
      await tester.tap(notifBack);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(NotificationsPage), findsNothing);

      // 5. Tap back arrow on SettingsPage -> return to HomePage
      final settingsBack = find.widgetWithIcon(IconButton, Icons.arrow_back);
      expect(settingsBack, findsOneWidget);
      await tester.tap(settingsBack);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(SettingsPage), findsNothing);
      expect(find.byType(NotificationsPage), findsNothing);
    });
  });
}
