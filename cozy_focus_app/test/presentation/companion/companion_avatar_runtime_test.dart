import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/presentation/companion/companion_avatar.dart';
import 'package:cozy_focus_app/presentation/companion/mochi_pose_prop.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_sprite_player.dart';
import 'package:cozy_focus_app/presentation/companion/mochi_pose_spec.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_presentation_clock.dart';
import 'package:cozy_focus_app/presentation/controllers/home_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// A home controller that reports a preset state instead of loading one.
class _PresetHomeController extends HomeController {
  final HomeUIState _preset;
  _PresetHomeController(super.ref, this._preset);

  @override
  Future<void> loadHomeData() async {
    state = _preset;
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// The prop currently rendered, or `null` when the pose carries none.
  /// The prop on screen. Never null: an absent prop *is* `none`.
  MochiPosePropKind renderedProp(WidgetTester tester) {
    final finder = find.byType(MochiPoseProp);
    if (finder.evaluate().isEmpty) return MochiPosePropKind.none;
    return tester.widget<MochiPoseProp>(finder.first).kind;
  }

  /// The action id the sprite player is presenting, or `null` when the approved
  /// layered rig is drawing instead.
  ///
  /// The V4.2.1 macro actions are now carried by *production sprite sequences* —
  /// a different drawing per action — rather than by a code-drawn prop layered
  /// onto the one approved silhouette. These tests assert what is actually on
  /// screen, so they follow the renderer that is really in use for each pose.
  String? renderedSpriteAction(WidgetTester tester) {
    final finder = find.byType(CompanionSpritePlayer);
    if (finder.evaluate().isEmpty) return null;
    return tester.widget<CompanionSpritePlayer>(finder.first).spec.actionId;
  }

  const focusActions = ['focus_read', 'focus_write', 'focus_think'];

  /// Builds a container whose home controller reports [homeState].
  ProviderContainer containerWith(HomeUIState homeState) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        homeControllerProvider
            .overrideWith((ref) => _PresetHomeController(ref, homeState)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Widget appWith(ProviderContainer c, Widget child) =>
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          // Centred so the avatar's box is exactly the companion, and a tap on
          // `CompanionAvatar` cannot land on empty space beside it.
          home: Scaffold(body: Center(child: child)),
        ),
      );

