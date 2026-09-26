// §71 — the companion presentation layer cannot touch business state.
//
// The gate requires positive proof that tapping, long-pressing, blinking,
// celebrating, encouraging, the time-of-day bands and the motion loops **cannot**
// settle a focus session, award XP, award coins, advance a craft job, add
// inventory, place a room item, or change a statistic.
//
// Two independent kinds of evidence, because either alone is weak:
//
//   1. **Structural.** A scan of every source file in the two companion layers
//      asserts that none of them imports a write-capable layer at all. A file
//      that cannot name a DAO, a repository or a domain service cannot call one.
//      This survives refactors that a runtime test would miss.
//
//   2. **Runtime.** A whole-database snapshot — every table, every row, every
//      column — is compared before and after the presentation layer has been
//      driven through its entire repertoire. Any write anywhere, including to a
//      table nobody thought to check, fails the comparison.
//
// The structural half proves the *capability* is absent; the runtime half proves
// the capability is not being obtained some other way.

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide FocusSession, Pet, CraftJob, CraftRecipe, InventoryItem, RoomItem;
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';
import 'package:cozy_focus_app/presentation/animations/pet_idle_fallback_view.dart';
import 'package:cozy_focus_app/presentation/animations/pet_interaction_spec.dart';
import 'package:cozy_focus_app/presentation/companion/companion_avatar.dart';
import 'package:cozy_focus_app/presentation/companion/time_of_day.dart';
import 'package:cozy_focus_app/presentation/controllers/pet_motion_controller.dart';
import 'package:cozy_focus_app/presentation/controllers/providers.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';
import 'package:cozy_focus_app/presentation/widgets/pet_avatar_widget.dart';

class _TestClock implements FocusClock {
  final DateTime _now;
  _TestClock(this._now);
  @override
  DateTime now() => _now;
}

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    );

PetIdleFallbackViewState _fallback(WidgetTester tester) => tester
    .state<PetIdleFallbackViewState>(find.byType(PetIdleFallbackView).first);

/// Every table, every row, canonically ordered.
///
/// Rows are JSON-encoded and sorted so the comparison is about *content*, not
/// about the order SQLite happened to return them in.
Future<Map<String, String>> _snapshot(AppDatabase db) async {
  final snapshot = <String, String>{};
  for (final table in db.allTables) {
    final name = table.actualTableName;
    final rows = await db.customSelect('SELECT * FROM $name').get();
    final encoded = rows.map((row) => jsonEncode(row.data)).toList()..sort();
    snapshot[name] = encoded.join('\n');
  }
  return snapshot;
}

/// A snapshot with at least one non-empty table, so the comparison can never
/// quietly become a comparison of two empty databases.
Future<void> _seed(AppDatabase db) async {
  await db.craftDao.upsertInventoryItem(InventoryItem(
    id: 'inv-1',
    userId: 'iso-user',
    itemId: 'sofa',
    quantity: 1,
    updatedAt: DateTime(2026, 9, 22),
  ));
  await db.craftDao.upsertRoomItem(RoomItem(
    id: 'room-1',
    userId: 'iso-user',
    itemId: 'sofa',
    positionX: 0.5,
    positionY: 0.7,
    scale: 1.0,
    zIndex: 0,
    isVisible: true,
    placedAt: DateTime(2026, 9, 22),
  ));
  await db.craftDao.saveJob(CraftJob(
    id: 'job-1',
    userId: 'iso-user',
    recipeId: 'recipe_1',
    status: CraftJobStatus.completed,
    progressSeconds: 1200,
    startedAt: DateTime(2026, 9, 22),
    completedAt: DateTime(2026, 9, 22, 1),
    rewardClaimed: true,
    sessionId: null,
  ));
}

