import 'package:drift/drift.dart';

import '../../../domain/models/rest_session.dart' as domain;
import '../app_database.dart';
import '../tables/rest_session_table.dart';

part 'rest_dao.g.dart';

/// Reads and writes rest sessions.
@DriftAccessor(tables: [RestSessions])
class RestDao extends DatabaseAccessor<AppDatabase> with _$RestDaoMixin {
  RestDao(super.db);

  Future<void> insert(domain.RestSession session) async {
    await into(restSessions).insert(
      RestSessionsCompanion(
        id: Value(session.id),
        userId: Value(session.userId),
        plannedSeconds: Value(session.plannedSeconds),
        startAt: Value(session.startAt),
        endAt: Value(session.endAt),
        status: Value(session.status.id),
        createdAt: Value(session.createdAt),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Named `updateSession` rather than `update`, because `DatabaseAccessor`
  /// already has an `update(table)` and a same-named method silently overrides
  /// it — which turns every `update(someTable)` in this class into a type error.
  Future<void> updateSession(domain.RestSession session) async {
    await (update(restSessions)..where((t) => t.id.equals(session.id))).write(
      RestSessionsCompanion(
        endAt: Value(session.endAt),
        status: Value(session.status.id),
      ),
    );
  }

  Future<domain.RestSession?> findById(String id) async {
    final row = await (select(restSessions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  /// The rest still running for this user, if there is one.
  ///
  /// One at a time, like a focus session: two rests at once is not a thing the
  /// product means, and the screen has one button.
  Future<domain.RestSession?> findRunning(String userId) async {
    final row = await (select(restSessions)
          ..where((t) => t.userId.equals(userId) & t.status.equals('running'))
          ..orderBy([(t) => OrderingTerm.desc(t.startAt)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  /// Rests that started within `[from, to)`, oldest first — the timeline's rows.
  Future<List<domain.RestSession>> findBetween(
    String userId,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await (select(restSessions)
          ..where((t) =>
              t.userId.equals(userId) &
              t.startAt.isBiggerOrEqualValue(from) &
              t.startAt.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.asc(t.startAt)]))
        .get();
    return rows.map(_map).toList();
  }

  /// Total rested seconds in `[from, to)`, counting only the time that happened.
  ///
  /// A running rest has no end yet and is left out: it has not finished being a
  /// fact.
  Future<int> totalSecondsBetween(
    String userId,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await findBetween(userId, from, to);
    var total = 0;
    for (final row in rows) {
      final end = row.endAt;
      if (end == null) continue;
      total += end.difference(row.startAt).inSeconds.clamp(0, 1 << 31);
    }
    return total;
  }

  domain.RestSession _map(RestSession row) => domain.RestSession(
        id: row.id,
        userId: row.userId,
        plannedSeconds: row.plannedSeconds,
        startAt: row.startAt,
        endAt: row.endAt,
        status: domain.RestStatus.fromId(row.status),
        createdAt: row.createdAt,
      );
}
