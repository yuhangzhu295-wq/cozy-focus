import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide
        Task,
        TaskSubtask,
        TaskSchedule,
        FocusSession,
        FocusRecord,
        RestSession,
        DistractionNote;
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/controllers/focus_session_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/pages/companion_picker_page.dart';
import 'package:cozy_focus_app/presentation/pages/distraction_inbox_page.dart';
import 'package:cozy_focus_app/presentation/pages/focus_active_page.dart';
import 'package:cozy_focus_app/presentation/pages/monthly_report_page.dart';
import 'package:cozy_focus_app/presentation/pages/pet_collection_page.dart';
import 'package:cozy_focus_app/presentation/pages/pet_dress_page.dart';
import 'package:cozy_focus_app/presentation/pages/progress_overview_page.dart';
import 'package:cozy_focus_app/presentation/pages/weekly_report_page.dart';
import 'package:cozy_focus_app/presentation/pages/yearly_report_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// Every button a screen reader reaches must say what it is.
///
/// ## Found by a programmatic pass, which is the only way it would have been
///
/// The state file listed "a programmatic pass over touch-target sizes and
/// semantics coverage on the new screens" as work that could be done alone.
/// Twenty-five `IconButton`s in `lib/presentation` had no accessible name: no
/// tooltip, no `Semantics` wrapper. Back arrows, the report pages'
/// previous/next chevrons, the review screen's close, the share button. A screen
/// reader announced "button" and stopped, and nothing noticed because no test
/// had ever asked what a control is called.
///
/// ## The check is the semantics tree, not the widget
///
/// Three shapes were tried and measured, and only the third works:
///
/// - `Semantics(button: true, label: '返回', child: IconButton(...))` — this is
///   the shape the codebase already used in four places. It produces **two**
///   button nodes, one named and one not, because the IconButton's own node is
///   not merged into the wrapper. A screen reader reaches both.
/// - `IconButton(tooltip: '返回')` — one node, but the string lands in the node's
///   `tooltip` and its `label` is still empty.
/// - `IconButton(icon: Icon(Icons.arrow_back, semanticLabel: '返回'))` — one
///   node, labelled.
///
/// So this walks `rootSemanticsNode` and asserts that no node carrying
/// `SemanticsFlag.isButton` has an empty label. Asking a *widget* for its
/// semantics misses exactly the case that matters: the widget is wrapped, the
/// node it makes is not.
///
/// ## What is asserted, and what is only recorded
///
/// Only the names. Several controls measure 38-46dp against the 48dp guideline,
/// and that is the app's density rather than a defect: Material's own `Chip` is
/// 32dp tall and its `SegmentedButton` is 40, and this app's segmented controls
/// and filter chips match those. A guard at 48 would fail the design's own
/// components, and a guard at 38 would encode today's state as a rule. The sizes
/// are measured and left alone; the names are unambiguous, so they are asserted.
///
/// `tools/find_unlabelled_icon_buttons.py` scans the whole app statically for
/// the same defect, for the screens this file cannot mount.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider
          .overrideWithValue(_FixedClock(DateTime(2026, 10, 8, 9))),
      currentUserIdProvider.overrideWithValue('default_user'),
      companionSelectionStoreProvider
          .overrideWithValue(InMemoryCompanionSelectionStore()),
      homeControllerProvider.overrideWith(
        (ref) => _PresetHomeController(ref, const HomeUIState()),
      ),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.lightTheme, home: page),
      ),
    );
    // Fixed frames: the companion's idle animation repeats forever, so
    // `pumpAndSettle` never returns on these screens.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Every button node the screen reader would reach, and its label.
  ///
  /// The rect is carried so a failure names *where* the unnamed button is
  /// instead of only that one exists.
  List<String> buttonLabels(WidgetTester tester) {
    // `pipelineOwner` is deprecated in favour of the tree rooted at
    // `rootPipelineOwner`, but that root's own `semanticsOwner` is null in a
    // widget test - the owner lives on the view's pipeline owner, which is the
    // deprecated accessor. Measured, not assumed: the replacement returns null
    // and this one returns the tree.
    // ignore: deprecated_member_use
    final owner = tester.binding.pipelineOwner.semanticsOwner;
    final root = owner!.rootSemanticsNode!;
    final labels = <String>[];
    void visit(SemanticsNode node) {
      if (node.hasFlag(SemanticsFlag.isButton)) {
        final label = node.label.trim();
        labels.add(label.isEmpty ? '@ ${node.rect}' : label);
      }
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(root);
    return labels;
  }

  Future<void> expectEveryButtonNamed(
    WidgetTester tester,
    Widget page,
    String screen,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, page);

    final labels = buttonLabels(tester);
    expect(labels, isNotEmpty,
        reason: '$screen has no buttons at all, so this proves nothing');
    expect(labels.where((l) => l.startsWith('@ ')), isEmpty,
        reason: '$screen has a button a screen reader cannot name. '
            'Labels found: ${labels.join(' | ')}');

    handle.dispose();
  }

  final screens = <String, Widget Function()>{
    'companion picker': () => const CompanionPickerPage(),
    'collection': () => const PetCollectionPage(),
    'dress': () => const PetDressPage(),
    'records': () => const ProgressOverviewPage(),
    'inbox': () => const DistractionInboxPage(),
    'weekly report': () => const WeeklyReportPage(),
    'monthly report': () => const MonthlyReportPage(),
    'yearly report': () => const YearlyReportPage(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key}: every button has a name', (tester) async {
      await expectEveryButtonNamed(tester, entry.value(), entry.key);
    });
  }

  testWidgets('the running screen names its buttons', (tester) async {
    final handle = tester.ensureSemantics();
    await container.read(focusSessionControllerProvider.notifier).startSession(
          userId: 'default_user',
          plannedSeconds: 25 * 60,
          mode: FocusMode.focus,
        );
    await pump(tester, const FocusActivePage());

    final labels = buttonLabels(tester);
    expect(labels, isNotEmpty);
    expect(labels.where((l) => l.startsWith('@ ')), isEmpty,
        reason: 'labels found: ${labels.join(' | ')}');

    await container
        .read(focusSessionControllerProvider.notifier)
        .cancelSession();
    handle.dispose();
  });

  testWidgets('the report pages name their period arrows', (tester) async {
    // The arrows that move a week, a month and a year are the controls a screen
    // reader user meets first on these screens, and they are four of the sites
    // this pass fixed. Named, and distinguishable from each other.
    final handle = tester.ensureSemantics();

    await pump(tester, const WeeklyReportPage());
    expect(buttonLabels(tester), contains('上一周'));
    expect(buttonLabels(tester), contains('下一周'));

    await pump(tester, const MonthlyReportPage());
    expect(buttonLabels(tester), contains('上一月'));
    expect(buttonLabels(tester), contains('下一月'));

    await pump(tester, const YearlyReportPage());
    expect(buttonLabels(tester), contains('上一年'));
    expect(buttonLabels(tester), contains('下一年'));

    handle.dispose();
  });

  testWidgets('negative proof: the walk finds an unnamed button',
      (tester) async {
    // A check that reports nothing is indistinguishable from one that cannot
    // report. This screen has a bare IconButton and the walk has to say so - and
    // it has to say so about the *node*, which is what the first shape of the
    // fix got wrong.
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(buttonLabels(tester).where((l) => l.startsWith('@ ')), isNotEmpty);
    handle.dispose();
  });

  testWidgets('negative proof: a wrapper alone is not a name', (tester) async {
    // The shape that looks like a fix and is not: the wrapper node is named, and
    // the IconButton's own node is still unnamed. This is why the guard reads
    // the tree rather than the widget.
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      Scaffold(
        appBar: AppBar(
          leading: Semantics(
            button: true,
            label: '返回',
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    final labels = buttonLabels(tester);
    expect(labels, contains('返回'));
    expect(labels.where((l) => l.startsWith('@ ')), isNotEmpty,
        reason: 'the wrapper names itself and leaves the button unnamed');
    handle.dispose();
  });
}

class _FixedClock implements FocusClock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}

class _PresetHomeController extends HomeController {
  _PresetHomeController(super.ref, HomeUIState preset) : _preset = preset;
  final HomeUIState _preset;

  @override
  Future<void> loadHomeData() async {
    state = _preset;
  }
}
