/// Measures how many independent authorities decide what the companion shows.
///
/// ## Why this exists
///
/// P19 recorded `BEHAVIOR_AUTHORITY_COUNT = 2` from a one-off reading of the
/// code, and `tools/cozy_gate.py` then reported that number for several phases
/// — as a literal. A gate that recites a finding it never re-measures cannot
/// notice the day the finding stops being true, in either direction.
///
/// ## What the two authorities were
///
/// * **A — the decision.** `FurnitureActionResolver` commits an action, and
///   `CompanionActivity.companionAction` carries it. The furniture panel names
///   the same action to the player.
/// * **B — the presentation.** `RoomPage` forwarded only the anchor's *role*, so
///   the presentation picked its own behaviour from the anchor's ambient recipe.
///   On the sofa, `seat` allowed exactly one behaviour, `room_sit` — so 坐下,
///   休息 and 小睡 all drew the same thing while the panel named three.
///
/// ## How it is measured
///
/// Not by reading the source. For every action the catalog can commit, this
/// drives the *real* director with the *real* catalog and asks what it presents.
/// When the committed action comes back verbatim the presentation is not making
/// a second decision, and there is one authority. The measurement runs the
/// engine, so it can only be satisfied by the engine behaving.
///
/// D5 (P25) answered this in favour of the action: tapping furniture chooses the
/// action, so the count is 1 and the gate passes. If the wiring regressed, the
/// director would present the anchor's behaviour instead and the count would
/// return to 2 without anyone editing this file.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/room/furniture_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_behavior_director.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/random_source.dart';

import '../presentation/companion/runtime/catalog_test_support.dart';

/// The actions the catalog can commit that the presentation does **not** present
/// verbatim — the concrete evidence for a count above 1.
///
/// Empty means the presentation honours the room's decision.
List<String> overriddenActions() {
  final catalog = loadShippedCatalog();
  final overridden = <String>[];

  for (final entry in FurnitureCatalog.entities.entries) {
    final item = entry.value;
    if (item.interactionPoints.isEmpty) continue;
    final anchor = item.interactionPoints.first;

    for (final action in item.actions) {
      final committed = CompanionMacroBehavior.fromId(action.companionAction);
      if (committed == null) continue;

      final director = CompanionBehaviorDirector(
        catalog: catalog,
        context: CompanionContext(
          companionId: CompanionId.dog,
          baseContext: CompanionBaseContext.room,
          roomAnchor: anchor,
          macroBehavior: committed,
        ),
        random: SeededRandomSource(1),
      );
      if (director.currentMacroBehavior != committed) {
        overridden.add('${entry.key}/${action.id}→${action.companionAction}');
      }
    }
  }
  return overridden;
}

/// What the presentation picks when the room commits **nothing**.
///
/// This is authority B on its own: the anchor's ambient recipe. Comparing it
/// against the committed actions is what makes the measurement meaningful — if
/// the two agreed for every action, a count of 2 would describe no real risk.
CompanionMacroBehavior? ambientPickFor(String itemId) {
  final catalog = loadShippedCatalog();
  final item = FurnitureCatalog.forId(itemId);
  if (item == null || item.interactionPoints.isEmpty) return null;
  return CompanionBehaviorDirector(
    catalog: catalog,
    context: CompanionContext(
      companionId: CompanionId.dog,
      baseContext: CompanionBaseContext.room,
      roomAnchor: item.interactionPoints.first,
    ),
    random: SeededRandomSource(1),
  ).currentMacroBehavior;
}

/// The measured number of authorities that decide what the companion presents.
int authorityCount() => overriddenActions().isEmpty ? 1 : 2;

void main() {
  test('the measurement matches how the room is actually wired', () {
    final overridden = overriddenActions();
    final count = authorityCount();

    // The marker the gate parses. Kept on one line, with no other text, so a
    // reader of the gate log can check the number rather than trust it.
    // ignore: avoid_print
    print('BEHAVIOR_AUTHORITY_COUNT=$count');
    // ignore: avoid_print
    print('BEHAVIOR_AUTHORITY_OVERRIDDEN=${overridden.join(',')}');

    expect(count, 1,
        reason: 'D5 decided that tapping furniture chooses the action, so the '
            'presentation must present it. Overridden: $overridden');
  });

  test(
      'negative verification: dropping the committed action restores two '
      'authorities', () {
    // The measurement must be able to see the *old* behaviour, or it is not
    // measuring anything. Without a committed action the director falls back to
    // the anchor's ambient recipe — which is precisely authority B.
    final sofaAmbient = ambientPickFor('sofa');
    expect(sofaAmbient, CompanionMacroBehavior.roomSit,
        reason: 'the seat anchor ambient behaviour is room_sit');

    // The sofa commits three different actions, so an ambient pick that is one
    // fixed behaviour for all of them is a real disagreement, not a formality.
    final sofaActions = FurnitureCatalog.forId('sofa')!
        .actions
        .map((a) => a.companionAction)
        .toSet();
    expect(sofaActions.length, greaterThan(1),
        reason: 'the measurement needs a multi-action item to be meaningful');
    final sofaBehaviours =
        sofaActions.map(CompanionMacroBehavior.fromId).toSet();
    expect(sofaBehaviours, isNot(contains(null)),
        reason: 'every committed action must be a real behaviour id');
    expect(
      sofaBehaviours,
      isNot({sofaAmbient}),
      reason: 'the committed actions and the ambient pick must be able to '
          'disagree, which is what the second authority cost',
    );
  });

  test('every catalog action is a behaviour the runtime knows', () {
    // A guard on the measurement's own inputs: a `companionAction` that is not
    // a real behaviour id would be silently skipped above, shrinking the
    // measurement instead of failing it.
    final unknown = <String>[];
    for (final item in FurnitureCatalog.entities.values) {
      for (final action in item.actions) {
        if (CompanionMacroBehavior.fromId(action.companionAction) == null) {
          unknown.add('${item.id}/${action.id}→${action.companionAction}');
        }
      }
    }
    expect(unknown, isEmpty,
        reason: 'these committed actions name no behaviour, so the room could '
            'never present them: $unknown');
  });
}
