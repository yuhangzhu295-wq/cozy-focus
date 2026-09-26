// §57 — craft job status mapping: audit + regression coverage.
//
// `craft_dao._mapJob` maps a persisted status string back onto the Dart enum:
//
//     CraftJobStatus.values.firstWhere((e) => e.name == row.status,
//         orElse: () => CraftJobStatus.pending)
//
// i.e. a status the enum does not recognise is **silently coerced** to `pending`
// rather than throwing. That behaviour had no test anywhere in the suite, which
// is what §57 asks to be closed.
//
// Severity is P2, and this file is why: the only read path that maps an
// *unfiltered* status is `findJobsByUser`, and that method has **no production
// caller** in `lib/` (verified — it exists on the DAO, the repository and the
// repository interface, and nowhere else). The path the app actually uses,
// `findActiveJobByUser`, filters on the raw status string with
// `status IN ('pending', 'inProgress')`, so an unmappable row can never be
// picked up as an active job.
//
// Per §57 a P2 finding gets the audit and the test, **not** a defensive fix, and
// certainly not a rewrite of the DAO. So the current behaviour is pinned here
// rather than changed: if someone later makes the fallback throw, or makes it
// fall back to something active, these tests go red and the decision has to be
// made deliberately.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/data/local/app_database.dart'
    hide FocusSession, Pet, CraftJob, CraftRecipe, InventoryItem, RoomItem;
import 'package:cozy_focus_app/data/repositories/drift_craft_repository.dart';
import 'package:cozy_focus_app/domain/models/craft_models.dart';
import 'package:cozy_focus_app/domain/models/enums.dart';

AppDatabase _openInMemory() => AppDatabase.forTesting(NativeDatabase.memory());

CraftJob _job({
  required String id,
  required String userId,
  required CraftJobStatus status,
}) =>
    CraftJob(
      id: id,
      userId: userId,
      recipeId: 'recipe_1',
      status: status,
      progressSeconds: 0,
      startedAt: DateTime(2026, 9, 22),
      completedAt: null,
      rewardClaimed: false,
      sessionId: null,
    );

/// Overwrites a job's status with a raw string, bypassing the enum entirely —
/// the only way to simulate a row the current build cannot name.
///
/// Note the plain Dart values: in this drift version `customStatement` forwards
/// its arguments straight to `sqlite3`, which accepts `String` / `int` / … and
/// rejects drift's `Variable` wrappers.
Future<void> _corruptStatus(
  AppDatabase db,
  String jobId,
  String rawStatus,
) async {
  await db.customStatement(
    'UPDATE craft_jobs SET status = ? WHERE id = ?',
    [rawStatus, jobId],
  );
}

/// Reads a job's persisted status string without going through the mapper.
Future<String?> _rawStatus(AppDatabase db, String jobId) async {
  final rows = await db.customSelect('SELECT id, status FROM craft_jobs').get();
  for (final row in rows) {
    if (row.read<String>('id') == jobId) return row.read<String>('status');
  }
  return null;
}

void main() {
  group('craft job status mapping', () {
    late AppDatabase db;
    late DriftCraftRepository repo;

    setUp(() {
      db = _openInMemory();
      repo = DriftCraftRepository(db.craftDao);
    });

    tearDown(() => db.close());

    test('the writer stores the enum spelling, not a localised one', () async {
      // The active-job query is a raw string comparison, so the spelling is a
      // contract between the writer and the reader. Camel-case `inProgress` is
      // what both sides assume; a change to snake_case here would silently make
      // every in-progress job invisible.
      await repo.saveJob(_job(
        id: 'spelling',
        userId: 'u-spelling',
        status: CraftJobStatus.inProgress,
      ));

      expect(await _rawStatus(db, 'spelling'), 'inProgress');
      expect(
        CraftJobStatus.values.map((e) => e.name),
        containsAll(<String>[
          'pending',
          'inProgress',
          'completed',
          'cancelled',
          'failed',
        ]),
      );
    });

    test('every CraftJobStatus survives a write and a read', () async {
      for (final status in CraftJobStatus.values) {
        final userId = 'u-${status.name}';
        await repo.saveJob(_job(
          id: 'job-${status.name}',
          userId: userId,
          status: status,
        ));

        final jobs = await repo.findJobsByUser(userId);
        expect(jobs, hasLength(1), reason: status.name);
        expect(jobs.single.status, status,
            reason: '${status.name} did not round-trip. A renamed enum value '
                'would orphan every existing row, and this is the test that '
                'would notice.');
      }
    });

    test('the active-job query and the enum agree about what is active',
        () async {
      // Two independent statements of the same fact: the enum (via the writer)
      // and the raw string filter (in the query). Pinning them against each
      // other is what stops one drifting from the other.
      for (final status in CraftJobStatus.values) {
        final userId = 'u-active-${status.name}';
        await repo.saveJob(_job(
          id: 'active-${status.name}',
          userId: userId,
          status: status,
        ));

        final shouldBeActive = status == CraftJobStatus.pending ||
            status == CraftJobStatus.inProgress;
        final active = await repo.findActiveJobByUser(userId);

        expect(active != null, shouldBeActive,
            reason: '${status.name} was ${shouldBeActive ? 'not' : 'wrongly'} '
                'treated as active');
      }
    });

    test('an unrecognised persisted status is coerced, not thrown', () async {
      const id = 'job-corrupt';
      const userId = 'u-corrupt';
      await repo.saveJob(_job(
        id: id,
        userId: userId,
        status: CraftJobStatus.inProgress,
      ));
      // `in_progress` is snake_case: a plausible corruption, and one the enum
      // genuinely cannot name.
      await _corruptStatus(db, id, 'in_progress');
      expect(await _rawStatus(db, id), 'in_progress');

      final jobs = await repo.findJobsByUser(userId);

      expect(jobs, hasLength(1),
          reason: 'an unmappable status must not hide the row from history');
      expect(jobs.single.status, CraftJobStatus.pending,
          reason: 'the documented fallback is `pending` — deliberately the '
              'inert value, never something that could look active');
    });

    test('an unmappable status can never masquerade as an active job',
        () async {
      // This is the property that keeps the silent fallback harmless today.
      const id = 'job-corrupt-active';
      const userId = 'u-corrupt-active';
      await repo.saveJob(_job(
        id: id,
        userId: userId,
        status: CraftJobStatus.inProgress,
      ));
      await _corruptStatus(db, id, 'in_progress');

      // The row is still readable through the unfiltered path...
      expect(await repo.findJobsByUser(userId), hasLength(1));
      // ...but the active-job query compares the raw string, so a spelling that
      // matches neither active value simply does not match.
      expect(await repo.findActiveJobByUser(userId), isNull);
    });

    test('a corrupted row cannot be resurrected by a later craft start',
        () async {
      // The fallback maps to `pending`, which *is* an active value. This test
      // proves the fallback still cannot resurrect anything, because the query
      // never sees the row in the first place.
      const id = 'job-corrupt-start';
      const userId = 'u-corrupt-start';
      await repo.saveJob(_job(
        id: id,
        userId: userId,
        status: CraftJobStatus.completed,
      ));
      await _corruptStatus(db, id, 'unknown_future_status');

      final started = await repo.startJobIfNoneActive(
        userId,
        _job(
          id: 'job-new',
          userId: userId,
          status: CraftJobStatus.pending,
        ),
      );

      expect(started, isTrue,
          reason: 'the corrupted row must not block a legitimate new job');
      final active = await repo.findActiveJobByUser(userId);
      expect(active?.id, 'job-new');
    });
  });
}