  group('CompanionAvatar presents the runtime pose', () {
    testWidgets('a focus context renders one of the three focus poses',
        (tester) async {
      final c = containerWith(const HomeUIState(hasActiveSession: true));
      await tester.pumpWidget(appWith(c, const CompanionAvatar(size: 140)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        renderedSpriteAction(tester),
        anyOf(focusActions),
        reason: 'a running session must present a work silhouette',
      );
    });

    testWidgets('a paused session rests instead of working', (tester) async {
      final c = containerWith(const HomeUIState(hasActiveSession: true));
      await tester.pumpWidget(appWith(
        c,
        const CompanionAvatar(
          size: 140,
          visualStateOverride: PetVisualState.pause,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(renderedSpriteAction(tester), 'pause_rest');
    });

    testWidgets('an idle home has no work prop at all', (tester) async {
      final c = containerWith(const HomeUIState());
      await tester.pumpWidget(appWith(c, const CompanionAvatar(size: 140)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The point is that an idle home shows no *work* silhouette. It is not
      // `none`: late at night the ambient pool legitimately adds a resting beat,
      // so asserting `none` made this test depend on the wall clock and fail
      // whenever the suite ran after midnight.
      expect(
        renderedProp(tester),
        isNot(
          anyOf(
            MochiPosePropKind.openBook,
            MochiPosePropKind.notebook,
            MochiPosePropKind.thoughtBubbles,
          ),
        ),
      );
    });

    testWidgets('a room anchor announces the room, not idle', (tester) async {
      final c = containerWith(const HomeUIState());
      await tester.pumpWidget(appWith(
        c,
        const CompanionAvatar(size: 140, roomAnchor: 'seat'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The renderer's state enum has no "in the room" value, so without the
      // override a companion sitting in its room would be announced as idle.
      expect(find.bySemanticsLabel(RegExp('在房间')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('空闲')), findsNothing);
    });

    testWidgets('a completion context celebrates', (tester) async {
      final c = containerWith(const HomeUIState());
      await tester.pumpWidget(appWith(
        c,
        const CompanionAvatar(
          size: 140,
          visualStateOverride: PetVisualState.celebrate,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(renderedProp(tester), MochiPosePropKind.confetti);
    });
  });

  group('interaction overlay during focus', () {
    testWidgets(
        'tap shows the overlay pose, then restores the focus pose — never idle',
        (tester) async {
      final c = containerWith(const HomeUIState(hasActiveSession: true));
      await tester.pumpWidget(appWith(c, const CompanionAvatar(size: 140)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final before = renderedProp(tester);
      final beforeAction = renderedSpriteAction(tester);
      // The real precondition: a running session presents a work silhouette, so
      // the restore below is compared against something meaningful. This read
      // `isNotNull` on a value that can never be null, which could not fail.
      expect(beforeAction, anyOf(focusActions));

      // Tap the companion. The gesture goes through the same controller path the
      // pre-V4.2.1 avatar used, and additionally asks the director for an overlay.
      await tester.tap(find.byType(CompanionAvatar));
      await tester.pump();
      // The presentation scheduler ticks on an interval rather than every frame,
      // so the overlay appears on the next tick rather than the next frame.
      await tester.pump(CompanionPresentationClock.tickInterval);

      expect(
        renderedSpriteAction(tester),
        'tap_react',
        reason: 'the overlay pose must be presented while the overlay runs',
      );

      // Past the overlay's maximum window (1200 ms).
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(CompanionPresentationClock.tickInterval);

      expect(
        renderedSpriteAction(tester),
        beforeAction,
        reason: 'the previous focus behaviour must be restored exactly',
      );
      expect(
        renderedSpriteAction(tester),
        isNot('idle'),
        reason: 'the overlay must never fall through to idle',
      );
      expect(renderedProp(tester), before);
    });

    testWidgets('long press shows the petting overlay', (tester) async {
      final c = containerWith(const HomeUIState(hasActiveSession: true));
      await tester.pumpWidget(appWith(c, const CompanionAvatar(size: 140)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.longPress(find.byType(CompanionAvatar));
      await tester.pump();
      await tester.pump(CompanionPresentationClock.tickInterval);

      // Two channels can carry an overlay pose: a production sprite sequence
      // when the pack ships one for that action, and the code-drawn prop layered
      // on the approved rig otherwise. `pet_react` has no sequence yet, so this
      // asserts whichever channel is really in use rather than assuming one.
      final petAction = renderedSpriteAction(tester);
      if (petAction != null) {
        expect(petAction, 'pet_react');
      } else {
        expect(renderedProp(tester), MochiPosePropKind.heart);
      }
    });
  });

  group('lifecycle', () {
    testWidgets('disposing the avatar leaves no active ticker', (tester) async {
      final c = containerWith(const HomeUIState(hasActiveSession: true));
      await tester.pumpWidget(appWith(c, const CompanionAvatar(size: 140)));
      await tester.pump(const Duration(milliseconds: 50));

      // Replacing the tree disposes the presentation clock; a leaked ticker would
      // fail this test at teardown with "A Ticker was still active".
      await tester.pumpWidget(appWith(c, const SizedBox.shrink()));
      await tester.pump();
      expect(find.byType(CompanionAvatar), findsNothing);
    });

    testWidgets('an unknown companion id still renders the default companion',
        (tester) async {
      final c = containerWith(const HomeUIState(hasActiveSession: true));
      await tester.pumpWidget(appWith(
        c,
        const CompanionAvatar(
            size: 140, companionId: CompanionIdUnderTest.unknown),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Falls back to the default profile's provider, so a stale stored
      // selection degrades to the dog rather than to an empty box.
      //
      // This asserted `isNotNull` on a non-nullable enum, which could never
      // fail, and so it hid the fact that the renderer was resolving the
      // provider by the *raw* id and drawing nothing at all. The assertion is
      // now about what is actually on screen.
      expect(
        renderedSpriteAction(tester),
        anyOf(focusActions),
        reason: 'an unknown companion must fall back to the default companion',
      );
    });
  });
}

/// A companion id this build does not ship, to exercise the safe fallback.
abstract final class CompanionIdUnderTest {
  static const unknown = CompanionId('not-a-shipped-companion');
}
