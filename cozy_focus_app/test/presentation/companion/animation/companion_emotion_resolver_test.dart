import 'package:cozy_focus_app/presentation/companion/animation/companion_emotion.dart';
import 'package:cozy_focus_app/presentation/companion/animation/companion_emotion_resolver.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/presentation_vitals.dart';
import 'package:flutter_test/flutter_test.dart';

/// P6 — the emotion resolver's derivation contract.
///
/// The emotion is derived, never stored. The same vitals always produce the
/// same emotion. The resolver is a pure function with no clock, no random and
/// no repository — so a test that holds its inputs constant can predict the
/// output exactly.
void main() {
  CompanionEmotion resolve(
    PresentationVitals vitals, {
    bool recentCompletion = false,
    bool recentlyInteracted = false,
  }) =>
      CompanionEmotionResolver.resolve(
        vitals: vitals,
        recentCompletion: recentCompletion,
        recentlyInteracted: recentlyInteracted,
      );

  group('resolution order', () {
    test('calm is the default for neutral vitals', () {
      expect(resolve(PresentationVitals.neutral), CompanionEmotion.calm);
    });

    test('tired wins over calm', () {
      expect(
        resolve(const PresentationVitals(energy: 20)),
        CompanionEmotion.tired,
      );
    });

    test('low mood is subdued, not distressed', () {
      expect(
        resolve(const PresentationVitals(mood: 20)),
        CompanionEmotion.lowMood,
      );
    });

    test('happy overrides tired and low mood', () {
      // The spec's own hard rule: completion must not be muted by low vitals.
      expect(
        resolve(const PresentationVitals(energy: 5, mood: 5),
            recentCompletion: true),
        CompanionEmotion.happy,
      );
    });

    test('curious from recent interaction', () {
      expect(
        resolve(PresentationVitals.neutral, recentlyInteracted: true),
        CompanionEmotion.curious,
      );
    });

    test('curious does not override tired', () {
      // A tired companion rests even if the player just interacted.
      expect(
        resolve(const PresentationVitals(energy: 10), recentlyInteracted: true),
        CompanionEmotion.tired,
      );
    });

    test('happy overrides curious', () {
      expect(
        resolve(PresentationVitals.neutral,
            recentCompletion: true, recentlyInteracted: true),
        CompanionEmotion.happy,
      );
    });
  });

  group('thresholds are the vitals\' own', () {
    test('tired threshold is 40', () {
      expect(resolve(const PresentationVitals(energy: 39)),
          CompanionEmotion.tired);
      expect(
          resolve(const PresentationVitals(energy: 40)), CompanionEmotion.calm);
    });

    test('low mood threshold is 40', () {
      expect(resolve(const PresentationVitals(mood: 39)),
          CompanionEmotion.lowMood);
      expect(
          resolve(const PresentationVitals(mood: 40)), CompanionEmotion.calm);
    });
  });

  group('the emotion is derived, never stored', () {
    test('identical inputs produce identical output', () {
      final a = resolve(PresentationVitals.neutral);
      final b = resolve(PresentationVitals.neutral);
      expect(a, same(b));
    });

    test('the resolver is a pure function: no clock, no random, no repository',
        () {
      final source = CompanionEmotionResolver.resolve.toString();
      for (final banned in [
        'DateTime.now()',
        'Random()',
        'Repository',
        'app_database',
        'Timer(',
      ]) {
        expect(source.contains(banned), isFalse, reason: banned);
      }
    });
  });
}
