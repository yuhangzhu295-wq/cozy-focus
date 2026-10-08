import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/current_task_card.dart';

/// The card design 01 puts between the companion and the duration selector.
///
/// ## What these are for
///
/// Two parts of that card are conditional, and both would be lies if drawn
/// unconditionally: the 专注中 badge claims a session is running, and `2/3`
/// claims a position among the day's tasks. Most of these tests are about those
/// two being absent when they are not true — a card that over-claims is worse
/// than one that shows less.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      );

  group('the subtitle', () {
    test('joins what is known', () {
      expect(
        CurrentTaskCard.subtitleFor(
          position: 2,
          total: 3,
          estimate: const Duration(minutes: 90),
        ),
        '2/3 · 预计 90 分钟',
      );
    });

    test('drops the position when there is none', () {
      // A task reached from a running session that was never planned has no
      // position. `null/3` or `0/3` would both be inventions.
      expect(
        CurrentTaskCard.subtitleFor(estimate: const Duration(minutes: 25)),
        '预计 25 分钟',
      );
    });

    test('drops the estimate when there is none', () {
      expect(
        CurrentTaskCard.subtitleFor(position: 1, total: 4),
        '1/4',
      );
    });

    test('is null when neither is known, so the line is not drawn', () {
      expect(CurrentTaskCard.subtitleFor(), isNull);
      expect(CurrentTaskCard.subtitleFor(position: 1, total: 0), isNull);
      expect(
        CurrentTaskCard.subtitleFor(estimate: Duration.zero),
        isNull,
      );
    });
  });

  group('the card', () {
    testWidgets('shows the task, and the badge only when it is in focus',
        (tester) async {
      await tester.pumpWidget(host(
        CurrentTaskCard(
          title: '写产品方案',
          inFocus: true,
          position: 2,
          total: 3,
          estimate: const Duration(minutes: 90),
          onTap: () {},
        ),
      ));

      expect(find.text('写产品方案'), findsOneWidget);
      expect(find.text('专注中'), findsOneWidget);
      expect(find.text('2/3 · 预计 90 分钟'), findsOneWidget);
    });

    testWidgets('an idle card does not claim to be focusing', (tester) async {
      await tester.pumpWidget(host(
        CurrentTaskCard(
          title: '写产品方案',
          position: 2,
          total: 3,
          estimate: const Duration(minutes: 90),
          onTap: () {},
        ),
      ));

      expect(find.text('写产品方案'), findsOneWidget);
      expect(
        find.text('专注中'),
        findsNothing,
        reason: 'no session is running, so the badge would be a claim',
      );
    });

    testWidgets('the line is absent rather than empty', (tester) async {
      await tester.pumpWidget(host(
        CurrentTaskCard(title: '无计划的任务', onTap: () {}),
      ));

      expect(find.text('无计划的任务'), findsOneWidget);
      expect(find.textContaining('预计'), findsNothing);
      expect(find.textContaining('/'), findsNothing);
    });

    testWidgets('taps reach the caller', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(
        CurrentTaskCard(title: '写产品方案', onTap: () => taps++),
      ));

      await tester.tap(find.text('写产品方案'));
      expect(taps, 1);
    });

    testWidgets('a screen reader hears one sentence, not the fragments',
        (tester) async {
      await tester.pumpWidget(host(
        CurrentTaskCard(
          title: '写产品方案',
          inFocus: true,
          position: 2,
          total: 3,
          estimate: const Duration(minutes: 90),
          onTap: () {},
        ),
      ));

      final node = tester.getSemantics(find.byType(CurrentTaskCard));
      expect(node.label, '当前任务 写产品方案，专注中，2/3 · 预计 90 分钟');
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    });
  });
}
