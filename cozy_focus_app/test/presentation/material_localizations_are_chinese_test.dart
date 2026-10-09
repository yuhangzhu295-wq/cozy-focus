import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/app_localization.dart';

/// The app is Chinese; Flutter's defaults are not.
///
/// ## Found by reading the accessibility tree on a device
///
/// `/records/today` announced its back control as `Back`. The rest screen, two
/// taps away, announced its own as `返回` — because that one is a hand-built
/// `IconButton` with `semanticLabel: '返回'` while this one is a plain
/// `BackButton`, which takes its name from `MaterialLocalizations`. With no
/// `localizationsDelegates`, `MaterialApp` falls back to
/// `DefaultMaterialLocalizations`, which is English-only.
///
/// Twelve screens use a plain `BackButton`, and `showDatePicker` /
/// `showTimePicker` are Material widgets too: they open with English month
/// names, `SELECT DATE` and `OK`. None of that is visible in a screenshot of
/// the app's own text, which is why only the device tree found it.
void main() {
  testWidgets('the app declares one Chinese locale', (tester) async {
    expect(appLocale.languageCode, 'zh');
    expect(appSupportedLocales, hasLength(1));
    expect(appSupportedLocales.single.languageCode, 'zh');
  });

  testWidgets('Material speaks Chinese under these delegates', (tester) async {
    late MaterialLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: appLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Builder(
          builder: (context) {
            l10n = MaterialLocalizations.of(context);
            return const Scaffold();
          },
        ),
      ),
    );

    // '返回' is what a Chinese Android TalkBack user hears for the back
    // control; 'Back' is what this app used to say.
    expect(l10n.backButtonTooltip, '返回');
    expect(l10n.okButtonLabel, '确定');
  });

  testWidgets('and a plain BackButton takes that name', (tester) async {
    // The exact widget the twelve screens use.
    await tester.pumpWidget(
      MaterialApp(
        locale: appLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              appBar: AppBar(leading: BackButton(onPressed: () {})),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('返回'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('the date picker opens in Chinese too', (tester) async {
    // The second half of the same defect: Material dialogs are Material
    // widgets. `showDatePicker` is reached from 今日计划 and 安排到今日计划.
    await tester.pumpWidget(
      MaterialApp(
        locale: appLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDatePicker(
                context: context,
                initialDate: DateTime(2026, 10, 9),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('确定'), findsWidgets);
    expect(find.text('取消'), findsWidgets);
    // The English default, which is what the app shipped.
    expect(find.text('OK'), findsNothing);
  });
}
