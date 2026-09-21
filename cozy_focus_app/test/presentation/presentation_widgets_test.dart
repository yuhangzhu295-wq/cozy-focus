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
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';
import 'package:cozy_focus_app/presentation/companion/mochi_layered_renderer.dart';
import 'package:cozy_focus_app/domain/models/pet_models.dart' as pet_domain;
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';
import 'package:cozy_focus_app/domain/models/craft_models.dart' as craft_domain;

class WidgetTestClock implements FocusClock {
  DateTime _now;
  WidgetTestClock(this._now);
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
}

class _TestHomeController extends HomeController {
  final HomeUIState _presetState;
  _TestHomeController(super.ref, this._presetState);

  @override
  Future<void> loadHomeData() async {
    state = _presetState;
  }
}

class _TestCraftController extends CraftController {
  final CraftState _presetState;
  bool loadAllCalled = false;
  _TestCraftController({
    required super.repo,
    required super.engine,
    required super.clock,
    required super.userId,
    required CraftState presetState,
  }) : _presetState = presetState;

  @override
  Future<void> loadAll() async {
    loadAllCalled = true;
    state = _presetState;
  }
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
    testWidgets('Screen 01: HomePage renders pet greeting and start button',
        (tester) async {
      await tester.pumpWidget(createTestApp(container, const HomePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('和 Mochi 一起'), findsOneWidget);
      expect(find.text('专注时长'), findsOneWidget);
      expect(find.text('开始专注'), findsOneWidget);
    });

    testWidgets('Screen 01: HomePage hero invents no numbers of its own',
        (tester) async {
      final progress = pet_domain.PetProgress(
        id: 'mochi_progress_id',
        petId: 'mochi_pet_id',
        level: 3,
        experiencePoints: 245,
        totalFocusMinutes: 120,
        happinessScore: 92,
        updatedAt: testClock.now(),
      );

      final homeState = HomeUIState(
        petProgress: progress,
        todayFocusSeconds: 1500,
        streakDays: 3,
      );

      final customContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          focusClockProvider.overrideWithValue(testClock),
          homeControllerProvider.overrideWith(
            (ref) => _TestHomeController(ref, homeState),
          ),
        ],
      );
      addTearDown(customContainer.dispose);

      await tester.pumpWidget(createTestApp(customContainer, const HomePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Reference 01 gives the hero to the illustration alone, so the hero
      // carries no speech bubble. That means the page must not print a level or
      // an XP figure anywhere in the hero either — the truthful level/XP display
      // lives on the Mochi growth page, which is where the design puts it.
      final avatarFinder = find.byType(PetAvatarWidget);
      expect(avatarFinder, findsOneWidget);
      final avatarWidget = tester.widget<PetAvatarWidget>(avatarFinder);
      expect(avatarWidget.message, isNull);

      expect(find.textContaining('累计专注'), findsNothing);
      expect(find.textContaining('Lv.'), findsNothing);
      expect(find.textContaining('245'), findsNothing);
    });

    testWidgets(
        'Screen 01: HomePage hero keeps the headline clear of the pet at 320x640',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final progress = pet_domain.PetProgress(
        id: 'mochi_progress_id',
        petId: 'mochi_pet_id',
        level: 3,
        experiencePoints: 245,
        totalFocusMinutes: 120,
        happinessScore: 92,
        updatedAt: testClock.now(),
      );

      final homeState = HomeUIState(
        petProgress: progress,
        todayFocusSeconds: 1500,
        streakDays: 3,
      );

      final customContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          focusClockProvider.overrideWithValue(testClock),
          homeControllerProvider.overrideWith(
            (ref) => _TestHomeController(ref, homeState),
          ),
        ],
      );
      addTearDown(customContainer.dispose);

      await tester.pumpWidget(createTestApp(customContainer, const HomePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final avatarFinder = find.byType(PetAvatarWidget);
      expect(avatarFinder, findsOneWidget);

      final headlineFinder = find.text('专注当下，\n让更好的自己慢慢长大。');
      expect(headlineFinder, findsOneWidget);

      // The guard that matters is the headline against the pet itself: the
      // approved hero has no bubble, so the pet is what the copy must clear.
      final petFinder = find.byType(MochiLayeredRenderer);
      expect(petFinder, findsOneWidget);

      final headlineRect = tester.getRect(headlineFinder);
      final petRect = tester.getRect(petFinder);
      expect(headlineRect.overlaps(petRect), isFalse);
    });

