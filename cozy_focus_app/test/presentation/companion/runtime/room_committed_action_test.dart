import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/runtime/companion_behavior_director.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/random_source.dart';

import 'catalog_test_support.dart';

/// The room is **action-authoritative** (P25 D5).
///
/// The simulation decides what the companion is doing — the player tapped a
/// piece of furniture, the panel named the action, and the activity carries the
/// dwell and the effect. The presentation's job is to present that decision.
///
/// Before D5 was answered, the page forwarded only the anchor's *role*, so the
/// presentation picked a second behaviour from the anchor's ambient recipe and
/// the two could disagree: the panel could say 正在看书 while the avatar drew a
/// standing idle. These tests pin the decision, and the negative cases pin the
/// fact that the anchor still decides when nothing is committed.
void main() {
  final catalog = loadShippedCatalog();

  CompanionBehaviorDirector director({
    required CompanionBaseContext base,
    String? roomAnchor,
    CompanionMacroBehavior? committed,
    int seed = 7,
  }) =>
      CompanionBehaviorDirector(
        catalog: catalog,
        context: CompanionContext(
          companionId: CompanionId.dog,
          baseContext: base,
          roomAnchor: roomAnchor,
          macroBehavior: committed,
        ),
        random: SeededRandomSource(seed),
      );

  group('a committed action is presented verbatim', () {
    test('every action the furniture catalog can commit', () {
      // The vocabulary the catalog uses is the macro-behaviour vocabulary, so
      // each of these is a real, presentable behaviour — this is what makes
      // "the panel names it, so the avatar draws it" true rather than aspirational.
      for (final committed in const [
        CompanionMacroBehavior.roomSit,
        CompanionMacroBehavior.rest,
        CompanionMacroBehavior.sleep,
        CompanionMacroBehavior.focusRead,
        CompanionMacroBehavior.focusWrite,
        CompanionMacroBehavior.focusThink,
        CompanionMacroBehavior.craftWork,
      ]) {
        final d = director(
          base: CompanionBaseContext.room,
          roomAnchor: 'seat',
          committed: committed,
        );
        expect(d.currentMacroBehavior, committed,
            reason: 'the simulation committed `${committed.id}`; the '
                'presentation must present it rather than pick its own');
      }
    });

    test('the committed action outranks the anchor its recipe allows', () {
      // The `seat` anchor's recipe allows exactly one behaviour, `room_sit`. A
      // committed `pause_rest` must survive that, or the ambient recipe would
      // veto the business decision on the next context push.
      final d = director(
        base: CompanionBaseContext.room,
        roomAnchor: 'seat',
        committed: CompanionMacroBehavior.rest,
      );
      expect(d.currentMacroBehavior, CompanionMacroBehavior.rest);

      // And it stays put across an unrelated context push.
      d.updateContext(
          d.context.copyWith(macroBehavior: CompanionMacroBehavior.rest));
      expect(d.currentMacroBehavior, CompanionMacroBehavior.rest);
    });
  });

  group('the anchor still decides when nothing is committed', () {
    test('each room anchor keeps its own behaviour', () {
      expect(
        director(base: CompanionBaseContext.room, roomAnchor: 'seat')
            .currentMacroBehavior,
        CompanionMacroBehavior.roomSit,
      );
      expect(
        director(base: CompanionBaseContext.room, roomAnchor: 'front')
            .currentMacroBehavior,
        CompanionMacroBehavior.roomRead,
      );
      expect(
        director(base: CompanionBaseContext.room, roomAnchor: 'work')
            .currentMacroBehavior,
        CompanionMacroBehavior.roomWork,
      );
      expect(
        director(base: CompanionBaseContext.room, roomAnchor: 'lie')
            .currentMacroBehavior,
        CompanionMacroBehavior.roomSleep,
      );
    });

    test('a non-room context is unaffected by this change', () {
      // The committed path is opt-in: only the room supplies a macro behaviour,
      // so every other context must pick exactly as it did before.
      final focus = director(
        base: CompanionBaseContext.focus,
        committed: null,
      );
      expect(focus.currentMacroBehavior, isNotNull,
          reason: 'an ungrounded focus context still gets a behaviour');

      final home = director(base: CompanionBaseContext.home);
      expect(home.currentMacroBehavior, isNotNull);
    });
  });

  group('a new action at the same anchor is noticed', () {
    test('sitting then resting on one sofa re-presents immediately', () {
      // The regression this guards: the slot is derived from the anchor, and
      // `sit` and `rest` share the `seat` anchor, so the slot does not change.
      // Without tracking the committed id, the presentation would keep drawing
      // the action the companion has already finished.
      final d = director(
        base: CompanionBaseContext.room,
        roomAnchor: 'seat',
        committed: CompanionMacroBehavior.roomSit,
      );
      expect(d.currentMacroBehavior, CompanionMacroBehavior.roomSit);

      d.updateContext(
        d.context.copyWith(macroBehavior: CompanionMacroBehavior.rest),
      );
      expect(d.currentMacroBehavior, CompanionMacroBehavior.rest,
          reason: 'the simulation moved the companion from sitting to resting '
              'on the same anchor');
    });
  });
}
