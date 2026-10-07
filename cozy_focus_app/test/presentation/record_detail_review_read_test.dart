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
import 'package:cozy_focus_app/data/repositories/drift_focus_record_repository.dart';
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/models/focus_review.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/record_detail_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// The record detail screen could not read what the review writes.
///
/// ## Found by walking the app on a device
///
/// P5 gave a record three new answers — a mood id, a set of gain ids, and a next
/// intention — and this screen was never updated to match. Three separate ways it
/// was wrong, all of them invisible to the suite:
///
/// 1. It showed `r.mood` raw, so a user who picked 心流 read the literal string
///    `flow` in their own record.
/// 2. Its edit dialog offered the six old emoji and *wrote the emoji*, so editing
///    a reviewed record put the old vocabulary back — undoing the migration that
///    translated them.
/// 3. `gains` and `nextIntention` were written and read by nothing at all: the
///    review collected two answers and no screen ever showed them.
void main() {
  late AppDatabase db;
  late DriftFocusRecordRepository records;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    records = DriftFocusRecordRepository(db.focusRecordDao);
  });

  tearDown(() async => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider
          .overrideWithValue(_FixedClock(DateTime(2026, 10, 8, 22))),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<String> record({
    String? mood,
    String? gains,
    String? nextIntention,
    String? note,
  }) async {
    await records.insert(FocusRecord(
      id: 'r1',
      sessionId: 'sess1',
      userId: userId,
      taskName: '写产品方案',
      mood: mood,
      gains: gains,
      nextIntention: nextIntention,
      note: note,
      durationSeconds: 25 * 60,
      startAt: DateTime(2026, 10, 8, 21),
      endAt: DateTime(2026, 10, 8, 21, 25),
      recordedAt: DateTime(2026, 10, 8, 21, 25),
      isCountedForReward: true,
    ));
    return 'r1';
  }

  Future<void> pump(
    WidgetTester tester,
    ProviderContainer c, {
    String key = 'r1',
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          // Keyed per case: the page loads its record in initState, so a
          // second pump of the same element would show the first record.
          home: RecordDetailPage(key: ValueKey(key), recordId: 'r1'),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('a reviewed mood reads as its name, not as its id',
      (tester) async {
    await record(mood: FocusMood.flow.id);
    await pump(tester, container());

    expect(find.text('心流'), findsOneWidget);
    expect(find.text('flow'), findsNothing,
        reason: 'the stored id is not a label a user should ever read');
  });

  testWidgets('every mood reads as its own name', (tester) async {
    for (final mood in FocusMood.values) {
      final c = container();
      await db.customStatement("DELETE FROM focus_records");
      await record(mood: mood.id);
      await pump(tester, c, key: mood.id);
      expect(find.text(mood.label), findsOneWidget, reason: mood.id);
      expect(find.text(mood.id), findsNothing, reason: mood.id);
    }
  });

  testWidgets('a legacy emoji still reads, because those rows exist',
      (tester) async {
    await record(mood: String.fromCharCode(0x1F60A));
    await pump(tester, container());
    // The migration translates the six it knows, but a row it did not recognise
    // keeps its value and must not turn into a blank.
    expect(find.text('未选择心情'), findsNothing);
  });

  testWidgets('no mood reads as nothing chosen', (tester) async {
    await record();
    await pump(tester, container());
    expect(find.text('未选择心情'), findsOneWidget);
  });

  testWidgets('the review\'s other two answers are shown', (tester) async {
    await record(
      mood: FocusMood.good.id,
      gains: FocusReview.encodeGains(
        const [FocusGain.moreFocused, FocusGain.newIdeas],
      ),
      nextIntention: '下次先列提纲',
    );
    await pump(tester, container());

    expect(find.text('本次收获'), findsOneWidget);
    expect(find.text('更专注了'), findsOneWidget);
    expect(find.text('有了新想法'), findsOneWidget);
    expect(find.text('下次继续'), findsOneWidget);
    expect(find.text('下次先列提纲'), findsOneWidget);
  });

  testWidgets('and nothing is invented when the record has neither',
      (tester) async {
    await record(mood: FocusMood.good.id);
    await pump(tester, container());

    expect(find.text('本次收获'), findsNothing);
    expect(find.text('下次继续'), findsNothing);
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
