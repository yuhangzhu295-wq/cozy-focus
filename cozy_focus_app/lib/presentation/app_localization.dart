import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// The app is written in Chinese and ships one locale, so this is not a
/// preference — it is the difference between a Material widget speaking the
/// app's language and speaking Flutter's default.
///
/// Without these, `MaterialApp` falls back to `DefaultMaterialLocalizations`,
/// which is English-only. On a device that meant the back button announcing
/// "Back" on the twelve screens that use a plain `BackButton`, and
/// `showDatePicker` / `showTimePicker` opening with English month names,
/// "SELECT DATE" and "OK" — in an otherwise entirely Chinese app.
const List<Locale> appSupportedLocales = <Locale>[Locale('zh')];

const Locale appLocale = Locale('zh');

const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
