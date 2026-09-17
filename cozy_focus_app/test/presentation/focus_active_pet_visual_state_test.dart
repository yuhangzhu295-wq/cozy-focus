import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/pages/focus_active_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';

class TestClock implements FocusClock {
  DateTime _now;
  TestClock(this._now);
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
  late TestClock testClock;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    testClock = TestClock(DateTime(2026, 9, 8, 10, 0, 0));
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

  void setScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('FocusActivePage PetVisualState Regression Tests', () {
    testWidgets(
        'Test A: Tap 提前结束, dialog opens, verify PetAvatarWidget has PetVisualState.pause',
        (tester) async {
      setScreenSize(tester);

      final engine = container.read(focusSessionEngineProvider);
      await engine.start(
        userId: 'default_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
      );

      await tester
          .pumpWidget(createTestApp(container, const FocusActivePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('提前结束'), findsOneWidget);
      await tester.tap(find.text('提前结束'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('提前结束专注吗？'), findsOneWidget);

      final dialogFinder = find.byType(Dialog);
      expect(dialogFinder, findsOneWidget);

      final avatarFinder = find.descendant(
        of: dialogFinder,
        matching: find.byType(PetAvatarWidget),
      );
      expect(avatarFinder, findsOneWidget);

      final avatar = tester.widget<PetAvatarWidget>(avatarFinder);
      expect(avatar.visualState, equals(PetVisualState.pause));
      expect(avatar.size, equals(80));

      await container
          .read(focusSessionControllerProvider.notifier)
          .cancelSession();
    });

    testWidgets('Test B: Restore overlay triggers PetVisualState.focus',
        (tester) async {
      setScreenSize(tester);

      final engine = container.read(focusSessionEngineProvider);
      await engine.start(
        userId: 'default_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
      );

      await tester
          .pumpWidget(createTestApp(container, const FocusActivePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Simulate app lifecycle change to resumed
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('已恢复专注状态'), findsOneWidget);

      final overlayAvatarFinder = find.byType(PetAvatarWidget);
      expect(overlayAvatarFinder, findsOneWidget);

      final avatar = tester.widget<PetAvatarWidget>(overlayAvatarFinder);
      expect(avatar.visualState, equals(PetVisualState.focus));
      expect(avatar.size, equals(120));

      await container
          .read(focusSessionControllerProvider.notifier)
          .cancelSession();
    });

    testWidgets('Test C: Normal running screen binds to sessionState.petState',
        (tester) async {
      setScreenSize(tester);

      final engine = container.read(focusSessionEngineProvider);
      await engine.start(
        userId: 'default_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
      );

      await tester
          .pumpWidget(createTestApp(container, const FocusActivePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Running session should have PetVisualState.focus
      var avatarFinder = find.byType(PetAvatarWidget);
      expect(avatarFinder, findsOneWidget);
      var avatar = tester.widget<PetAvatarWidget>(avatarFinder);
      expect(avatar.visualState, equals(PetVisualState.focus));
      expect(avatar.size, equals(160));

      // Pause session via controller
      final controller =
          container.read(focusSessionControllerProvider.notifier);
      await controller.pauseSession();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Paused session should reflect PetVisualState.pause
      avatarFinder = find.byType(PetAvatarWidget);
      expect(avatarFinder, findsOneWidget);
      avatar = tester.widget<PetAvatarWidget>(avatarFinder);
      expect(avatar.visualState, equals(PetVisualState.pause));

      // Resume session via controller
      await controller.resumeSession();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Resumed session returns to PetVisualState.focus
      avatarFinder = find.byType(PetAvatarWidget);
      expect(avatarFinder, findsOneWidget);
      avatar = tester.widget<PetAvatarWidget>(avatarFinder);
      expect(avatar.visualState, equals(PetVisualState.focus));

      await controller.cancelSession();
    });
  });
}
