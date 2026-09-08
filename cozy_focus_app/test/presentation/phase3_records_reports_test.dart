import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cozy_focus_app/data/local/app_database.dart' hide FocusRecord;
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/controllers/records_controller.dart';
import 'package:cozy_focus_app/presentation/pages/progress_overview_page.dart';
import 'package:cozy_focus_app/presentation/pages/record_detail_page.dart';
import 'package:cozy_focus_app/presentation/pages/weekly_report_page.dart';
import 'package:cozy_focus_app/presentation/pages/monthly_report_page.dart';
import 'package:cozy_focus_app/presentation/pages/yearly_report_page.dart';
import 'package:cozy_focus_app/presentation/pages/yearly_wrapped_share_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

class Phase3TestClock implements FocusClock {
  DateTime _now;
  Phase3TestClock(this._now);
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
}

Widget createTestApp(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    ),
  );
}

void main() {
  late AppDatabase db;
  late Phase3TestClock testClock;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    testClock = Phase3TestClock(DateTime(2026, 9, 8, 14, 0, 0));
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider.overrideWithValue(testClock),
      ],
    );

    // Seed test records into db
    final recordRepo = container.read(focusRecordRepositoryProvider);
    final baseDate = DateTime(2026, 9, 8, 10, 0, 0);

    final record1 = FocusRecord(
      id: 'rec-1',
      sessionId: 'sess-1',
      userId: 'default_user',
      taskName: 'Flutter Architecture Review',
      categoryId: 'work',
      mood: '😊',
      durationSeconds: 1500, // 25 min
      startAt: baseDate,
      endAt: baseDate.add(const Duration(minutes: 25)),
      recordedAt: baseDate.add(const Duration(minutes: 25)),
      isCountedForReward: true,
      note: 'Finished phase 3 architecture',
    );

    final record2 = FocusRecord(
      id: 'rec-2',
      sessionId: 'sess-2',
      userId: 'default_user',
      taskName: 'Reading Domain Book',
      categoryId: 'reading',
      mood: '😌',
      durationSeconds: 1800, // 30 min
      startAt: baseDate.subtract(const Duration(days: 1)),
      endAt: baseDate
          .subtract(const Duration(days: 1))
          .add(const Duration(minutes: 30)),
      recordedAt: baseDate
          .subtract(const Duration(days: 1))
          .add(const Duration(minutes: 30)),
      isCountedForReward: true,
      note: 'Deep focus reading',
    );

    await recordRepo.insert(record1);
    await recordRepo.insert(record2);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Phase 3 Records & Reports UI & Controller Tests', () {
    testWidgets(
        'Screen 05: ProgressOverviewPage renders today records and switches tabs',
        (tester) async {
      await tester
          .pumpWidget(createTestApp(container, const ProgressOverviewPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('今日记录'), findsOneWidget);
      expect(find.text('今日'), findsOneWidget);
      expect(find.text('历史'), findsOneWidget);
      expect(find.text('日历'), findsOneWidget);

      // Verify today's content
      expect(find.text('今日专注时长'), findsOneWidget);
      expect(find.text('专注次数'), findsOneWidget);

      // Switch to History tab (tab index 1)
      await tester.tap(find.text('历史'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, '全部'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '学习'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '工作'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '阅读'), findsOneWidget);
    });

    testWidgets(
        'Screen 05C: RecordDetailPage loads record, renders details and action dialogs',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
          createTestApp(container, const RecordDetailPage(recordId: 'rec-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('记录详情'), findsOneWidget);
      expect(find.text('Flutter Architecture Review'), findsOneWidget);
      expect(find.text('25 分钟'), findsOneWidget);
      expect(find.text('😊'), findsOneWidget);
      expect(find.text('Finished phase 3 architecture'), findsOneWidget);
      expect(find.text('编辑记录'), findsOneWidget);
      expect(find.text('删除记录'), findsOneWidget);

      // Tap Edit record button
      await tester.tap(find.text('编辑记录'));
      await tester.pumpAndSettle();
      expect(find.text('编辑记录'), findsWidgets);
      expect(find.text('取消'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Tap Delete record button
      await tester.tap(find.text('删除记录'));
      await tester.pumpAndSettle();
      expect(find.text('确认删除记录？'), findsOneWidget);
      expect(find.text('删除此记录后，相关的统计数据与图表将被重新计算。此操作不可恢复。'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'Screen 06: WeeklyReportPage renders weekly stats, Mochi dialogue, and share CTA',
        (tester) async {
      await tester
          .pumpWidget(createTestApp(container, const WeeklyReportPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('数据记录'), findsOneWidget);
      expect(find.text('周报'), findsOneWidget);
      expect(find.text('专注总时长'), findsOneWidget);
      expect(find.text('专注次数'), findsOneWidget);
      expect(find.text('本周最强专注日'), findsOneWidget);
      expect(find.text('分享本周成就'), findsOneWidget);
    });

    testWidgets(
        'Screen 07: MonthlyReportPage renders monthly stats, time slots, and navigation',
        (tester) async {
      await tester
          .pumpWidget(createTestApp(container, const MonthlyReportPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('专注记录'), findsOneWidget);
      expect(find.text('月报'), findsOneWidget);
      expect(find.text('分享月度成就'), findsOneWidget);
      expect(find.text('平均专注时长'), findsOneWidget);
      expect(find.text('最长一次专注'), findsOneWidget);
    });

    testWidgets(
        'Screen 08: YearlyReportPage renders yearly summary and wrapped CTA',
        (tester) async {
      await tester
          .pumpWidget(createTestApp(container, const YearlyReportPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('年度报告'), findsOneWidget);
      expect(find.text('我的专注之旅'), findsOneWidget);
      expect(find.text('最佳月份'), findsOneWidget);
      expect(find.text('最常专注时间段'), findsOneWidget);
      expect(find.text('生成并分享我的年度报告'), findsOneWidget);
    });

    testWidgets(
        'Screen 08A: YearlyWrappedSharePage renders privacy note and share button',
        (tester) async {
      await tester
          .pumpWidget(createTestApp(container, const YearlyWrappedSharePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('年度 Wrapped 分享'), findsOneWidget);
      expect(find.textContaining('Focus Journey'), findsOneWidget);
      expect(find.textContaining('不含私人备注'), findsOneWidget);
      expect(find.text('保存卡片到相册'), findsOneWidget);
    });

    test('RecordsController update and delete functionality works with real DB',
        () async {
      final recordsNotifier =
          container.read(recordsControllerProvider.notifier);
      await recordsNotifier.loadData();

      // Verify initial records
      var state = container.read(recordsControllerProvider);
      expect(state.allRecords.length, 2);

      final recordRepo = container.read(focusRecordRepositoryProvider);
      final r1 = await recordRepo.findById('rec-1');
      expect(r1, isNotNull);

      // Update record 1 note and mood
      await recordsNotifier.updateRecord(
        r1!.copyWith(
          taskName: 'Updated Task Name',
          mood: '🔥',
          note: 'Updated Note',
        ),
      );

      final updated = await recordRepo.findById('rec-1');
      expect(updated, isNotNull);
      expect(updated!.taskName, 'Updated Task Name');
      expect(updated.mood, '🔥');
      expect(updated.note, 'Updated Note');

      // Delete record 2
      await recordsNotifier.deleteRecord('rec-2');
      final deleted = await recordRepo.findById('rec-2');
      expect(deleted, isNull);

      await recordsNotifier.loadData();
      state = container.read(recordsControllerProvider);
      expect(state.allRecords.length, 1);
    });
  });
}
