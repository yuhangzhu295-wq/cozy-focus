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
import 'package:cozy_focus_app/domain/models/rest_session.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/rest_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// The rest screen laid its four lengths out three-then-one.
///
/// ## Found by walking the app on a device
///
/// A `Wrap` of fixed-width chips put 5 / 10 / 15 on the first row and left 30
/// alone on the second, which reads as a list with an afterthought rather than as
/// four equal choices. The design draws two rows of two. No assertion could have
/// caught this — every widget existed and was tappable, which is all the rest
/// screen's own tests checked.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider
          .overrideWithValue(_FixedClock(DateTime(2026, 10, 8, 22))),
      currentUserIdProvider.overrideWithValue('default_user'),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets('lays the four lengths out two by two', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/rest',
      routes: [
        GoRoute(path: '/rest', builder: (context, state) => const RestPage()),
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
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    final centers = [
      for (final minutes in RestSession.presets)
        tester.getCenter(find.byKey(ValueKey('rest_preset_$minutes'))),
    ];

    expect(centers[0].dy, centers[1].dy, reason: '5 and 10 share a row');
    expect(centers[2].dy, centers[3].dy, reason: '15 and 30 share a row');
    expect(centers[2].dy, greaterThan(centers[0].dy),
        reason: 'the second row is below the first, not beside it');
    expect(centers[0].dx, lessThan(centers[1].dx));
    expect(centers[2].dx, lessThan(centers[3].dx));
  });

  testWidgets('and the two rows are the same two columns', (tester) async {
    // A grid, not a wrap: the left column's two tiles line up, and so do the
    // right column's. Three-then-one failed both of these.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/rest',
      routes: [
        GoRoute(path: '/rest', builder: (context, state) => const RestPage()),
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
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    final left = [
      tester.getCenter(find.byKey(const ValueKey('rest_preset_5'))),
      tester.getCenter(find.byKey(const ValueKey('rest_preset_15'))),
    ];
    final right = [
      tester.getCenter(find.byKey(const ValueKey('rest_preset_10'))),
      tester.getCenter(find.byKey(const ValueKey('rest_preset_30'))),
    ];

    expect(left[0].dx, left[1].dx);
    expect(right[0].dx, right[1].dx);
    expect(left[0].dx, lessThan(right[0].dx));
  });

  testWidgets('each preset announces its length once', (tester) async {
    // The device tree read `5 分钟\n5\n分钟` on all four: the wrapper supplied
    // the name and the chip's own number and unit were merged into the same
    // node. The two tests above were green throughout — they measure where the
    // chips are, not what they say.
    final router = GoRouter(
      initialLocation: '/rest',
      routes: [
        GoRoute(path: '/rest', builder: (context, state) => const RestPage()),
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
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    for (final minutes in RestSession.presets) {
      final node = tester.getSemantics(
        find.byKey(ValueKey('rest_preset_$minutes')),
      );
      expect(node.label, '$minutes 分钟', reason: '$minutes');
    }
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
