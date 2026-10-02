import 'package:cozy_focus_app/core/auth/current_user.dart';
import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/animations/pet_idle_fallback_view.dart';
import 'package:cozy_focus_app/presentation/animations/pet_interaction_spec.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_random_source_provider.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/random_source.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_sprite_player.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/home_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReachabilityTestClock implements FocusClock {
  final DateTime _now = DateTime(2026, 9, 16, 9);

  @override
  DateTime now() => _now;
}

Widget _testApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const HomePage(),
    ),
  );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider.overrideWithValue(_ReachabilityTestClock()),
        // Pin behaviour selection. Without this the director draws from the
        // system RNG, so which pose Mochi presents varies run to run — and a
        // pose with its own sprite drawing routes the avatar through the sprite
        // player rather than the layered rig this test reads.
        companionRandomSourceProvider
            .overrideWithValue(const FixedRandomSource()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  PetAvatarWidget homeAvatar(WidgetTester tester) {
    return tester.widget<PetAvatarWidget>(find.byType(PetAvatarWidget));
  }

  /// The action a production sprite sequence is presenting, or `null` when the
  /// approved layered rig is drawing instead.
  ///
  /// A focus session can now be presented either way: the V4.2.1 macro actions
  /// ship as sprite sequences, while idle keeps the rig because micro-motion is
  /// its whole content. The shared gesture and controller contract is identical,
  /// so these tests read whichever channel is really in use.
  String? spriteAction(WidgetTester tester) {
    final finder = find.byType(CompanionSpritePlayer);
    if (finder.evaluate().isEmpty) return null;
    return tester.widget<CompanionSpritePlayer>(finder.first).spec.actionId;
  }

  PetIdleFallbackViewState fallbackState(WidgetTester tester) {
    return tester.state<PetIdleFallbackViewState>(
      find.byType(PetIdleFallbackView),
    );
  }

  testWidgets(
      'Home idle Mochi exposes the fallback interaction without changing session data',
      (tester) async {
    await tester.pumpWidget(_testApp(container));
    await tester.pump();

    final avatar = homeAvatar(tester);
    final controller = avatar.controller!;
    final fallback = fallbackState(tester);
    final homeBeforeTap = container.read(homeControllerProvider);
    final focusBeforeTap = container.read(focusSessionControllerProvider);
    final sessionsBeforeTap = await db.select(db.focusSessions).get();
    final recordsBeforeTap = await db.select(db.focusRecords).get();
    final rewardsBeforeTap = await db.select(db.rewardLedgerTable).get();

    expect(avatar.enableRive, isFalse);
    expect(controller.visualState, PetVisualState.idle);
    expect(
      find.descendant(
        of: find.byType(PetAvatarWidget),
        matching: find.byType(GestureDetector),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(PetAvatarWidget));
    await tester.pump();

    expect(fallback.interactController.isAnimating, isTrue);
    expect(controller.visualState, PetVisualState.idle);
    expect(container.read(homeControllerProvider), same(homeBeforeTap));
    expect(
        container.read(focusSessionControllerProvider), same(focusBeforeTap));
    expect(await db.select(db.focusSessions).get(), sessionsBeforeTap);
    expect(await db.select(db.focusRecords).get(), recordsBeforeTap);
    expect(await db.select(db.rewardLedgerTable).get(), rewardsBeforeTap);

    await tester.pump(const Duration(milliseconds: 751));
    expect(fallback.interactController.isAnimating, isFalse);
  });

  testWidgets(
      'Home entered with an active session shows focus Mochi that answers a tap',
      (tester) async {
    await container.read(focusSessionControllerProvider.notifier).startSession(
          userId: localMvpUserId,
          plannedSeconds: 1500,
          mode: FocusMode.focus,
        );
    await container.read(homeControllerProvider.notifier).loadHomeData();

    await tester.pumpWidget(_testApp(container));
    await tester.pump();

    final controller = homeAvatar(tester).controller!;

    expect(controller.visualState, PetVisualState.focus);
    // Two channels can present a focus session. A production sprite sequence is
    // its own animation, so the rig's blink / ear-twitch timers are stopped; the
    // layered rig keeps its two scheduler timers running. Either way the base
    // state stays focus, which is what this test is about.
    final presentingSprites = spriteAction(tester) != null;
    if (!presentingSprites) {
      expect(controller.activeTimerCount, 2);
    }

    await tester.tap(find.byType(PetAvatarWidget));
    await tester.pump();

    // STAGE 4: a tap during focus used to be silently dropped, which read as
    // broken rather than as considerate. Mochi now answers with a glance — a
    // short head-and-eyes response — and stays in focus throughout.
    if (!presentingSprites) {
      final fallback = fallbackState(tester);
      expect(fallback.interactController.isAnimating, isTrue);
      expect(fallback.interactionKind, PetInteractionKind.glance);
      // And the glance is *only* a glance: no body movement, so the focus pose
      // underneath is not replaced.
      expect(fallback.interactionSpec!.tapBodyTiltDegrees, 0.0);
      expect(fallback.interactionSpec!.tapScalePeak, 1.0);
    }
    expect(controller.visualState, PetVisualState.focus);

    await container
        .read(focusSessionControllerProvider.notifier)
        .cancelSession();
  });

  testWidgets('Home unmount disposes its page-owned Mochi controller',
      (tester) async {
    await tester.pumpWidget(_testApp(container));
    await tester.pump();

    final controller = homeAvatar(tester).controller!;
    expect(controller.isDisposed, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(controller.isDisposed, isTrue);
    expect(controller.activeTimerCount, 0);
    expect(controller.triggerInteract(), isFalse);
  });
}
