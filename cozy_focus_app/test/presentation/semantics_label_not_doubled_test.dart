import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide Task, TaskSubtask, TaskSchedule, DistractionNote;
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/distraction_capture_sheet.dart';

/// A `Semantics` wrapper that repeats the text it wraps makes a screen reader say
/// the same thing twice.
///
/// ## Found on the device
///
/// The capture sheet's category chips are written as
///
/// ```dart
/// Semantics(button: true, label: '标签 ${category.label}', child: ... Text(category.label))
/// ```
///
/// which reads as if the wrapper renames the chip. It does not: `Semantics` keeps
/// the semantics of what it wraps, so the two merge into one node. Asking the
/// Android accessibility tree for that chip returned
/// `标签 生活&#10;生活` — the label, then the label again.
///
/// This is the second time in this project that the obvious reading of an
/// accessibility API was not the one that behaves; the first was the unnamed
/// `IconButton`, where wrapping in `Semantics` produced *two* button nodes.
///
/// The fix is `excludeSemantics: true` on the wrapper, which makes the wrapper
/// supply the whole name. It was applied to sixteen wrappers found by
/// `tools/find_doubled_semantics_labels.py`.
void main() {
  group('no Semantics wrapper repeats the text it wraps', () {
    test('across the whole of lib/', () {
      final offenders = _scanLib();

      expect(
        offenders,
        isEmpty,
        reason: 'these wrappers will be announced twice:\n'
            '${offenders.map((o) => '  $o').join('\n')}\n'
            'Add excludeSemantics: true, or drop the redundant label.',
      );
    });
  });

  group('the capture sheet chip', () {
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

    testWidgets('announces its label once, not twice', (tester) async {
      await openSheet(tester);

      final node = tester.getSemantics(
        find.byKey(const ValueKey('distraction_tag_life')),
      );

      // The whole name, exactly. Before the fix this read
      // '标签 生活\n生活', because the wrapper's label and the child Text merged.
      expect(node.label, '标签 生活');
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(node.hasFlag(SemanticsFlag.isSelected), isFalse);
    });
  });
}

/// Every `Semantics(` in lib/ that supplies a `label` repeating the text it wraps.
///
/// Paren-aware rather than line-based: the wrapper and the `Text` it duplicates
/// can be twenty lines apart, and a window heuristic would flag unrelated `Text`
/// widgets that happen to sit inside the same card.
List<String> _scanLib() {
  final offenders = <String>[];
  final root = Directory('lib');
  if (!root.existsSync()) return offenders;

  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart')) continue;
    final source = entity.readAsStringSync();

    for (final match in RegExp(r'(?<![\w.])Semantics\(').allMatches(source)) {
      final open = match.end - 1;
      final close = _matchParen(source, open);
      if (close < 0) continue;
      final body = source.substring(open + 1, close);

      final label = _argument(body, 'label');
      if (label == null || label.isEmpty) continue;
      if (body.contains('excludeSemantics: true')) continue;

      final wanted = _normalise(label);
      if (wanted.isEmpty) continue;

      for (final text in RegExp(r'(?<![\w.])Text\(\s*').allMatches(body)) {
        final value = _normalise(_firstArgument(body, text.end));
        if (value.isEmpty) continue;
        if (value == wanted || wanted.contains('\${$value}')) {
          final line = '\n'.allMatches(source.substring(0, open)).length + 1;
          offenders.add('${entity.path}:$line  label $label / Text($value)');
          break;
        }
      }
    }
  }
  return offenders;
}

String _normalise(String expression) =>
    expression.replaceAll(RegExp(r'\s+'), '');

int _skipString(String source, int index) {
  final quote = source[index];
  if (source.startsWith(quote * 3, index)) {
    final end = source.indexOf(quote * 3, index + 3);
    return end < 0 ? source.length : end + 3;
  }
  var i = index + 1;
  while (i < source.length) {
    if (source[i] == r'\') {
      i += 2;
      continue;
    }
    if (source[i] == quote) return i + 1;
    if (source[i] == '\n') return i;
    i++;
  }
  return source.length;
}

int _matchParen(String source, int openIndex) {
  var depth = 0;
  var i = openIndex;
  while (i < source.length) {
    final ch = source[i];
    if (ch == "'" || ch == '"') {
      i = _skipString(source, i);
      continue;
    }
    if (ch == '/' && i + 1 < source.length && source[i + 1] == '/') {
      final nl = source.indexOf('\n', i);
      i = nl < 0 ? source.length : nl;
      continue;
    }
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  return -1;
}

/// The value of the named argument, up to the next comma at depth zero.
String? _argument(String body, String name) {
  final match = RegExp('(?<![\\w.])$name\\s*:\\s*').firstMatch(body);
  if (match == null) return null;
  return _slice(body, match.end);
}

/// The first positional argument starting at [start].
String _firstArgument(String body, int start) => _slice(body, start);

String _slice(String body, int start) {
  var depth = 0;
  var i = start;
  while (i < body.length) {
    final ch = body[i];
    if (ch == "'" || ch == '"') {
      i = _skipString(body, i);
      continue;
    }
    if (ch == '(' || ch == '[' || ch == '{') {
      depth++;
    } else if (ch == ')' || ch == ']' || ch == '}') {
      if (depth == 0) break;
      depth--;
    } else if (ch == ',' && depth == 0) {
      break;
    }
    i++;
  }
  return body.substring(start, i).trim();
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
