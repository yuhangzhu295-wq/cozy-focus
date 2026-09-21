import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/craft_models.dart' as craft_domain;
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/craft_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/focus_active_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// Reference 03 draws the in-progress craft on the running screen: item icon,
/// name, a bar and the real percentage. The row is gated on
/// `craft.activeJob != null && craft.activeRecipe != null`, so it is invisible
/// in any capture taken while no craft is running -- which is every capture the
/// page sweep can produce, because no sweep recipe starts a craft.
///
/// That makes a widget test the only evidence for the row. These tests pin both
/// directions: the row renders with the job's own numbers when a job is active,
/// and it is absent when one is not.

class _TestClock implements FocusClock {
  final DateTime _now = DateTime(2026, 9, 21, 10, 0, 0);
  @override
  DateTime now() => _now;
}

/// A CraftController whose state is preset, so the page can be rendered against
/// a known job without driving the whole craft engine.
class _PresetCraftController extends CraftController {
  final CraftState _preset;
  _PresetCraftController({
    required super.repo,
    required super.engine,
    required super.clock,
    required super.userId,
    required CraftState preset,
  }) : _preset = preset;

  @override
  Future<void> loadAll() async {
    state = _preset;
  }
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const FocusActivePage(),
    ),
  );
}

void main() {
  late AppDatabase db;
  late _TestClock clock;

  // 50 minutes required, 35 minutes banked -> 70%, matching reference 03.
  const recipe = craft_domain.CraftRecipe(
    id: 'chair',
    name: '木质椅子',
    requiredMinutes: 50,
    ingredientCosts: {},
    outputItemId: 'chair',
    outputQuantity: 1,
    icon: '🪑',
  );
  final job = craft_domain.CraftJob(
    id: 'job_03',
    userId: 'default_user',
    recipeId: 'chair',
    status: CraftJobStatus.inProgress,
    progressSeconds: 35 * 60,
    startedAt: DateTime(2026, 9, 21, 9, 0, 0),
    rewardClaimed: false,
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _TestClock();
  });

  tearDown(() async {
    await db.close();
  });

  Future<ProviderContainer> containerWith(CraftState craftState) async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider.overrideWithValue(clock),
        craftControllerProvider.overrideWith(
          (ref) => _PresetCraftController(
            repo: ref.watch(craftRepositoryProvider),
            engine: ref.watch(craftEngineProvider),
            clock: ref.watch(focusClockProvider),
            userId: 'default_user',
            preset: craftState,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(focusSessionEngineProvider).start(
          userId: 'default_user',
          plannedSeconds: 1500,
          mode: FocusMode.focus,
        );
    return container;
  }

  void setScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('renders the craft row with the job\'s own name and percentage',
      (tester) async {
    setScreenSize(tester);
    final container = await containerWith(
      CraftState(activeJob: job, activeRecipe: recipe),
    );

    await tester.pumpWidget(_app(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('正在制作 木质椅子'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    final bar = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, closeTo(0.7, 0.001));

    await container
        .read(focusSessionControllerProvider.notifier)
        .cancelSession();
  });

  testWidgets('omits the craft row when no craft job is active',
      (tester) async {
    setScreenSize(tester);
    final container = await containerWith(const CraftState());

    await tester.pumpWidget(_app(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('正在制作'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await container
        .read(focusSessionControllerProvider.notifier)
        .cancelSession();
  });
}
