import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/domain/growth/growth_stage.dart';
import 'package:cozy_focus_app/presentation/companion/pet_encouragement.dart';

/// The tone contract, checked as a contract rather than as a list.
///
/// `pet_encouragement_test.dart` already asserts the copy table is clean. What
/// it could not see is whether the guard *covers the whole contract*: the brief
/// names seven things Mochi may never be, and two of them — dependency
/// induction and emotional blackmail — had no tokens defending them at all. A
/// line like "别走，没有你 Mochi 会难过" would have passed a suite that was
/// green.
///
/// So this file tests the guard itself, on three axes:
///
///  * **coverage** — every named axis has tokens, driven by [PetToneAxis] so an
///    eighth axis cannot be added uncovered;
///  * **precision** — every token matches something, belongs to exactly one
///    axis, and no token fires on kindness;
///  * **honesty** — the guard is a floor and not a proof, and the one line in
///    this app that breaks the contract by *formula* rather than by vocabulary
///    is pinned here so the limitation stays visible instead of being assumed
///    away.
void main() {
  group('the tone contract names seven prohibitions', () {
    test('every axis the brief names exists, and every axis is defended', () {
      expect(
        PetToneAxis.values.map((axis) => axis.label).toSet(),
        {
          'HUMILIATION',
          'BLAME',
          'URGING',
          'GUILT',
          'DEPENDENCY',
          'PET_PUNISHES_USER',
          'EMOTIONAL_BLACKMAIL',
        },
        reason: 'the brief names exactly these seven, and the enum is the '
            'checklist the coverage assertion below runs against',
      );

      expect(
        PetEncouragementCopyGuard.uncoveredAxes,
        isEmpty,
        reason: 'these axes have no tokens, so nothing stops a line from '
            'breaking them: '
            '${PetEncouragementCopyGuard.uncoveredAxes.map((a) => a.label).join(', ')}',
      );
    });

    test('the axis map and the flat token list agree', () {
      // `forbiddenTokens` is what the matching code uses; `axisTokens` is what
      // the coverage assertion reads. If they drift, an axis can look defended
      // while the matcher never sees its tokens.
      final fromAxes = <String>[
        for (final axis in PetToneAxis.values)
          ...PetEncouragementCopyGuard.axisTokens[axis] ?? const <String>[],
      ];
      expect(PetEncouragementCopyGuard.forbiddenTokens, fromAxes);
      expect(PetEncouragementCopyGuard.forbiddenTokens, isNotEmpty);
    });
  });

  group('every token earns its place', () {
    test('each token matches itself, so none is a typo that never fires', () {
      final dead = PetEncouragementCopyGuard.forbiddenTokens
          .where((token) =>
              !PetEncouragementCopyGuard.violationsIn(token).contains(token))
          .toList();
      expect(dead, isEmpty, reason: 'tokens that never match anything: $dead');
    });

    test('no token is claimed by two axes', () {
      final seen = <String, PetToneAxis>{};
      final conflicts = <String>[];
      for (final axis in PetToneAxis.values) {
        for (final token
            in PetEncouragementCopyGuard.axisTokens[axis] ?? const <String>[]) {
          final owner = seen[token];
          if (owner != null) {
            conflicts.add('$token: ${owner.label} and ${axis.label}');
          }
          seen[token] = axis;
        }
      }
      expect(conflicts, isEmpty,
          reason: 'a token in two axes reports the wrong one: $conflicts');
    });

    test('no token fires on kindness', () {
      // The guard's own note: "a guard that fires on kindness would be turned
      // off within a week". These are lines the product would *want* Mochi to
      // say, so a token that blocks them is a precision bug, not a safety net.
      const kind = [
        '该休息了',
        '你应该去睡一会儿',
        '慢慢来，不着急',
        '幸亏今天开始了',
        '多亏了你陪着，这段才走得下来',
        '歇一会儿挺好。想回来的时候我在。',
      ];
      for (final line in kind) {
        expect(PetEncouragementCopyGuard.isClean(line), isTrue,
            reason: 'the guard blocks a kind line: "$line" '
                '(${PetEncouragementCopyGuard.violationsIn(line).join(', ')})');
      }
    });

    test('no token from the original roster was dropped by accident', () {
      // Grouping the tokens by axis is a refactor of a flat list, and a refactor
      // of a flat list is exactly how a token disappears without anyone
      // noticing. This roster is frozen at the original twenty-two minus the one
      // deliberate removal (`亏`, see `_guiltTokens` for why it cannot be told
      // apart from `幸亏`). A drop has to be an edit to this list, which means it
      // has to be a decision.
      const roster = [
        '浪费',
        '白费',
        '可惜',
        '活该',
        '又没',
        '怎么还没',
        '你怎',
        '为什么没',
        '别再',
        '加把劲',
        '抓紧',
        '失败',
        '落后',
        '差劲',
        '比不上',
        '别人都',
        '对不起',
        '惩罚',
        '失望',
        '不够努力',
        '懒',
      ];
      final missing = roster
          .where((token) =>
              !PetEncouragementCopyGuard.forbiddenTokens.contains(token))
          .toList();
      expect(missing, isEmpty,
          reason: 'these tokens used to defend the contract and now defend '
              'nothing: $missing');
    });

    test('each axis actually fires on a line built for it', () {
      const samples = {
        PetToneAxis.humiliation: '别人都比你强',
        PetToneAxis.blame: '你怎么还没开始',
        PetToneAxis.urging: '加把劲，抓紧点',
        PetToneAxis.guilt: '这样太浪费了，真让人失望',
        PetToneAxis.dependency: '别走，别丢下我',
        PetToneAxis.petPunishment: '这样 Mochi 要惩罚你',
        PetToneAxis.emotionalBlackmail: '为了我，你就不能再撑一下吗',
      };
      for (final entry in samples.entries) {
        expect(
            PetEncouragementCopyGuard.axesIn(entry.value), contains(entry.key),
            reason: '${entry.key.label} did not fire on "${entry.value}"');
      }
    });
  });

  group('the copy table', () {
    test('is nine categories of four stage variants — the thirty-six lines',
        () {
      const table = PetEncouragementCopy.table;
      expect(table.length, PetMessageKind.values.length,
          reason: 'every category must have copy, and no category may be '
              'missing from the table');
      expect(table.keys.toSet(), PetMessageKind.values.toSet());

      final wrong = <String>[];
      for (final entry in table.entries) {
        if (entry.value.length != 4) {
          wrong.add('${entry.key.name} has ${entry.value.length}');
        }
      }
      expect(wrong, isEmpty,
          reason: 'each category needs exactly one variant per growth stage, '
              'because `forKind` indexes the list by `stage.index`: $wrong');

      final total = table.values.fold<int>(0, (n, v) => n + v.length);
      expect(total, 36, reason: 'the copy review counts thirty-six lines');
    });

    test('is clean on every axis', () {
      final findings = <String>[];
      for (final entry in PetEncouragementCopy.table.entries) {
        for (final line in entry.value) {
          final axes = PetEncouragementCopyGuard.axesIn(line);
          if (axes.isNotEmpty) {
            findings.add(
                '${entry.key.name} -> "$line" (${axes.map((a) => a.label).join(', ')})');
          }
        }
      }
      expect(findings, isEmpty, reason: findings.join('\n'));
      expect(PetEncouragementCopyGuard.auditCopyTable(), isEmpty);
    });

    test('every category grows from its sprout line to its blooming line', () {
      // The library doc claims growth is audible in the voice. The strong form
      // of that claim — each stage longer than the one before — is *false*: the
      // intermediate steps are not monotonic in seven of the nine categories.
      // The form asserted here is the one that actually holds, so the claim in
      // the doc is checked rather than believed.
      final flat = <String>[];
      for (final entry in PetEncouragementCopy.table.entries) {
        final sprout = entry.value[GrowthStage.sprout.index];
        final blooming = entry.value[GrowthStage.blooming.index];
        if (blooming.length <= sprout.length) {
          flat.add('${entry.key.name}: sprout ${sprout.length} -> '
              'blooming ${blooming.length}');
        }
      }
      expect(flat, isEmpty,
          reason: 'a category does not grow in the voice: $flat');
    });

    test('selects a variant per stage, so growth is audible', () {
      // The same "additive growth" rule the motion layer follows: a later stage
      // gains vocabulary, and a younger one is not silenced.
      final perStage = <String>[];
      for (final kind in PetMessageKind.values) {
        final lines = <String>{
          for (final stage in GrowthStage.values)
            PetEncouragementCopy.forKind(kind, stage),
        };
        if (lines.length != GrowthStage.values.length) {
          perStage.add('${kind.name} repeats a line across stages');
        }
      }
      expect(perStage, isEmpty, reason: perStage.join('; '));
    });
  });

  group('the guard is a floor, not a proof', () {
    test('the early-finish dialog breaks the contract and the guard misses it',
        () {
      // Read from source rather than copied, so this test fails if the line is
      // reworded — which is the moment the finding below needs re-judging.
      const path = 'lib/presentation/pages/focus_active_page.dart';
      final source = File(path).readAsStringSync();
      const pressure = '再坚持一会儿，你可以做得更好！';

      expect(source.contains(pressure), isTrue,
          reason: 'the documented counter-example is no longer in $path, so '
              'this finding must be re-checked rather than left standing');

      // The whole point: the line presses the user to keep going at the exact
      // moment they chose to stop, and not one token in the guard sees it. The
      // pressure is in the formula — "你可以做得更好" implies the effort so far
      // was not good enough — not in any word.
      expect(PetEncouragementCopyGuard.isClean(pressure), isTrue,
          reason:
              'if this ever starts failing, the guard learned something and '
              'the finding can be closed');
      expect(PetEncouragementCopyGuard.axesIn(pressure), isEmpty);

      // Recorded as a *limitation* rather than fixed, because the line is the
      // approved design's own copy: V4.1 page `03C_提前结束确认.png` prints it
      // verbatim. The brief makes visual truth the V4.1 package (§9) and also
      // forbids urging and guilt (§33); where those two point in opposite
      // directions the call belongs to the owner, not to a token list.
      // See `COMPANION_STAGE_E_COPY_AUDIT.md` §4.
    });
  });
}
