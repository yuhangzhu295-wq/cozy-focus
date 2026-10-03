import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/presentation/companion/companion_avatar.dart';
import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/procedural_companion_art.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_behavior_director.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_sprite_player.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_presentation_clock.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/random_source.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/pet_motion_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

import '../presentation/companion/runtime/catalog_test_support.dart';

class _PresetHomeController extends HomeController {
  final HomeUIState _preset;
  _PresetHomeController(super.ref, this._preset);

  @override
  Future<void> loadHomeData() async {
    state = _preset;
  }
}

/// A craft controller that reports no active job.
class _IdleCraftController extends CraftController {
  _IdleCraftController({
    required super.repo,
    required super.engine,
    required super.clock,
    required super.userId,
  });

  @override
  Future<void> loadAll() async {}
}

/// Lifecycle and resource audits required by §61 and §65 of the brief.
///
/// These assert the *absence* of resources after a widget is gone. A leak is
/// invisible to a functional test — the screen still works while a timer ticks
/// into nothing — so it has to be asserted directly.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  ProviderContainer containerWith(HomeUIState home) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        companionSelectionStoreProvider
            .overrideWithValue(InMemoryCompanionSelectionStore()),
        homeControllerProvider
            .overrideWith((ref) => _PresetHomeController(ref, home)),
        craftControllerProvider.overrideWith(
          (ref) => _IdleCraftController(
            repo: ref.read(craftRepositoryProvider),
            engine: ref.read(craftEngineProvider),
            clock: ref.read(focusClockProvider),
            userId: 'default_user',
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Widget app(ProviderContainer c, Widget child) => UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: Center(child: child)),
        ),
      );

  group('the presentation scheduler releases everything', () {
    testWidgets('no frame callback and no pending timer survive disposal',
        (tester) async {
      final c = containerWith(const HomeUIState(hasActiveSession: true));
      await tester.pumpWidget(app(c, const CompanionAvatar(size: 140)));
      await tester.pump();
      await tester.pump(CompanionPresentationClock.tickInterval);

      // While mounted, the clock is running and holds a periodic timer.
      final clockState = tester.state<State<CompanionPresentationClock>>(
        find.byType(CompanionPresentationClock),
      );
      expect((clockState as dynamic).isRunning, isTrue);

      await tester.pumpWidget(app(c, const SizedBox.shrink()));
      await tester.pump();

      // A surviving periodic timer fails this test at teardown with
      // "A Timer is still pending". Asserting it explicitly makes the intent
      // readable rather than relying on the framework's message.
      expect(find.byType(CompanionPresentationClock), findsNothing);
      expect(tester.binding.transientCallbackCount, 0,
          reason: 'the presentation clock must not leave a frame callback');
    });

    testWidgets('the clock itself requests no frame callback', (tester) async {
      // Mounted on its own, with no renderer: the approved Mochi renderer
      // legitimately holds AnimationControllers for breathing and blinking, so
      // measuring the two together would prove nothing about the clock. This
      // isolates the claim to the scheduler.
      final director = CompanionBehaviorDirector(
        catalog: loadShippedCatalog(),
        context: const CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.home,
        ),
        random: SeededRandomSource(1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CompanionPresentationClock(
            director: director,
            builder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      // A Ticker-based clock would hold a transient callback here, which is what
      // keeps an idle app from ever settling.
      expect(
        tester.binding.transientCallbackCount,
        0,
        reason: 'the scheduler must not hold a frame callback',
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
    });
  });

  group('repeated rebuilds do not accumulate listeners or timers', () {
    testWidgets('the motion controller returns to zero listeners and timers',
        (tester) async {
      final c = containerWith(const HomeUIState(hasActiveSession: true));
      final controller = PetMotionController();

      for (var i = 0; i < 6; i++) {
        await tester.pumpWidget(
          app(c, CompanionAvatar(size: 140, controller: controller)),
        );
        await tester.pump();
        await tester.pump(CompanionPresentationClock.tickInterval);
      }

      // Mounted repeatedly, then removed.
      await tester.pumpWidget(app(c, const SizedBox.shrink()));
      await tester.pump();

      expect(controller.listenerCount, 0,
          reason: 'a supplied controller must not accumulate listeners');
      expect(controller.activeTimerCount, 0,
          reason: 'no blink / ear-twitch timer may outlive the widget');

      controller.dispose();
    });

    testWidgets('switching companion repeatedly leaks nothing', (tester) async {
      final c = containerWith(const HomeUIState(hasActiveSession: true));
      final selection = c.read(companionSelectionProvider.notifier);

      for (final id in [
        CompanionId.cat,
        CompanionId.rabbit,
        CompanionId.dog,
        CompanionId.cat,
      ]) {
        await selection.select(id);
        await tester.pumpWidget(app(c, const CompanionAvatar(size: 140)));
        await tester.pump();
        await tester.pump(CompanionPresentationClock.tickInterval);
      }

      await tester.pumpWidget(app(c, const SizedBox.shrink()));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('lifecycle transitions leave no stuck state', () {
    testWidgets('background then foreground resumes the same behaviour',
        (tester) async {
      final c = containerWith(const HomeUIState(hasActiveSession: true));
      await tester.pumpWidget(app(c, const CompanionAvatar(size: 140)));
      await tester.pump();
      await tester.pump(CompanionPresentationClock.tickInterval);

      final clock = tester.state<State<CompanionPresentationClock>>(
        find.byType(CompanionPresentationClock),
      );
      final before = (clock as dynamic).elapsed as Duration;

      // Hidden: the scheduler stops, so hidden time is not presentation time.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect((clock as dynamic).isRunning, isFalse);

      await tester.pump(const Duration(seconds: 5));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect((clock as dynamic).isRunning, isTrue);
      expect(
        (clock as dynamic).elapsed,
        before,
        reason: 'backgrounded time must not advance a behaviour',
      );
    });

    testWidgets('reduced motion toggling mid-flight leaves no pending timer',
        (tester) async {
      final c = containerWith(const HomeUIState(hasActiveSession: true));

      for (final disable in [true, false, true, false]) {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(disableAnimations: disable),
            child: app(c, const CompanionAvatar(size: 140)),
          ),
        );
        await tester.pump();
        await tester.pump(CompanionPresentationClock.tickInterval);
      }

      await tester.pumpWidget(app(c, const SizedBox.shrink()));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('a placeholder companion releases its micro-motion', () {
    testWidgets('the cat animates, and releases everything on disposal',
        (tester) async {
      final c = containerWith(const HomeUIState());
      final selection = c.read(companionSelectionProvider.notifier);
      await selection.select(CompanionId.cat);

      await tester.pumpWidget(app(c, const CompanionAvatar(size: 140)));
      await tester.pump();

      // Two channels can present the cat. Where it has a production sequence the
      // sequence is its own animation and the placeholder's breathing controller
      // is not in the tree at all; where it does not, the procedural art breathes
      // and a frame callback is expected while it is mounted.
      final presentingSprites =
          find.byType(CompanionSpritePlayer).evaluate().isNotEmpty;
      if (presentingSprites) {
        expect(find.byType(ProceduralCompanionArt), findsNothing,
            reason: 'a sprite sequence replaces the procedural placeholder');
      } else {
        expect(
          tester.binding.transientCallbackCount,
          greaterThan(0),
          reason: 'a placeholder companion must not be frozen',
        );
      }

      await tester.pumpWidget(app(c, const SizedBox.shrink()));
      await tester.pump();

      // Disposal must release the breathing controller and both blink timers; a
      // survivor fails this test at teardown with "A Timer is still pending".
      expect(find.byType(CompanionSpritePlayer), findsNothing);
      expect(find.byType(ProceduralCompanionArt), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('reduced motion stops the breathing entirely', (tester) async {
      final c = containerWith(const HomeUIState());
      await c
          .read(companionSelectionProvider.notifier)
          .select(CompanionId.rabbit);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: app(c, const CompanionAvatar(size: 140)),
        ),
      );
      await tester.pump();

      // The semantic pose is preserved; only the movement is dropped.
      //
      // Which channel draws it depends on whether the companion ships a
      // production sequence for the pose. The rabbit used to have no pack and
      // always took the procedural path; now that its `idle` ships, it takes the
      // sprite path. The invariant is the same either way, so it is asserted
      // rather than the channel.
      expect(
        find.byType(ProceduralCompanionArt).evaluate().isNotEmpty ||
            find.byType(CompanionSpritePlayer).evaluate().isNotEmpty,
        isTrue,
        reason: 'the companion must still be drawn under reduced motion',
      );
      expect(tester.binding.transientCallbackCount, 0,
          reason: 'reduced motion must stop the breathing controller');
    });
  });

  group('the director owns no timer of its own', () {
    test('advancing it a thousand times creates nothing to release', () {
      // The director is a plain object with no dispose(), because it holds no
      // resource. This is the structural half of the leak audit: there is
      // nothing to leak because there is nothing to own.
      final director = CompanionBehaviorDirector(
        catalog: loadShippedCatalog(),
        context: const CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.home,
        ),
        random: SeededRandomSource(3),
      );

      for (var ms = 0; ms <= 1000000; ms += 1000) {
        director.advanceTo(Duration(milliseconds: ms));
      }
      expect(director.currentMacroBehavior, isNotNull);
    });

    test('its source owns no timer, ticker or stream', () {
      // If the director ever gains a resource it will need a dispose, and the
      // presentation clock must then be the thing that calls it. Reading the
      // source is the only way to assert the absence of a subscription.
      // Comments are stripped first: the director's own docs *say* it owns no
      // Timer, and matching that prose would be a false positive.
      final source = File(
        'lib/presentation/companion/runtime/companion_behavior_director.dart',
      )
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      for (final forbidden in [
        'Timer',
        'Ticker',
        'StreamSubscription',
        'AnimationController',
        'addListener',
        'dispose(',
      ]) {
        expect(
          source.contains(forbidden),
          isFalse,
          reason:
              'the director must own no resource, but mentions "$forbidden"',
        );
      }
    });
  });
}
