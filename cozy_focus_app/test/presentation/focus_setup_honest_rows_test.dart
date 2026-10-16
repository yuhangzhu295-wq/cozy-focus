import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide
        Task,
        TaskSubtask,
        TaskSchedule,
        FocusSession,
        FocusRecord,
        RestSession;
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/focus_setup_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// A screen may not offer a control for a feature that is not connected.
///
/// ## Found while auditing the release blockers
///
/// `focus_setup_page` carried two rows for the two features the release audit
/// lists as unimplemented, and both of them lied about it in different ways:
///
/// * **白噪音** showed `森林  >` — a current value and a drill-in chevron, on a
///   row with no `onTap`. It promised both a setting and a navigation, and
///   delivered neither. The project had already refused to add exactly this as
///   `更多 ›`.
/// * **专注结束提醒** showed a real `Switch`, wired to a working `setState`,
///   **defaulting to ON** — while `flutter_local_notifications` sits in
///   `pubspec.yaml` and has never been imported in `lib/`. Nothing could be
///   scheduled. This is the worse of the two: the control moves, so the user has
///   positive feedback that reminders are armed.
///
/// The settings page already states both honestly. So the app contradicted
/// itself, and this page was the half that was wrong.
///
/// ## Why the assertion is "no Switch" rather than "no fake switch"
///
/// A widget test cannot ask whether a `Switch` reaches a platform channel. What
/// it can ask is whether this screen offers an interactive control for a feature
/// with no implementation, and on this screen the only such control was that
/// switch. So the guard is: **this page presents no toggle at all**, plus the two
/// honest statements are on it. Adding a real reminder toggle later means
/// deleting this test deliberately, which is the point.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(_FixedClock()),
      currentUserIdProvider.overrideWithValue('default_user'),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpSetup(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/focus/setup',
      routes: [
        GoRoute(
          path: '/focus/setup',
          builder: (context, state) => const FocusSetupPage(),
        ),
        GoRoute(
          path: '/focus/active',
          builder: (context, state) => const Scaffold(body: Text('active')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
      ],
    );
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
    await tester.pump(const Duration(milliseconds: 120));
  }

  testWidgets('the setup screen offers no toggle at all', (tester) async {
    await pumpSetup(tester);
    expect(find.byType(Switch), findsNothing,
        reason: 'a switch here toggles a local bool and schedules nothing');
  });

  testWidgets('white noise is stated, not offered', (tester) async {
    await pumpSetup(tester);
    expect(find.text('专注白噪音'), findsOneWidget);
    expect(find.text('当前版本未接入音频素材'), findsOneWidget);
    // The dead affordance: a value plus a chevron for a picker that does not
    // exist. `森林` was the invented "current sound".
    expect(find.textContaining('森林'), findsNothing);
    // A real chevron on this page is still allowed: `自定义 >` opens the
    // duration picker and was verified on the device. What is gone is the one
    // that opened nothing. Asserting both halves is what makes this a guard
    // rather than a ban on chevrons.
    expect(find.text('自定义 >'), findsOneWidget,
        reason: 'the working chevron should still be here');
  });

  testWidgets('the reminder is stated, not switchable', (tester) async {
    await pumpSetup(tester);
    expect(find.text('专注结束提醒'), findsOneWidget);
    expect(find.text('当前版本尚未接入系统通知'), findsOneWidget);
  });

  testWidgets('and the two rows agree with the settings page', (tester) async {
    // Same features, same wording. If one surface ever starts promising a
    // feature the other says is missing, the strings stop matching.
    await pumpSetup(tester);
    const settingsWording = [
      '当前版本尚未接入系统通知',
      '当前版本未接入音频素材',
    ];
    for (final line in settingsWording) {
      expect(find.text(line), findsOneWidget,
          reason: 'the setup page does not carry the honest line "$line"');
    }
  });
}

class _FixedClock implements FocusClock {
  @override
  DateTime now() => DateTime(2026, 10, 7, 9);
}
