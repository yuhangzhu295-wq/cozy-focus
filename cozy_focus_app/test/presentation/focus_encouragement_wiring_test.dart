import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/companion/companion_avatar.dart';
import 'package:cozy_focus_app/presentation/companion/pet_encouragement.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/focus_active_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

class TestClock implements FocusClock {
  DateTime _now;
  TestClock(this._now);
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
}

/// The encouragement channel, proven end to end on the real screen.
///
/// `pet_encouragement_test.dart` proves the engine's *decisions*; this file
/// proves the decisions actually reach the active-focus render tree, and that
/// the channel cannot disturb the controls that share that screen.
void main() {
  late AppDatabase db;
  late TestClock testClock;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // 10:00 local — comfortably outside the late-night band, so the copy under
    // test does not depend on the hour the suite happens to run at.
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

  Future<void> startSession({int plannedSeconds = 1500}) async {
    await container.read(focusSessionEngineProvider).start(
          userId: 'default_user',
          plannedSeconds: plannedSeconds,
          mode: FocusMode.focus,
        );
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const FocusActivePage(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Moves the real clock forward and lets the session's own display ticker
  /// observe it. Nothing here drives the encouragement engine directly — it is
  /// reached only through the session tick, exactly as in production.
  Future<void> elapse(WidgetTester tester, Duration duration) async {
    testClock.advance(duration);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Ends the session so its one-second ticker is not still pending when the
  /// widget tree is torn down — the test framework asserts on that.
  Future<void> stopSession(WidgetTester tester) async {
    await container
        .read(focusSessionControllerProvider.notifier)
        .cancelSession();
    await tester.pump();
  }

  String? displayedMessage(WidgetTester tester) {
    final avatar = tester.widget<CompanionAvatar>(find.byType(CompanionAvatar));
    return avatar.message;
  }

  group('the encouragement channel reaches the active focus screen', () {
    testWidgets('Mochi is silent in the opening seconds', (tester) async {
      setScreenSize(tester);
      await startSession();
      await pumpPage(tester);

      await elapse(tester, const Duration(seconds: 10));

      expect(displayedMessage(tester), isNull,
          reason: 'Mochi spoke before the opening delay elapsed');

      await stopSession(tester);
    });

    testWidgets('the opening line appears once the session is under way',
        (tester) async {
      setScreenSize(tester);
      await startSession();
      await pumpPage(tester);

      await elapse(
          tester,
          PetEncouragementBudget.firstMessageDelay +
              const Duration(seconds: 5));

      final message = displayedMessage(tester);
      expect(message, isNotNull);
      expect(
        PetEncouragementCopy.table[PetMessageKind.startEncouragement],
        contains(message),
        reason: 'the first thing Mochi says should be the opening line',
      );

      await stopSession(tester);
    });

    testWidgets('a paused session gets the comfort line', (tester) async {
      setScreenSize(tester);
      await startSession();
      await pumpPage(tester);

      await elapse(
          tester,
          PetEncouragementBudget.firstMessageDelay +
              const Duration(seconds: 5));

      await tester.tap(find.text('暂停'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The pause is a distinct event, so it may speak after the shorter pause
      // gap rather than waiting out the full 150 s.
      await elapse(tester,
          PetEncouragementBudget.minGapAfterPause + const Duration(seconds: 2));

      final message = displayedMessage(tester);
      expect(message, isNotNull);
      expect(
        PetEncouragementCopy.table[PetMessageKind.pauseComfort],
        contains(message),
      );

      await stopSession(tester);
    });

    testWidgets('the bubble clears when its window closes', (tester) async {
      setScreenSize(tester);
      await startSession();
      await pumpPage(tester);

      await elapse(
          tester,
          PetEncouragementBudget.firstMessageDelay +
              const Duration(seconds: 5));
      expect(displayedMessage(tester), isNotNull);

      await elapse(tester,
          PetEncouragementBudget.displayDuration + const Duration(seconds: 2));
      expect(displayedMessage(tester), isNull,
          reason: 'the bubble outlived its display window');

      await stopSession(tester);
    });

    testWidgets('a whole session stays inside the message budget',
        (tester) async {
      setScreenSize(tester);
      // A 30-minute session swept for 25 minutes: long enough to exercise the
      // whole budget, short enough that the session never auto-completes (which
      // would navigate away from this screen).
      await startSession(plannedSeconds: 30 * 60);
      await pumpPage(tester);

      // A message is on screen for 12 s at a time, so the bubble is sampled
      // every 5 s and the distinct lines are counted. Because every line is
      // unique per kind and stage, the distinct count is the message count.
      final seen = <String>{};
      for (var i = 0; i < 25 * 60 ~/ 5; i++) {
        await elapse(tester, const Duration(seconds: 5));
        final message = displayedMessage(tester);
        if (message != null) seen.add(message);
      }

      expect(seen.length,
          lessThanOrEqualTo(PetEncouragementBudget.maxMessagesPerSession),
          reason: 'Mochi produced ${seen.length} messages in one session');
      expect(seen, isNotEmpty);

      await stopSession(tester);
    });
  });

  group('the encouragement channel cannot disturb the controls', () {
    testWidgets('the pause control still works while Mochi is speaking',
        (tester) async {
      setScreenSize(tester);
      await startSession();
      await pumpPage(tester);

      await elapse(
          tester,
          PetEncouragementBudget.firstMessageDelay +
              const Duration(seconds: 5));
      expect(displayedMessage(tester), isNotNull,
          reason: 'this test only means something while the bubble is up');

      await tester.tap(find.text('暂停'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('继续专注'), findsOneWidget,
          reason: 'the bubble absorbed the pause tap');
      expect(
        container.read(focusSessionControllerProvider).session?.status,
        FocusSessionStatus.paused,
      );

      await stopSession(tester);
    });

    testWidgets('the timer keeps counting while Mochi is speaking',
        (tester) async {
      setScreenSize(tester);
      await startSession();
      await pumpPage(tester);

      await elapse(
          tester,
          PetEncouragementBudget.firstMessageDelay +
              const Duration(seconds: 5));
      expect(displayedMessage(tester), isNotNull);

      final before =
          container.read(focusSessionControllerProvider).elapsedSeconds;
      await elapse(tester, const Duration(seconds: 10));
      final after =
          container.read(focusSessionControllerProvider).elapsedSeconds;

      expect(after - before, 10,
          reason: 'the encouragement channel must not stall the session clock');

      await stopSession(tester);
    });
  });
}
