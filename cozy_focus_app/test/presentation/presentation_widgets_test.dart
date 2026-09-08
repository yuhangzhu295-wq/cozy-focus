import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/pages/home_page.dart';
import 'package:cozy_focus_app/presentation/pages/focus_setup_page.dart';
import 'package:cozy_focus_app/presentation/pages/focus_active_page.dart';
import 'package:cozy_focus_app/presentation/pages/focus_complete_page.dart';
import 'package:cozy_focus_app/presentation/pages/focus_save_page.dart';
import 'package:cozy_focus_app/presentation/pages/focus_reward_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

class WidgetTestClock implements FocusClock {
  DateTime _now;
  WidgetTestClock(this._now);
  void advance(Duration d) => _now = _now.add(d);
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
  late WidgetTestClock testClock;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    testClock = WidgetTestClock(DateTime(2026, 9, 8, 10, 0, 0));
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider.overrideWithValue(testClock),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Phase 2 Widget Rendering & Interactions Tests', () {
    testWidgets('Screen 01: HomePage renders pet greeting and start button', (tester) async {
      await tester.pumpWidget(createTestApp(container, const HomePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Cozy Focus'), findsOneWidget);
      expect(find.textContaining('今日尚未开启专注'), findsOneWidget);
      expect(find.text('开始专注 >'), findsOneWidget);
    });

    testWidgets('Screen 02: FocusSetupPage renders categories and mode options', (tester) async {
      await tester.pumpWidget(createTestApp(container, const FocusSetupPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('设置专注'), findsOneWidget);
      expect(find.text('选择分类'), findsOneWidget);
      expect(find.text('学习'), findsWidgets);
      expect(find.text('工作'), findsWidgets);
      expect(find.text('阅读'), findsWidgets);
      expect(find.text('生活'), findsWidgets);
      expect(find.text('开始专注'), findsOneWidget);
    });

    testWidgets('Screen 03: FocusActivePage shows timer and pause/resume button', (tester) async {
      // Start session first
      final engine = container.read(focusSessionEngineProvider);
      await engine.start(
        userId: 'widget_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
      );

      await tester.pumpWidget(createTestApp(container, const FocusActivePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('专注中'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Cancel session to stop ticker
      await container.read(focusSessionControllerProvider.notifier).cancelSession();
    });

    testWidgets('Screen 04: FocusCompletePage renders celebration and minutes', (tester) async {
      await tester.pumpWidget(createTestApp(container, const FocusCompletePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('专注完成'), findsOneWidget);
      expect(find.text('Great Work!'), findsOneWidget);
      expect(find.text('继续保存记录'), findsOneWidget);
    });

    testWidgets('Screen 04A: FocusSavePage allows mood selection & save', (tester) async {
      await tester.pumpWidget(createTestApp(container, const FocusSavePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('保存本次记录'), findsOneWidget);
      expect(find.text('心情'), findsOneWidget);
      expect(find.text('记录这一刻的心情、感悟或收获...'), findsOneWidget);
      expect(find.text('保存记录'), findsOneWidget);
    });

    testWidgets('Screen 04B: FocusRewardPage renders rewards and return CTA', (tester) async {
      await tester.pumpWidget(createTestApp(container, const FocusRewardPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

     expect(find.text('获得奖励'), findsOneWidget);
      expect(find.text('制作工坊'), findsOneWidget);
      expect(find.text('返回首页'), findsOneWidget);
    });
  });
}
