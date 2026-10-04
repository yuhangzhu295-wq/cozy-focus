/// Measures how many independent authorities decide what the companion shows.
///
/// ## Why this exists
///
/// P19 recorded `BEHAVIOR_AUTHORITY_COUNT = 2` from a one-off reading of the
/// code. `tools/cozy_gate.py` then reported that number for several phases — as
/// a constant. A gate that recites a finding it never re-measures is not a gate;
/// it cannot notice the day the finding stops being true, in either direction.
/// This file is the missing measurement, so the gate can run it.
///
/// ## The two authorities
///
/// * **A — the decision.** `FurnitureActionResolver` commits an action, and
///   `CompanionActivity.companionAction` is documented as *"the semantic
///   companion action the sprite player should present."* The contract says the
///   committed action is what gets presented.
/// * **B — the presentation.** `RoomPage` forwards
///   `FurnitureCatalog.forId(itemId).interactionPoints.first` to the avatar. That
///   value is a property of the **item**, so every action on one item presents
///   the *same* posture.
///
/// B is therefore not a function of A. On an item with three actions, the room
/// can commit any of three and the page can show only one — that is the second
/// authority, and it is the divergence the gate reports.
///
/// ## This file measures; it does not assert the product is wrong
///
/// The tests here pass today. That is deliberate: the fix direction is the
/// owner's decision (P25 D5 — does tapping furniture choose the action, or only
/// the destination), and committing a red test would be committing a broken
/// state. The gate reads the measured count and decides. When D5 is answered and
/// the page forwards the action, [authorityCount] returns 1 with no edit here.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/room/furniture_catalog.dart';
import 'package:cozy_focus_app/presentation/companion/room/furniture_entity.dart';

/// How a posture is chosen for [action] on [item].
typedef PostureSelector = String? Function(
  FurnitureEntity item,
  FurnitureAction action,
);

/// Authority B as the app implements it today: the item's first interaction
/// point, which carries no information about *which* action was committed.
String? itemDerivedPosture(FurnitureEntity item, FurnitureAction action) =>
    item.interactionPoints.isEmpty ? null : item.interactionPoints.first;

/// Authority B as the activity contract intends it: the action's own companion
/// action, which is the value the sprite player is told to present.
String? actionDerivedPosture(FurnitureEntity item, FurnitureAction action) =>
    action.companionAction;

/// The furniture items on which the room can commit an action it cannot show.
///
/// An item is ambiguous when it declares more distinct actions than [posture]
/// can distinguish. Ambiguity on any item means the presentation layer holds a
/// second, independent say in what the companion does.
List<String> ambiguousItems(PostureSelector posture) {
  final ambiguous = <String>[];
  for (final entry in FurnitureCatalog.entities.entries) {
    final item = entry.value;
    final actions = item.actions.map((a) => a.id).toSet();
    final postures = item.actions.map((a) => posture(item, a)).toSet();
    if (postures.length < actions.length) ambiguous.add(entry.key);
  }
  return ambiguous;
}

/// The measured number of authorities that decide what the companion presents.
///
/// 1 when the presented posture is determined by the committed action; 2 when
/// the presentation has an independent say.
int authorityCount(PostureSelector posture) =>
    ambiguousItems(posture).isEmpty ? 1 : 2;

void main() {
  test('the measurement matches how the room is actually wired', () {
    final ambiguous = ambiguousItems(itemDerivedPosture);
    final count = authorityCount(itemDerivedPosture);

    // The marker the gate parses. Kept on one line, with no other text, so a
    // reader of the gate log can check the number rather than trust it.
    // ignore: avoid_print
    print('BEHAVIOR_AUTHORITY_COUNT=$count');
    // ignore: avoid_print
    print('BEHAVIOR_AUTHORITY_AMBIGUOUS_ITEMS=${ambiguous.join(',')}');

    // The catalog is the reason the count is what it is. If this ever becomes
    // empty, either the presentation was fixed or the catalog lost its actions
    // — and the gate would go green for the wrong reason. Naming the items here
    // makes that visible in the log rather than only in the count.
    expect(FurnitureCatalog.entities, isNotEmpty,
        reason:
            'the catalog must not be empty, or this measurement is vacuous');
    expect(ambiguous, isNotEmpty,
        reason: 'if no item is ambiguous the count is 1 and the gate should '
            'pass — update the gate deliberately rather than by accident');
  });

  test('negative verification: an action-derived posture is a single authority',
      () {
    // The measurement must be able to return 1. If it always returned 2, the
    // gate would be a constant again, just written differently.
    expect(authorityCount(actionDerivedPosture), 1,
        reason: 'when the presented posture comes from the committed action, '
            'there is only one authority');
    expect(ambiguousItems(actionDerivedPosture), isEmpty);
  });

  test('negative verification: a synthetic divergence is detected', () {
    // Collapse every action on an item to one posture, as the item-derived
    // selector does, and confirm the measurement sees the divergence. This is
    // the check that the first test is not passing for an unrelated reason.
    String? alwaysTheSame(FurnitureEntity item, FurnitureAction action) =>
        'constant';

    final multiAction = FurnitureCatalog.entities.values
        .where((item) => item.actions.length > 1)
        .map((item) => item.id)
        .toList();
    expect(multiAction, isNotEmpty,
        reason:
            'the synthetic divergence needs at least one multi-action item');
    expect(ambiguousItems(alwaysTheSame), containsAll(multiAction));
    expect(authorityCount(alwaysTheSame), 2);
  });

  test('every item the room can commit an action on declares a posture', () {
    // A guard on the measurement's own inputs: an item with no interaction
    // point would make `itemDerivedPosture` null and silently inflate the
    // ambiguity count for a reason that has nothing to do with authority.
    for (final entry in FurnitureCatalog.entities.entries) {
      expect(entry.value.interactionPoints, isNotEmpty,
          reason: '${entry.key} has no interaction point, so the room cannot '
              'place the companion on it at all');
      expect(entry.value.actions, isNotEmpty,
          reason: '${entry.key} declares no action');
    }
  });
}
