// Frame time, measured on a device.
//
// Why this file exists rather than a `flutter test`: `flutter test` runs on a fake
// clock, so a FrameTiming taken there is a number with no meaning. Frame time is a
// property of a real engine rendering real frames, so the measurement has to be
// taken where the frames are.
//
// Run it with:
//
//   flutter drive --profile -d emulator-5554 \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/frame_time_test.dart
//
// READ THE RASTER NUMBERS WITH CARE. On the AVD this project uses, the GPU is
// disabled (`hw.gpu.enabled=no`) and Flutter falls back to `swiftshader_indirect`,
// so raster time is a software-rasteriser number and is not what a phone does.
// The build (UI thread) numbers are the ones that transfer: they are CPU work in
// Dart, and the same code does the same work on a phone.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:cozy_focus_app/main.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_install_plan.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_root.dart';

/// A percentile, nearest-rank, on a sorted list. No interpolation: with a few
/// hundred samples the interpolated value would be a precision the sample count
/// does not support.
Duration _pct(List<Duration> sorted, double p) {
  if (sorted.isEmpty) return Duration.zero;
  final i = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1);
  return sorted[i];
}

Map<String, Object> _summarise(String label, List<Duration> d) {
  final sorted = [...d]..sort();
  return {
    '${label}_n': sorted.length,
    '${label}_p50_us': _pct(sorted, 0.50).inMicroseconds,
    '${label}_p90_us': _pct(sorted, 0.90).inMicroseconds,
    '${label}_p99_us': _pct(sorted, 0.99).inMicroseconds,
    '${label}_max_us': sorted.isEmpty ? 0 : sorted.last.inMicroseconds,
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('frame time: companion idle animation and a scroll',
      (tester) async {
    final timings = <FrameTiming>[];
    SchedulerBinding.instance.addTimingsCallback(timings.addAll);
    addTearDown(
        () => SchedulerBinding.instance.removeTimingsCallback(timings.addAll));

    // The app's own bootstrap, because the companion pack root is resolved from
    // the documents directory and a test that skipped it would be measuring a
    // different app than the one that ships.
    final documents = await getApplicationDocumentsDirectory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          companionPackRootProvider.overrideWithValue(
            '${documents.path}/${CompanionPackInstallRules.root}',
          ),
        ],
        child: const CozyFocusApp(),
      ),
    );

    // Let the first frame and any database open settle. Deliberately not
    // pumpAndSettle: the companion animation loops forever, so it never settles.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Workload 1: the companion idle animation on the growth page, at rest. This
    // is the animation the app runs most of the time it is open.
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final idleCount = timings.length;

    // Workload 2: a scroll, which builds and lays out new slivers each frame.
    // Eight passes rather than three: the late-frame count is a handful out of a
    // few hundred, and a count that small needs a bigger denominator before it
    // means anything. This is the difference between "3 frames were late" and
    // "1% of frames were late", and only the second one is a measurement.
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      for (var pass = 0; pass < 8; pass++) {
        await tester.drag(scrollable.first, const Offset(0, -260));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.drag(scrollable.first, const Offset(0, 260));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
    }

    final build = timings.map((t) => t.buildDuration).toList();
    final raster = timings.map((t) => t.rasterDuration).toList();
    final total = timings.map((t) => t.totalSpan).toList();

    // A frame is late when it misses a 60 Hz budget on the UI thread. Raster is
    // excluded on purpose: under swiftshader a raster miss says nothing about a
    // phone, and folding it in would make the number uninterpretable.
    const budget = Duration(microseconds: 16667);
    final lateIndices = <int>[
      for (var i = 0; i < build.length; i++)
        if (build[i] > budget) i,
    ];

    // Startup is not steady state: opening the database and building the first
    // route cost far more than a frame of scrolling does, and counting them
    // together would make both numbers wrong. The first 30 frames are dropped
    // from the steady-state figures and reported on their own.
    const warmup = 30;
    final steady = build.length > warmup ? build.sublist(warmup) : <Duration>[];

    final view = binding.platformDispatcher.implicitView;

    binding.reportData = <String, dynamic>{
      'device': view == null
          ? 'unknown'
          : '${view.physicalSize.width.toInt()}x${view.physicalSize.height.toInt()}',
      'dpr': view?.devicePixelRatio ?? 0,
      'frames_observed': timings.length,
      'frames_before_scroll': idleCount,
      ..._summarise('build', build),
      ..._summarise('build_steady', steady),
      ..._summarise('raster', raster),
      ..._summarise('total', total),
      'late_build_frames': lateIndices.length,
      'late_build_fraction':
          timings.isEmpty ? 0 : lateIndices.length / timings.length,
      'late_build_indices': lateIndices.take(20).toList(),
      'late_build_after_warmup': lateIndices.where((i) => i >= warmup).length,
    };

    // Guard against the harness silently measuring nothing: a run with no frames
    // would otherwise "pass" and read as a clean result.
    expect(timings.length, greaterThan(60),
        reason:
            'the engine reported almost no frames; the measurement did not happen');
    expect(steady, isNotEmpty,
        reason: 'not enough frames to separate startup from steady state');
  });
}
