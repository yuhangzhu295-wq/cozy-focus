import 'package:cozy_focus_app/core/auth/current_user.dart';
import 'package:cozy_focus_app/data/local/app_database.dart'
    hide CraftJob, CraftRecipe;
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/animations/pet_idle_fallback_view.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_random_source_provider.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/random_source.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_sprite_player.dart';
import 'package:cozy_focus_app/presentation/animations/pet_motion_spec.dart';
import 'package:cozy_focus_app/presentation/companion/companion_avatar.dart';
import 'package:cozy_focus_app/presentation/companion/mochi_layered_renderer.dart';
import 'package:cozy_focus_app/presentation/companion/pet_craft_activity.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/pet_motion_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/navigation/app_router.dart';
import 'package:cozy_focus_app/presentation/pages/settings_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A fresh router per test. The shared global kept its location between tests
/// in a file, so each test silently inherited the previous one's route.
late GoRouter router;

/// Deterministic blink / ear-twitch scheduler for lifecycle assertions.
class _FixedScheduler implements IPetMotionScheduler {
  final Duration blinkInterval;
  final Duration earTwitchInterval;

  const _FixedScheduler({
    this.blinkInterval = const Duration(milliseconds: 400),
    this.earTwitchInterval = const Duration(milliseconds: 600),
  });

  @override
  Duration nextBlinkInterval() => blinkInterval;

  @override
  Duration nextEarTwitchInterval() => earTwitchInterval;
}

class _FixedClock implements FocusClock {
  final DateTime _now = DateTime(2026, 9, 19, 9);
  @override
  DateTime now() => _now;
}

class _PresetHomeController extends HomeController {
  final HomeUIState preset;
  _PresetHomeController(super.ref, this.preset);

  @override
  Future<void> loadHomeData() async {
    state = preset;
  }
}

class _PresetCraftController extends CraftController {
  final CraftState preset;
  _PresetCraftController({
    required super.repo,
    required super.engine,
    required super.clock,
    required super.userId,
    required this.preset,
  }) {
    // The pinned state is available from the first read; pages that never call
    // loadAll (Settings, Notifications, ...) still see the real business state.
    state = preset;
  }

  @override
  Future<void> loadAll() async {
    state = preset;
  }
}

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

PetIdleFallbackViewState _fallback(WidgetTester tester) => tester
    .state<PetIdleFallbackViewState>(find.byType(PetIdleFallbackView).first);

/// The visual state the renderer actually received — i.e. what the user sees.
///
/// Two renderers can be on screen. The approved layered rig reports its state
/// directly; a production sprite sequence reports the action it is playing, which
/// this maps back onto the same vocabulary. Reading whichever is present keeps the
/// assertion about what the user sees rather than about which channel drew it.
PetVisualState _renderedState(WidgetTester tester) {
  final fallbackFinder = find.byType(PetIdleFallbackView);
  if (fallbackFinder.evaluate().isNotEmpty) {
    return tester.widget<PetIdleFallbackView>(fallbackFinder.first).visualState;
  }
  final spriteFinder = find.byType(CompanionSpritePlayer);
  if (spriteFinder.evaluate().isNotEmpty) {
    return _stateForAction(
      tester.widget<CompanionSpritePlayer>(spriteFinder.first).spec.actionId,
    );
  }
  fail('no companion renderer is on screen');
}

/// The base state a production action presents.
PetVisualState _stateForAction(String actionId) => switch (actionId) {
      'focus_read' || 'focus_write' || 'focus_think' => PetVisualState.focus,
      'pause_rest' => PetVisualState.pause,
      'craft_work' => PetVisualState.craft,
      'celebrate' => PetVisualState.celebrate,
      'sleep' => PetVisualState.sleep,
      _ => PetVisualState.idle,
    };

CraftJob _job({required int progressSeconds}) => CraftJob(
      id: 'job-live-1',
      userId: localMvpUserId,
      recipeId: 'sofa',
      status: CraftJobStatus.inProgress,
      progressSeconds: progressSeconds,
      startedAt: DateTime(2026, 9, 19, 8),
      rewardClaimed: false,
    );

const _recipe = CraftRecipe(
  id: 'sofa',
  name: '沙发',
  requiredMinutes: 10,
  ingredientCosts: <String, int>{'wood': 2},
  outputItemId: 'sofa',
  outputQuantity: 1,
);

