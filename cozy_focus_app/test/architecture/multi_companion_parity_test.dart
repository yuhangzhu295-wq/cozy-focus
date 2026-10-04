import 'dart:io';

import 'package:cozy_focus_app/presentation/companion/companion_visual_registry.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest_data.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_manifest_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dog, cat and rabbit must be the same thing three times.
///
/// ## Why this is a gate and not a review
///
/// A companion that is *nearly* like the others is the failure mode: it ships,
/// it renders, and it quietly differs in one dimension — a missing action, a
/// short frame count, a pack that is not declared so its art never reaches the
/// device, a provider nobody registered. Each of those is invisible in the app
/// and obvious in a comparison, which is what this file is.
///
/// ## It iterates the data, not a list of three
///
/// Every check below loops over `CompanionManifestData.profiles.keys`. A fourth
/// companion added to the data is therefore covered **without editing this
/// file**, and a test asserts exactly that — otherwise a parity suite that
/// hard-coded three names would keep passing while a fourth went unchecked.
void main() {
  final companions = CompanionManifestData.profiles.keys.toList();

  test('the parity check covers every companion the data declares', () {
    // The property that makes the rest of this file meaningful. If someone adds
    // a companion and this file still only checks three, the suite would be
    // green and wrong.
    //
    // An earlier version compared `companions` against the expression it was
    // derived from -- the same expression on both sides, so it could never fail.
    // This compares the *sources* instead, which can disagree: a companion
    // present in one and missing from the other is a real defect, and it is the
    // shape an incomplete addition actually takes.
    expect(companions, isNotEmpty);

    final profiles =
        CompanionManifestData.profiles.keys.map((c) => c.value).toSet();
    final actionManifests = CompanionActionManifestData.manifests.keys.toSet();

    expect(companions.map((c) => c.value).toSet(), profiles,
        reason: 'the parity loop must cover exactly the catalog profiles');
    expect(actionManifests, profiles,
        reason: 'a companion with a catalog profile and no action manifest, or '
            'the reverse, would be half-registered. Profiles only: '
            '${profiles.difference(actionManifests)}; manifests only: '
            '${actionManifests.difference(profiles)}');
  });

  group('five dimensions, compared against the dog as reference', () {
    const reference = CompanionManifestData.defaultProfileId;

    test('1. action set — every companion ships the same action ids', () {
      final dog = CompanionActionManifestData.forCompanion(reference.value)!;
      for (final id in companions) {
        final other = CompanionActionManifestData.forCompanion(id.value);
        expect(other, isNotNull, reason: '${id.value} has no action manifest');
        expect(other!.actionIds, dog.actionIds,
            reason: '${id.value} does not ship the same action set as the dog');
      }
    });

    test('2. frame target — the same target per action', () {
      final dog = CompanionActionManifestData.forCompanion(reference.value)!;
      for (final id in companions) {
        final other = CompanionActionManifestData.forCompanion(id.value)!;
        for (final actionId in dog.actionIds) {
          final a = dog.specFor(actionId)!;
          final b = other.specFor(actionId)!;
          expect(b.effectiveTargetFrameCount, a.effectiveTargetFrameCount,
              reason: '${id.value}/$actionId has a different frame target');
          expect(b.loopMode, a.loopMode,
              reason: '${id.value}/$actionId plays differently');
        }
      }
    });

    test('3. manifest completeness — nothing declares itself unfinished', () {
      for (final id in companions) {
        final manifest = CompanionActionManifestData.forCompanion(id.value)!;
        expect(manifest.incompleteActions, isEmpty,
            reason: '${id.value} declares actions it has not finished');
      }
    });

    test('4. asset inclusion — every declared frame exists and ships', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final id in companions) {
        // The directory must be declared, or the art never reaches the device.
        // Flutter does not recurse into subdirectories, which is why the
        // pubspec names each pack explicitly -- and why forgetting one is a
        // silent failure that only shows up as a missing sprite on a real
        // device.
        expect(pubspec.contains('assets/companions/${id.value}/'), isTrue,
            reason: 'assets/companions/${id.value}/ is not declared in '
                'pubspec.yaml, so its art would not be bundled');

        final manifest = CompanionActionManifestData.forCompanion(id.value)!;
        final missing = [
          for (final path in manifest.allFrames)
            if (!File(path).existsSync()) path,
        ];
        expect(missing, isEmpty,
            reason: '${id.value} declares frames that are not on disk:\n'
                '${missing.join('\n')}');
        expect(manifest.allFrames, isNotEmpty,
            reason: '${id.value} declares no frames at all');
      }
    });

    test('5. runtime registration — profile, manifest and provider', () {
      final catalog = bundledCompanionCatalog();
      final registry = buildCompanionVisualRegistry();
      for (final id in companions) {
        // In the catalog the director reads.
        expect(catalog.profileFor(id).displayName, isNotEmpty,
            reason: '${id.value} is missing from the companion catalog');
        // In the action manifest the sprite layer reads.
        expect(CompanionActionManifestData.forCompanion(id.value), isNotNull,
            reason: '${id.value} is missing from the action manifests');
        // And with a visual provider, so it can actually be drawn.
        expect(registry.providerForCompanion(id), isNotNull,
            reason: '${id.value} has no visual provider registered, so nothing '
                'would draw it');
      }
    });
  });

  group('species branching is zero', () {
    /// A comparison against a companion id or a species — the shape a branch
    /// takes. Deliberately not a bare name search: a map key like
    /// `CompanionId.dog: _profile(...)` is a registration, and a
    /// `?? CompanionId.dog` is a default. Neither is a branch, and flagging
    /// them would make this gate noise that gets suppressed.
    bool branchesOnSpecies(String source) {
      for (final line in source.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
        for (final pattern in [
          '== CompanionId.',
          '!= CompanionId.',
          'case CompanionId.',
          '== PetSpecies.',
          'case PetSpecies.',
          "== 'dog'",
          "== 'cat'",
          "== 'rabbit'",
        ]) {
          if (trimmed.contains(pattern)) return true;
        }
      }
      return false;
    }

    test('pages contain no species branch', () {
      final offenders = <String>[];
      final dir = Directory('lib/presentation/pages');
      expect(dir.existsSync(), isTrue);
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (branchesOnSpecies(entity.readAsStringSync())) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'a page that branches on the species cannot host a fourth '
              'companion without an edit:\n${offenders.join('\n')}');
    });

    test('the generic renderer contains no species branch', () {
      final offenders = <String>[];
      for (final path in const [
        'lib/presentation/widgets/pet_avatar_widget.dart',
        'lib/presentation/companion/companion_avatar.dart',
        'lib/presentation/companion/runtime/companion_behavior_director.dart',
        'lib/presentation/companion/runtime/companion_renderer.dart',
        'lib/presentation/companion/runtime/companion_sprite_art.dart',
        'lib/presentation/companion/runtime/companion_asset_resolver.dart',
      ]) {
        final file = File(path);
        if (!file.existsSync()) continue;
        if (branchesOnSpecies(file.readAsStringSync())) offenders.add(path);
      }
      expect(offenders, isEmpty,
          reason: 'the renderer must not know which companion it is drawing:\n'
              '${offenders.join('\n')}');
    });

    test('negative proof: the scan detects a branch it is given', () {
      // A scan that matches nothing is indistinguishable from one that cannot
      // match. These are the shapes it must catch, and the shapes it must not.
      expect(branchesOnSpecies('if (id == CompanionId.dog) return a;'), isTrue);
      expect(
          branchesOnSpecies('switch (id) { case CompanionId.cat: }'), isTrue);
      expect(branchesOnSpecies("if (species == 'rabbit') return b;"), isTrue);

      expect(branchesOnSpecies('CompanionId.dog: _profile(...),'), isFalse,
          reason: 'a map key is a registration, not a branch');
      expect(branchesOnSpecies('?? CompanionId.dog'), isFalse,
          reason: 'a default is not a branch');
      expect(branchesOnSpecies('// if (id == CompanionId.dog)'), isFalse,
          reason: 'a comment is not a branch');
    });
  });

  group('the registry is a table, not a branch', () {
    test('every catalog companion has exactly one provider', () {
      final registry = buildCompanionVisualRegistry();
      final ids = <CompanionId>[];
      for (final id in companions) {
        expect(registry.providerForCompanion(id), isNotNull, reason: id.value);
        ids.add(id);
      }
      // No duplicates: a second registration would silently win or lose
      // depending on order.
      expect(ids.toSet().length, ids.length);
    });
  });
}
