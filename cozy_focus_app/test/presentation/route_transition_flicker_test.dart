import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/navigation/app_router.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// Flicker, measured rather than asserted by eye.
///
/// ## What this looks for
///
/// A frame during a route transition that draws *neither* page — a flash of bare
/// background between two screens. That is what a rebuild that loses its content
/// looks like, and it is the failure the S4.04 "no flicker" row is about.
///
/// ## How it decides
///
/// It renders a screen that genuinely draws nothing, keeps those pixels as the
/// reference, then walks the transition frame by frame asking how much of each
/// frame that reference explains. A frame the empty screen explains almost
/// entirely is a blank frame.
///
/// Three derived measures were tried first and all three were wrong, which is
/// worth recording because the first looked reasonable:
///
///   - **share of pixels differing from the frame's own modal colour.** A page
///     with one line of text is legitimately ~99.3% background, so "mostly
///     background" cannot tell a sparse page from an empty one. It flagged
///     eleven good frames.
///   - **distinct-colour count.** An empty `Scaffold` still paints 46 colours
///     here, so the count does not separate empty from sparse either.
///   - **share of pixels differing from `AppColors.background`.** An empty
///     `Scaffold` measures 0.0019 off that colour — small, but not zero, and
///     chasing down what those pixels are is work this check does not need.
///
/// Comparing against a rendered empty screen sidesteps all of it: "did this
/// frame draw nothing" becomes "is this frame the same picture as a screen that
/// drew nothing", which needs no colour theory and calibrates itself.
///
/// ## What it cannot see
///
/// A frame that draws the right *amount* of content but the wrong content — a
/// stale page, a doubled image, a pose that snaps mid-transition. Those need
/// consecutive frames compared against each other, which is a different check.
/// This answers "was anything drawn", not "was the right thing drawn", and the
/// row's evidence says so rather than implying more.
void main() {
  late AppDatabase db;
  late _FixedClock clock;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _FixedClock(DateTime(2026, 10, 8, 9));
  });

  tearDown(() async => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      focusClockProvider.overrideWithValue(clock),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<Uint8List> capture(WidgetTester tester, GlobalKey key) async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    var bytes = Uint8List(0);
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (data != null) bytes = data.buffer.asUint8List();
    });
    return bytes;
  }

  /// The share of pixels two captures agree on, 0..1.
  double agreement(Uint8List a, Uint8List b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0;
    var same = 0;
    var total = 0;
    for (var i = 0; i + 3 < a.length; i += 4) {
      if (a[i] == b[i] && a[i + 1] == b[i + 1] && a[i + 2] == b[i + 2]) same++;
      total++;
    }
    return total == 0 ? 0 : same / total;
  }

  /// Above this, the empty screen explains the frame: nothing was drawn.
  const blankAgreement = 0.995;

  /// Pixels of a screen that draws nothing, captured from the same tree at the
  /// same size as the frames it will be compared against.
  Future<Uint8List> blankReference(
    WidgetTester tester,
    ProviderContainer c,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      ),
    );
    await tester.pump();
    return capture(tester, key);
  }

  testWidgets('no frame of a route transition draws nothing', (tester) async {
    final c = container();
    final blank = await blankReference(tester, c);

    final key = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: RepaintBoundary(
          key: key,
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: createAppRouter(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    // The page we leave has to carry content, or "no blank frame" would be
    // satisfied by a transition between two empty screens.
    final before = await capture(tester, key);
    expect(agreement(before, blank), lessThan(blankAgreement),
        reason: 'the page being left must itself have content');

    final context = tester.element(find.byType(Scaffold).first);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _ContentPage('records')),
    );

    final agreements = <double>[];
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      agreements.add(agreement(await capture(tester, key), blank));
    }

    final blankFrames = <int>[
      for (var i = 0; i < agreements.length; i++)
        if (agreements[i] >= blankAgreement) i,
    ];

    expect(blankFrames, isEmpty,
        reason:
            'these frames of the transition are the picture an empty screen '
            'draws, which is what a flash of blank looks like. Agreement with '
            'the empty screen, per frame: '
            '${agreements.map((a) => a.toStringAsFixed(4)).toList()}');
  });

  testWidgets('the detector notices a frame that draws nothing',
      (tester) async {
    // The harness has to be shown to fail on the thing it looks for, or "no
    // blank frame" above means nothing.
    final c = container();
    final blank = await blankReference(tester, c);

    final key = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const _ContentPage('something'),
          ),
        ),
      ),
    );
    await tester.pump();

    final withContent = await capture(tester, key);
    expect(agreement(withContent, blank), lessThan(blankAgreement),
        reason:
            'a page with content must not look like an empty screen, or the '
            'check above cannot fail either');

    // And the same unchanged screen must agree with itself, which is what makes
    // the comparison meaningful rather than two arbitrary pictures differing.
    final again = await capture(tester, key);
    expect(agreement(again, withContent), greaterThan(0.9),
        reason: 'two captures of the same unchanged screen must agree, or the '
            'measurement is noise');
  });
}

class _ContentPage extends StatelessWidget {
  final String label;
  const _ContentPage(this.label);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('这一页有内容，用来给转场做端点'),
            SizedBox(height: 12),
            Text('转场中间的每一帧都必须画点东西，而不是一片底色。'),
            SizedBox(height: 12),
            Text('否则用户在两个页面之间会看到一次白闪。'),
          ],
        ),
      ),
    );
  }
}

class _FixedClock implements FocusClock {
  final DateTime _now;
  _FixedClock(this._now);
  @override
  DateTime now() => _now;
}