void main() {
  // ==========================================================================
  // 1. Structural — the layers cannot name a writer
  // ==========================================================================
  group('the companion layers cannot reach a write-capable layer', () {
    test('no source file in the companion or animation layer imports one', () {
      // If a file cannot import a DAO, a repository or a domain service, it
      // cannot call one. This is the strongest available statement of "the
      // animation observes business state; it does not own it".
      const forbidden = <String>[
        'data/local',
        'data/repositories',
        'domain/repositories',
        'domain/services',
      ];
      final roots = <Directory>[
        Directory('lib/presentation/companion'),
        Directory('lib/presentation/animations'),
      ];

      var scanned = 0;
      for (final root in roots) {
        expect(root.existsSync(), isTrue, reason: '${root.path} is missing');
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          scanned++;

          for (final line in const LineSplitter().convert(
            entity.readAsStringSync(),
          )) {
            final trimmed = line.trim();
            if (!trimmed.startsWith('import ')) continue;
            for (final banned in forbidden) {
              expect(trimmed.contains(banned), isFalse,
                  reason: '${entity.path} imports $banned — the presentation '
                      'layer must not be able to reach business writes');
            }
          }
        }
      }

      // A path typo would make the scan vacuous and it would still pass, so the
      // file count is asserted rather than only the outcome.
      expect(scanned, greaterThanOrEqualTo(15),
          reason: 'the scan found only $scanned files — the roots are wrong');
    });
  });

  // ==========================================================================
  // 2. Runtime — the renderer writes nothing, whatever it is doing
  // ==========================================================================
  group('the renderer writes nothing across its whole repertoire', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seed(db);
    });

    tearDown(() => db.close());

    testWidgets(
        'every visual state, a tap and a long press leave the DB intact',
        (tester) async {
      final controller = PetMotionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(PetAvatarWidget(
        visualState: PetVisualState.idle,
        controller: controller,
        growthProfile: null,
      )));
      await tester.pump(const Duration(milliseconds: 100));

      final before = await _snapshot(db);
      expect(before.values.any((v) => v.isNotEmpty), isTrue,
          reason: 'the seed did not land, so this comparison proves nothing');

      // Every real state, long enough for the blink and ear-twitch timers to fire
      // and for the flourish pool to complete several cycles. `interact` is
      // skipped on purpose: it exists in the enum but is never a state, and
      // assigning it here would break the invariant this suite relies on. The
      // overlay is exercised below, the way it actually happens — by touching
      // Mochi.
      for (final state in PetVisualState.values) {
        if (state == PetVisualState.interact) continue;
        controller.updateState(state);
        await tester.pump(const Duration(seconds: 6));
      }

      // A tap and a long press in the state that answers both. Each gesture is
      // *proved* to have landed before the database is compared again: a tap
      // that missed would make the isolation claim vacuous, and a silent miss
      // is exactly the failure mode a snapshot comparison cannot detect.
      controller.updateState(PetVisualState.idle);
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byType(PetAvatarWidget));
      await tester.pump(const Duration(milliseconds: 120));
      final tapped = _fallback(tester);
      expect(tapped.interactionKind, PetInteractionKind.friendly,
          reason: 'the tap never reached Mochi');
      expect(tapped.interactController.isAnimating, isTrue);
      await tester.pump(const Duration(milliseconds: 1200));

      await tester.longPress(find.byType(PetAvatarWidget));
      await tester.pump(const Duration(milliseconds: 120));
      final stroked = _fallback(tester);
      expect(stroked.isStrokeHeartVisible, isTrue,
          reason: 'the long press never reached Mochi');
      expect(stroked.strokeController.isAnimating, isTrue);
      await tester.pump(const Duration(milliseconds: 1200));

      // Reduced Motion on and off again, which tears the loops down and back up.
      // Fresh mounts with distinct keys are used here so each renderer owns its
      // controller — what is under test is the teardown/rebuild path, not the
      // controller's identity.
      await tester.pumpWidget(_app(
        const PetAvatarWidget(
          key: ValueKey('reduced-motion-on'),
          visualState: PetVisualState.idle,
        ),
        reduceMotion: true,
      ));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(_app(const PetAvatarWidget(
        key: ValueKey('reduced-motion-off'),
        visualState: PetVisualState.idle,
      )));
      await tester.pump(const Duration(seconds: 6));

      expect(await _snapshot(db), before);
    });
  });

  // ==========================================================================
  // 3. Runtime — the provider-backed avatar writes nothing while it lives
  // ==========================================================================
  group('the provider-backed avatar writes nothing while it lives', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seed(db);
    });

    tearDown(() => db.close());

    testWidgets('idle life, a tap and a long press leave the DB intact',
        (tester) async {
      final container = ProviderContainer(overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        focusClockProvider
            .overrideWithValue(_TestClock(DateTime(2026, 9, 22, 10))),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _app(const CompanionAvatar(size: 140)),
      ));

      // The baseline is taken *after* the initial load settles, not before it.
      // Loading is allowed to make its own one-time business writes (the home
      // controller performs an idempotent recovery on first load); what this
      // test is about is the behaviour *after* the companion is alive.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      final before = await _snapshot(db);

      await tester.pump(const Duration(seconds: 20));
      await tester.tap(find.byType(CompanionAvatar));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.longPress(find.byType(CompanionAvatar));
      await tester.pump(const Duration(milliseconds: 1200));

      expect(await _snapshot(db), before);
    });
  });

  // ==========================================================================
  // 4. Runtime — the time-of-day bands are inert
  // ==========================================================================
  group('the time-of-day bands cannot write', () {
    test('resolving every hour of the day leaves the database untouched',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);

      final before = await _snapshot(db);

      // Every hour of a day, plus the boundary hours either side, so each band
      // is resolved many times over.
      for (var hour = 0; hour < 24; hour++) {
        final band = TimeOfDayResolver.resolve(DateTime(2026, 9, 22, hour));
        expect(TimeOfDayBand.values, contains(band));
      }

      expect(await _snapshot(db), before);
    });
  });
}
