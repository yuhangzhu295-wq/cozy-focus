import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_install_plan.dart';

/// P32 — the last decision before the filesystem is touched.
void main() {
  CompanionPackInstallDecision plan({
    String id = 'mimi',
    String name = 'Mimi',
    String species = 'dog',
    CompanionPackSource source = CompanionPackSource.localImport,
    Set<String> builtIn = const {'dog', 'cat', 'rabbit'},
    Set<String> installed = const {},
  }) =>
      CompanionPackInstallRules.plan(
        manifest: {'companionId': id},
        displayName: name,
        speciesId: species,
        source: source,
        builtInIds: builtIn,
        installedIds: installed,
      );

  test('an ordinary import is planned into its own directory', () {
    final decision = plan();
    expect(decision.ok, isTrue, reason: '${decision.validation}');
    expect(decision.plan!.packId, 'mimi');
    expect(decision.plan!.relativeDirectory, 'companion_packs/mimi');
    expect(decision.plan!.source, CompanionPackSource.localImport);
  });

  group('the id reaches the filesystem, so it is refused rather than escaped',
      () {
    test('a separator is refused', () {
      expect(CompanionPackInstallRules.isSafePackId('a/b'), isFalse);
      expect(CompanionPackInstallRules.isSafePackId(r'a\b'), isFalse);
    });

    test('a traversal cannot even be spelled', () {
      expect(CompanionPackInstallRules.isSafePackId('..'), isFalse);
      expect(CompanionPackInstallRules.isSafePackId('../mimi'), isFalse);
    });

    test('a dot, a space and a colon are refused', () {
      expect(CompanionPackInstallRules.isSafePackId('mi.mi'), isFalse);
      expect(CompanionPackInstallRules.isSafePackId('mi mi'), isFalse);
      expect(CompanionPackInstallRules.isSafePackId('mi:mi'), isFalse);
    });

    test('an absolute path is refused', () {
      expect(CompanionPackInstallRules.isSafePackId('/mimi'), isFalse);
      expect(CompanionPackInstallRules.isSafePackId('C:mimi'), isFalse);
    });

    test('an empty or over-long id is refused', () {
      expect(CompanionPackInstallRules.isSafePackId(''), isFalse);
      expect(CompanionPackInstallRules.isSafePackId('a' * 65), isFalse);
    });

    test('an ordinary id is allowed', () {
      expect(CompanionPackInstallRules.isSafePackId('mimi'), isTrue);
      expect(CompanionPackInstallRules.isSafePackId('mimi-2_b'), isTrue);
    });

    test('a plan with an unsafe id is refused, not sanitised', () {
      final decision = plan(id: '../mimi');
      expect(decision.ok, isFalse);
      expect(decision.validation.codes, contains('unsafe_pack_id'));
    });
  });

  group('identity is not up for grabs', () {
    test('a built-in id is refused', () {
      // Two companions answering to `dog` would make the persisted selection
      // ambiguous, and the built-in is the one the app promises to ship.
      final decision = plan(id: 'dog');
      expect(decision.validation.codes, contains('pack_id_reserved'));
    });

    test('re-installing an id is refused rather than shadowing it', () {
      final decision = plan(installed: {'mimi'});
      expect(decision.validation.codes, contains('pack_already_installed'));
    });

    test('an unsupported species is refused', () {
      final decision = plan(species: 'snake');
      expect(decision.validation.codes, contains('unsupported_species'));
    });

    test('a nameless companion is refused', () {
      final decision = plan(name: '   ');
      expect(decision.validation.codes, contains('empty_display_name'));
    });
  });

  test('the name is trimmed, because it is shown to the player', () {
    expect(plan(name: '  Mimi  ').plan!.displayName, 'Mimi');
  });

  test('every source is representable and none changes the plan', () {
    // The architecture rule: origin must not change how a companion behaves, so
    // it is recorded and nothing else about the plan depends on it.
    for (final source in CompanionPackSource.values) {
      final decision = plan(source: source);
      expect(decision.ok, isTrue, reason: '$source: ${decision.validation}');
      expect(decision.plan!.relativeDirectory, 'companion_packs/mimi');
    }
  });

  test('the source round-trips through its id', () {
    for (final source in CompanionPackSource.values) {
      expect(CompanionPackSource.fromId(source.id), source);
    }
    expect(CompanionPackSource.fromId('invented'), isNull);
  });

  test('every reason is reported, not just the first', () {
    final decision = plan(id: 'dog', species: 'snake', name: '');
    expect(decision.validation.codes, contains('pack_id_reserved'));
    expect(decision.validation.codes, contains('unsupported_species'));
    expect(decision.validation.codes, contains('empty_display_name'));
  });
}
