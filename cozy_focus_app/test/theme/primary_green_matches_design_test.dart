import 'dart:math' as math;

import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG relative luminance, from the sRGB definition.
double _luminance(Color color) {
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('the primary green is the one the designs use', () {
    // Measured with tools/qa/palette_report.py across the sixteen boards: this
    // value fills the primary buttons on every one of them (125,256 pixels),
    // while the #5E8D6D it replaced matched only 1,468 pixels — the
    // anti-aliased fringe of the deeper green, not a fill anywhere.
    const designPrimary = Color(0xFF44714B);

    test('primarySage is the design green, not a lighter one', () {
      expect(AppColors.primarySage, designPrimary);
    });

    test('it is darker than the tint and lighter than the ink', () {
      expect(
        _luminance(AppColors.primarySage),
        lessThan(_luminance(AppColors.primaryLight)),
        reason: 'the pale tint has to stay a tint of the primary',
      );
      expect(
        _luminance(AppColors.primarySage),
        lessThan(_luminance(AppColors.background)),
        reason: 'a primary that is lighter than the page is not a primary',
      );
    });

    test('white on it clears WCAG AA for body text', () {
      // The old #5E8D6D measured 3.82:1, under the 4.5 AA floor, so every
      // filled button in the app was carrying unreadable-by-the-standard label
      // text. This guards the replacement rather than just its hue.
      expect(
        _contrast(AppColors.textLight, AppColors.primarySage),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('the theme actually routes buttons through it', () {
    test('the colour scheme primary is the primary green', () {
      expect(AppTheme.lightTheme.colorScheme.primary, AppColors.primarySage);
    });

    test('the elevated button fill is the primary green', () {
      final style = AppTheme.lightTheme.elevatedButtonTheme.style;
      final resolved = style?.backgroundColor?.resolve(<WidgetState>{});
      expect(resolved, AppColors.primarySage);
    });

    testWidgets('a FilledButton paints it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: FilledButton(onPressed: () {}, child: const Text('开始')),
            ),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(FilledButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, AppColors.primarySage);
    });
  });
}