/// Builds a container whose business providers are pinned to known states.
ProviderContainer _container({
  required AppDatabase db,
  bool hasActiveSession = false,
  CraftState? craftState,
}) {
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(_FixedClock()),
      // Pin behaviour selection. The avatar builds its own director, so without
      // this the pool pick comes from the system RNG and "which beat is Mochi
      // in" varies run to run. The clock override above is not enough on its
      // own: it fixes the time-of-day *band*, not the draw within the pool.
      companionRandomSourceProvider
          .overrideWithValue(const FixedRandomSource()),
      homeControllerProvider.overrideWith(
        (ref) => _PresetHomeController(
          ref,
          HomeUIState(hasActiveSession: hasActiveSession),
        ),
      ),
      craftControllerProvider.overrideWith(
        (ref) => _PresetCraftController(
          repo: ref.watch(craftRepositoryProvider),
          engine: ref.watch(craftEngineProvider),
          clock: ref.watch(focusClockProvider),
          userId: localMvpUserId,
          preset: craftState ?? const CraftState(),
        ),
      ),
    ],
  );
  return container;
}

void main() {
  late AppDatabase db;

  setUp(() {
    router = createAppRouter();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // ==========================================================================
  // LIVE_MOCHI_INTERACTION_GATE
  //
  // The three defects these tests pin down:
  //   M-1  focusProgress / craftProgress reached the renderer but were never read
  //   M-3  celebrate / greeting looped forever instead of playing once
  //   M-4  craft froze ears and tail for the whole job
  // ==========================================================================

  group('M-1 · progress binding drives motion intensity', () {
    testWidgets('focusProgress maps to intensity and clamps outside 0..1',
        (tester) async {
      Future<double> intensityFor(double? progress) async {
        await tester.pumpWidget(
          _app(PetAvatarWidget(
            visualState: PetVisualState.focus,
            focusProgress: progress,
          )),
        );
        await tester.pump();
        return _fallback(tester).progressIntensity;
      }

      expect(await intensityFor(null), 1.0);
      expect(await intensityFor(0.0), PetMotionSpec.progressIntensityMin);
      expect(
        await intensityFor(0.5),
        closeTo(
          (PetMotionSpec.progressIntensityMin +
                  PetMotionSpec.progressIntensityMax) /
              2,
          1e-9,
        ),
      );
      expect(await intensityFor(1.0), PetMotionSpec.progressIntensityMax);

      // Clamping is enforced at the rendering boundary.
      expect(await intensityFor(-3.0), PetMotionSpec.progressIntensityMin);
      expect(await intensityFor(9.0), PetMotionSpec.progressIntensityMax);
    });

    testWidgets('each progress channel binds only to its own state',
        (tester) async {
      await tester.pumpWidget(
        _app(const PetAvatarWidget(
          visualState: PetVisualState.craft,
          focusProgress: 0.0,
          craftProgress: 1.0,
        )),
      );
      await tester.pump();
      // craft reads craftProgress only; the focus value must not leak in.
      expect(_fallback(tester).progressIntensity,
          PetMotionSpec.progressIntensityMax);

      await tester.pumpWidget(
        _app(const PetAvatarWidget(
          visualState: PetVisualState.idle,
          focusProgress: 0.0,
          craftProgress: 0.0,
        )),
      );
      await tester.pump();
      // idle carries no progress binding at all.
      expect(_fallback(tester).progressIntensity, 1.0);
    });

    testWidgets(
        'progress scales the delta from the neutral pose, never the pose',
        (tester) async {
      // A distinct Key per run forces a fresh State, so both runs start their
      // animation phase at zero and sample the very same time offsets.
      //
      // STAGE 5 note: `craftProgress` now drives *two* things — the intensity
      // binding measured here, and (via 11G) which craft beat is playing. A
      // plain time sweep therefore measures both at once and can no longer
      // isolate the binding, so the beat clock is parked inside the `pause`
      // beat for the whole sweep. `pause` is the one beat whose spec carries no
      // `dy` offset, which takes the beat layer out of the measurement without
      // weakening the claim: the binding must still scale the delta by exactly
      // the declared intensity ratio.
      double pausePositionFor(double progress) {
        final stage = PetCraftStageResolver.resolve(progress);
        final window = PetCraftActivitySchedule.windowsFor(stage)
            .firstWhere((w) => w.activity == PetCraftActivity.pause);
        return (window.start + window.end) / 2;
      }

      Future<List<double>> sampleDy(double craftProgress) async {
        await tester.pumpWidget(_app(const SizedBox.shrink()));
        await tester.pump();
        await tester.pumpWidget(
          _app(PetAvatarWidget(
            key: ValueKey(craftProgress),
            visualState: PetVisualState.craft,
            craftProgress: craftProgress,
          )),
        );
        await tester.pump();

        // The controller's `value` setter stops the animation, so the beat
        // stays parked while the sweep below advances time.
        _fallback(tester).workCycleController.value =
            pausePositionFor(craftProgress);
        await tester.pump();

        final samples = <double>[];
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          samples.add(_fallback(tester).bodyDyForTesting);
        }
        return samples;
      }

      final low = await sampleDy(0.0);
      final high = await sampleDy(1.0);

      double peak(List<double> xs) =>
          xs.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);

      final lowPeak = peak(low);
      final highPeak = peak(high);

      expect(lowPeak, greaterThan(0.0),
          reason: 'Progress 0.0 must still animate, just more calmly');
      expect(highPeak, greaterThan(lowPeak),
          reason: 'Progress 1.0 must animate more strongly than 0.0');

      // The amplitude ratio must match the declared intensity ratio.
      const expectedRatio = PetMotionSpec.progressIntensityMax /
          PetMotionSpec.progressIntensityMin;
      expect(highPeak / lowPeak, closeTo(expectedRatio, 0.05));
    });
  });

  group('M-3 · celebrate and greeting are one-shot triggers', () {
    testWidgets('celebrate plays once, settles, and never loops',
        (tester) async {
      await tester.pumpWidget(
        _app(const PetAvatarWidget(visualState: PetVisualState.celebrate)),
      );
      await tester.pump();

      final fallback = _fallback(tester);
      expect(fallback.celebrateController.isAnimating, isTrue,
          reason: 'The trigger must play when the state is entered');

      // Let the one-shot finish (cycle 1200ms).
      await tester.pump(PetMotionSpec.celebrateCycle);
      await tester.pump(const Duration(milliseconds: 50));

      expect(fallback.isCelebrateSettled, isTrue);
      expect(fallback.celebrateController.isAnimating, isFalse,
          reason: 'The big bounce must not repeat forever');

      // Handed back to base aliveness.
      expect(fallback.breatheController.isAnimating, isTrue);
      expect(fallback.tailController.isAnimating, isTrue);

      // Long observation window: it must stay settled.
      await tester.pump(const Duration(seconds: 20));
      expect(fallback.celebrateController.isAnimating, isFalse);
    });

    testWidgets('greeting plays once and settles', (tester) async {
      await tester.pumpWidget(
        _app(const PetAvatarWidget(visualState: PetVisualState.greeting)),
      );
      await tester.pump();

      final fallback = _fallback(tester);
      expect(fallback.greetingController.isAnimating, isTrue);

      await tester.pump(PetMotionSpec.greetingCycle);
      await tester.pump(const Duration(milliseconds: 50));

      expect(fallback.isGreetingSettled, isTrue);
      expect(fallback.greetingController.isAnimating, isFalse);

      await tester.pump(const Duration(seconds: 15));
      expect(fallback.greetingController.isAnimating, isFalse);
    });

    testWidgets('leaving a settled trigger re-arms it for the next entry',
        (tester) async {
      final controller = PetMotionController(
        visualState: PetVisualState.celebrate,
      );
      await tester.pumpWidget(
        _app(PetAvatarWidget(
          visualState: controller.visualState,
          controller: controller,
        )),
      );
      await tester.pump();
      await tester.pump(PetMotionSpec.celebrateCycle);
      await tester.pump(const Duration(milliseconds: 50));

      final fallback = _fallback(tester);
      expect(fallback.isCelebrateSettled, isTrue);

      controller.updateState(PetVisualState.idle);
      await tester.pump();
      expect(fallback.isCelebrateSettled, isFalse);

      controller.updateState(PetVisualState.celebrate);
      await tester.pump();
      expect(fallback.celebrateController.isAnimating, isTrue,
          reason: 'A second entry must play the trigger again');
      expect(fallback.isCelebrateSettled, isFalse);

      controller.dispose();
    });
  });

  group('M-4 · the ambient micro layer stays engaged in long states', () {
    for (final state in const [
      PetVisualState.focus,
      PetVisualState.pause,
      PetVisualState.craft,
    ]) {
      testWidgets('$state keeps tail, head, blink and ear twitch alive',
          (tester) async {
        final controller = PetMotionController(
          visualState: state,
          scheduler: const _FixedScheduler(
            blinkInterval: Duration(milliseconds: 400),
            earTwitchInterval: Duration(milliseconds: 600),
          ),
        );

        await tester.pumpWidget(
          _app(PetAvatarWidget(
            visualState: controller.visualState,
            controller: controller,
          )),
        );
        await tester.pump();

        final fallback = _fallback(tester);

        // Continuous channels run for the whole state.
        expect(fallback.tailController.isAnimating, isTrue);
        expect(fallback.headController.isAnimating, isTrue);

        // The tail channel must actually move the artwork, not be pinned at 0.
        final tailT0 = fallback.tailRotationForTesting;
        await tester.pump(const Duration(milliseconds: 600));
        expect(fallback.tailRotationForTesting, isNot(equals(tailT0)),
            reason: 'Tail must drift instead of freezing');

        // Discrete channels are scheduled, not disabled.
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          fallback.blinkController.isAnimating ||
              fallback.earTwitchController.isAnimating,
          isTrue,
          reason: 'Blink / ear-twitch must still be scheduled in $state',
        );

        // Body ambience stays owned by idle.
        expect(fallback.breatheController.isAnimating, isFalse);
        expect(fallback.swayController.isAnimating, isFalse);

        controller.dispose();
      });
    }

    testWidgets('sleep stays still apart from deep breathing', (tester) async {
      await tester.pumpWidget(
        _app(const PetAvatarWidget(visualState: PetVisualState.sleep)),
      );
      await tester.pump();

      final fallback = _fallback(tester);
      expect(fallback.sleepController.isAnimating, isTrue);
      expect(fallback.tailController.isAnimating, isFalse);
      expect(fallback.headController.isAnimating, isFalse);
      expect(fallback.blinkController.isAnimating, isFalse);
    });

    test('ambient gate covers exactly the long-lived base states', () {
      for (final state in const [
        PetVisualState.idle,
        PetVisualState.focus,
        PetVisualState.pause,
        PetVisualState.craft,
      ]) {
        final c = PetMotionController(visualState: state);
        expect(c.supportsAmbientMotion, isTrue, reason: '$state');
        c.dispose();
      }
      for (final state in const [
        PetVisualState.sleep,
        PetVisualState.celebrate,
        PetVisualState.greeting,
      ]) {
        final c = PetMotionController(visualState: state);
        expect(c.supportsAmbientMotion, isFalse, reason: '$state');
        c.dispose();
      }
    });

    test('a settled trigger may borrow ambient motion, and the loan is reset',
        () {
      final c = PetMotionController(visualState: PetVisualState.celebrate);
      expect(c.supportsAmbientMotion, isFalse);

      c.extendAmbientMotionTo(PetVisualState.celebrate);
      expect(c.supportsAmbientMotion, isTrue);

      // A real state transition discards the extension.
      c.updateState(PetVisualState.idle);
      expect(c.supportsAmbientMotion, isTrue); // idle is natively ambient
      c.updateState(PetVisualState.celebrate);
      expect(c.supportsAmbientMotion, isFalse);

      c.dispose();
    });
  });

  group('M-5 · the head carries a delayed response of its own', () {
    testWidgets('the head moves even when the body is completely still',
        (tester) async {
      // Pause holds the body at rotation 0.0, so any head movement can only
      // come from the independent head channel.
      await tester.pumpWidget(
        _app(const PetAvatarWidget(visualState: PetVisualState.pause)),
      );
      await tester.pump();

      final fallback = _fallback(tester);
      final samples = <double>[];
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 120));
        expect(fallback.bodyRotationForTesting, 0.0);
        samples.add(fallback.headRotationValue);
      }

      expect(samples.any((v) => v != 0.0), isTrue,
          reason: 'Head must be alive while the body holds still');
      expect(samples.toSet().length, greaterThan(1),
          reason: 'Head must keep changing over time');
    });

    testWidgets('the head counter-rotates against the body sway',
        (tester) async {
      await tester.pumpWidget(
        _app(const PetAvatarWidget(visualState: PetVisualState.idle)),
      );
      await tester.pump();

      final fallback = _fallback(tester);
      var opposite = 0;
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        final body = fallback.bodyRotationForTesting;
        final head = fallback.headRotationValue;
        if (body != 0.0 && head * body < 0) opposite++;
      }

      expect(opposite, greaterThanOrEqualTo(3),
          reason:
              'The head must lag the body instead of moving rigidly with it');
    });

    testWidgets('the head assembly is rendered as its own rotated group',
        (tester) async {
      await tester.pumpWidget(
        _app(const PetAvatarWidget(visualState: PetVisualState.idle)),
      );
      await tester.pump(const Duration(milliseconds: 750));

      // The head group is an ancestor of the face, both ears, both eyes and the
      // sprout, so those parts move together, independently of the body.
      for (final key in [
        MochiLayerKeys.face,
        MochiLayerKeys.earLeft,
        MochiLayerKeys.earRight,
        MochiLayerKeys.eyeLeft,
        MochiLayerKeys.eyeRight,
        MochiLayerKeys.sprout,
      ]) {
        expect(
          find.ancestor(
            of: find.byKey(key),
            matching: find.byKey(MochiLayerKeys.headGroup),
          ),
          findsOneWidget,
          reason: '$key must live inside the head group',
        );
      }

      // The body must NOT be inside the head group: the head moves on its own.
      expect(
        find.ancestor(
          of: find.byKey(MochiLayerKeys.body),
          matching: find.byKey(MochiLayerKeys.headGroup),
        ),
        findsNothing,
      );

      // Each layer still exists exactly once after the regrouping.
      for (final key in MochiLayerKeys.all) {
        expect(find.byKey(key), findsOneWidget, reason: 'missing layer $key');
      }
    });
  });

  group('M-2 · pages derive Mochi from business state, never page-local state',
      () {
    testWidgets(
        'an active craft job is announced on a previously hard-coded page',
        (tester) async {
      final container = _container(
        db: db,
        craftState: CraftState(
          recipes: const [_recipe],
          activeJob: _job(progressSeconds: 300),
          activeRecipe: _recipe,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // SettingsPage hides the badge, so the truthful state is proven through
      // the state the renderer actually received.
      expect(_renderedState(tester), PetVisualState.craft);

      // The avatar receives the live craft progress binding.
      final avatar =
          tester.widget<PetAvatarWidget>(find.byType(PetAvatarWidget));
      expect(
          avatar.craftProgress, closeTo(300 / _recipe.requiredSeconds, 1e-9));
      expect(avatar.visualState, PetVisualState.craft);
    });

    testWidgets('an active focus session outranks an idle craft board',
        (tester) async {
      final container = _container(db: db, hasActiveSession: true);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(_renderedState(tester), PetVisualState.focus);
    });

    testWidgets('with nothing running the pet is truthfully idle',
        (tester) async {
      final container = _container(db: db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The invariant is that nothing running means no *work* presentation.
      //
      // The `sleep` alternative used to be here because the ambient modifier
      // read the wall clock, so a late-night run added a sleeping beat and a
      // strict `idle` assertion failed after 23:00. The avatar now reads the
      // injected clock (this file fixes it at 09:00) and the random source is
      // pinned, so the band and the draw are both deterministic and the
      // tolerance is no longer load-bearing. It is kept because the invariant
      // this test exists to protect is "not focus, not craft" — not "exactly
      // idle" — and a future ambient rule may legitimately rest the companion.
      expect(
        _renderedState(tester),
        anyOf(PetVisualState.idle, PetVisualState.sleep),
      );
      expect(_renderedState(tester), isNot(PetVisualState.focus));
      expect(_renderedState(tester), isNot(PetVisualState.craft));
    });

    testWidgets('CompanionAvatar follows the business state it is given',
        (tester) async {
      final container = _container(
        db: db,
        hasActiveSession: true,
        craftState: CraftState(
          recipes: const [_recipe],
          activeJob: _job(progressSeconds: 60),
          activeRecipe: _recipe,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: CompanionAvatar(size: 120)),
          ),
        ),
      );
      await tester.pump();

      // Focus outranks craft, matching the shared mapper contract.
      expect(find.text('Mochi 专注中'), findsOneWidget);
    });

    testWidgets('the avatar owns and disposes its controller with itself',
        (tester) async {
      final container = _container(db: db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: CompanionAvatar(size: 100)),
          ),
        ),
      );
      await tester.pump();

      final controller = tester
          .widget<PetAvatarWidget>(find.byType(PetAvatarWidget))
          .controller;
      expect(controller, isNotNull);
      expect(controller!.isDisposed, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(controller.isDisposed, isTrue);
      expect(controller.activeTimerCount, 0);
    });
  });

  group('no business side effects', () {
    testWidgets('a settled celebrate never touches the database',
        (tester) async {
      final container = _container(db: db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PetAvatarWidget(visualState: PetVisualState.celebrate),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(PetMotionSpec.celebrateCycle);
      await tester.pump(const Duration(seconds: 3));

      expect(await db.select(db.focusSessions).get(), isEmpty);
      expect(await db.select(db.focusRecords).get(), isEmpty);
      expect(await db.select(db.rewardLedgerTable).get(), isEmpty);
      expect(await db.select(db.craftJobs).get(), isEmpty);
    });
  });

  group('cross-page consistency & lifecycle', () {
    Future<void> mountRouter(WidgetTester tester, ProviderContainer container) {
      return tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    }

    testWidgets('an active craft job survives navigation away and back',
        (tester) async {
      final container = _container(
        db: db,
        craftState: CraftState(
          recipes: const [_recipe],
          activeJob: _job(progressSeconds: 120),
          activeRecipe: _recipe,
        ),
      );
      addTearDown(container.dispose);

      await mountRouter(tester, container);
      router.go('/');
      await settle(tester);
      expect(_renderedState(tester), PetVisualState.craft);

      // Navigate to a page that never loads craft itself.
      router.go('/growth');
      await settle(tester);
      expect(_renderedState(tester), PetVisualState.craft,
          reason: 'Leaving Home must not reset Mochi to idle');

      // And back again.
      router.go('/');
      await settle(tester);
      expect(_renderedState(tester), PetVisualState.craft,
          reason: 'Returning to Home must not reset Mochi to idle');
    });

    testWidgets('an active focus session survives navigation away and back',
        (tester) async {
      final container = _container(db: db, hasActiveSession: true);
      addTearDown(container.dispose);

      await mountRouter(tester, container);
      router.go('/');
      await settle(tester);
      expect(_renderedState(tester), PetVisualState.focus);

      router.go('/progress');
      await settle(tester);
      expect(_renderedState(tester), PetVisualState.focus);

      router.go('/');
      await settle(tester);
      expect(_renderedState(tester), PetVisualState.focus);
    });

    testWidgets('rapid state flips never duplicate ambient timers',
        (tester) async {
      final controller = PetMotionController(
        visualState: PetVisualState.idle,
        scheduler: const _FixedScheduler(),
      );

      await tester.pumpWidget(
        _app(PetAvatarWidget(
          visualState: PetVisualState.idle,
          controller: controller,
        )),
      );
      await tester.pump();
      expect(controller.activeTimerCount, 2);

      for (final state in const [
        PetVisualState.focus,
        PetVisualState.idle,
        PetVisualState.craft,
        PetVisualState.idle,
        PetVisualState.pause,
        PetVisualState.idle,
      ]) {
        controller.updateState(state);
        await tester.pump(const Duration(milliseconds: 20));
        expect(controller.activeTimerCount, lessThanOrEqualTo(2));
      }

      controller.dispose();
      expect(controller.activeTimerCount, 0);
    });

    testWidgets('unmounting the renderer leaves no dangling ticker or timer',
        (tester) async {
      await tester.pumpWidget(
        _app(const PetAvatarWidget(visualState: PetVisualState.idle)),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.pumpWidget(_app(const SizedBox.shrink()));
      // A leaked Ticker or Timer would surface here.
      await tester.pump(const Duration(seconds: 12));

      expect(find.byType(PetIdleFallbackView), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion freezes the pet but keeps the state legible',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: PetAvatarWidget(
                visualState: PetVisualState.craft,
                craftProgress: 0.5,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final fallback = _fallback(tester);
      expect(fallback.craftController.isAnimating, isFalse);
      expect(fallback.tailController.isAnimating, isFalse);
      expect(fallback.headController.isAnimating, isFalse);

      // Static, yet still truthful and readable.
      expect(find.text('Mochi 制作中'), findsOneWidget);

      final t0 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();
      await tester.pump(const Duration(milliseconds: 1500));
      final t1 = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform)
          .toList();

      for (var i = 0; i < t0.length; i++) {
        expect(t1[i], equals(t0[i]),
            reason: 'Reduced motion must freeze every transform in craft');
      }
    });
  });
}
