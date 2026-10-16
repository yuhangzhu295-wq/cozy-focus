import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cozy_focus_app/data/local/app_database.dart' hide Pet;
import 'package:cozy_focus_app/data/local/daos/sync_outbox_dao.dart';
import 'package:cozy_focus_app/data/repositories/drift_craft_repository.dart';
import 'package:cozy_focus_app/data/repositories/drift_sync_outbox_repository.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';
import 'package:cozy_focus_app/domain/services/sync_engine.dart';
import 'package:cozy_focus_app/presentation/navigation/app_router.dart';

/// D1, D2 and D7 — the three decisions that needed **no code change**, pinned.
///
/// Each of these was already true of the code; the owner has now confirmed the
/// behaviour is the intended one rather than an unfinished feature. A decision
/// that is only written in a document drifts the moment someone adds a shop
/// page, so the parts that are mechanically checkable are checked here.
///
/// What these tests **cannot** prove is stated with each one. They are guards
/// against silent reintroduction, not proofs of product intent.
void main() {
  group('D1 — crafting costs time, not materials', () {
    late AppDatabase db;
    late DriftCraftRepository craftRepo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      craftRepo = DriftCraftRepository(db.craftDao);
      await db.craftDao.findAllRecipes();
    });

    tearDown(() async => db.close());

    test('every seeded recipe has an empty material cost', () async {
      final recipes = await craftRepo.findAllRecipes();
      expect(recipes, isNotEmpty,
          reason: 'the seed did not run, so this would assert nothing');
      for (final r in recipes) {
        expect(r.ingredientCosts, isEmpty,
            reason:
                '${r.id} now costs ${r.ingredientCosts}, which introduces a '
                'material economy D1 declined');
      }
    });

    test('a recipe costs exactly the focus minutes it declares', () async {
      // The decision's positive half: time is the whole cost. If a future recipe
      // needed materials this would still pass, so the check above is the one
      // that carries D1; this one pins that time is present and positive.
      final recipes = await craftRepo.findAllRecipes();
      for (final r in recipes) {
        expect(r.requiredMinutes, greaterThan(0),
            reason: '${r.id} costs neither time nor materials');
      }
    });
  });

  group('D2 — coins accumulate, nothing spends them', () {
    test('no route is a shop, store, mall or exchange', () {
      // D2 keeps the ledger and declines a sink. A sink would need a route, so
      // the absence of one is the checkable half. It cannot prove no *future*
      // in-page redemption is added without a route, which is why the decision
      // is also recorded in P25.
      final router = createAppRouter();
      final paths = router.configuration.routes.expand(_allPaths).toList();
      expect(paths, isNotEmpty, reason: 'the router read as empty');
      expect(paths.length, greaterThan(30),
          reason: 'only ${paths.length} paths were read, so the traversal is '
              'not walking the whole router and the check below is too narrow');

      const commerce = ['shop', 'store', 'mall', 'exchange', 'redeem', 'buy'];
      for (final path in paths) {
        for (final word in commerce) {
          expect(path.toLowerCase(), isNot(contains(word)),
              reason:
                  'route "$path" looks like a coin sink, which D2 declined');
        }
      }
    });
  });

  group('D7 — local-first, and nothing claims to have synced', () {
    late AppDatabase db;
    late SyncOutboxDao dao;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = db.syncOutboxDao;
    });

    tearDown(() async => db.close());

    test('the engine reports itself offline', () {
      final engine = LocalOnlySyncEngine(
        outboxRepo: DriftSyncOutboxRepository(dao),
      );
      expect(engine.isOnline, isFalse,
          reason: 'claiming connectivity would be the first half of a fake '
              'synced state');
    });

    test('a flushed entry is still pending, because flush does not sync',
        () async {
      // The guard that matters: the outbox has a `synced` status and a
      // markSynced() method, so the machinery to claim success exists. This pins
      // that running the real flush() leaves the record pending — no code path
      // marks it synced, so no screen can report a sync that did not happen.
      final engine = LocalOnlySyncEngine(
        outboxRepo: DriftSyncOutboxRepository(dao),
      );
      await engine.enqueue(
        tableName: 'focus_sessions',
        recordId: 'session-1',
        operation: 'insert',
        payload: const {'id': 'session-1'},
      );

      expect(await dao.findPending(), hasLength(1));

      await engine.flush();

      final stillPending = await dao.findPending();
      expect(stillPending, hasLength(1),
          reason: 'flush() completed the outbox, which would let the UI show a '
              'synced state for a sync that never happened');
      expect(stillPending.single.status, SyncStatus.pending);
    });
  });
}

/// Every path under a route, including nested children.
Iterable<String> _allPaths(RouteBase route) sync* {
  if (route is GoRoute) {
    yield route.path;
    for (final child in route.routes) {
      yield* _allPaths(child);
    }
  }
}
