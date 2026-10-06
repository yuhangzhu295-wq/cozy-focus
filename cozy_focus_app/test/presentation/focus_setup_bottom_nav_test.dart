import 'dart:io';

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

/// The focus setup screen marked the wrong tab in the bottom bar.
///
/// ## Found by walking the app on a device, not by a test
///
/// The whole suite passed while this was wrong. Nothing had ever asserted *which*
/// tab the bar marks — only that the bar exists — so a screen claiming the user was
/// in 成长 while they were in a flow entered from 首页 was invisible to it.
///
/// Reading the pixels settled it: the setup screen's 成长 label was drawn in
/// `primarySage` and the home screen's 首页 label was too, which is a
/// contradiction the source did not have — `focus_complete_page`, the next screen
/// in the same flow, already said 0.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider
          .overrideWithValue(_FixedClock(DateTime(2026, 10, 8, 21))),
      currentUserIdProvider.overrideWithValue('default_user'),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets('marks 首页 in the bottom bar, not 成长', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/focus/setup',
      routes: [
        GoRoute(
          path: '/focus/setup',
          builder: (context, state) => const FocusSetupPage(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/records',
          builder: (context, state) => const Scaffold(body: Text('records')),
        ),
        GoRoute(
          path: '/growth',
          builder: (context, state) => const Scaffold(body: Text('growth')),
        ),
        GoRoute(
          path: '/focus/active',
          builder: (context, state) => const Scaffold(body: Text('active')),
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
    // Fixed frames rather than settling: the companion's idle animation repeats
    // forever, so `pumpAndSettle` never returns on this screen.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    final bar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bar.currentIndex, 0,
        reason: 'the focus flow is entered from 首页, and the completion page in '
            'the same flow already marks 首页 — this screen marked 成长, a tab '
            'the user had never opened');
  });

  test('and it is the same index the completion page uses', () {
    // The two screens are one flow, so a disagreement between them is the defect
    // rather than either value on its own.
    final source = File('lib/presentation/pages/focus_complete_page.dart')
        .readAsStringSync();
    expect(source.contains('AppBottomNav(currentIndex: 0)'), isTrue);
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
