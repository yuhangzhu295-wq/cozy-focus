import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule, DistractionNote;
import 'package:cozy_focus_app/domain/models/distraction_note.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/distraction_capture_sheet.dart';

/// P4 — the capture sheet, against a real database.
///
/// ## What these tests are for
///
/// The sheet's only job is to get a thought into the inbox without costing the
/// user their focus, so every assertion ends at the database: what was typed, the
/// tag that was on screen, and which session it interrupted. A test that only
/// checked the sheet closed would pass on a version that saved nothing.
void main() {
  late AppDatabase db;
  late _FixedClock clock;
  late ProviderContainer container;

  const userId = 'default_user';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _FixedClock(DateTime(2026, 10, 7, 14, 23));
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

  Widget host({String? sessionId}) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDistractionCaptureSheet(
                    context,
                    sessionId: sessionId,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> openSheet(WidgetTester tester, {String? sessionId}) async {
    await tester.pumpWidget(host(sessionId: sessionId));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<List<DistractionNote>> notes() =>
      db.distractionDao.findByFilter(userId, DistractionFilter.all);

  testWidgets('saves what was typed and closes', (tester) async {
    await openSheet(tester);

    expect(find.text('分心收集箱'), findsOneWidget);
    expect(find.text('想到什么，先记下来…'), findsOneWidget);
    expect(find.text('0/100'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '买充电线');
    await tester.pump();
    expect(find.text('4/100'), findsOneWidget);

    await tester.tap(find.text('记下，继续专注'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final saved = await notes();
    expect(saved, hasLength(1));
    expect(saved.single.text, '买充电线');
    expect(saved.single.categoryId, isNull);
    expect(saved.single.createdAt, clock.now());
    expect(find.text('分心收集箱'), findsNothing, reason: 'the sheet closed');
  });

  testWidgets('the tag on screen is the tag that is stored', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), '买充电线');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('distraction_tag_life')));
    await tester.pump();
    await tester.tap(find.text('记下，继续专注'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect((await notes()).single.categoryId, 'life');
  });

  testWidgets('the tag is optional and can be un-chosen', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), '随便想到的');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('distraction_tag_work')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('distraction_tag_work')));
    await tester.pump();
    await tester.tap(find.text('记下，继续专注'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect((await notes()).single.categoryId, isNull,
        reason: 'a tag that cannot be taken back is not optional');
  });

  testWidgets('an empty note cannot be saved', (tester) async {
    await openSheet(tester);

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '记下，继续专注'),
    );
    expect(save.onPressed, isNull);
    expect(await notes(), isEmpty);
  });

  testWidgets('whitespace alone is not a thought', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), '    ');
    await tester.pump();

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '记下，继续专注'),
    );
    expect(save.onPressed, isNull);
    expect(await notes(), isEmpty);
  });

  testWidgets('closing without saving stores nothing', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), '算了我自己记');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('distraction_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(await notes(), isEmpty);
    expect(find.text('分心收集箱'), findsNothing);
  });

  testWidgets('the note remembers the session it interrupted', (tester) async {
    await openSheet(tester, sessionId: 'sess_1');
    await tester.enterText(find.byType(TextField), '买充电线');
    await tester.pump();
    await tester.tap(find.text('记下，继续专注'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect((await notes()).single.sessionId, 'sess_1');
  });

  testWidgets('a screen reader is told what the tags and the close button are',
      (tester) async {
    await openSheet(tester);

    // Addressed by key, then read through the semantics tree: a chip's label
    // merges with its own text, so matching the prose alone would also match
    // anything else saying 生活.
    for (final id in const ['life', 'study', 'work', 'other']) {
      final node = tester.getSemantics(
        find.byKey(ValueKey('distraction_tag_$id')),
      );
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue, reason: id);
      expect(node.hasFlag(SemanticsFlag.isSelected), isFalse, reason: id);
    }
    expect(find.byKey(const ValueKey('distraction_close')), findsOneWidget);
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
