import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/room/furniture_catalog.dart';

/// P35 — an imported companion is a first-class companion, and stays one.
///
/// ## What this guards against
///
/// The failure mode is not a crash. It is a custom companion that *works* while
/// quietly becoming a second kind of thing: a `CustomCompanionPage`, a
/// `MimiVisualProvider`, a branch in the room that asks where a companion came
/// from before deciding how it behaves. Each of those passes its own tests and
/// then means every future feature has to be built twice.
///
/// So these are source-level assertions rather than behavioural ones. Behaviour
/// tests cannot see the class that does not exist yet; a rule about what the code
/// is allowed to contain can.
void main() {
  /// Every `.dart` file under [dir], recursively.
  List<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  group('one runtime, not one per companion', () {
    test('there is one generic provider class, not one class per pet', () {
      final providers = <String>[];
      final pattern = RegExp(r'class (\w+) extends CompanionVisualProvider');

      for (final file in dartFiles('lib')) {
        for (final match in pattern.allMatches(file.readAsStringSync())) {
          providers.add(match.group(1)!);
        }
      }

      // The three shipped companions have a class each, because each draws
      // different code-built art. Everything a user installs is served by the one
      // generic provider, instantiated per pack from that pack's own data — which
      // is the whole point: a pack is data, and the only thing that differs
      // between two of them is which data and which directory.
      expect(
        providers..sort(),
        [
          'CatVisualProvider',
          'MochiVisualProvider',
          'PackBackedCompanionVisualProvider',
          'RabbitVisualProvider'
        ],
        reason: 'a new visual-provider class means someone built a second kind '
            'of companion rather than adding a pack. If this list changed, say '
            'why in the phase handoff.',
      );
    });

    test('no page or room file branches on where a companion came from', () {
      // The architecture rule from P31: origin is recorded and consulted by
      // nothing. A companion's behaviour must not depend on whether it arrived
      // as a built-in, an import, a local compile or a cloud generation, so the
      // source must not appear outside the pack layer at all.
      final offenders = <String>[];

      for (final file in dartFiles('lib')) {
        final path = file.path.replaceAll(r'\', '/');
        if (path.contains('/pack/')) continue; // the layer that owns the record
        if (file.readAsStringSync().contains('CompanionPackSource')) {
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty,
          reason: 'these files read how a companion arrived, which means the '
              'runtime now behaves differently for a custom companion: '
              '$offenders');
    });

    test('and no page or room file branches on "is this one custom"', () {
      final offenders = <String>[];
      final suspicion = RegExp(
        r'\b(isCustom|isInstalledPack|customCompanion|customPet|importedPack)\b',
      );

      for (final file in dartFiles('lib')) {
        final source = file.readAsStringSync();
        if (suspicion.hasMatch(source)) {
          offenders.add(file.path.replaceAll(r'\', '/'));
        }
      }

      expect(offenders, isEmpty,
          reason: 'a custom-companion branch means the app has two kinds of '
              'companion, and every feature after this one has to be built '
              'twice: $offenders');
    });
  });

  group('furniture semantics are shared deliberately, not by accident', () {
    test(
        'the companion actions shared by two affordances are the recorded ones',
        () {
      final byCompanionAction = <String, List<String>>{};
      for (final itemId in FurnitureCatalog.itemIds) {
        final entity = FurnitureCatalog.forId(itemId);
        if (entity == null) continue;
        for (final action in entity.actions) {
          byCompanionAction
              .putIfAbsent(action.companionAction, () => [])
              .add('$itemId/${action.id}');
        }
      }

      final shared = {
        for (final entry in byCompanionAction.entries)
          if (entry.value.length > 1) entry.key: entry.value..sort(),
      };

      // Three companion actions are claimed by two affordances each, and each is
      // a recorded decision rather than an accident:
      //
      //   room_sit     sofa/sit, rug/sit      two places to sit, one sitting
      //   sleep        sofa/nap, bed/sleep    a nap and a night's sleep
      //   focus_think  bookshelf/search, desk/study
      //
      // The last one is the P35 question: two labels promising different companion
      // behaviour while producing the same animation. There is one `focus_think`
      // and no second one is going to be invented for the difference, so the
      // honest position is two affordances with one visible behaviour. Pinned here
      // so a *new* collision has to be a decision.
      //
      // `room_sit` is also the P28.4 case: it has no frames of its own, so the
      // panel does not offer it. The room may still commit it for a companion
      // that declares a fallback for it, which the dog does.
      expect(
          shared.keys.toList()..sort(), ['focus_think', 'room_sit', 'sleep']);
      expect(shared['focus_think'], ['bookshelf/search', 'desk/study']);
      expect(shared['room_sit'], ['rug/sit', 'sofa/sit']);
      expect(shared['sleep'], ['bed/sleep', 'sofa/nap']);
    });

    test('and no affordance shares a label with a different behaviour', () {
      // The other half: two labels for one behaviour is a recorded decision, but
      // one label for two behaviours would be a real ambiguity.
      final byLabel = <String, Set<String>>{};
      for (final itemId in FurnitureCatalog.itemIds) {
        final entity = FurnitureCatalog.forId(itemId);
        if (entity == null) continue;
        for (final action in entity.actions) {
          byLabel
              .putIfAbsent(action.label, () => {})
              .add(action.companionAction);
        }
      }

      final ambiguous = {
        for (final entry in byLabel.entries)
          if (entry.value.length > 1) entry.key: entry.value,
      };
      expect(ambiguous, isEmpty,
          reason: 'these labels promise two different companion behaviours: '
              '$ambiguous');
    });
  });
}
