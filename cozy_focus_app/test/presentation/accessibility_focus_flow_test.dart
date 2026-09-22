import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cozy_focus_app/core/auth/current_user.dart';
import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/animations/pet_idle_fallback_view.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/pet_motion_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/focus_active_page.dart';
import 'package:cozy_focus_app/presentation/pages/home_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';

class _FixedClock implements FocusClock {
  DateTime _now = DateTime(2026, 9, 18, 10, 0, 0);
  @override
  DateTime now() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

void main() {
  group('Accessibility: Semantics and 2.0x Text Scale Suite', () {
    late AppDatabase db;
    late _FixedClock clock;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      clock = _FixedClock();
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

    testWidgets(
        '1. PetAvatarWidget exposes accessible semantics for idle state and triggers interact',
        (tester) async {
      final controller = PetMotionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PetAvatarWidget(
              visualState: PetVisualState.idle,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the pet interactive Semantics node. The hint is per state now —
      // it used to say "仅空闲时可互动", which stopped being true in STAGE 4:
      // Mochi answers in every base state, with a different response in each.
      final petSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Mochi 空闲' &&
            widget.properties.button == true &&
            widget.properties.hint == '点一下会回应，长按可以摸摸头',
      );
      expect(petSemantics, findsOneWidget);

      final fallback = tester.state<PetIdleFallbackViewState>(
        find.byType(PetIdleFallbackView),
      );
      expect(fallback.interactController.isAnimating, isFalse);
      expect(fallback.strokeController.isAnimating, isFalse);

      // Tap on the Semantics / Pet
      await tester.tap(petSemantics);
      await tester.pump();

      expect(fallback.interactController.isAnimating, isTrue);
      expect(fallback.strokeController.isAnimating, isFalse);
      expect(controller.visualState, PetVisualState.idle);

      await tester.pump(const Duration(milliseconds: 751));
      expect(fallback.interactController.isAnimating, isFalse);

      // Long press is the "轻抚" gesture and drives its own controller, so the
      // two gestures cannot swallow each other.
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.longPress(petSemantics);
      await tester.pump();

      expect(fallback.strokeController.isAnimating, isTrue);
      expect(fallback.interactController.isAnimating, isFalse);
      expect(controller.visualState, PetVisualState.idle);
    });

    testWidgets(
        '2. PetAvatarWidget reflects actual visualState in Semantics label',
        (tester) async {
      final controller = PetMotionController(visualState: PetVisualState.focus);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PetAvatarWidget(
              visualState: PetVisualState.focus,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      // STAGE 4: a non-idle state is still a button, because Mochi answers in
      // every base state. What changes per state is the *hint*, so a screen
      // reader user knows whether a tap will interrupt what they are doing.
      void expectSemantics(String label, String hint) {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == label &&
                widget.properties.button == true &&
                widget.properties.hint == hint &&
                widget.properties.onTap != null &&
                widget.properties.onLongPress != null,
          ),
          findsOneWidget,
          reason: 'no semantics node for "$label" / "$hint"',
        );
      }

      expectSemantics('Mochi 专注中', '点一下会看你一眼，不会打断专注');

      final semanticsHandle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Mochi 专注中'), findsOneWidget);
      semanticsHandle.dispose();

      controller.updateState(PetVisualState.pause);
      await tester.pump();
      expectSemantics('Mochi 暂停中', '点一下会安静地陪着你');

      controller.updateState(PetVisualState.craft);
      await tester.pump();
      expectSemantics('Mochi 制作中', '点一下会回应一下，不会打断制作');
    });

    testWidgets('3. HomePage primary focus button provides button Semantics',
        (tester) async {
      final handle = tester.ensureSemantics();

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomePage(),
          ),
        ),
      );
      await tester.pump();

      final startFocusButton = find.bySemanticsLabel('开始专注');
      expect(startFocusButton, findsOneWidget);
      final semantics = tester.getSemantics(startFocusButton);
      expect(semantics.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(semantics.label, contains('开始专注'));
      handle.dispose();
    });

    testWidgets(
        '4. FocusActivePage exposes read-only timer and running/paused Semantics',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Start a 25 min session
      final sessionNotifier =
          container.read(focusSessionControllerProvider.notifier);
      await sessionNotifier.startSession(
        userId: localMvpUserId,
        plannedSeconds: 1500,
        mode: FocusMode.focus,
        taskName: '阅读',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const FocusActivePage(),
          ),
        ),
      );
      await tester.pump();

      // Running semantics
      final runningTimerSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.readOnly == true &&
            widget.properties.label == '专注计时 25:00，当前专注中',
      );
      expect(runningTimerSemantics, findsOneWidget);

      // Pause session
      clock.advance(const Duration(minutes: 5));
      await sessionNotifier.pauseSession();
      await tester.pump();

      // Paused semantics
      final pausedTimerSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.readOnly == true &&
            widget.properties.label == '专注计时 20:00，当前已暂停',
      );
      expect(pausedTimerSemantics, findsOneWidget);

      await sessionNotifier.cancelSession();
    });

    testWidgets(
        '5. HomePage renders robustly under TextScaler.linear(2.0) without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: HomePage(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(PetAvatarWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '6. FocusActivePage renders robustly under TextScaler.linear(2.0) without unhandled exceptions',
        (tester) async {
      final sessionNotifier =
          container.read(focusSessionControllerProvider.notifier);
      await sessionNotifier.startSession(
        userId: localMvpUserId,
        plannedSeconds: 1500,
        mode: FocusMode.focus,
        taskName: '无障碍测试',
      );

      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: FocusActivePage(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FocusActivePage), findsOneWidget);
      expect(tester.takeException(), isNull);

      await sessionNotifier.cancelSession();
    });
  });
}
