import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guards for the V4.2.1 architecture contract.
///
/// These read the source tree rather than exercising behaviour, because the
/// properties they protect are *structural*: they are about code that must not
/// exist. A behavioural test cannot prove the absence of a species switch, and
/// the brief's final gate asks for exactly those counts.
void main() {
  List<File> dartFilesIn(String directory) {
    final dir = Directory(directory);
    if (!dir.existsSync()) return const [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  }

  group('page-level species branches', () {
    test('no page branches on a species', () {
      final pages = dartFilesIn('lib/presentation/pages');
      expect(pages, isNotEmpty, reason: 'page scan found nothing to check');

      // A page must never ask "which companion is this?". It may mention a
      // companion only through the catalog, which is data.
      final offenders = <String>[];
      for (final file in pages) {
        final source = file.readAsStringSync();
        for (final needle in [
          'PetSpecies',
          "== 'dog'",
          '== "dog"',
          "== 'cat'",
          '== "cat"',
          "== 'rabbit'",
          '== "rabbit"',
          'CompanionId.dog',
          'CompanionId.cat',
          'CompanionId.rabbit',
        ]) {
          if (source.contains(needle)) {
            offenders.add('${file.path}: $needle');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'PAGE_LEVEL_SPECIES_BRANCHES > 0:\n${offenders.join('\n')}');
    });
  });

  group('generic renderer species branches', () {
    test('the generic runtime never names a species', () {
      // These are the *generic* files. The catalog and the manifest data are
      // deliberately excluded: they are where companion ids are data, which is
      // the opposite of a branch. The director, the intent, the renderer, the
      // clock and the provider interface must never know a species exists.
      final files = [
        'companion_behavior_director.dart',
        'companion_presentation_intent.dart',
        'companion_renderer.dart',
        'companion_presentation_clock.dart',
        'companion_visual_provider.dart',
        'companion_asset_resolver.dart',
        'companion_context.dart',
        'companion_pose.dart',
      ].map((n) => File('lib/presentation/companion/runtime/$n')).toList()
        ..add(File('lib/presentation/companion/companion_avatar.dart'));
      for (final f in files) {
        expect(f.existsSync(), isTrue, reason: 'missing \$f');
      }

      final offenders = <String>[];
      for (final file in files) {
        final source = file.readAsStringSync();
        for (final needle in [
          "CompanionId('dog')",
          'CompanionId.dog',
          'CompanionId.cat',
          'CompanionId.rabbit',
          "'dog'",
          "'cat'",
          "'rabbit'",
        ]) {
          if (source.contains(needle)) {
            offenders.add('${file.path}: $needle');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'GENERIC_RENDERER_SPECIES_BRANCHES > 0:\n${offenders.join('\n')}',
      );
    });

    test('the director does not import a controller, repository or engine', () {
      final source = File(
        'lib/presentation/companion/runtime/companion_behavior_director.dart',
      ).readAsStringSync();

      // This is what makes SECOND_BUSINESS_STATE_MACHINE structural: the file
      // cannot write business state because it cannot reach any of it.
      for (final forbidden in [
        'controllers/',
        'repositories/',
        'focus_session_engine',
        'craft_engine',
        'reward_service',
        'app_database',
        'drift',
      ]) {
        expect(
          source.contains(forbidden),
          isFalse,
          reason: 'the director must not reference "$forbidden"',
        );
      }
    });
  });

  group('one engine, not one per species', () {
    test('no per-companion focus engine or controller exists', () {
      final lib = dartFilesIn('lib');
      final offenders = lib
          .where((f) {
            final name = f.path.toLowerCase();
            return name.contains('dog_') ||
                name.contains('cat_') ||
                name.contains('rabbit_') ||
                name.contains('_dog.') ||
                name.contains('_cat.') ||
                name.contains('_rabbit.');
          })
          .map((f) => f.path)
          .toList();

      // The only permitted species-named files are the leaf visual providers and
      // their art, which is where species-specific *drawing* is allowed to live.
      final unexpected = offenders.where((path) {
        final name = path.split(RegExp(r'[/\\]')).last;
        return !(name.startsWith('cat_visual') ||
            name.startsWith('rabbit_visual') ||
            name.startsWith('placeholder_visual'));
      }).toList();

      expect(unexpected, isEmpty,
          reason: 'unexpected species-named files: $unexpected');
    });

    test('exactly one behavior director class exists', () {
      final lib = dartFilesIn('lib');
      final declarations = <String>[];
      for (final file in lib) {
        final source = file.readAsStringSync();
        if (RegExp(r'class\s+CompanionBehaviorDirector\b').hasMatch(source)) {
          declarations.add(file.path);
        }
      }
      expect(declarations.length, 1, reason: 'found: $declarations');
    });
  });

  group('shared progress, not per-companion economy', () {
    test('no per-companion XP, currency or vitals exist', () {
      final lib = dartFilesIn('lib');
      final offenders = <String>[];
      for (final file in lib) {
        final source = file.readAsStringSync().toLowerCase();
        for (final forbidden in [
          'perpetxp',
          'per_pet_xp',
          'petcurrency',
          'hungersystem',
          'petrarity',
          'gachapool',
        ]) {
          if (source.contains(forbidden)) {
            offenders.add('${file.path}: $forbidden');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('the fourth-companion contract', () {
    test('no production file mentions the test-only companion', () {
      // The proof that adding a companion needs no production edit: the fox
      // exists only in test code, yet it drives the shared director and renders
      // through the production page widget.
      final offenders = <String>[];
      for (final file in dartFilesIn('lib')) {
        final source = file.readAsStringSync();
        if (source.contains("'fox'") || source.contains('FoxVisualProvider')) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'the fox must be test-only: \$offenders');
    });

    test('registration is a single centralised touch-point', () {
      final source = File(
        'lib/presentation/companion/companion_visual_registry.dart',
      ).readAsStringSync();

      // One function registers every companion; a new one is a row here plus a
      // profile, and nothing else in the app changes.
      expect(source.contains('buildCompanionVisualRegistry'), isTrue);
      expect(RegExp(r'registry\.register\(').allMatches(source).length,
          greaterThanOrEqualTo(3));
    });
  });

  group('the runtime is data-driven', () {
    test('behaviour eligibility comes from the manifest, not a switch', () {
      final source = File(
        'lib/presentation/companion/runtime/companion_manifest_data.dart',
      ).readAsStringSync();

      // Every context slot is declared as data.
      for (final context in [
        'CompanionBaseContext.home',
        'CompanionBaseContext.focus',
        'CompanionBaseContext.pause',
        'CompanionBaseContext.complete',
        'CompanionBaseContext.craft',
        'CompanionBaseContext.room',
        'CompanionBaseContext.sleep',
      ]) {
        expect(source.contains(context), isTrue,
            reason: 'missing recipe for $context');
      }
    });
  });
}
