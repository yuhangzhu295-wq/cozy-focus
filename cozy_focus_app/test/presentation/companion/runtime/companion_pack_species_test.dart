import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_manifest_data.dart';

/// P31 — a companion's species is declared, not inferred.
///
/// `dog`, `cat` and `rabbit` are identity ids that *happen* to name a species
/// too, and that coincidence holds only while there is exactly one companion per
/// species. A user-supplied pack breaks it: the moment two dogs can exist, an id
/// can no longer answer "what animal is this" — and the motion semantics a pack
/// must reuse depend on that answer.
///
/// So the profile carries `species` explicitly, and nothing may derive it from
/// the id. This file is the guard that it stays declared and that the shipped
/// JSON and its Dart mirror agree.
void main() {
  late Map<String, dynamic> profiles;

  setUpAll(() {
    final file = File('assets/companion/companion_profiles.json');
    expect(file.existsSync(), isTrue,
        reason: 'the shipped profiles are the source of truth for this test');
    final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    profiles = root['profiles'] as Map<String, dynamic>;
  });

  test('every profile declares the animal it is', () {
    expect(profiles, isNotEmpty, reason: 'otherwise this test is vacuous');
    for (final entry in profiles.entries) {
      final declared = (entry.value as Map)['species'] as String?;
      expect(declared, isNotNull,
          reason: '${entry.key} declares no species, so anything reading it '
              'would have to guess from the id');
      expect(const ['dog', 'cat', 'rabbit'], contains(declared),
          reason: '${entry.key} names an animal outside the supported set: '
              '$declared');
    }
  });

  test('the Dart mirror agrees with the shipped JSON', () {
    // The mirror is compiled in and is what the runtime actually reads, so a
    // field present in one and absent from the other would be worse than absent
    // from both.
    for (final entry in profiles.entries) {
      final fromJson = (entry.value as Map)['species'] as String?;
      final fromMirror =
          CompanionManifestData.profiles[CompanionId(entry.key)]?.species;
      expect(fromMirror, fromJson,
          reason: 'the mirror must declare the same species as the JSON for '
              '${entry.key}');
    }
  });

  test('species is a separate field from the identity id', () {
    // Stated as a test because the whole point is that the two are not
    // interchangeable: an id may one day be `mimi` while the species stays `dog`.
    final dog = CompanionManifestData.profiles[const CompanionId('dog')];
    expect(dog, isNotNull);
    expect(dog!.id.value, 'dog');
    expect(dog.species, 'dog',
        reason: 'they agree today for the built-ins, and the field is what '
            'keeps that from being the only way to know');
  });
}
