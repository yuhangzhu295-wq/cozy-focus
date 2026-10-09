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
      // Delegates to the scanner rather than reimplementing it.
      //
      // There used to be a Dart copy of this scan beside the Python one, and the
      // copy was weaker: it only knew the `${name}` interpolation form, not the
      // `$name` one — the exact shape that hid the rest page's four duration
      // chips. Two implementations of one rule is how the validator and the pack
      // loader came to disagree about `posePack`; one authority is cheaper.
      final result = _runScanner(const []);

      expect(
        result.exitCode,
        0,
        reason: 'these wrappers will be announced twice:\n${result.stdout}\n'
            'Add excludeSemantics: true, or drop the redundant label.',
      );
    });

    test('and the scan can tell the shapes apart', () {
      // A scanner that reports nothing looks exactly like a codebase with
      // nothing wrong, so the scanner carries the cases it must discriminate
      // and this asserts they still hold.
      final result = _runScanner(const ['--self-test']);

      expect(result.exitCode, 0, reason: result.stdout + result.stderr);
      expect(result.stdout, contains('self-test: ok'));
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

/// Runs the scanner. It is the authority; this file does not reimplement it.
///
/// `--self-test` makes the scanner check the cases it must discriminate — a
/// scanner that reports nothing looks exactly like a codebase with nothing
/// wrong.
ProcessResult _runScanner(List<String> args) => Process.runSync(
      'python',
      ['tools/find_doubled_semantics_labels.py', ...args],
    );

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}
