import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule, FocusSession, FocusRecord;
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/models/focus_record.dart';
import 'package:cozy_focus_app/domain/models/focus_review.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/focus_save_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// P5 — the review screen, against a real database.
///
/// ## What these tests are for
///
/// The screen's job is to write down what the user chose and nothing else. The
/// case that matters most is the one the screen it replaced got wrong: a user who
/// chooses no mood must get no mood recorded, not a default the app picked. So
/// the assertions go to the stored record rather than to the picker's colour.
void main() {
  late AppDatabase db;
  late _TestClock clock;
  late ProviderContainer container;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _TestClock(DateTime(2026, 10, 8, 9));
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(clock),
      currentUserIdProvider.overrideWithValue(userId),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Runs a session to the point where the review screen is what comes next.
  Future<String> finishedSession() async {
    final notifier = container.read(focusSessionControllerProvider.notifier);
    final session = await notifier.startSession(
      userId: userId,
      plannedSeconds: 25 * 60,
      mode: FocusMode.focus,
      taskName: '写产品方案',
    );
    clock.advance(const Duration(minutes: 25));
    await notifier.completeSession();
    return session.id;
  }

  Widget app() {
    final router = GoRouter(
      initialLocation: '/focus/save',
      routes: [
        GoRoute(
          path: '/focus/save',
          builder: (context, state) => const FocusSavePage(),
        ),
        GoRoute(
          path: '/focus/reward',
          builder: (context, state) => const Scaffold(body: Text('reward')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  /// Pumps fixed frames instead of `pumpAndSettle`: the companion's idle
  /// animation repeats forever, so settling never happens.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await settle(tester);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.text('保存记录');
    await tester.ensureVisible(button);
    await settle(tester);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<FocusRecord> recordFor(String sessionId) async =>
      (await db.focusRecordDao.findBySessionId(sessionId))!;

  testWidgets('offers the four moods with none chosen', (tester) async {
    await finishedSession();
    await pump(tester);

    expect(find.text('这次感觉怎么样？'), findsOneWidget);
    for (final mood in FocusMood.values) {
      expect(find.text(mood.label), findsOneWidget, reason: mood.id);
      final node = tester.getSemantics(
        find.byKey(ValueKey('review_mood_${mood.id}')),
      );
      expect(node.hasFlag(SemanticsFlag.isSelected), isFalse, reason: mood.id);
    }
  });

  testWidgets('saving with nothing chosen records nothing', (tester) async {
    final sessionId = await finishedSession();
    await pump(tester);
    await save(tester);

    final record = await recordFor(sessionId);
    expect(record.mood, isNull);
    expect(record.gains, isNull);
    expect(record.nextIntention, isNull);
    expect(record.note, isNull);
    expect(record.durationSeconds, 25 * 60,
        reason: 'an empty review still records the session');
  });

  testWidgets('the mood that is chosen is the mood that is stored',
      (tester) async {
    final sessionId = await finishedSession();
    await pump(tester);

    await tapKey(tester, 'review_mood_flow');
    final node =
        tester.getSemantics(find.byKey(const ValueKey('review_mood_flow')));
    expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);

    await save(tester);
    expect((await recordFor(sessionId)).mood, 'flow');
  });

  testWidgets('a chosen mood can be taken back', (tester) async {
    final sessionId = await finishedSession();
    await pump(tester);

    await tapKey(tester, 'review_mood_okay');
    await tapKey(tester, 'review_mood_okay');
    final node =
        tester.getSemantics(find.byKey(const ValueKey('review_mood_okay')));
    expect(node.hasFlag(SemanticsFlag.isSelected), isFalse);

    await save(tester);
    expect((await recordFor(sessionId)).mood, isNull,
        reason: 'a picker that cannot be cleared is not optional');
  });

  testWidgets('gains are optional, multiple, and stored as ids',
      (tester) async {
    final sessionId = await finishedSession();
    await pump(tester);

    await tapKey(tester, 'review_gain_moreFocused');
    await tapKey(tester, 'review_gain_newIdeas');

    await save(tester);
    final record = await recordFor(sessionId);
    expect(record.gainValues, [FocusGain.moreFocused, FocusGain.newIdeas]);
    expect(record.gains, 'moreFocused,newIdeas');
  });

  testWidgets('a gain can be un-chosen', (tester) async {
    final sessionId = await finishedSession();
    await pump(tester);

    await tapKey(tester, 'review_gain_learnedSomething');
    await tapKey(tester, 'review_gain_learnedSomething');

    await save(tester);
    expect((await recordFor(sessionId)).gains, isNull);
  });

  testWidgets('what-was-done and next intention reach the record',
      (tester) async {
    final sessionId = await finishedSession();
    await pump(tester);

    await tester.enterText(find.byType(TextField).at(1), '写完了初稿');
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(2), '下次先列提纲');
    await settle(tester);

    await save(tester);
    final record = await recordFor(sessionId);
    expect(record.note, '写完了初稿');
    expect(record.nextIntention, '下次先列提纲');
    expect(record.mood, isNull,
        reason: 'the mood is its own column and was not chosen');
  });

  testWidgets('saving goes on to the reward screen', (tester) async {
    await finishedSession();
    await pump(tester);
    await save(tester);

    expect(find.text('reward'), findsOneWidget);
  });

  testWidgets('the counters count characters, not code units', (tester) async {
    await finishedSession();
    await pump(tester);

    await tester.enterText(find.byType(TextField).at(1), '写完了');
    await settle(tester);
    expect(find.text('3/50'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(2), '试试');
    await settle(tester);
    expect(find.text('2/30'), findsOneWidget);
  });
}

class _TestClock implements FocusClock {
  _TestClock(this._now);
  DateTime _now;

  void advance(Duration by) => _now = _now.add(by);

  @override
  DateTime now() => _now;
}
