/// Debug-only entry point that seeds a QA scenario and then runs the app.
///
/// ## How to use it
///
/// ```text
/// flutter run -t lib/dev/qa_fixture_main.dart \
///     --dart-define=QA_SCENARIO=room_two_anchors
/// ```
///
/// Add `--dart-define=QA_RESET=true` to clear previously seeded QA state instead
/// of seeding. Omitting `QA_SCENARIO` lists the available scenarios and exits.
///
/// ## Why a separate entry point rather than a flag in `main.dart`
///
/// A flag in the shipping entry point would put fixture code **inside the release
/// binary**, reachable if the flag were ever set. This file is not referenced by
/// `lib/main.dart` or by anything else in the shipping tree, so the release build
/// does not contain a path to it at all — and `qa_fixture_guard_test.dart` fails
/// if that ever stops being true.
///
/// ## What it does not do
///
/// It adds no route, no button and no visible affordance to the app. The seeded
/// state is reached through the same repositories the app uses, so what runs
/// afterwards is the shipping application on shipping code.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/app_localization.dart';
import '../presentation/controllers/providers.dart';
import '../presentation/navigation/app_router.dart';
import '../presentation/theme/app_theme.dart';
import 'qa_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const scenarioId = String.fromEnvironment('QA_SCENARIO');
  const reset = bool.fromEnvironment('QA_RESET');

  final container = ProviderContainer();
  final harness = QaFixtureHarness(
    pets: container.read(petRepositoryProvider),
    craft: container.read(craftRepositoryProvider),
    db: container.read(appDatabaseProvider),
    clock: container.read(focusClockProvider),
  );

  if (reset) {
    final report = await harness.reset();
    debugPrint('QA_RESET: $report');
  }

  final scenario = QaScenario.fromId(scenarioId);
  if (scenario == null) {
    debugPrint('QA_SCENARIO must be one of: '
        '${QaScenario.values.map((s) => s.id).join(', ')}');
    container.dispose();
    return;
  }

  final report = await harness.seed(scenario);
  debugPrint('QA_SEED: $report');

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const _QaFixtureApp(),
    ),
  );
}

/// The shipping app, unchanged: same router, same theme.
///
/// Reused rather than re-implemented so the seeded state is observed through the
/// real application, which is the only thing worth observing it through.
class _QaFixtureApp extends StatelessWidget {
  const _QaFixtureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cozy Focus (QA fixture)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: appLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      routerConfig: appRouter,
    );
  }
}
