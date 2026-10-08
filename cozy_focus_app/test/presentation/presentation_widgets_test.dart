import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:cozy_focus_app/domain/models/pet_models.dart' as pet_domain;
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';
import 'package:cozy_focus_app/presentation/navigation/app_router.dart';
import 'package:cozy_focus_app/domain/models/craft_models.dart' as craft_domain;

/// A fresh router per test. The shared global kept its location between tests
/// in a file, so each test silently inherited the previous one's route.
late GoRouter router;

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

/// The hero's companion.
///
/// The home page draws a second, much smaller one in the 放松一下 row — a
/// thumbnail of the same pet asleep — so `find.byType(PetAvatarWidget)` is no
/// longer the hero's alone. The hero's is the large one; every other companion
/// on this page is a thumbnail.
Finder heroPetFinder(WidgetTester tester) {
  final largest = tester
      .widgetList<PetAvatarWidget>(find.byType(PetAvatarWidget))
      .reduce((a, b) => a.size >= b.size ? a : b);
  return find.byWidget(largest);
}

void main() {
  late AppDatabase db;
  late WidgetTestClock testClock;
  late ProviderContainer container;

  setUp(() {
    router = createAppRouter();
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
      // The design's own words for this card. It used to read `专注时长` with a
      // sprout emoji in front; the board reads `选择专注时长` and carries no
      // leading glyph, so the label moved with the design.
      expect(find.text('选择专注时长'), findsOneWidget);
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
      final avatarFinder = heroPetFinder(tester);
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

      final avatarFinder = heroPetFinder(tester);
      expect(avatarFinder, findsOneWidget);

      final headlineFinder = find.text('专注当下，\n让更好的自己慢慢长大。');
      expect(headlineFinder, findsOneWidget);

      // Measure the companion's rendered box rather than a specific renderer:
      // the pose can legitimately use either the layered rig or sprite art.
      final petFinder = heroPetFinder(tester);
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

      final avatarFinder = heroPetFinder(tester);
      expect(avatarFinder, findsOneWidget);
      final avatarWidget = tester.widget<PetAvatarWidget>(avatarFinder);
      expect(avatarWidget.message, isNull);

      final headlineFinder = find.text('专注当下，\n让更好的自己慢慢长大。');
      expect(headlineFinder, findsOneWidget);

      final petFinder = heroPetFinder(tester);
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

      final avatarFinder = heroPetFinder(tester);
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
      // The page is a scroll view, and this test's surface is 800x600 — shorter
      // than any phone — so the control starts below the fold. Scrolling to it is
      // how a user on a short screen reaches it; the tap itself is unchanged.
      await tester.ensureVisible(find.text('提前结束'));
      await tester.pump();
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

    testWidgets(
        'Screen 04: FocusCompletePage renders the reference sections and the '
        'settled reward rates', (tester) async {
      // Drive a real 25-minute session to `finishing` — the state
      // FocusActivePage leaves before routing here.
      final notifier = container.read(focusSessionControllerProvider.notifier);
      await notifier.startSession(
        userId: 'test_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
        taskName: '写作练习',
        categoryName: '学习',
      );
      testClock.advance(const Duration(minutes: 25));
      await notifier.completeSession();

      await tester
          .pumpWidget(createTestApp(container, const FocusCompletePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Reference 04's three cards, its banner and its single action. The
      // previous revision rendered none of the cards and titled itself in
      // English.
      expect(find.textContaining('专注完成'), findsOneWidget);
      expect(find.text('本次专注时长'), findsOneWidget);
      expect(find.text('恭喜获得奖励'), findsOneWidget);
      expect(find.text('记录一下此刻心情（可选）'), findsOneWidget);
      expect(find.text('完成并返回首页'), findsOneWidget);
      expect(find.textContaining('每一次专注，都是在靠近更喜欢自己'), findsOneWidget);

      // The duration is MM:SS, the form the reference prints (25:00).
      expect(find.text('25:00'), findsOneWidget);

      // RewardService settles 2 coins and 5 XP per whole minute. The page must
      // not print numbers the ledger will disagree with.
      expect(find.text('+50'), findsOneWidget);
      expect(find.text('+125'), findsOneWidget);
    });

    testWidgets('Screen 04: quick finish persists the record and the mood note',
        (tester) async {
      final notifier = container.read(focusSessionControllerProvider.notifier);
      final session = await notifier.startSession(
        userId: 'test_user',
        plannedSeconds: 1500,
        mode: FocusMode.focus,
        taskName: '写作练习',
        categoryName: '学习',
      );
      testClock.advance(const Duration(minutes: 25));
      await notifier.completeSession();

      addTearDown(() => router.go('/'));
      router.go('/focus/complete');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), '今天状态很好');
      await tester.pump();

      final cta = find.text('完成并返回首页');
      await tester.ensureVisible(cta);
      await tester.pump();
      await tester.tap(cta);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // The action has to actually persist. A completion screen that renders
      // correctly but writes nothing is the same class of defect as the
      // abandoned `finishing` session this flow already shipped once.
      final record = await db.focusRecordDao.findBySessionId(session.id);
      expect(record, isNotNull);
      expect(record!.durationSeconds, 1500);
      expect(record.note, '今天状态很好');
      expect(record.mood, isNull,
          reason: 'reference 04 has no mood picker, so no mood is invented');
      expect(record.taskName, '写作练习');
    });

    testWidgets('Screen 06: the review screen offers every part of the review',
        (tester) async {
      await tester.pumpWidget(createTestApp(container, const FocusSavePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The four moods, the gains, and the two optional fields. P5's own tests
      // cover what saving them writes; this only pins that the screen is here.
      expect(find.text('这次感觉怎么样？'), findsOneWidget);
      expect(find.text('这次做了什么？（可选）'), findsOneWidget);
      expect(find.text('本次收获（可选）'), findsOneWidget);
      expect(find.text('下次继续（可选）'), findsOneWidget);
      for (final label in const ['分心较多', '一般', '不错', '心流']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
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
        'RP-5: Tapping Mochi in focus state answers without leaving focus',
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

      // STAGE 4 changed this expectation on purpose. The old contract — "focus
      // blocks interaction" — meant a user tapping a working Mochi got nothing
      // at all. The brief requires the opposite: a brief glance, then straight
      // back to work. The critical constraint is the second line: the base state
      // is *still focus*, never idle.
      expect(controller.visualState, equals(PetVisualState.focus));
      expect(controller.isInteractCooldownActive, isTrue);
    });
  });
}
