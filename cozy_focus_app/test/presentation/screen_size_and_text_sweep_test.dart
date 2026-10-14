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
  const portrait = <Size>[Size(360, 800), Size(393, 852), Size(412, 915)];

  /// The same three devices rotated.
  ///
  /// Landscape is not hypothetical here. `AndroidManifest.xml` carries no
  /// `screenOrientation` lock and its `configChanges` includes `orientation`, so
  /// the activity really does rotate and re-lay-out in place. Before this list
  /// existed nothing had ever laid a screen out at 800x360, so "adapts to
  /// different sizes" was only half checked - the half that happens to be
  /// portrait.
  const landscape = <Size>[Size(800, 360), Size(852, 393), Size(915, 412)];

  const sizes = <Size>[...portrait, ...landscape];

  /// The routes worth sweeping, each with a string that only that screen draws.
  ///
  /// The marker is the point: a sweep that only checks for exceptions is green when
  /// the route never rendered at all.
  const markers = <String, String>{
    '/': '选择专注时长',
    '/records': '今天的专注',
    '/growth': '成长属性',
    '/records/tasks': '新建任务',
    '/records/today': '列表',
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
          await settle(tester);

          // Proof the route rendered, and proof the marker is not doing it by
          // accident: `skipOffstage: false` because the default finder visits only
          // the slivers currently inside the viewport. In landscape a page is 360dp
          // tall, so a section that sits mid-page is built but off-stage, and the
          // default finder reports zero. That is a property of the finder, not of
          // the screen - it was the growth page's 成长属性 and nothing else.
          expect(find.text(entry.value, skipOffstage: false), findsWidgets,
              reason: '${entry.key} did not render its marker '
                  '"${entry.value}" at '
                  '${size.width.toInt()}x${size.height.toInt()}');
          final error = tester.takeException();
          expect(error, isNull,
              reason: '${entry.key} overflowed at '
                  '${size.width.toInt()}x${size.height.toInt()} '
                  'at ${scale}x text: $error');

          // Scroll to the end. Two things come out of this that the first
          // viewport cannot show: the sections below the fold get laid out (a
          // sliver outside the viewport is built but its layout is only checked
          // when it is reached), and the marker has to actually become visible -
          // "built somewhere in the tree" is not the same claim as "the user can
          // get to it", and on a short landscape viewport that difference is the
          // whole question.
          var seenOnStage = find.text(entry.value).evaluate().isNotEmpty;
          for (var step = 0; step < 14; step++) {
            final target = verticalScrollable(tester);
            if (target == null) break;
            await tester.drag(target, const Offset(0, -600),
                warnIfMissed: false);
            await settle(tester, frames: 4);
            if (find.text(entry.value).evaluate().isNotEmpty) {
              seenOnStage = true;
            }
            final scrollError = tester.takeException();
            expect(scrollError, isNull,
                reason: '${entry.key} overflowed while scrolling at '
                    '${size.width.toInt()}x${size.height.toInt()} '
                    'at ${scale}x text: $scrollError');
          }
          expect(seenOnStage, isTrue,
              reason: '${entry.key} built its marker but never showed it, even '
                  'after scrolling to the end, at '
                  '${size.width.toInt()}x${size.height.toInt()}');
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

  testWidgets(
      'the reachability step can fail: content below the fold is not '
      'visible until it is scrolled to', (tester) async {
    // The other half of the instrument. The landscape rows above only pass
    // because the scroll step brings mid-page content on stage, so if that step
    // ever stopped doing work the sweep would go green while reporting nothing.
    // This pins the mechanism on a real screen: at 800x360 the growth page's
    // sub-nav is built but sits below the fold.
    //
    // It used to be 成长属性 that played this part. Removing the growth page's
    // header and moving its sub-nav to the bottom - board 10's layout - lifted
    // 成长属性 into the first viewport, so it could no longer demonstrate
    // anything about scrolling. The sub-nav is now the last sliver, which is a
    // stronger case for the same mechanism.
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
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
    router.go('/growth');
    await settle(tester);

    expect(find.text('图鉴', skipOffstage: false), findsWidgets,
        reason: 'the growth page must build its sub-nav at all');
    expect(find.text('图鉴'), findsNothing,
        reason: 'at 360dp tall the sub-nav must start below the fold, or this '
            'test is not exercising the scroll step');

    final target = verticalScrollable(tester);
    expect(target, isNotNull,
        reason: 'the scroll step needs a vertical scrollable to drive');

    var revealed = false;
    for (var step = 0; step < 14 && !revealed; step++) {
      await tester.drag(target!, const Offset(0, -600), warnIfMissed: false);
      await settle(tester, frames: 4);
      revealed = find.text('图鉴').evaluate().isNotEmpty;
    }
    expect(revealed, isTrue,
        reason: 'scrolling must bring the section on stage; if this fails the '
            'sweep above is green for the wrong reason');
  });
}

/// Pump a fixed number of frames.
///
/// Not `pumpAndSettle`: the companion animation is continuous, so settling would
/// time out on every screen that has one.
Future<void> settle(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// The first vertical scrollable, or null when the screen has none.
///
/// Vertical on purpose. Several screens carry horizontal chip rows, and
/// `find.byType(Scrollable).first` can land on one of those - a vertical drag on
/// a horizontal list moves nothing, so the scroll step would silently do no work
/// and the reachability assertion would fail for the wrong reason.
Finder? verticalScrollable(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    skipOffstage: false,
  );
  return finder.evaluate().isEmpty ? null : finder.first;
}

class _FixedClock implements FocusClock {
  final DateTime _now;
  _FixedClock(this._now);
  @override
  DateTime now() => _now;
}
