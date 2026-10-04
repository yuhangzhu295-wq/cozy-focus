import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/room/companion_vitals.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_entity.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_use_panel.dart';

/// P28.5 — every player-facing promise has to be true.
///
/// The furniture panel describes an action in words: 恢复精神, 消耗一些精力,
/// 心情变好, 更专注. A phrase is only allowed there when the effect behind it has a
/// real, observable runtime consequence — something the player can see happen.
///
/// The room shows exactly three meters (`CompanionVitalsBar`): 心情, 精力 and
/// 专注. Those are the whole of what a furniture action can currently change, so
/// those are the only three things that may be promised.
///
/// This file is the proof, in both directions: no phrase without a consequence,
/// and no consequence silently missing from the copy.
void main() {
  /// The phrases the panel may show, each with the meter that proves it.
  const provenPhrases = {
    '恢复精神': 'energy rises',
    '消耗一些精力': 'energy falls',
    '心情变好': 'mood rises',
    '更专注': 'focusLevel rises',
  };

  group('no phrase is shown without a consequence', () {
    test('every phrase the catalog can produce is on the proven list', () {
      final seen = <String>{};
      for (final item in FurnitureCatalog.entities.values) {
        for (final action in item.actions) {
          final text = FurnitureUsePanel.describeEffect(action.effect);
          seen.addAll(text.split(' · ').where((p) => p.isNotEmpty));
        }
      }
      expect(seen, isNotEmpty,
          reason: 'the catalog must produce at least one phrase, or this test '
              'is vacuous');
      for (final phrase in seen) {
        expect(provenPhrases.keys, contains(phrase),
            reason: '"$phrase" is shown to the player but no meter proves it. '
                'Either it has a real consequence or it must not be promised.');
      }
    });

    test('the knowledge effect promises nothing', () {
      // `bookshelf/read` carries `knowledge: ['reading']`. Nothing reads that
      // field: `copyWithEffect` does not carry it, no page shows a knowledge
      // value, and no session or craft record is written from it. The phrase was
      // removed rather than a knowledge mechanic invented to justify it.
      final read = FurnitureCatalog.forId('bookshelf')!.actionById('read')!;
      expect(read.effect.knowledge, isNotEmpty,
          reason:
              'the data still carries it, so this test is about the promise '
              'rather than about the field being absent');
      expect(FurnitureUsePanel.describeEffect(read.effect),
          isNot(contains('认识新事物')));
    });
  });

  group('every proven phrase has a real, observable consequence', () {
    /// The vitals after [effect] is applied, which is what the room renders.
    CompanionVitals applied(FurnitureEffect effect) =>
        CompanionVitals.initial.copyWithEffect(effect);

    test('恢复精神 really raises the energy the room shows', () {
      const effect = FurnitureEffect(energy: 4);
      expect(FurnitureUsePanel.describeEffect(effect), contains('恢复精神'));
      expect(
          applied(effect).energy, greaterThan(CompanionVitals.initial.energy));
    });

    test('消耗一些精力 really lowers it', () {
      const effect = FurnitureEffect(energy: -5);
      expect(FurnitureUsePanel.describeEffect(effect), contains('消耗一些精力'));
      expect(applied(effect).energy, lessThan(CompanionVitals.initial.energy));
    });

    test('心情变好 really raises the mood the room shows', () {
      const effect = FurnitureEffect(mood: 3);
      expect(FurnitureUsePanel.describeEffect(effect), contains('心情变好'));
      expect(applied(effect).mood, greaterThan(CompanionVitals.initial.mood));
    });

    test('更专注 really raises the focus meter the room shows', () {
      const effect = FurnitureEffect(focus: 8);
      expect(FurnitureUsePanel.describeEffect(effect), contains('更专注'));
      expect(applied(effect).focusLevel,
          greaterThan(CompanionVitals.initial.focusLevel));
    });

    test('a neutral effect promises nothing at all', () {
      expect(FurnitureUsePanel.describeEffect(FurnitureEffect.none), isEmpty);
    });

    test('a knowledge-only effect is silent', () {
      // The exact shape `bookshelf/read` declares, minus the energy it also has:
      // knowledge alone must produce no promise.
      const knowledgeOnly = FurnitureEffect(knowledge: ['reading']);
      expect(FurnitureUsePanel.describeEffect(knowledgeOnly), isEmpty,
          reason: 'nothing observable happens, so nothing is said');
    });
  });
}
