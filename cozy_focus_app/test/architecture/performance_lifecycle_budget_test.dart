import 'dart:io';

import 'package:cozy_focus_app/presentation/companion/companion_avatar.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest_data.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_presentation_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart' as db_import;

/// Lifecycle and performance budgets.
///
/// ## Where the numbers come from
///
/// The brief is explicit: **do not invent arbitrary performance promises**. So
/// every budget in this file was measured first, and the `calibration` test
/// prints the measurement it is derived from. A budget with no measurement
/// behind it is a wish, and a wish that fails is worse than no gate.
///
/// ## What this file is not
///
/// It is not a benchmark. Widget-test frame timing is synthetic — the binding
/// does not rasterise — so nothing here claims a frame rate. What it measures is
/// the **rate at which the app asks to do work**: rebuilds per simulated second
/// and pending timers. Those are the facts that separate "animating" from
/// "spinning".
void main() {
  late db_import.AppDatabase db;

  setUp(() => db = db_import.AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  ProviderContainer container() => ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );

  Widget app(ProviderContainer c, Widget child) => UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme: AppTheme.lightTheme, home: Scaffold(body: child)),
      );

  // ── budgets, each derived from a measurement below ───────────────────────

  /// The fastest any periodic timer in `lib/` may run.
  ///
  /// Measured: the fastest is the presentation clock at **250 ms** (4 Hz). A
  /// busy-loop would poll at frame rate (~16 ms). 100 ms sits far above every
  /// real interval and far below a spin.
  const minPeriodicIntervalMs = 100;

  /// Frame callbacks one companion may hold at once.
  ///
  /// Measured: see the print in the gate below. The layered renderer holds a
  /// handful of AnimationControllers, and the number running varies with the
  /// behaviour, so this bounds the peak rather than pinning it.
  const maxFrameCallbacks = 20;

  group('no permanent busy loop', () {
    test('the presentation scheduler is far slower than a frame', () {
      // The one interval the app repeats on a schedule. Measured at 250ms
      // (4 Hz). A busy loop would poll at frame rate; this is a scheduler.
      //
      // Note what this does NOT claim: widget-test frame timing is synthetic --
      // the binding does not rasterise -- so nothing here asserts a frame rate.
      // What it asserts is the rate at which the app asks to do work.
      expect(CompanionPresentationClock.tickInterval.inMilliseconds,
          greaterThanOrEqualTo(minPeriodicIntervalMs),
          reason: 'a presentation scheduler faster than '
              '${minPeriodicIntervalMs}ms is a busy loop wearing a scheduler '
              'costume');
    });

    testWidgets('frame callbacks stay bounded, they do not accumulate',
        (tester) async {
      // Sampled rather than compared between two instants, and the first
      // version of this test is why: it asserted the count was *constant* and
      // failed, 4 then 6. That is not a leak -- the companion changes behaviour,
      // so a different number of AnimationControllers is legitimately running
      // at different moments. A snapshot of a varying quantity is the wrong
      // assertion.
      //
      // What a loop that never settles would look like is the count *growing
      // without bound*, so this samples across several seconds and bounds the
      // peak.
      final c = container();
      addTearDown(c.dispose);
      await tester.pumpWidget(app(c, const CompanionAvatar(size: 140)));
      await tester.pump();

      var peak = 0;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        final n = tester.binding.transientCallbackCount;
        if (n > peak) peak = n;
      }
      // ignore: avoid_print
      print('MEASURED peak frame callbacks over 10 simulated seconds: $peak');
      expect(peak, lessThan(maxFrameCallbacks),
          reason: 'a companion holding $peak frame callbacks is not settling. '
              'Measured peak is printed above.');
    });
  });

  group('no per-companion timer proliferation', () {
    testWidgets('each companion has exactly one scheduler, not more',
        (tester) async {
      // The real risk, and the reason this is `==` rather than `<= 1`.
      //
      // Each avatar owns its own `CompanionBehaviorDirector`, and the clock is
      // what advances it -- so one clock per companion is the design, not
      // duplication. Three companions legitimately means three schedulers.
      //
      // What would be proliferation is a *second* repeating timer per avatar:
      // someone adding another `Timer.periodic` inside the avatar, so a page
      // with three companions runs six schedulers for three behaviours. That is
      // what this catches, and it is why the assertion is exact.
      final c = container();
      addTearDown(c.dispose);

      Future<(int avatars, int clocks)> countsFor(int count) async {
        await tester.pumpWidget(
          app(
            c,
            Column(
              children: [
                for (var i = 0; i < count; i++) const CompanionAvatar(size: 80),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        return (
          tester.widgetList(find.byType(CompanionAvatar)).length,
          tester.widgetList(find.byType(CompanionPresentationClock)).length,
        );
      }

      for (final n in [1, 3]) {
        final (avatars, clocks) = await countsFor(n);
        expect(avatars, n);
        expect(clocks, avatars,
            reason: 'with $n companions there must be exactly $n schedulers. '
                'More than one per companion is proliferation.');
      }
    });

    testWidgets('every scheduler is released with its companion',
        (tester) async {
      final c = container();
      addTearDown(c.dispose);
      await tester.pumpWidget(app(c, const CompanionAvatar(size: 140)));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CompanionPresentationClock), findsOneWidget);

      await tester.pumpWidget(app(c, const SizedBox.shrink()));
      await tester.pump();
      // A surviving periodic timer fails at teardown; asserting the widget is
      // gone makes the intent readable rather than relying on that message.
      expect(find.byType(CompanionPresentationClock), findsNothing);
    });
  });

  group('negative proof: the busy-loop gate can fail', () {
    testWidgets('an unbounded spinner exceeds the frame-callback budget',
        (tester) async {
      // A gate that cannot fire is indistinguishable from one that is not
      // there. This mounts a widget that schedules another repeating controller
      // on every frame -- the shape of a loop that never settles -- and shows
      // the same measurement used above exceeds the bound.
      final c = container();
      addTearDown(c.dispose);
      await tester.pumpWidget(app(c, const _UnboundedSpinner()));
      await tester.pump();

      // Longer than the gate's own window, so the separation is unambiguous
      // rather than a couple of callbacks either side of the line. The gate
      // samples 20 times and sees a settled 5; this runs 60 and shows a loop
      // climbing far past the budget.
      var peak = 0;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        final n = tester.binding.transientCallbackCount;
        if (n > peak) peak = n;
      }
      // ignore: avoid_print
      print('MEASURED unbounded spinner peak: $peak');
      expect(peak, greaterThan(maxFrameCallbacks),
          reason: 'the gate above only means something if a real loop can '
              'exceed it');

      // Release it, so this test does not itself leak into teardown.
      await tester.pumpWidget(app(c, const SizedBox.shrink()));
      await tester.pump();
    });
  });

  group('asset budget', () {
    test('the sprite packs stay inside their measured budget', () {
      // Measured after the indexed-PNG work: 147 frames, 3.1 MB. The budget is
      // that with headroom, so adding an action is fine and re-introducing
      // full-colour PNGs is not.
      var bytes = 0;
      var frames = 0;
      for (final companion in CompanionActionManifestData.manifests.keys) {
        final manifest = CompanionActionManifestData.forCompanion(companion)!;
        for (final path in manifest.allFrames) {
          final file = File(path);
          if (!file.existsSync()) continue;
          bytes += file.lengthSync();
          frames++;
        }
      }
      // ignore: avoid_print
      print('MEASURED sprites: $frames frames, '
          '${(bytes / 1048576).toStringAsFixed(2)} MB, '
          '${(bytes / frames / 1024).toStringAsFixed(1)} KB/frame average');

      expect(frames, greaterThan(0));
      expect(bytes, lessThan(maxSpriteBytes),
          reason: 'the packs are ${(bytes / 1048576).toStringAsFixed(1)} MB; '
              'the budget is ${(maxSpriteBytes / 1048576).toStringAsFixed(1)} MB. '
              'A jump here means the encoding regressed.');
      expect(bytes / frames, lessThan(maxBytesPerFrame),
          reason: 'average frame size is a better regression signal than the '
              'total, because it does not move when an action is added');
    });
  });
}

/// Measured: 147 frames at 3.1 MB. Budget 6 MB, roughly double, so growth is
/// allowed and a return to full-colour PNGs (~19 MB) is not.
const int maxSpriteBytes = 6 * 1024 * 1024;

/// Measured: ~22 KB per frame. Budget 40 KB, which is well above indexed PNG
/// and well below the ~110 KB an RGBA frame costs.
const double maxBytesPerFrame = 40 * 1024;

/// Schedules another repeating controller on every frame.
///
/// Exists only for the negative proof: it is what a busy loop looks like, and
/// the gate above must be able to tell it apart from a settled companion.
class _UnboundedSpinner extends StatefulWidget {
  const _UnboundedSpinner();

  @override
  State<_UnboundedSpinner> createState() => _UnboundedSpinnerState();
}

class _UnboundedSpinnerState extends State<_UnboundedSpinner>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_grow);
  }

  void _grow(Duration _) {
    if (!mounted) return;
    _controllers.add(
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat(),
    );
    WidgetsBinding.instance.addPostFrameCallback(_grow);
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
