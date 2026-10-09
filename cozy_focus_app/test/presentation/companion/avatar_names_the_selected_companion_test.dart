import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/presentation/companion/mochi_visual_provider.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_presentation_intent.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_visual_provider.dart';
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// The avatar used to announce `Mochi 空闲` no matter which companion was
/// selected.
///
/// The state labels were the literal `'Mochi 空闲'` … `'Mochi 互动中'`, so a user
/// who selected the cat got a cat on screen announced as Mochi. Found on a device
/// with an imported companion selected; the growth page and the dress page had
/// already been checked, and this is the avatar every page shares.
///
/// This drives the *production* provider rather than the widget, because the
/// widget taking a name is not the property that matters — the property is that
/// the runtime passes the selected companion's name to it.
class _PresetHomeController extends HomeController {
  _PresetHomeController(super.ref, this._preset);

  final HomeUIState _preset;

  @override
  Future<void> loadHomeData() async {
    state = _preset;
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('the avatar names the selected companion, not Mochi',
      (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          homeControllerProvider.overrideWith(
            (ref) => _PresetHomeController(ref, const HomeUIState()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => MochiVisualProvider().build(
                context,
                const CompanionPresentationIntent(
                  companionId: CompanionId('catpack'),
                  pose: CompanionPose.idle,
                  baseContext: CompanionBaseContext.home,
                ),
                const CompanionVisualOptions(
                  displayName: '小猫',
                  size: 100,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('小猫 空闲'), findsOneWidget);
    expect(find.bySemanticsLabel('Mochi 空闲'), findsNothing,
        reason: 'the selected companion is 小猫, not the built-in default');

    handle.dispose();
  });

  testWidgets('and the built-in companion still says its own name',
      (tester) async {
    // The default is not a lie: when Mochi really is selected, that is the name.
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          homeControllerProvider.overrideWith(
            (ref) => _PresetHomeController(ref, const HomeUIState()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => MochiVisualProvider().build(
                context,
                const CompanionPresentationIntent(
                  companionId: CompanionId.dog,
                  pose: CompanionPose.idle,
                  baseContext: CompanionBaseContext.home,
                ),
                const CompanionVisualOptions(
                  displayName: 'Mochi',
                  size: 100,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Mochi 空闲'), findsOneWidget);

    handle.dispose();
  });
}
