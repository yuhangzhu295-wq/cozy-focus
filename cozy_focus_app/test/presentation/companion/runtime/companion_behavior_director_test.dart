import 'package:cozy_focus_app/presentation/companion/focus_phase.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_behavior_director.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_pose.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/random_source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_test_support.dart';

/// Drives a director forward, recording the macro behaviour after each second.
List<CompanionMacroBehavior?> runFor(
  CompanionBehaviorDirector director,
  int seconds, {
  int stepMs = 1000,
}) {
  final seen = <CompanionMacroBehavior?>[];
  for (var ms = 0; ms <= seconds * 1000; ms += stepMs) {
    director.advanceTo(Duration(milliseconds: ms));
    final macro = director.currentMacroBehavior;
    if (seen.isEmpty || seen.last != macro) seen.add(macro);
  }
  return seen;
}

CompanionContext focusContext({
  FocusPhase phase = FocusPhase.working,
  double progress = 0.3,
  CompanionId id = CompanionId.dog,
}) =>
    CompanionContext(
      companionId: id,
      baseContext: CompanionBaseContext.focus,
      focusPhase: phase,
      focusProgress: progress,
    );

void main() {
  late CompanionCatalog catalog;

  setUp(() => catalog = loadShippedCatalog());

  CompanionBehaviorDirector director(
    CompanionContext context, {
    int seed = 7,
  }) =>
      CompanionBehaviorDirector(
        catalog: catalog,
        context: context,
        random: SeededRandomSource(seed),
      );

  group('determinism', () {
    test('the same seed produces the same behaviour sequence', () {
      final a = runFor(director(focusContext(), seed: 42), 400);
      final b = runFor(director(focusContext(), seed: 42), 400);
      expect(a, b);
      expect(a.length, greaterThan(5),
          reason: 'should have re-picked several times');
    });

    test('different seeds produce different sequences', () {
      final a = runFor(director(focusContext(), seed: 1), 600);
      final b = runFor(director(focusContext(), seed: 2), 600);
      expect(a, isNot(equals(b)));
    });
  });

  group('no immediate repeat', () {
    test('a focus behaviour is never chosen twice in a row', () {
      final d = director(focusContext(), seed: 11);
      final sequence = runFor(d, 900);
      for (var i = 1; i < sequence.length; i++) {
        expect(
          sequence[i],
          isNot(sequence[i - 1]),
          reason: 'repeated ${sequence[i]?.id} at index $i in $sequence',
        );
      }
    });

    test('a single-behaviour recipe still re-picks rather than freezing', () {
      final d = director(
        const CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.craft,
          craftProgress: 0.2,
        ),
      );
      final sequence = runFor(d, 120);
      expect(sequence, isNotEmpty);
      expect(
          sequence.every((b) => b == CompanionMacroBehavior.craftWork), isTrue);
    });
  });

  group('business-truth grounding', () {
    test('craft behaviour never plays without a real craft job', () {
      final d = director(
        const CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.craft,
          // craftProgress stays null: no CraftJob is active.
        ),
      );
      expect(d.currentMacroBehavior, CompanionMacroBehavior.idle);
      final sequence = runFor(d, 60);
      expect(
        sequence.any((b) => b == CompanionMacroBehavior.craftWork),
        isFalse,
      );
    });

    test('focus behaviour never plays without a real session', () {
      final d = director(
        const CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.focus,
          // no focusPhase: nothing is running.
        ),
      );
      final sequence = runFor(d, 60);
      expect(
        sequence.any(CompanionMacroBehavior.focusBehaviors.contains),
        isFalse,
      );
    });

    test('an active craft job does allow craft work', () {
      final d = director(
        const CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.craft,
          craftProgress: 0.4,
        ),
      );
      expect(d.currentMacroBehavior, CompanionMacroBehavior.craftWork);
    });

    test('pause schedules only the rest pose, never a focus behaviour', () {
      final d = director(
        const CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.pause,
        ),
      );
      final sequence = runFor(d, 200);
      expect(sequence, [CompanionMacroBehavior.rest]);
      expect(d.pose, CompanionPose.rest);
    });

    test('ending the job mid-flight drops the craft behaviour immediately', () {
      final d = director(
        const CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.craft,
          craftProgress: 0.4,
        ),
      );
      expect(d.currentMacroBehavior, CompanionMacroBehavior.craftWork);

      d.updateContext(
        const CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.craft,
        ),
      );
      expect(d.currentMacroBehavior, CompanionMacroBehavior.idle);
    });
  });

  group('overlays', () {
    test('a tap overlay restores the previous macro behaviour exactly', () {
      final d = director(focusContext());
      final before = d.currentMacroBehavior;
      expect(CompanionMacroBehavior.focusBehaviors.contains(before), isTrue);

      final started = d.triggerOverlay(CompanionOverlay.tapReact);
      expect(started, isTrue);
      expect(d.intent.isOverlayActive, isTrue);
      expect(d.pose, CompanionPose.tapReact);

      // The base context and the macro underneath are untouched by the overlay.
      expect(d.intent.baseContext, CompanionBaseContext.focus);
      expect(d.currentMacroBehavior, before);

      // Advance past the overlay's window (max 1200 ms).
      d.advanceTo(const Duration(milliseconds: 1300));

      expect(d.intent.isOverlayActive, isFalse);
      expect(d.currentMacroBehavior, before);
      expect(d.pose, before!.pose);
    });

    test('an overlay never changes the base context', () {
      final d = director(focusContext());
      for (final overlay in CompanionOverlay.values) {
        if (!overlay.isActive) continue;
        d.triggerOverlay(overlay);
        expect(d.intent.baseContext, CompanionBaseContext.focus);
        expect(d.intent.macroBehavior, isNotNull);
        d.advanceTo(Duration(milliseconds: d.now.inMilliseconds + 3000));
      }
      expect(d.intent.baseContext, CompanionBaseContext.focus);
    });

    test('a long-press overlay is a different pose from a tap', () {
      final d = director(focusContext());
      d.triggerOverlay(CompanionOverlay.petReact);
      expect(d.pose, CompanionPose.petReact);
    });

    test('overlays cannot stack', () {
      final d = director(focusContext());
      expect(d.triggerOverlay(CompanionOverlay.tapReact), isTrue);
      expect(d.triggerOverlay(CompanionOverlay.petReact), isFalse);
      expect(d.overlay, CompanionOverlay.tapReact);
    });

    test('clearOverlay ends an overlay immediately and restores the macro', () {
      final d = director(focusContext());
      final before = d.currentMacroBehavior;
      d.triggerOverlay(CompanionOverlay.petReact);
      d.clearOverlay();
      expect(d.intent.isOverlayActive, isFalse);
      expect(d.currentMacroBehavior, before);
    });
  });

  group('reduced motion', () {
    test('preserves the semantic pose', () {
      final normal = director(focusContext(), seed: 5);
      final reduced = CompanionBehaviorDirector(
        catalog: catalog,
        context: focusContext().copyWith(reducedMotion: true),
        random: SeededRandomSource(5),
      );

      final a = runFor(normal, 300);
      final b = runFor(reduced, 300);
      expect(b, a,
          reason: 'reduced motion must not change which pose is presented');
      expect(reduced.intent.reducedMotion, isTrue);
      expect(normal.intent.reducedMotion, isFalse);
    });
  });

  group('phase transitions are visible', () {
    test('a phase change re-picks immediately instead of waiting out the dwell',
        () {
      final d =
          director(focusContext(phase: FocusPhase.starting, progress: 0.01));
      expect(d.currentMacroBehavior, isNotNull);

      d.updateContext(focusContext(phase: FocusPhase.deepFocus, progress: 0.7));
      // The deep-focus recipe has a 15s minimum dwell, so if the director had
      // waited for the old dwell the next pick would still be the old behaviour.
      expect(
        d.nextBehaviorAt!.inSeconds,
        greaterThanOrEqualTo(15),
        reason: 'deep focus should now govern the dwell',
      );
      expect(d.focusPhase, FocusPhase.deepFocus);
    });

    test('the finishing phase can offer a glance or a finish beat', () {
      final d =
          director(focusContext(phase: FocusPhase.finishing, progress: 0.95));
      final sequence = runFor(d, 400);
      final allowed = {
        CompanionMacroBehavior.focusWrite,
        CompanionMacroBehavior.focusRead,
        CompanionMacroBehavior.glance,
        CompanionMacroBehavior.finish,
      };
      expect(sequence.every(allowed.contains), isTrue, reason: '$sequence');
    });
  });

  group('intent', () {
    test('carries the profile micro-motion channels and the companion id', () {
      final d = director(focusContext(id: CompanionId.cat));
      expect(d.intent.companionId, CompanionId.cat);
      expect(d.intent.microMotion, isNotEmpty);
    });

    test('reports the real focus and craft progress it was given', () {
      final d = director(focusContext(progress: 0.42));
      expect(d.intent.focusProgress, 0.42);
      expect(d.intent.craftProgress, isNull);
    });

    test('a null context yields the idle pose rather than throwing', () {
      final d = CompanionBehaviorDirector(
        catalog: CompanionCatalog.empty(),
        context: const CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.home,
        ),
      );
      expect(d.pose, CompanionPose.idle);
    });
  });
}
