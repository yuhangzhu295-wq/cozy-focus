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
        DistractionNote;
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/models/focus_review.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/progress_overview_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// A reviewed session's row in 今日记录 printed the stored mood id.
///
/// ## Found by walking the flow on a device
///
/// The record detail screen had already been taught to resolve a mood through
/// `FocusMood`; the list row beside it had not, so a session reviewed as 心流
/// showed the string `flow` — the value in the column, which is not something
/// the user wrote and not something they can read. `FocusMood.face` exists
/// precisely so that "the review screen, the record detail screen and any later
/// summary draw the same face for the same mood", and this row was the summary
/// that had been missed.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider
          .overrideWithValue(_FixedClock(DateTime(2026, 10, 8, 9, 30))),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// A record on the day the page is showing, with [mood] as stored.
  Future<void> seedRecord(
    String? mood, {
    String id = 'rec_1',
    int hour = 9,
  }) async {
    final at = DateTime(2026, 10, 8, hour, 13);
    await db.focusRecordDao.insert(FocusRecord(
      id: id,
      sessionId: 'sess_$id',
      userId: userId,
      taskName: '专注任务',
      mood: mood,
      timingMode: FocusTimingMode.countdown,
      durationSeconds: 120,
      startAt: at,
      endAt: at.add(const Duration(minutes: 2)),
      recordedAt: at.add(const Duration(minutes: 2)),
      isCountedForReward: true,
    ));
  }

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

  testWidgets('a reviewed mood is drawn as its face, never as its id',
      (tester) async {
    await seedRecord(FocusMood.flow.id);
    await pumpRecords(tester);

    expect(find.text(FocusMood.flow.face), findsOneWidget);
    expect(find.text('flow'), findsNothing,
        reason: 'the id in the column is not a word for the user');
  });

  testWidgets('every mood the review writes draws its own face',
      (tester) async {
    // One row per mood, all on the same day, so a single pump covers the whole
    // vocabulary.
    for (var i = 0; i < FocusMood.values.length; i++) {
      await seedRecord(
        FocusMood.values[i].id,
        id: 'rec_$i',
        hour: 8 + i,
      );
    }
    await pumpRecords(tester);

    for (final mood in FocusMood.values) {
      expect(find.text(mood.face), findsOneWidget, reason: mood.id);
      expect(find.text(mood.id), findsNothing, reason: mood.id);
    }
  });

  testWidgets('a record with no mood shows no mood mark at all',
      (tester) async {
    await seedRecord(null);
    await pumpRecords(tester);

    for (final mood in FocusMood.values) {
      expect(find.text(mood.face), findsNothing, reason: mood.id);
    }
  });

  testWidgets('a legacy emoji is still shown as it is', (tester) async {
    // The column predates the vocabulary and holds free-form strings. An
    // unrecognised one is shown rather than relabelled or hidden.
    await seedRecord('🤔');
    await pumpRecords(tester);

    expect(find.text('🤔'), findsOneWidget);
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
