import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/focus_control_row.dart';

/// The round controls design 04 draws under the timer.
///
/// ## What these are for
///
/// The hierarchy on this row is carried by **size and weight**, not by position:
/// the board makes the control the screen is for the largest circle and the only
/// filled one. An earlier version of this screen drew every control full width,
/// so nothing said which one it was for — and a test that only counted three
/// buttons would pass on that just as happily.
void main() {
  Widget host(List<FocusControl> controls) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: FocusControlRow(controls: controls)),
      );

  List<FocusControl> three({VoidCallback? onPause, bool pauseEnabled = true}) =>
      [
        FocusControl(
            icon: Icons.edit_note_rounded, label: '记一下', onPressed: () {}),
        FocusControl(
          icon: Icons.pause_rounded,
          label: '暂停',
          primary: true,
          onPressed: pauseEnabled ? (onPause ?? () {}) : null,
        ),
        FocusControl(icon: Icons.stop_rounded, label: '提前结束', onPressed: () {}),
      ];

  /// The circle behind a control's icon.
  Container circleOf(WidgetTester tester, IconData icon) {
    return tester.widget<Container>(
      find
          .ancestor(of: find.byIcon(icon), matching: find.byType(Container))
          .first,
    );
  }

  group('the row', () {
    testWidgets('draws one circle per control, with its name underneath',
        (tester) async {
      await tester.pumpWidget(host(three()));

      for (final label in const ['记一下', '暂停', '提前结束']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    });

    testWidgets('makes the primary the largest and the filled one',
        (tester) async {
      await tester.pumpWidget(host(three()));

      final primary = circleOf(tester, Icons.pause_rounded);
      final secondary = circleOf(tester, Icons.edit_note_rounded);

      final primaryBox = tester.getSize(find.byWidget(primary));
      final secondaryBox = tester.getSize(find.byWidget(secondary));
      expect(primaryBox.width, FocusControlRow.primaryDiameter);
      expect(secondaryBox.width, FocusControlRow.secondaryDiameter);
      expect(primaryBox.width, greaterThan(secondaryBox.width));

      expect(
          (primary.decoration! as BoxDecoration).color, AppColors.primarySage);
      expect(
        (secondary.decoration! as BoxDecoration).color,
        AppColors.primaryLight,
      );
    });

    testWidgets('greys a control it refuses instead of hiding it',
        (tester) async {
      // Deep focus cannot pause. The board has no such state, but the app does,
      // and the control has to say so rather than vanish.
      await tester.pumpWidget(host(three(pauseEnabled: false)));

      final paused = circleOf(tester, Icons.pause_rounded);
      expect(
        (paused.decoration! as BoxDecoration).color,
        AppColors.surfaceMuted,
      );
      expect(find.text('暂停'), findsOneWidget);
    });

    testWidgets('each one is a named button', (tester) async {
      await tester.pumpWidget(host(three()));

      for (final label in const ['记一下', '暂停', '提前结束']) {
        final node = tester.getSemantics(find.text(label));
        expect(node.label, label, reason: label);
        expect(node.hasFlag(SemanticsFlag.isButton), isTrue, reason: label);
      }
    });

    testWidgets('and a refused one says it is not enabled', (tester) async {
      await tester.pumpWidget(host(three(pauseEnabled: false)));

      final node = tester.getSemantics(find.text('暂停'));
      expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse);
    });

    testWidgets('tapping reaches the callback', (tester) async {
      var pauses = 0;
      await tester.pumpWidget(host(three(onPause: () => pauses++)));

      await tester.tap(find.text('暂停'));
      expect(pauses, 1);
    });
  });
}
