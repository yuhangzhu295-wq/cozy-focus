import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule, DistractionNote;
import 'package:cozy_focus_app/domain/models/task.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/distraction_capture_sheet.dart';
import 'package:cozy_focus_app/presentation/widgets/task_category_chip.dart';

/// Four differences between the capture sheet and design 05.
///
/// ## What each of these is for
///
/// The audit compared the running sheet against the board and found the tags all
/// drew the same glyph where the design gives each category its own, the selected
/// tag tinted by category where the design tints by selection, the count sitting
/// below the field where the design puts it inside, and the field half the height
/// the design draws. Each assertion below is one of those, measured rather than
/// eyeballed.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider
          .overrideWithValue(_FixedClock(DateTime(2026, 10, 7, 14, 23))),
      currentUserIdProvider.overrideWithValue('default_user'),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> openSheet(WidgetTester tester) async {
    // The design's target size, so the field's proportions can be compared with
    // the board's. The ratio matters: 1080 physical at a device pixel ratio of
    // 1.0 is a 1080pt-wide viewport, not the 411dp phone the design draws, and
    // the field's height-to-width came out a third of what it should be.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1080 / 411;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDistractionCaptureSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Icon chipIcon(WidgetTester tester, String categoryId) {
    return tester.widget<Icon>(
      find
          .descendant(
            of: find.byKey(ValueKey('distraction_tag_$categoryId')),
            matching: find.byType(Icon),
          )
          .first,
    );
  }

  group('the category tags', () {
    testWidgets('each one draws its own icon', (tester) async {
      await openSheet(tester);

      final icons = <IconData>{};
      for (final category in taskCategories) {
        icons.add(chipIcon(tester, category.id).icon!);
      }

      // Four categories, four different marks. Before this they were all
      // `Icons.sell_outlined` and this set had one element.
      expect(icons, hasLength(taskCategories.length));
    });

    testWidgets('and the icon is the one the model names', (tester) async {
      await openSheet(tester);

      expect(chipIcon(tester, 'life').icon, Icons.home_rounded);
      expect(chipIcon(tester, 'study').icon, Icons.menu_book_rounded);
      expect(chipIcon(tester, 'work').icon, Icons.work_rounded);
      expect(chipIcon(tester, 'other').icon, Icons.more_horiz_rounded);
    });

    testWidgets('selection is the brand green, not the category colour',
        (tester) async {
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('distraction_tag_life')));
      await tester.pump();

      final decoration = tester
          .widget<Container>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('distraction_tag_life')),
                  matching: find.byType(Container),
                )
                .first,
          )
          .decoration! as BoxDecoration;

      // 生活's own colour is `catLife` (orange). Selecting it must not paint the
      // chip orange: on a screen where the chip is a *choice*, the tint means
      // "chosen", and design 05 draws it green.
      expect(decoration.color, AppColors.primaryLight);
      expect(decoration.color,
          isNot(taskCategoryColor('life').withValues(alpha: 0.14)));
    });
  });

  group('the input field', () {
    testWidgets('puts the count inside the box', (tester) async {
      await openSheet(tester);

      final field = tester.getRect(find.byType(TextField));
      final counter = tester.getRect(find.text('0/100'));

      // Flutter's own counter renders below the field and outside its border;
      // the design draws it inside the bottom-right corner.
      expect(
        field.contains(counter.bottomRight),
        isTrue,
        reason: 'counter at $counter is outside the field at $field',
      );
    });

    testWidgets('is about as tall as the design draws it', (tester) async {
      await openSheet(tester);

      final field = tester.getRect(find.byType(TextField));
      final ratio = field.height / field.width;

      // Measured off the board: the design's field is about a third of its own
      // width, roughly four lines. The old two-line field was 0.17.
      expect(
        ratio,
        greaterThan(0.25),
        reason: 'field is ${field.height} x ${field.width}, ratio $ratio',
      );
    });

    testWidgets('and the count still counts', (tester) async {
      await openSheet(tester);

      await tester.enterText(find.byType(TextField), 'buy milk');
      await tester.pump();

      expect(find.text('8/100'), findsOneWidget);
    });
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
