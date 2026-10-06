import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide
        Task,
        TaskSubtask,
        TaskSchedule,
        FocusSession,
        FocusRecord,
        RestSession;
import 'package:cozy_focus_app/domain/models/distraction_note.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/distraction_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/progress_overview_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// The records tab kept saying 还没有记录 after a thought was captured.
///
/// ## Found by walking the app on a device
///
/// The tab's count comes from `openDistractionCountProvider`, a `FutureProvider`
/// that caches its answer for as long as it is alive. Nothing invalidated it, so a
/// count read before the capture was still being served afterwards — the tab said
/// 还没有记录 while the inbox itself held the note. Every inbox test drove the
/// controller directly and never looked at the tab, which is why the suite passed.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider
          .overrideWithValue(_FixedClock(DateTime(2026, 10, 8, 21, 56))),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpRecords(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProgressOverviewPage(),
        ),
      ),
    );
    // Fixed frames rather than settling: the companion's idle animation repeats
    // forever, so `pumpAndSettle` never returns on this screen.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('counts a captured thought without being reopened',
      (tester) async {
    await pumpRecords(tester);

    expect(find.text('还没有记录'), findsOneWidget,
        reason: 'nothing has been captured yet');

    // A capture, through the same call the sheet makes.
    await container
        .read(distractionInboxControllerProvider.notifier)
        .capture(text: '买充电线');
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(find.text('1 条待处理'), findsOneWidget,
        reason: 'the tab has to notice; before this it kept saying 还没有记录 '
            'while the inbox itself held the note');
    expect(find.text('还没有记录'), findsNothing);
  });

  testWidgets('and goes back to zero when the thought is handled',
      (tester) async {
    final inbox = container.read(distractionInboxControllerProvider.notifier);
    await inbox.capture(text: '买充电线');

    await pumpRecords(tester);
    expect(find.text('1 条待处理'), findsOneWidget);

    final note = (await container
            .read(distractionRepositoryProvider)
            .findByFilter(userId, DistractionFilter.open))
        .single;
    await inbox.markHandled(note);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(find.text('还没有记录'), findsOneWidget);
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
