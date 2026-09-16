import 'package:cozy_focus_app/presentation/navigation/app_router.dart';
import 'package:cozy_focus_app/presentation/pages/data_sync_page.dart';
import 'package:cozy_focus_app/presentation/pages/settings_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 7C DataSyncPage Tests', () {
    testWidgets('1. DataSyncPage renders honest local-only status',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const DataSyncPage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('数据与同步'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byType(PetAvatarWidget), findsOneWidget);
      expect(find.text('没关系～'), findsOneWidget);
      expect(find.text('你的专注数据已安全保存在本机。'), findsOneWidget);
      expect(find.text('数据状态'), findsOneWidget);
    });

    testWidgets('2. DataSyncPage renders the three approved status cards',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const DataSyncPage()),
      );
      await tester.pump();

      expect(find.text('本地数据已保存'), findsOneWidget);
      expect(find.text('你的专注数据已安全保存在本机'), findsOneWidget);
      expect(find.text('当前处于离线状态'), findsOneWidget);
      expect(find.text('当前版本为本地离线模式，网络状态不影响本地使用'), findsOneWidget);
      expect(find.text('云端同步'), findsOneWidget);
      expect(find.text('当前版本暂不支持云端同步'), findsOneWidget);
      expect(find.text('当前版本以本地存储方式运行，不会执行云端同步。'), findsOneWidget);
    });

    testWidgets(
        '3. DataSyncPage has no fake controls or navigation affordances',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const DataSyncPage()),
      );
      await tester.pump();

      expect(find.byType(Switch), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets(
        '4. Settings opens Data Sync and its back button returns to Settings',
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
      appRouter.go('/settings');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SettingsPage).hitTestable(), findsOneWidget);
      final targetRow = find.widgetWithText(GestureDetector, '数据与同步');
      expect(targetRow, findsOneWidget);
      await tester.scrollUntilVisible(
        targetRow,
        100.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(targetRow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DataSyncPage).hitTestable(), findsOneWidget);
      final dataSyncBack = find.descendant(
        of: find.byType(DataSyncPage),
        matching: find.widgetWithIcon(IconButton, Icons.arrow_back),
      );
      expect(dataSyncBack, findsOneWidget);
      await tester.tap(dataSyncBack);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SettingsPage).hitTestable(), findsOneWidget);
      expect(find.byType(DataSyncPage).hitTestable(), findsNothing);
    });
  });
}