    testWidgets(
        'Screen 01: HomePage hero keeps the headline clear of the pet at 360x800',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final progress = pet_domain.PetProgress(
        id: 'mochi_progress_id',
        petId: 'mochi_pet_id',
        level: 3,
        experiencePoints: 245,
        totalFocusMinutes: 120,
        happinessScore: 92,
        updatedAt: testClock.now(),
      );

      final homeState = HomeUIState(
        petProgress: progress,
        todayFocusSeconds: 1500,
        streakDays: 3,
      );

      final customContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          focusClockProvider.overrideWithValue(testClock),
          homeControllerProvider.overrideWith(
            (ref) => _TestHomeController(ref, homeState),
          ),
        ],
      );
      addTearDown(customContainer.dispose);

      await tester.pumpWidget(createTestApp(customContainer, const HomePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final avatarFinder = find.byType(PetAvatarWidget);
      expect(avatarFinder, findsOneWidget);
      final avatarWidget = tester.widget<PetAvatarWidget>(avatarFinder);
      expect(avatarWidget.message, isNull);

      final headlineFinder = find.text('专注当下，\n让更好的自己慢慢长大。');
      expect(headlineFinder, findsOneWidget);

      final petFinder = find.byType(MochiLayeredRenderer);
      expect(petFinder, findsOneWidget);

      final headlineRect = tester.getRect(headlineFinder);
      final petRect = tester.getRect(petFinder);
      expect(headlineRect.overlaps(petRect), isFalse);
    });

    testWidgets(
        'Screen 01: HomePage handles null PetProgress with 264 hero band',
        (tester) async {
      const homeState = HomeUIState(
        petProgress: null,
        todayFocusSeconds: 1500,
        streakDays: 3,
      );

      final customContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          focusClockProvider.overrideWithValue(testClock),
          homeControllerProvider.overrideWith(
            (ref) => _TestHomeController(ref, homeState),
          ),
        ],
      );
      addTearDown(customContainer.dispose);

      await tester.pumpWidget(createTestApp(customContainer, const HomePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final avatarFinder = find.byType(PetAvatarWidget);
      expect(avatarFinder, findsOneWidget);
      final avatarWidget = tester.widget<PetAvatarWidget>(avatarFinder);
      expect(avatarWidget.message, isNull);

      expect(find.textContaining('累计专注'), findsNothing);

      // The hero band is what keeps the pet clear of the headline, and it is
      // sized from the approved page: reference 01 measures 311.25pt from the
      // page top to the focus card's margin box, of which the test environment
      // contributes no status-bar inset.
      final heroFinder = find
          .ancestor(
            of: find.text('和 Mochi 一起'),
            matching: find.byType(SizedBox),
          )
          .first;
      final heroWidget = tester.widget<SizedBox>(heroFinder);
      expect(heroWidget.height, equals(264));
      expect(tester.getSize(heroFinder).height, equals(264));
    });

    testWidgets('Screen 02: FocusSetupPage renders categories and mode options',
        (tester) async {
      await tester.pumpWidget(createTestApp(container, const FocusSetupPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // V4.1: no AppBar title; shows duration chips and start button
      expect(find.text('选择专注时长'), findsOneWidget);
      expect(find.textContaining('25'), findsWidgets); // default duration chip
      expect(find.text('开始专注'), findsOneWidget);
    });

    testWidgets(
        'Screen 03: FocusActivePage shows timer and pause/resume button',
        (tester) async {
      // Start session first
      final engine = container.read(focusSessionEngineProvider);
      await engine.start(
        userId: 'widget_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
      );

      await tester
          .pumpWidget(createTestApp(container, const FocusActivePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // V4.1: '专注中 🌱' header + 'Mochi 专注中' subtitle, large timer, pause button
      expect(find.textContaining('专注中'), findsWidgets);
      expect(find.text('25:00'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Cancel session to stop ticker
      await container
          .read(focusSessionControllerProvider.notifier)
          .cancelSession();
    });

    testWidgets(
        'FocusActivePage early finish confirmation dialog shows PetAvatarWidget with pause visualState',
        (tester) async {
      final engine = container.read(focusSessionEngineProvider);
      await engine.start(
        userId: 'widget_user',
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

      final dialogAvatarFinder = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(PetAvatarWidget),
      );
      expect(dialogAvatarFinder, findsOneWidget);

      final dialogAvatar = tester.widget<PetAvatarWidget>(dialogAvatarFinder);
      expect(dialogAvatar.visualState, equals(PetVisualState.pause));

      await container
          .read(focusSessionControllerProvider.notifier)
          .cancelSession();
    });

    testWidgets('Screen 04: FocusCompletePage renders celebration and minutes',
        (tester) async {
      await tester
          .pumpWidget(createTestApp(container, const FocusCompletePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('专注完成'), findsOneWidget);
      expect(find.text('Great Work!'), findsOneWidget);
      expect(find.text('继续保存记录'), findsOneWidget);
    });

    testWidgets('Screen 04A: FocusSavePage allows mood selection & save',
        (tester) async {
      await tester.pumpWidget(createTestApp(container, const FocusSavePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('保存本次记录'), findsOneWidget);
      expect(find.text('心情'), findsOneWidget);
      expect(find.text('记录这一刻的心情、感悟或收获...'), findsOneWidget);
      expect(find.text('保存记录'), findsOneWidget);
    });

    testWidgets('Screen 04B: FocusRewardPage renders rewards and return CTA',
        (tester) async {
      await tester
          .pumpWidget(createTestApp(container, const FocusRewardPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('获得奖励'), findsOneWidget);
      expect(find.text('制作工坊'), findsOneWidget);
      expect(find.text('返回首页'), findsOneWidget);
    });

    // ── RP-5: Craft state + interact tap ──────────────────────────

    testWidgets(
        'RP-5: HomePage triggers one-shot loadAll on craftControllerProvider',
        (tester) async {
      const homeState = HomeUIState(
        petProgress: null,
        todayFocusSeconds: 0,
        streakDays: 0,
      );

      final customContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          focusClockProvider.overrideWithValue(testClock),
          homeControllerProvider.overrideWith(
            (ref) => _TestHomeController(ref, homeState),
          ),
          craftControllerProvider.overrideWith((ref) => _TestCraftController(
                repo: ref.watch(craftRepositoryProvider),
                engine: ref.watch(craftEngineProvider),
                clock: ref.watch(focusClockProvider),
                userId: 'test_user',
                presetState: const CraftState(),
              )),
        ],
      );
      addTearDown(customContainer.dispose);

      final ctrl = customContainer.read(craftControllerProvider.notifier)
          as _TestCraftController;
      expect(ctrl.loadAllCalled, isFalse);
      await tester.pumpWidget(createTestApp(customContainer, const HomePage()));
      expect(ctrl.loadAllCalled, isTrue);
    });

    testWidgets(
        'RP-5: HomePage mochiState = craft when activeJob present and no focus session',
        (tester) async {
      const homeState = HomeUIState(
        petProgress: null,
        todayFocusSeconds: 0,
        streakDays: 0,
      );

      final activeJob = craft_domain.CraftJob(
        id: 'job_rp5',
        userId: 'test_user',
        recipeId: 'sofa',
        status: CraftJobStatus.inProgress,
        progressSeconds: 300,
        startedAt: DateTime(2026, 9, 1),
        completedAt: null,
        rewardClaimed: false,
      );
      final craftPreset = CraftState(activeJob: activeJob);

      final customContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          focusClockProvider.overrideWithValue(testClock),
          homeControllerProvider.overrideWith(
            (ref) => _TestHomeController(ref, homeState),
          ),
          craftControllerProvider.overrideWith((ref) => _TestCraftController(
                repo: ref.watch(craftRepositoryProvider),
                engine: ref.watch(craftEngineProvider),
                clock: ref.watch(focusClockProvider),
                userId: 'test_user',
                presetState: craftPreset,
              )),
        ],
      );
      addTearDown(customContainer.dispose);

      await tester.pumpWidget(createTestApp(customContainer, const HomePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final avatarFinder = find.byType(PetAvatarWidget);
      expect(avatarFinder, findsOneWidget);
      final avatarWidget = tester.widget<PetAvatarWidget>(avatarFinder);
      expect(avatarWidget.visualState, equals(PetVisualState.craft));
    });

    testWidgets(
        'RP-5: HomePage mochiState = focus takes priority over craft activeJob',
        (tester) async {
      const homeState = HomeUIState(
        petProgress: null,
        todayFocusSeconds: 600,
        streakDays: 1,
        hasActiveSession: true,
      );

      final activeJob = craft_domain.CraftJob(
        id: 'job_rp5_b',
        userId: 'test_user',
        recipeId: 'table',
        status: CraftJobStatus.inProgress,
        progressSeconds: 600,
        startedAt: DateTime(2026, 9, 1),
        completedAt: null,
        rewardClaimed: false,
      );
      final craftPreset = CraftState(activeJob: activeJob);

      final customContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          focusClockProvider.overrideWithValue(testClock),
          homeControllerProvider.overrideWith(
            (ref) => _TestHomeController(ref, homeState),
          ),
          craftControllerProvider.overrideWith((ref) => _TestCraftController(
                repo: ref.watch(craftRepositoryProvider),
                engine: ref.watch(craftEngineProvider),
                clock: ref.watch(focusClockProvider),
                userId: 'test_user',
                presetState: craftPreset,
              )),
        ],
      );
      addTearDown(customContainer.dispose);

      await tester.pumpWidget(createTestApp(customContainer, const HomePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final avatarFinder = find.byType(PetAvatarWidget);
      expect(avatarFinder, findsOneWidget);
      final avatarWidget = tester.widget<PetAvatarWidget>(avatarFinder);
      expect(avatarWidget.visualState, equals(PetVisualState.focus));
    });

    testWidgets(
        'RP-5: Tapping Mochi in idle state activates interact cooldown while visualState remains idle',
        (tester) async {
      const homeState = HomeUIState(
        petProgress: null,
        todayFocusSeconds: 0,
        streakDays: 0,
      );

      final customContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          focusClockProvider.overrideWithValue(testClock),
          homeControllerProvider.overrideWith(
            (ref) => _TestHomeController(ref, homeState),
          ),
        ],
      );
      addTearDown(customContainer.dispose);

      await tester.pumpWidget(createTestApp(customContainer, const HomePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final avatarFinder = find.byType(PetAvatarWidget);
      expect(avatarFinder, findsOneWidget);
      final avatarWidget = tester.widget<PetAvatarWidget>(avatarFinder);
      final controller = avatarWidget.controller!;

      expect(controller.visualState, equals(PetVisualState.idle));
      expect(controller.isInteractCooldownActive, isFalse);

      await tester.tap(avatarFinder);
      await tester.pump();

      expect(controller.visualState, equals(PetVisualState.idle));
      expect(controller.isInteractCooldownActive, isTrue);
    });

    testWidgets(
        'RP-5: Tapping Mochi in focus state does not activate interact cooldown',
        (tester) async {
      const homeState = HomeUIState(
        petProgress: null,
        todayFocusSeconds: 600,
        streakDays: 1,
        hasActiveSession: true,
      );

      final customContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          focusClockProvider.overrideWithValue(testClock),
          homeControllerProvider.overrideWith(
            (ref) => _TestHomeController(ref, homeState),
          ),
        ],
      );
      addTearDown(customContainer.dispose);

      await tester.pumpWidget(createTestApp(customContainer, const HomePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final avatarFinder = find.byType(PetAvatarWidget);
      expect(avatarFinder, findsOneWidget);
      final avatarWidget = tester.widget<PetAvatarWidget>(avatarFinder);
      final controller = avatarWidget.controller!;

      expect(controller.visualState, equals(PetVisualState.focus));
      expect(controller.isInteractCooldownActive, isFalse);

      await tester.tap(avatarFinder);
      await tester.pump();

      expect(controller.visualState, equals(PetVisualState.focus));
      expect(controller.isInteractCooldownActive, isFalse);
    });
  });
}
