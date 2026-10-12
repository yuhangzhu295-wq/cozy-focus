import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/navigation/app_router.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// Every main screen, at the three sizes the brief names, at 1.0 and 1.3 text.
///
/// ## Why this is a test and not a device sweep
///
/// The brief asks for 360x800 / 393x852 / 412x915 and at least 1.3x text. The device
/// could not be relied on for it: the host has 3.3 GB free and the emulator swaps, so
/// the app is reclaimed mid-flow and the foreground falls back to another app. A
/// layout overflow is a property of the widget tree at a given size, and a widget
/// test sets that size exactly - so this is the instrument that actually answers the
/// question, and it runs in CI rather than depending on a phone being free.
///
/// A RenderFlex overflow throws during layout, so simply pumping each screen at each
/// size is the assertion. `takeException` is checked explicitly so the failure names
/// the overflow rather than surfacing later as an unrelated error.
///
/// What it cannot see: anything the device draws outside Flutter's tree, and the
/// real-device look. Those stay the device's job.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider
          .overrideWithValue(_FixedClock(DateTime(2026, 10, 12, 10))),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  /// The three sizes the brief names, in dp.
  const sizes = <Size>[Size(360, 800), Size(393, 852), Size(412, 915)];

  /// The routes worth sweeping, each with a string that only that screen draws.
  ///
  /// The marker is the point: a sweep that only checks for exceptions is green when
  /// the route never rendered at all.
  const markers = <String, String>{
    '/': '选择专注时长',
    '/records': '今天的专注',
    '/growth': '成长属性',
    '/records/tasks': '新建任务',
    '/records/today': '计划',
    '/records/inbox': '分心箱清单',
    '/settings': '设置',
    '/rest': '开始休息',
  };

  for (final size in sizes) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets(
          'no screen overflows at ${size.width.toInt()}x${size.height.toInt()} '
          'at ${scale}x text', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        // Through the platform dispatcher, NOT by wrapping the app in a MediaQuery.
        // The first version did the latter with a bare `MediaQueryData(textScaler:)`,
        // which carries no size - so every screen laid out at 0x0 and nothing could
        // overflow. It went green while a deliberately 2000px-wide header sat in the
        // tree. A sweep that cannot fail is worse than no sweep.
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });

        final c = container();
        final router = createAppRouter();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        for (final entry in markers.entries) {
          router.go(entry.key);
          // Fixed pumps rather than pumpAndSettle: the companion animation never
          // settles, so pumpAndSettle would time out on every screen that has one.
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 60));
          }
          // Proof the route rendered. Without this the sweep is green for the wrong
          // reason - it was, until the marker was added.
          expect(find.text(entry.value), findsWidgets,
              reason: '${entry.key} did not render its marker '
                  '"${entry.value}" at '
                  '${size.width.toInt()}x${size.height.toInt()}');
          final error = tester.takeException();
          expect(error, isNull,
              reason: '${entry.key} overflowed at '
                  '${size.width.toInt()}x${size.height.toInt()} '
                  'at ${scale}x text: $error');
        }
      });
    }
  }
  testWidgets('the sweep can fail: a deliberate overflow is caught at 360x800',
      (tester) async {
    // The reverse proof for the sweep itself. The first version of this file was
    // green while a 2000px-wide header sat in the tree, because it wrapped the app in
    // a bare `MediaQueryData(textScaler:)` with no size and every screen laid out at
    // 0x0. A sweep that cannot fail is worse than no sweep, so this pins the
    // instrument: at the smallest size the brief names, an overflowing Row must be
    // reported.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(width: 2000, height: 8),
              SizedBox(width: 2000, height: 8),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNotNull,
        reason:
            'the instrument must report an overflow, or every green above is '
            'unearned');
  });
}

class _FixedClock implements FocusClock {
  final DateTime _now;
  _FixedClock(this._now);
  @override
  DateTime now() => _now;
}
