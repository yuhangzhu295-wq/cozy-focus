import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart' hide FocusSession;
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/focus_active_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// The running screen's controls must be on screen at every target size.
///
/// ## Found while adding the design's ring
///
/// Reference 04 draws the ring around the timer and the controls below it on one
/// screen. A fixed 224pt ring pushed 暂停 and 提前结束 past the bottom on the
/// smallest target: measured at 360x800, their labels sat at y 790-808 in an
/// 800pt viewport. The page scrolls, so they were reachable — but the design
/// shows them without scrolling, and a primary control you have to hunt for is
/// not the design.
///
/// The ring is sized from the screen height now (see `FocusTimerRing.diameterFor`)
/// and this holds it: the lowest control keeps room for its own padding above the
/// bottom edge, at all three sizes the brief names.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider
          .overrideWithValue(_FixedClock(DateTime(2026, 10, 8, 9))),
      currentUserIdProvider.overrideWithValue('default_user'),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpAt(WidgetTester tester, Size dp) async {
    tester.view.physicalSize = dp;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await container.read(focusSessionControllerProvider.notifier).startSession(
          userId: 'default_user',
          plannedSeconds: 25 * 60,
          mode: FocusMode.focus,
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const FocusActivePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The three sizes the brief names, in dp.
  const targets = [Size(360, 800), Size(393, 852), Size(412, 915)];

  for (final size in targets) {
    testWidgets(
        'the controls fit on screen at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
      await pumpAt(tester, size);

      expect(find.byType(FocusTimerRing), findsOneWidget);

      // The label's own box plus room for the button's vertical padding has to
      // clear the bottom edge. 20pt is under any Material button's padding.
      for (final label in const ['记一下', '暂停', '提前结束']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.bottom, lessThan(size.height - 20),
            reason: '"$label" sits at y ${rect.bottom.toInt()} in a '
                '${size.height.toInt()}pt viewport, so its button is clipped');
      }

      await container
          .read(focusSessionControllerProvider.notifier)
          .cancelSession();
    });
  }

  testWidgets('the ring keeps the design proportion on the drawn-for phone',
      (tester) async {
    await pumpAt(tester, const Size(412, 915));

    // Reference 04 draws it about 220pt across; the cap is 224.
    expect(FocusTimerRing.diameterFor(915), closeTo(220, 1));
    expect(FocusTimerRing.diameterFor(800), lessThan(224),
        reason: 'a short screen gets a smaller ring, which is what keeps the '
            'controls on it');

    await container
        .read(focusSessionControllerProvider.notifier)
        .cancelSession();
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
